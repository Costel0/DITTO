const {randomUUID} = require("node:crypto");
const {FieldValue} = require("firebase-admin/firestore");

const META_COLLECTION = "worldMap";
const META_DOCUMENT = "meta";
const SECTORS_COLLECTION = "worldMapSectors";
const SPAWN_CHUNKS_COLLECTION = "worldMapSpawnChunks";
const LEGACY_CANDIDATES_COLLECTION = "worldMapSpawnCandidates";
const MAP_SCHEMA_VERSION = 2;
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
  spawnChunkWidth: 5,
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

function spawnChunkRef(db, id) {
  return db.collection(SPAWN_CHUNKS_COLLECTION).doc(id);
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
    "spawnChunkWidth",
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
  if (config.spawnChunkWidth < 1) {
    throw new Error("spawnChunkWidth must be >= 1.");
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

function spawnWindowForNumber(number, config = DEFAULT_CONFIG) {
  if (!Number.isInteger(number) || number < config.initialSpawnNumberMin) {
    return null;
  }

  if (number <= config.initialSpawnNumberMax) {
    return {
      min: config.initialSpawnNumberMin,
      max: config.initialSpawnNumberMax,
    };
  }

  const firstLaterNumber = config.initialSpawnNumberMax + 1;
  const offset = number - firstLaterNumber;
  const windowIndex = Math.floor(offset / config.subsequentSpawnWindowSize);
  const min = firstLaterNumber + windowIndex * config.subsequentSpawnWindowSize;
  return {
    min,
    max: min + config.subsequentSpawnWindowSize - 1,
  };
}

function spawnChunkForNumber(number, config = DEFAULT_CONFIG) {
  const window = spawnWindowForNumber(number, config);
  if (!window) return null;

  const chunkIndex = Math.floor(
    (number - window.min) / config.spawnChunkWidth,
  );
  const min = window.min + chunkIndex * config.spawnChunkWidth;
  const max = Math.min(window.max, min + config.spawnChunkWidth - 1);
  return {
    id: `${min}-${max}`,
    min,
    max,
    windowMin: window.min,
    windowMax: window.max,
  };
}

function chunksForWindow(windowMin, windowMax, config = DEFAULT_CONFIG) {
  const chunks = [];
  for (let number = windowMin; number <= windowMax;) {
    const chunk = spawnChunkForNumber(number, config);
    if (!chunk || chunk.windowMin !== windowMin || chunk.windowMax !== windowMax) {
      throw new Error(`Invalid spawn window: ${windowMin}-${windowMax}.`);
    }
    chunks.push(chunk);
    number = chunk.max + 1;
  }
  return chunks;
}

function canEverBeSpawnCandidate(letter, number, config) {
  return isLetterInRange(letter, config.spawnLetterMin, config.spawnLetterMax) &&
    number >= config.initialSpawnNumberMin;
}

function candidateChunkForCoordinate(coordinate, config) {
  if (!canEverBeSpawnCandidate(coordinate.letter, coordinate.number, config)) {
    return null;
  }
  return spawnChunkForNumber(coordinate.number, config);
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

function normalizeCandidates(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const result = {};
  for (const [id, rawWeight] of Object.entries(value)) {
    const weight = Number(rawWeight);
    if (/^[A-Z]\d+$/.test(id) && Number.isFinite(weight) && weight > 0) {
      result[id] = weight;
    }
  }
  return result;
}

function candidateWeightSum(candidates) {
  return Object.values(candidates)
    .reduce((sum, weight) => sum + Number(weight), 0);
}

function chunkWriteData(chunk, candidates) {
  return {
    id: chunk.id,
    windowMin: chunk.windowMin,
    windowMax: chunk.windowMax,
    numberMin: chunk.min,
    numberMax: chunk.max,
    candidates,
    totalWeight: candidateWeightSum(candidates),
    candidateCount: Object.keys(candidates).length,
    updatedAt: FieldValue.serverTimestamp(),
  };
}

async function createMapRange(
  db,
  fromNumber,
  toNumber,
  config,
  blockedCandidateIds = new Set(),
) {
  if (toNumber < fromNumber) {
    return {sectorsCreated: 0, candidatesCreated: 0, chunksTouched: 0};
  }

  let writers = [];
  let sectorsCreated = 0;
  let candidatesCreated = 0;
  let chunksTouched = 0;
  let activeChunk = null;
  let activeChunkCandidates = {};
  let activeChunkCount = 0;

  const flushWriters = async () => {
    if (writers.length === 0) return;
    await commitWriters(db, writers);
    writers = [];
  };

  const flushChunk = async () => {
    if (!activeChunk || activeChunkCount === 0) {
      activeChunk = null;
      activeChunkCandidates = {};
      activeChunkCount = 0;
      return;
    }

    const ref = spawnChunkRef(db, activeChunk.id);
    const existing = await ref.get();
    const candidates = {
      ...normalizeCandidates(existing.exists ? existing.data()?.candidates : null),
      ...activeChunkCandidates,
    };
    writers.push({
      type: "set",
      ref,
      data: chunkWriteData(activeChunk, candidates),
    });
    chunksTouched += 1;
    activeChunk = null;
    activeChunkCandidates = {};
    activeChunkCount = 0;

    if (writers.length >= BATCH_SIZE) await flushWriters();
  };

  for (let number = fromNumber; number <= toNumber; number += 1) {
    const numberChunk = spawnChunkForNumber(number, config);
    if (activeChunk && (!numberChunk || activeChunk.id !== numberChunk.id)) {
      await flushChunk();
    }
    if (numberChunk && !activeChunk) activeChunk = numberChunk;

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

      if (
        numberChunk &&
        canEverBeSpawnCandidate(letter, number, config) &&
        !blockedCandidateIds.has(id)
      ) {
        const priority = proximityWeight({letter, number}, config);
        activeChunkCandidates[id] = priority;
        activeChunkCount += 1;
        candidatesCreated += 1;
      }

      if (writers.length >= BATCH_SIZE) await flushWriters();
    }

    if (numberChunk && number === numberChunk.max) {
      await flushChunk();
    }
  }

  await flushChunk();
  await flushWriters();
  return {sectorsCreated, candidatesCreated, chunksTouched};
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
    await deleteCollection(db, SPAWN_CHUNKS_COLLECTION);
    await deleteCollection(db, LEGACY_CANDIDATES_COLLECTION);
    await deleteCollection(db, SECTORS_COLLECTION);
    await ref.delete();
  }

  await ref.set({
    schemaVersion: MAP_SCHEMA_VERSION,
    initializationStatus: "INITIALIZING",
    expansionStatus: "READY",
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
  if (Number(data.schemaVersion) !== MAP_SCHEMA_VERSION) {
    throw new Error(
      `World map schema ${data.schemaVersion ?? "unknown"} is obsolete. ` +
      "Run map init --force once to rebuild the spawn index.",
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
    spawnChunkWidth: meta.spawnChunkWidth,
  });
}

async function expansionBlockedCandidateIds(
  db,
  currentMaximum,
  newMaximum,
  config,
) {
  const radius = Math.ceil(config.minimumPlayerDistance);
  if (radius <= 0) return new Set();

  const firstRelevantExistingNumber = Math.max(
    config.initialNumberMin,
    currentMaximum + 1 - radius,
  );
  const refs = [];
  for (
    let number = firstRelevantExistingNumber;
    number <= currentMaximum;
    number += 1
  ) {
    for (
      let li = letterIndex(config.letterMin);
      li <= letterIndex(config.letterMax);
      li += 1
    ) {
      refs.push(sectorRef(db, sectorId(indexLetter(li), number)));
    }
  }

  if (refs.length === 0) return new Set();
  const snapshots = await db.getAll(...refs);
  const blocked = new Set();

  for (const snapshot of snapshots) {
    if (!snapshot.exists || snapshot.data()?.type !== "PLAYER_BUNKER") continue;
    const bunker = parseSectorId(snapshot.id);
    for (const coordinate of neighbourCoordinates(bunker, config)) {
      if (
        coordinate.number > currentMaximum &&
        coordinate.number <= newMaximum &&
        canEverBeSpawnCandidate(coordinate.letter, coordinate.number, config)
      ) {
        blocked.add(sectorId(coordinate.letter, coordinate.number));
      }
    }
  }

  return blocked;
}

async function expandMap(db, newMaximum) {
  if (!Number.isInteger(newMaximum) || newMaximum < 1) {
    throw new Error("newMaximum must be a positive integer.");
  }

  const {data: initialMeta} = await requiredMeta(db);
  const config = configFromMeta(initialMeta);
  const currentMaximum = Number(initialMeta.currentMapNumberMax);

  if (newMaximum <= currentMaximum) {
    return {
      expanded: false,
      currentMapNumberMax: currentMaximum,
      sectorsCreated: 0,
      candidatesCreated: 0,
      chunksTouched: 0,
    };
  }

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(metaRef(db));
    const meta = snapshot.data() || {};
    if (meta.expansionStatus === "EXPANDING") {
      throw new Error("World map expansion is already in progress.");
    }
    if (Number(meta.currentMapNumberMax) !== currentMaximum) {
      throw new Error("World map changed while preparing expansion. Retry.");
    }
    transaction.update(metaRef(db), {
      expansionStatus: "EXPANDING",
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  try {
    const blockedCandidateIds = await expansionBlockedCandidateIds(
      db,
      currentMaximum,
      newMaximum,
      config,
    );
    const created = await createMapRange(
      db,
      currentMaximum + 1,
      newMaximum,
      config,
      blockedCandidateIds,
    );

    await metaRef(db).update({
      currentMapNumberMax: newMaximum,
      expansionStatus: "READY",
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {
      expanded: true,
      previousMapNumberMax: currentMaximum,
      currentMapNumberMax: newMaximum,
      blockedCandidatesSkipped: blockedCandidateIds.size,
      ...created,
    };
  } catch (error) {
    await metaRef(db).update({
      expansionStatus: "READY",
      updatedAt: FieldValue.serverTimestamp(),
    });
    throw error;
  }
}

function activeWindowKey(meta) {
  return `${Number(meta.activeSpawnNumberMin)}:${Number(meta.activeSpawnNumberMax)}`;
}

function chunkRecordFromSnapshot(
  snapshot,
  currentMapNumberMax = Number.MAX_SAFE_INTEGER,
) {
  const data = snapshot.data() || {};
  const candidates = Object.fromEntries(
    Object.entries(normalizeCandidates(data.candidates))
      .filter(([id]) => parseSectorId(id).number <= currentMapNumberMax),
  );
  return {
    id: snapshot.id,
    ref: snapshot.ref,
    windowMin: Number(data.windowMin),
    windowMax: Number(data.windowMax),
    numberMin: Number(data.numberMin),
    numberMax: Number(data.numberMax),
    candidates,
    totalWeight: candidateWeightSum(candidates),
    candidateCount: Object.keys(candidates).length,
  };
}

function clearCandidateCache(cache) {
  if (!cache || typeof cache !== "object") return;
  cache.windowKey = null;
  cache.chunks = null;
  cache.meta = null;
}

function updateCandidateCache(cache, updatedChunks) {
  if (!cache || !Array.isArray(cache.chunks) || !Array.isArray(updatedChunks)) {
    return;
  }
  const updates = new Map(updatedChunks.map((chunk) => [chunk.id, chunk]));
  cache.chunks = cache.chunks.map((chunk) => updates.get(chunk.id) || chunk);
}

async function chunkRecordsForActiveWindow(db, meta, config, cache = null) {
  const windowKey = activeWindowKey(meta);
  if (
    cache &&
    cache.windowKey === windowKey &&
    Array.isArray(cache.chunks)
  ) {
    return cache.chunks;
  }

  const chunks = chunksForWindow(
    Number(meta.activeSpawnNumberMin),
    Number(meta.activeSpawnNumberMax),
    config,
  );
  const snapshots = await db.getAll(
    ...chunks.map((chunk) => spawnChunkRef(db, chunk.id)),
  );
  const currentMapNumberMax = Number(meta.currentMapNumberMax);
  const records = snapshots
    .filter((snapshot) => snapshot.exists)
    .map((snapshot) => chunkRecordFromSnapshot(snapshot, currentMapNumberMax));

  if (cache) {
    cache.windowKey = windowKey;
    cache.chunks = records;
    cache.meta = meta;
  }
  return records;
}

async function metaForAllocation(db, cache) {
  if (cache?.meta && cache.windowKey === activeWindowKey(cache.meta)) {
    return cache.meta;
  }
  const {data} = await requiredMeta(db);
  if (cache) cache.meta = data;
  return data;
}

function randomUnit() {
  const buffer = Buffer.from(randomUUID().replaceAll("-", ""), "hex");
  const integer = buffer.readUIntBE(0, 6);
  return integer / 0x1000000000000;
}

function chooseWeightedEntry(entries, getWeight, random = randomUnit) {
  const weighted = entries
    .map((entry) => ({entry, weight: Number(getWeight(entry))}))
    .filter(({weight}) => Number.isFinite(weight) && weight > 0);
  if (weighted.length === 0) return null;

  const total = weighted.reduce((sum, item) => sum + item.weight, 0);
  let target = random() * total;
  for (const item of weighted) {
    target -= item.weight;
    if (target <= 0) return item.entry;
  }
  return weighted[weighted.length - 1].entry;
}

function chooseWeightedChunk(chunks, random = randomUnit) {
  return chooseWeightedEntry(chunks, (chunk) => chunk.totalWeight, random);
}

function chooseWeightedCandidate(candidates, random = randomUnit) {
  const entries = Object.entries(normalizeCandidates(candidates));
  const selected = chooseWeightedEntry(entries, ([, weight]) => weight, random);
  if (!selected) return null;
  return {id: selected[0], priority: Number(selected[1])};
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

function affectedChunkIds(coordinates, config, currentMapNumberMax) {
  const ids = new Set();
  for (const coordinate of coordinates) {
    if (coordinate.number > currentMapNumberMax) continue;
    const chunk = candidateChunkForCoordinate(coordinate, config);
    if (chunk) ids.add(chunk.id);
  }
  return [...ids];
}

function updatedChunkAfterInvalidation(snapshot, invalidatedIds) {
  const record = chunkRecordFromSnapshot(snapshot);
  const candidates = {...normalizeCandidates(snapshot.data()?.candidates)};
  for (const id of invalidatedIds) delete candidates[id];
  return {
    ...record,
    candidates,
    totalWeight: candidateWeightSum(candidates),
    candidateCount: Object.keys(candidates).length,
  };
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
    const meta = await metaForAllocation(db, candidateCache);
    if (meta.expansionStatus === "EXPANDING") {
      clearCandidateCache(candidateCache);
      throw new Error("World map expansion is in progress. Retry allocation.");
    }

    const config = configFromMeta(meta);
    const chunks = await chunkRecordsForActiveWindow(
      db,
      meta,
      config,
      candidateCache,
    );
    const selectableChunks = chunks.filter((chunk) => chunk.totalWeight > 0);

    if (selectableChunks.length === 0) {
      await advanceSpawnWindow(db, meta);
      clearCandidateCache(candidateCache);
      continue;
    }

    const selectedChunk = chooseWeightedChunk(selectableChunks);
    const selectedCandidate = selectedChunk
      ? chooseWeightedCandidate(selectedChunk.candidates)
      : null;
    if (!selectedChunk || !selectedCandidate) {
      clearCandidateCache(candidateCache);
      continue;
    }

    const selectedCoordinate = parseSectorId(selectedCandidate.id);
    const forbiddenCoordinates = neighbourCoordinates(selectedCoordinate, config);
    const invalidatedCandidateIds = new Set(
      forbiddenCoordinates.map((coordinate) =>
        sectorId(coordinate.letter, coordinate.number),
      ),
    );
    const affectedIds = affectedChunkIds(
      forbiddenCoordinates,
      config,
      Number(meta.currentMapNumberMax),
    );
    const selectedSectorRef = sectorRef(db, selectedCandidate.id);
    const affectedRefs = affectedIds.map((id) => spawnChunkRef(db, id));

    const result = await db.runTransaction(async (transaction) => {
      const snapshots = await transaction.getAll(
        metaRef(db),
        selectedSectorRef,
        ...affectedRefs,
      );
      const [transactionMeta, selectedSector, ...affectedChunkSnapshots] = snapshots;
      const currentMeta = transactionMeta.data() || {};

      if (
        Number(currentMeta.schemaVersion) !== MAP_SCHEMA_VERSION ||
        currentMeta.expansionStatus === "EXPANDING" ||
        selectedCoordinate.number > Number(currentMeta.currentMapNumberMax) ||
        selectedCoordinate.number < Number(currentMeta.activeSpawnNumberMin) ||
        selectedCoordinate.number > Number(currentMeta.activeSpawnNumberMax)
      ) {
        return {retry: true};
      }

      if (!selectedSector.exists || selectedSector.data()?.status !== "UNGENERATED") {
        return {retry: true};
      }

      const authoritativeSelectedChunk = affectedChunkSnapshots.find(
        (snapshot) => snapshot.id === selectedChunk.id,
      );
      const authoritativeCandidates = authoritativeSelectedChunk?.exists
        ? normalizeCandidates(authoritativeSelectedChunk.data()?.candidates)
        : {};
      if (!(Number(authoritativeCandidates[selectedCandidate.id]) > 0)) {
        return {retry: true};
      }

      const sequence = Number(currentMeta.simulatedPlayerSequence || 0) +
        (providedPlayerId ? 0 : 1);
      const playerId = providedPlayerId ||
        `sim-player-${String(sequence).padStart(6, "0")}`;
      const sectorData = selectedSector.data() || {};

      transaction.set(selectedSectorRef, {
        ...sectorData,
        status: "POPULATED",
        type: "PLAYER_BUNKER",
        playerId,
        zones: placeholderPlayerZones(playerId, config.zonesPerSector),
        populatedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      const updatedChunks = [];
      for (const snapshot of affectedChunkSnapshots) {
        if (!snapshot.exists) continue;
        const updated = updatedChunkAfterInvalidation(
          snapshot,
          invalidatedCandidateIds,
        );
        transaction.update(snapshot.ref, {
          candidates: updated.candidates,
          totalWeight: updated.totalWeight,
          candidateCount: updated.candidateCount,
          updatedAt: FieldValue.serverTimestamp(),
        });
        updatedChunks.push({
          id: updated.id,
          ref: snapshot.ref,
          windowMin: updated.windowMin,
          windowMax: updated.windowMax,
          numberMin: updated.numberMin,
          numberMax: updated.numberMax,
          candidates: updated.candidates,
          totalWeight: updated.totalWeight,
          candidateCount: updated.candidateCount,
        });
      }

      if (!providedPlayerId) {
        transaction.set(metaRef(db), {
          simulatedPlayerSequence: sequence,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }

      return {
        retry: false,
        playerId,
        sectorId: selectedCandidate.id,
        letter: selectedCoordinate.letter,
        number: selectedCoordinate.number,
        priority: selectedCandidate.priority,
        updatedChunks,
      };
    });

    if (result.retry) {
      clearCandidateCache(candidateCache);
      continue;
    }

    updateCandidateCache(candidateCache, result.updatedChunks);
    return {
      playerId: result.playerId,
      sectorId: result.sectorId,
      letter: result.letter,
      number: result.number,
      priority: result.priority,
      chunksUpdated: result.updatedChunks.length,
    };
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

  const candidateCache = {};
  const added = [];
  for (let index = 0; index < count; index += 1) {
    added.push(await allocatePlayerSector(db, {candidateCache}));
  }
  return added;
}

async function markSectorResolved(db, id, resolution) {
  const parsed = parseSectorId(id);
  const {data: meta} = await requiredMeta(db);
  const config = configFromMeta(meta);
  const ref = sectorRef(db, id);
  const chunk = candidateChunkForCoordinate(parsed, config);
  const chunkRef = chunk && parsed.number <= Number(meta.currentMapNumberMax)
    ? spawnChunkRef(db, chunk.id)
    : null;
  const zones = Array.isArray(resolution?.zones) ? resolution.zones : [];
  let changed = false;

  await db.runTransaction(async (transaction) => {
    const snapshots = chunkRef
      ? await transaction.getAll(ref, chunkRef)
      : [await transaction.get(ref)];
    const [current, chunkSnapshot] = snapshots;
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

    if (chunkSnapshot?.exists) {
      const updated = updatedChunkAfterInvalidation(
        chunkSnapshot,
        new Set([id]),
      );
      transaction.update(chunkSnapshot.ref, {
        candidates: updated.candidates,
        totalWeight: updated.totalWeight,
        candidateCount: updated.candidateCount,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
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
  const [sectorSnapshot, chunkSnapshot] = await Promise.all([
    db.collection(SECTORS_COLLECTION).get(),
    db.collection(SPAWN_CHUNKS_COLLECTION).get(),
  ]);

  const candidateIds = new Set();
  for (const chunkDocument of chunkSnapshot.docs) {
    for (const id of Object.keys(
      normalizeCandidates(chunkDocument.data()?.candidates),
    )) {
      candidateIds.add(id);
    }
  }

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
      spawnCandidates: candidateIds.size,
      spawnChunks: chunkSnapshot.size,
      playerBunkers: sectors.filter((sector) => sector.type === "PLAYER_BUNKER").length,
      populated: sectors.filter((sector) => sector.status === "POPULATED").length,
    },
    sectors,
  };
}

module.exports = {
  DEFAULT_CONFIG,
  LEGACY_CANDIDATES_COLLECTION,
  MAP_SCHEMA_VERSION,
  META_COLLECTION,
  META_DOCUMENT,
  SECTORS_COLLECTION,
  SPAWN_CHUNKS_COLLECTION,
  addSimulatedPlayers,
  allocatePlayerSector,
  chooseWeightedCandidate,
  chooseWeightedChunk,
  chunksForWindow,
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
  spawnChunkForNumber,
  spawnWindowForNumber,
};
