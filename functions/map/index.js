const {randomUUID} = require("node:crypto");
const {FieldValue} = require("firebase-admin/firestore");

const META_COLLECTION = "worldMap";
const META_DOCUMENT = "meta";
const SECTORS_COLLECTION = "worldMapSectors";
const CANDIDATES_COLLECTION = "worldMapSpawnCandidates";
const BATCH_SIZE = 400;

const DEFAULT_CONFIG = Object.freeze({
  letterMin: "A",
  letterMax: "Z",
  initialNumberMin: 1,
  initialNumberMax: 50,
  zonesPerSector: 5,
  spawnLetterMin: "D",
  spawnLetterMax: "W",
  spawnOriginLetter: "M",
  spawnOriginNumber: 25,
  initialSpawnNumberMin: 10,
  initialSpawnNumberMax: 40,
  minimumPlayerDistance: 2,
  priorityAlpha: 2,
  subsequentSpawnWindowSize: 40,
});

function letterIndex(letter) {
  if (typeof letter !== "string" || !/^[A-Z]$/.test(letter)) {
    throw new Error(`Invalid map letter: ${letter}`);
  }
  return letter.charCodeAt(0) - 65;
}

function indexLetter(index) {
  if (!Number.isInteger(index) || index < 0 || index > 25) {
    throw new Error(`Invalid map letter index: ${index}`);
  }
  return String.fromCharCode(65 + index);
}

function sectorId(letter, number) {
  if (!Number.isInteger(number) || number < 1) {
    throw new Error(`Invalid sector number: ${number}`);
  }
  return `${letter}${number}`;
}

function parseSectorId(value) {
  const match = /^([A-Z])(\d+)$/.exec(String(value || "").trim());
  if (!match) throw new Error(`Invalid sector id: ${value}`);
  const number = Number(match[2]);
  if (!Number.isSafeInteger(number) || number < 1) {
    throw new Error(`Invalid sector id: ${value}`);
  }
  return {letter: match[1], number};
}

function sectorDistance(a, b) {
  const dx = letterIndex(a.letter) - letterIndex(b.letter);
  const dy = a.number - b.number;
  return Math.sqrt(dx * dx + dy * dy);
}

function proximityWeight(coordinate, config = DEFAULT_CONFIG) {
  const distance = sectorDistance(coordinate, {
    letter: config.spawnOriginLetter,
    number: config.spawnOriginNumber,
  });
  return 1 / Math.pow(1 + distance, config.priorityAlpha);
}

function isLetterInRange(letter, minLetter, maxLetter) {
  const value = letterIndex(letter);
  return value >= letterIndex(minLetter) && value <= letterIndex(maxLetter);
}

function forbiddenOffsets(minimumDistance = DEFAULT_CONFIG.minimumPlayerDistance) {
  const radius = Math.ceil(minimumDistance);
  const result = [];
  for (let dx = -radius; dx <= radius; dx += 1) {
    for (let dy = -radius; dy <= radius; dy += 1) {
      if (Math.sqrt(dx * dx + dy * dy) <= minimumDistance) {
        result.push({dx, dy});
      }
    }
  }
  return result;
}

function neighbourCoordinates(coordinate, config) {
  const minLetterIndex = letterIndex(config.letterMin);
  const maxLetterIndex = letterIndex(config.letterMax);
  const baseLetterIndex = letterIndex(coordinate.letter);

  return forbiddenOffsets(config.minimumPlayerDistance)
    .map(({dx, dy}) => ({
      letterIndex: baseLetterIndex + dx,
      number: coordinate.number + dy,
    }))
    .filter(({letterIndex: li, number}) =>
      li >= minLetterIndex &&
      li <= maxLetterIndex &&
      number >= config.initialNumberMin,
    )
    .map(({letterIndex: li, number}) => ({
      letter: indexLetter(li),
      number,
    }));
}

function metaRef(db) {
  return db.collection(META_COLLECTION).doc(META_DOCUMENT);
}

function sectorRef(db, id) {
  return db.collection(SECTORS_COLLECTION).doc(id);
}

function candidateRef(db, id) {
  return db.collection(CANDIDATES_COLLECTION).doc(id);
}

function normalizeConfig(overrides = {}) {
  const config = {...DEFAULT_CONFIG, ...overrides};

  const integerFields = [
    "initialNumberMin",
    "initialNumberMax",
    "zonesPerSector",
    "spawnOriginNumber",
    "initialSpawnNumberMin",
    "initialSpawnNumberMax",
    "subsequentSpawnWindowSize",
  ];
  for (const field of integerFields) {
    if (!Number.isInteger(config[field])) {
      throw new Error(`${field} must be an integer.`);
    }
  }

  if (config.initialNumberMin < 1) {
    throw new Error("initialNumberMin must be >= 1.");
  }
  if (config.initialNumberMax < config.initialNumberMin) {
    throw new Error("initialNumberMax must be >= initialNumberMin.");
  }
  if (config.initialSpawnNumberMin < config.initialNumberMin) {
    throw new Error("initialSpawnNumberMin must be inside the map.");
  }
  if (config.initialSpawnNumberMax < config.initialSpawnNumberMin) {
    throw new Error("initialSpawnNumberMax must be >= initialSpawnNumberMin.");
  }
  if (config.zonesPerSector < 1) {
    throw new Error("zonesPerSector must be >= 1.");
  }
  if (!(config.minimumPlayerDistance >= 0)) {
    throw new Error("minimumPlayerDistance must be >= 0.");
  }
  if (!(config.priorityAlpha > 0)) {
    throw new Error("priorityAlpha must be > 0.");
  }
  if (config.subsequentSpawnWindowSize < 1) {
    throw new Error("subsequentSpawnWindowSize must be >= 1.");
  }

  for (const field of [
    "letterMin",
    "letterMax",
    "spawnLetterMin",
    "spawnLetterMax",
    "spawnOriginLetter",
  ]) {
    letterIndex(config[field]);
  }

  if (!isLetterInRange(
    config.spawnLetterMin,
    config.letterMin,
    config.letterMax,
  ) || !isLetterInRange(
    config.spawnLetterMax,
    config.letterMin,
    config.letterMax,
  )) {
    throw new Error("Spawn letters must be inside the map letter range.");
  }
  if (letterIndex(config.spawnLetterMin) > letterIndex(config.spawnLetterMax)) {
    throw new Error("spawnLetterMin must not be after spawnLetterMax.");
  }
  if (!isLetterInRange(
    config.spawnOriginLetter,
    config.spawnLetterMin,
    config.spawnLetterMax,
  )) {
    throw new Error("spawnOriginLetter must be inside the spawn letter range.");
  }

  return config;
}

async function deleteCollection(db, collectionName) {
  while (true) {
    const snapshot = await db.collection(collectionName).limit(BATCH_SIZE).get();
    if (snapshot.empty) return;
    const batch = db.batch();
    for (const doc of snapshot.docs) batch.delete(doc.ref);
    await batch.commit();
  }
}

async function commitWriters(db, writers) {
  for (let start = 0; start < writers.length; start += BATCH_SIZE) {
    const batch = db.batch();
    const slice = writers.slice(start, start + BATCH_SIZE);
    for (const entry of slice) {
      if (entry.type === "set") batch.set(entry.ref, entry.data, entry.options || {});
      else if (entry.type === "delete") batch.delete(entry.ref);
      else throw new Error(`Unknown batch writer type: ${entry.type}`);
    }
    await batch.commit();
  }
}

function sectorDocument(letter, number, config) {
  const coordinate = {letter, number};
  return {
    id: sectorId(letter, number),
    letter,
    letterIndex: letterIndex(letter),
    number,
    status: "UNGENERATED",
    type: null,
    playerId: null,
    zones: [],
    spawnPriority: proximityWeight(coordinate, config),
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
}

function canEverBeSpawnCandidate(letter, number, config) {
  return isLetterInRange(letter, config.spawnLetterMin, config.spawnLetterMax) &&
    number >= config.initialSpawnNumberMin;
}

function candidateDocument(letter, number, config) {
  return {
    id: sectorId(letter, number),
    letter,
    letterIndex: letterIndex(letter),
    number,
    priority: proximityWeight({letter, number}, config),
    createdAt: FieldValue.serverTimestamp(),
  };
}

async function createMapRange(db, fromNumber, toNumber, config) {
  if (toNumber < fromNumber) return {sectorsCreated: 0, candidatesCreated: 0};

  let writers = [];
  let sectorsCreated = 0;
  let candidatesCreated = 0;

  const flush = async () => {
    if (writers.length === 0) return;
    await commitWriters(db, writers);
    writers = [];
  };

  for (let number = fromNumber; number <= toNumber; number += 1) {
    for (
      let li = letterIndex(config.letterMin);
      li <= letterIndex(config.letterMax);
      li += 1
    ) {
      const letter = indexLetter(li);
      const id = sectorId(letter, number);
      writers.push({
        type: "set",
        ref: sectorRef(db, id),
        data: sectorDocument(letter, number, config),
      });
      sectorsCreated += 1;

      if (canEverBeSpawnCandidate(letter, number, config)) {
        writers.push({
          type: "set",
          ref: candidateRef(db, id),
          data: candidateDocument(letter, number, config),
        });
        candidatesCreated += 1;
      }

      if (writers.length >= BATCH_SIZE) {
        await flush();
      }
    }
  }

  await flush();
  return {sectorsCreated, candidatesCreated};
}

async function initializeMap(db, options = {}) {
  const config = normalizeConfig(options.config || {});
  const ref = metaRef(db);
  const existing = await ref.get();

  if (existing.exists && !options.force) {
    throw new Error(
      "World map is already initialized. Use force only when you intend to reset it.",
    );
  }

  if (options.force) {
    await deleteCollection(db, CANDIDATES_COLLECTION);
    await deleteCollection(db, SECTORS_COLLECTION);
    await ref.delete();
  }

  await ref.set({
    schemaVersion: 1,
    initializationStatus: "INITIALIZING",
    ...config,
    currentMapNumberMax: config.initialNumberMax,
    activeSpawnNumberMin: config.initialSpawnNumberMin,
    activeSpawnNumberMax: config.initialSpawnNumberMax,
    simulatedPlayerSequence: 0,
    initializedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  const created = await createMapRange(
    db,
    config.initialNumberMin,
    config.initialNumberMax,
    config,
  );

  await ref.update({
    initializationStatus: "READY",
    updatedAt: FieldValue.serverTimestamp(),
  });

  return {
    initialized: true,
    config,
    currentMapNumberMax: config.initialNumberMax,
    activeSpawnNumberMin: config.initialSpawnNumberMin,
    activeSpawnNumberMax: config.initialSpawnNumberMax,
    ...created,
  };
}

async function requiredMeta(db) {
  const snapshot = await metaRef(db).get();
  if (!snapshot.exists) {
    throw new Error("World map is not initialized. Run map init first.");
  }
  const data = snapshot.data() || {};
  if (data.initializationStatus !== "READY") {
    throw new Error(
      "World map initialization is incomplete. Re-run map init --force to rebuild it.",
    );
  }
  return {snapshot, data};
}

function configFromMeta(meta) {
  return normalizeConfig({
    letterMin: meta.letterMin,
    letterMax: meta.letterMax,
    initialNumberMin: meta.initialNumberMin,
    initialNumberMax: meta.initialNumberMax,
    zonesPerSector: meta.zonesPerSector,
    spawnLetterMin: meta.spawnLetterMin,
    spawnLetterMax: meta.spawnLetterMax,
    spawnOriginLetter: meta.spawnOriginLetter,
    spawnOriginNumber: meta.spawnOriginNumber,
    initialSpawnNumberMin: meta.initialSpawnNumberMin,
    initialSpawnNumberMax: meta.initialSpawnNumberMax,
    minimumPlayerDistance: meta.minimumPlayerDistance,
    priorityAlpha: meta.priorityAlpha,
    subsequentSpawnWindowSize: meta.subsequentSpawnWindowSize,
  });
}

async function expandMap(db, newMaximum) {
  if (!Number.isInteger(newMaximum) || newMaximum < 1) {
    throw new Error("newMaximum must be a positive integer.");
  }

  const {data: meta} = await requiredMeta(db);
  const config = configFromMeta(meta);
  const currentMaximum = Number(meta.currentMapNumberMax);

  if (newMaximum <= currentMaximum) {
    return {
      expanded: false,
      currentMapNumberMax: currentMaximum,
      sectorsCreated: 0,
      candidatesCreated: 0,
    };
  }

  const created = await createMapRange(
    db,
    currentMaximum + 1,
    newMaximum,
    config,
  );

  await metaRef(db).update({
    currentMapNumberMax: newMaximum,
    updatedAt: FieldValue.serverTimestamp(),
  });

  return {
    expanded: true,
    previousMapNumberMax: currentMaximum,
    currentMapNumberMax: newMaximum,
    ...created,
  };
}

function activeWindowKey(meta) {
  return `${Number(meta.activeSpawnNumberMin)}:${Number(meta.activeSpawnNumberMax)}`;
}

function clearCandidateCache(cache) {
  if (!cache || typeof cache !== "object") return;
  cache.windowKey = null;
  cache.docs = null;
}

function removeCandidateIdsFromCache(cache, ids) {
  if (!cache || !Array.isArray(cache.docs) || !ids || ids.size === 0) return;
  cache.docs = cache.docs.filter((doc) => !ids.has(doc.id));
}

async function candidateDocsForActiveWindow(db, meta, cache = null) {
  const windowKey = activeWindowKey(meta);
  if (
    cache &&
    cache.windowKey === windowKey &&
    Array.isArray(cache.docs)
  ) {
    return cache.docs;
  }

  const snapshot = await db.collection(CANDIDATES_COLLECTION)
    .where("number", ">=", Number(meta.activeSpawnNumberMin))
    .where("number", "<=", Number(meta.activeSpawnNumberMax))
    .select("letter", "number", "priority")
    .get();

  if (cache) {
    cache.windowKey = windowKey;
    cache.docs = snapshot.docs;
  }
  return snapshot.docs;
}

function randomUnit() {
  const buffer = Buffer.from(randomUUID().replaceAll("-", ""), "hex");
  const integer = buffer.readUIntBE(0, 6);
  return integer / 0x1000000000000;
}

function chooseWeightedCandidate(docs, random = randomUnit) {
  if (!Array.isArray(docs) || docs.length === 0) return null;
  const weighted = docs
    .map((doc) => ({doc, weight: Number(doc.data().priority)}))
    .filter(({weight}) => Number.isFinite(weight) && weight > 0);
  if (weighted.length === 0) return null;

  const total = weighted.reduce((sum, entry) => sum + entry.weight, 0);
  let target = random() * total;
  for (const entry of weighted) {
    target -= entry.weight;
    if (target <= 0) return entry.doc;
  }
  return weighted[weighted.length - 1].doc;
}

function placeholderPlayerZones(playerId, zonesPerSector) {
  return Array.from({length: zonesPerSector}, (_, index) => ({
    index: index + 1,
    type: index === 0 ? "PLAYER_BUNKER" : "EMPTY",
    playerId: index === 0 ? playerId : null,
    status: "RESOLVED",
  }));
}

async function advanceSpawnWindow(db, meta) {
  const size = Number(meta.subsequentSpawnWindowSize);
  const nextMin = Number(meta.activeSpawnNumberMax) + 1;
  const nextMax = Number(meta.activeSpawnNumberMax) + size;

  if (Number(meta.currentMapNumberMax) < nextMax) {
    await expandMap(db, nextMax);
  }

  await metaRef(db).update({
    activeSpawnNumberMin: nextMin,
    activeSpawnNumberMax: nextMax,
    updatedAt: FieldValue.serverTimestamp(),
  });

  return {activeSpawnNumberMin: nextMin, activeSpawnNumberMax: nextMax};
}

async function allocatePlayerSector(db, options = {}) {
  const providedPlayerId = typeof options.playerId === "string" &&
    options.playerId.trim()
    ? options.playerId.trim()
    : null;
  const maxAttempts = options.maxAttempts || 100;
  const candidateCache = options.candidateCache &&
    typeof options.candidateCache === "object"
    ? options.candidateCache
    : null;

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    const {data: meta} = await requiredMeta(db);
    const config = configFromMeta(meta);
    const candidateDocs = await candidateDocsForActiveWindow(
      db,
      meta,
      candidateCache,
    );

    if (candidateDocs.length === 0) {
      await advanceSpawnWindow(db, meta);
      clearCandidateCache(candidateCache);
      continue;
    }

    const selectedDoc = chooseWeightedCandidate(candidateDocs);
    if (!selectedDoc) {
      throw new Error("Spawn candidate pool contains no positive priorities.");
    }

    const selected = selectedDoc.data();
    const selectedCoordinate = {letter: selected.letter, number: selected.number};
    const allForbiddenCoordinates = neighbourCoordinates(selectedCoordinate, config);
    const selectedId = selectedDoc.id;
    const nearbyCoordinates = allForbiddenCoordinates.filter((coordinate) =>
      sectorId(coordinate.letter, coordinate.number) !== selectedId,
    );
    const nearbySectorRefs = nearbyCoordinates.map((coordinate) =>
      sectorRef(db, sectorId(coordinate.letter, coordinate.number)),
    );
    const candidateRefsToDelete = allForbiddenCoordinates.map((coordinate) =>
      candidateRef(db, sectorId(coordinate.letter, coordinate.number)),
    );
    const invalidatedCandidateIds = new Set(
      allForbiddenCoordinates.map((coordinate) =>
        sectorId(coordinate.letter, coordinate.number),
      ),
    );
    const selectedSectorRef = sectorRef(db, selectedId);

    const result = await db.runTransaction(async (transaction) => {
      const snapshots = await transaction.getAll(
        metaRef(db),
        selectedDoc.ref,
        selectedSectorRef,
        ...nearbySectorRefs,
      );
      const [
        transactionMeta,
        selectedCandidate,
        selectedSector,
        ...nearbySectors
      ] = snapshots;
      const currentMeta = transactionMeta.data() || {};

      if (!selectedCandidate.exists || !selectedSector.exists) {
        return {retry: true};
      }

      if (
        selected.number < Number(currentMeta.activeSpawnNumberMin) ||
        selected.number > Number(currentMeta.activeSpawnNumberMax)
      ) {
        return {retry: true};
      }

      const sectorData = selectedSector.data() || {};
      if (sectorData.status !== "UNGENERATED") {
        transaction.delete(selectedDoc.ref);
        return {retry: true};
      }

      if (nearbySectors.some((snapshot) =>
        snapshot.exists && snapshot.data()?.type === "PLAYER_BUNKER",
      )) {
        transaction.delete(selectedDoc.ref);
        return {retry: true};
      }

      const sequence = Number(currentMeta.simulatedPlayerSequence || 0) +
        (providedPlayerId ? 0 : 1);
      const playerId = providedPlayerId ||
        `sim-player-${String(sequence).padStart(6, "0")}`;

      transaction.set(selectedSectorRef, {
        ...sectorData,
        status: "POPULATED",
        type: "PLAYER_BUNKER",
        playerId,
        zones: placeholderPlayerZones(playerId, config.zonesPerSector),
        populatedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      // No candidate reads are required here. Deleting a missing document is
      // harmless, and all forbidden coordinates are known from geometry.
      for (const ref of candidateRefsToDelete) {
        transaction.delete(ref);
      }

      transaction.set(metaRef(db), {
        ...(providedPlayerId ? {} : {simulatedPlayerSequence: sequence}),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});

      return {
        retry: false,
        playerId,
        sectorId: selectedId,
        letter: selected.letter,
        number: selected.number,
        priority: Number(selected.priority),
        invalidatedCandidateIds: [...invalidatedCandidateIds],
      };
    });

    if (result.retry) {
      clearCandidateCache(candidateCache);
      continue;
    }

    removeCandidateIdsFromCache(candidateCache, invalidatedCandidateIds);
    return result;
  }

  throw new Error(`Unable to allocate a player sector after ${maxAttempts} attempts.`);
}

async function addSimulatedPlayers(db, count) {
  if (!Number.isInteger(count) || count < 1) {
    throw new Error("count must be a positive integer.");
  }
  if (count > 10000) {
    throw new Error("Refusing to add more than 10000 simulated players in one command.");
  }

  // A batch simulation is still strictly one player at a time. The only thing
  // reused is the already-downloaded candidate pool for the active window.
  // Each successful allocation removes its forbidden cells from this cache,
  // while every player still gets its own Firestore transaction.
  const candidateCache = {};
  const added = [];
  for (let index = 0; index < count; index += 1) {
    added.push(await allocatePlayerSector(db, {candidateCache}));
  }
  return added;
}

async function markSectorResolved(db, id, resolution) {
  const parsed = parseSectorId(id);
  const ref = sectorRef(db, id);
  const zones = Array.isArray(resolution?.zones) ? resolution.zones : [];
  let changed = false;

  await db.runTransaction(async (transaction) => {
    const current = await transaction.get(ref);
    if (!current.exists) throw new Error(`Sector ${id} does not exist.`);
    if (current.data()?.status === "POPULATED") return;

    transaction.set(ref, {
      ...current.data(),
      status: "POPULATED",
      type: resolution?.type || "UNKNOWN",
      zones,
      populatedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.delete(candidateRef(db, sectorId(parsed.letter, parsed.number)));
    changed = true;
  });

  return {changed, sectorId: id};
}

function serializeFirestoreValue(value) {
  if (value && typeof value.toDate === "function") {
    return value.toDate().toISOString();
  }
  if (Array.isArray(value)) return value.map(serializeFirestoreValue);
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value).map(([key, entry]) => [key, serializeFirestoreValue(entry)]),
    );
  }
  return value;
}

async function exportMap(db) {
  const {data: meta} = await requiredMeta(db);
  const [sectorSnapshot, candidateSnapshot] = await Promise.all([
    db.collection(SECTORS_COLLECTION).get(),
    // Only candidate document IDs are needed for the export. Avoid downloading
    // their priority/coordinate fields again on large maps.
    db.collection(CANDIDATES_COLLECTION).select().get(),
  ]);

  const candidateIds = new Set(candidateSnapshot.docs.map((doc) => doc.id));
  const sectors = sectorSnapshot.docs
    .map((doc) => ({
      ...serializeFirestoreValue(doc.data()),
      isSpawnCandidate: candidateIds.has(doc.id),
    }))
    .sort((a, b) => a.number - b.number || a.letterIndex - b.letterIndex);

  return {
    exportedAt: new Date().toISOString(),
    meta: serializeFirestoreValue(meta),
    counts: {
      sectors: sectors.length,
      spawnCandidates: candidateSnapshot.size,
      playerBunkers: sectors.filter((sector) => sector.type === "PLAYER_BUNKER").length,
      populated: sectors.filter((sector) => sector.status === "POPULATED").length,
    },
    sectors,
  };
}

module.exports = {
  CANDIDATES_COLLECTION,
  DEFAULT_CONFIG,
  META_COLLECTION,
  META_DOCUMENT,
  SECTORS_COLLECTION,
  addSimulatedPlayers,
  allocatePlayerSector,
  chooseWeightedCandidate,
  expandMap,
  exportMap,
  forbiddenOffsets,
  initializeMap,
  letterIndex,
  markSectorResolved,
  neighbourCoordinates,
  parseSectorId,
  proximityWeight,
  sectorDistance,
  sectorId,
};
