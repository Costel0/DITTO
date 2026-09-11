const {FieldValue} = require("firebase-admin/firestore");
const {
  DEFAULT_CONFIG,
  MAP_SCHEMA_VERSION,
  META_COLLECTION,
  META_DOCUMENT,
  SECTORS_COLLECTION,
  SPAWN_CHUNKS_COLLECTION,
  chooseWeightedCandidate,
  chooseWeightedChunk,
  chunksForWindow,
  expandMap,
  letterIndex,
  neighbourCoordinates,
  parseSectorId,
  sectorId,
  spawnChunkForNumber,
} = require("./index");

function metaRef(db) {
  return db.collection(META_COLLECTION).doc(META_DOCUMENT);
}

function sectorRef(db, id) {
  return db.collection(SECTORS_COLLECTION).doc(id);
}

function chunkRef(db, id) {
  return db.collection(SPAWN_CHUNKS_COLLECTION).doc(id);
}

function configFromMeta(meta) {
  return {
    ...DEFAULT_CONFIG,
    letterMin: meta.letterMin,
    letterMax: meta.letterMax,
    initialNumberMin: Number(meta.initialNumberMin),
    initialNumberMax: Number(meta.initialNumberMax),
    zonesPerSector: Number(meta.zonesPerSector),
    spawnLetterMin: meta.spawnLetterMin,
    spawnLetterMax: meta.spawnLetterMax,
    spawnOriginLetter: meta.spawnOriginLetter,
    spawnOriginNumber: Number(meta.spawnOriginNumber),
    initialSpawnNumberMin: Number(meta.initialSpawnNumberMin),
    initialSpawnNumberMax: Number(meta.initialSpawnNumberMax),
    minimumPlayerDistance: Number(meta.minimumPlayerDistance),
    priorityAlpha: Number(meta.priorityAlpha),
    subsequentSpawnWindowSize: Number(meta.subsequentSpawnWindowSize),
    spawnChunkWidth: Number(meta.spawnChunkWidth),
  };
}

function normalizeCandidates(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const candidates = {};
  for (const [id, rawWeight] of Object.entries(value)) {
    const weight = Number(rawWeight);
    if (/^[A-Z]\d+$/.test(id) && Number.isFinite(weight) && weight > 0) {
      candidates[id] = weight;
    }
  }
  return candidates;
}

function candidateWeightSum(candidates) {
  return Object.values(candidates)
    .reduce((sum, weight) => sum + Number(weight), 0);
}

function placeholderPlayerZones(playerId, zonesPerSector) {
  return Array.from({length: zonesPerSector}, (_, index) => ({
    index: index + 1,
    type: index === 0 ? "PLAYER_BUNKER" : "EMPTY_FIELD",
    playerId: index === 0 ? playerId : null,
    status: "RESOLVED",
  }));
}

function affectedChunkIds(coordinates, config, currentMapNumberMax) {
  const ids = new Set();
  for (const coordinate of coordinates) {
    if (coordinate.number > currentMapNumberMax) continue;
    if (
      letterIndex(coordinate.letter) < letterIndex(config.spawnLetterMin) ||
      letterIndex(coordinate.letter) > letterIndex(config.spawnLetterMax)
    ) {
      continue;
    }
    const chunk = spawnChunkForNumber(coordinate.number, config);
    if (chunk) ids.add(chunk.id);
  }
  return [...ids];
}

function updatedChunk(snapshot, invalidatedIds) {
  const data = snapshot.data() || {};
  const candidates = normalizeCandidates(data.candidates);
  for (const id of invalidatedIds) delete candidates[id];
  return {
    candidates,
    totalWeight: candidateWeightSum(candidates),
    candidateCount: Object.keys(candidates).length,
  };
}

async function requiredMeta(db) {
  const snapshot = await metaRef(db).get();
  if (!snapshot.exists) {
    throw new Error("World map is not initialized. Run map init first.");
  }
  const meta = snapshot.data() || {};
  if (
    meta.initializationStatus !== "READY" ||
    Number(meta.schemaVersion) !== MAP_SCHEMA_VERSION
  ) {
    throw new Error("World map is not ready for player allocation.");
  }
  if (meta.expansionStatus === "EXPANDING") {
    throw new Error("World map expansion is in progress. Retry allocation.");
  }
  return meta;
}

async function advanceSpawnWindow(db, meta) {
  const currentMin = Number(meta.activeSpawnNumberMin);
  const currentMax = Number(meta.activeSpawnNumberMax);
  const size = Number(meta.subsequentSpawnWindowSize);
  const nextMin = currentMax + 1;
  const nextMax = currentMax + size;

  if (Number(meta.currentMapNumberMax) < nextMax) {
    await expandMap(db, nextMax);
  }

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(metaRef(db));
    const current = snapshot.data() || {};
    if (
      Number(current.activeSpawnNumberMin) !== currentMin ||
      Number(current.activeSpawnNumberMax) !== currentMax
    ) {
      return;
    }
    transaction.update(metaRef(db), {
      activeSpawnNumberMin: nextMin,
      activeSpawnNumberMax: nextMax,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

/**
 * Allocates one PLAYER_BUNKER sector and optionally executes additional writes
 * in the exact same Firestore transaction.
 *
 * transactionHandler is called after every authoritative map read and before
 * any write. It may perform additional reads, then write the user onboarding
 * documents. Throwing aborts the entire allocation, including the map sector.
 */
async function allocatePlayerSectorWithTransaction(
  db,
  {
    playerId,
    maxAttempts = 100,
    transactionHandler = null,
  },
) {
  const cleanPlayerId = typeof playerId === "string" ? playerId.trim() : "";
  if (!cleanPlayerId) throw new Error("playerId is required.");

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    const meta = await requiredMeta(db);
    const config = configFromMeta(meta);
    const currentMapNumberMax = Number(meta.currentMapNumberMax);
    const chunkDefinitions = chunksForWindow(
      Number(meta.activeSpawnNumberMin),
      Number(meta.activeSpawnNumberMax),
      config,
    );
    const chunkSnapshots = await db.getAll(
      ...chunkDefinitions.map((chunk) => chunkRef(db, chunk.id)),
    );
    const chunks = chunkSnapshots
      .filter((snapshot) => snapshot.exists)
      .map((snapshot) => chunkRecord(snapshot, currentMapNumberMax))
      .filter((chunk) => chunk.totalWeight > 0);

    if (chunks.length === 0) {
      await advanceSpawnWindow(db, meta);
      continue;
    }

    const selectedChunk = chooseWeightedChunk(chunks);
    const selectedCandidate = selectedChunk
      ? chooseWeightedCandidate(selectedChunk.candidates)
      : null;
    if (!selectedChunk || !selectedCandidate) continue;

    const coordinate = parseSectorId(selectedCandidate.id);
    const forbiddenCoordinates = neighbourCoordinates(coordinate, config);
    const invalidatedIds = new Set(
      forbiddenCoordinates.map((entry) => sectorId(entry.letter, entry.number)),
    );
    const affectedIds = affectedChunkIds(
      forbiddenCoordinates,
      config,
      currentMapNumberMax,
    );
    const selectedSectorRef = sectorRef(db, selectedCandidate.id);
    const affectedRefs = affectedIds.map((id) => chunkRef(db, id));

    const result = await db.runTransaction(async (transaction) => {
      const snapshots = await transaction.getAll(
        metaRef(db),
        selectedSectorRef,
        ...affectedRefs,
      );
      const [metaSnapshot, sectorSnapshot, ...affectedChunkSnapshots] = snapshots;
      const currentMeta = metaSnapshot.data() || {};

      if (
        Number(currentMeta.schemaVersion) !== MAP_SCHEMA_VERSION ||
        currentMeta.initializationStatus !== "READY" ||
        currentMeta.expansionStatus === "EXPANDING" ||
        coordinate.number > Number(currentMeta.currentMapNumberMax) ||
        coordinate.number < Number(currentMeta.activeSpawnNumberMin) ||
        coordinate.number > Number(currentMeta.activeSpawnNumberMax)
      ) {
        return {retry: true};
      }

      if (!sectorSnapshot.exists || sectorSnapshot.data()?.status !== "UNGENERATED") {
        return {retry: true};
      }

      const authoritativeChunk = affectedChunkSnapshots.find(
        (snapshot) => snapshot.id === selectedChunk.id,
      );
      const authoritativeCandidates = authoritativeChunk?.exists
        ? normalizeCandidates(authoritativeChunk.data()?.candidates)
        : {};
      if (!(Number(authoritativeCandidates[selectedCandidate.id]) > 0)) {
        return {retry: true};
      }

      const allocation = {
        playerId: cleanPlayerId,
        sectorId: selectedCandidate.id,
        letter: coordinate.letter,
        number: coordinate.number,
        zoneIndex: 1,
        priority: selectedCandidate.priority,
        bunkerCoordinates: {
          x: letterIndex(coordinate.letter),
          y: coordinate.number,
          z: 1,
        },
      };

      const handlerResult = typeof transactionHandler === "function"
        ? await transactionHandler({
          transaction,
          allocation,
          meta: currentMeta,
        })
        : null;

      const sectorData = sectorSnapshot.data() || {};
      transaction.set(selectedSectorRef, {
        ...sectorData,
        status: "POPULATED",
        type: "PLAYER_BUNKER",
        playerId: cleanPlayerId,
        zones: placeholderPlayerZones(cleanPlayerId, config.zonesPerSector),
        populatedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      for (const snapshot of affectedChunkSnapshots) {
        if (!snapshot.exists) continue;
        const next = updatedChunk(snapshot, invalidatedIds);
        transaction.update(snapshot.ref, {
          candidates: next.candidates,
          totalWeight: next.totalWeight,
          candidateCount: next.candidateCount,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      return {
        retry: false,
        allocation,
        handlerResult,
      };
    });

    if (result.retry) continue;
    return {
      ...result.allocation,
      handlerResult: result.handlerResult,
    };
  }

  throw new Error(`Unable to allocate a player sector after ${maxAttempts} attempts.`);
}

module.exports = {
  allocatePlayerSectorWithTransaction,
};
