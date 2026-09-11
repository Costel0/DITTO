const {FieldValue} = require("firebase-admin/firestore");
const {
  DEFAULT_CONFIG,
  MAP_SCHEMA_VERSION,
  META_COLLECTION,
  META_DOCUMENT,
  SECTORS_COLLECTION,
  SPAWN_CHUNKS_COLLECTION,
  letterIndex,
  parseSectorId,
  spawnChunkForNumber,
} = require("./index");

const TYPE_PATTERN = /^[A-Z][A-Z0-9_]*$/;
const RESERVED_STATUS_NAMES = new Set(["UNGENERATED", "POPULATED"]);

function normalizedType(rawValue, label) {
  const value = typeof rawValue === "string"
    ? rawValue.trim().toUpperCase()
    : "";
  if (!value || !TYPE_PATTERN.test(value) || RESERVED_STATUS_NAMES.has(value)) {
    throw new Error(`${label} must be an uppercase-safe type slug.`);
  }
  return value;
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

function emptyZones(zonesPerSector) {
  return Array.from({length: zonesPerSector}, (_, index) => ({
    index: index + 1,
    type: "EMPTY",
    playerId: null,
    status: "RESOLVED",
  }));
}

function normalizedZones(source, zonesPerSector) {
  const byIndex = new Map();
  if (Array.isArray(source)) {
    for (const zone of source) {
      if (
        zone &&
        Number.isInteger(zone.index) &&
        zone.index >= 1 &&
        zone.index <= zonesPerSector
      ) {
        byIndex.set(zone.index, {...zone});
      }
    }
  }

  return emptyZones(zonesPerSector).map((fallback) =>
    byIndex.has(fallback.index) ? byIndex.get(fallback.index) : fallback,
  );
}

function candidateChunkForSector(coordinate, config, currentMapNumberMax) {
  if (coordinate.number > currentMapNumberMax) return null;
  const li = letterIndex(coordinate.letter);
  if (
    li < letterIndex(config.spawnLetterMin) ||
    li > letterIndex(config.spawnLetterMax) ||
    coordinate.number < config.initialSpawnNumberMin
  ) {
    return null;
  }
  return spawnChunkForNumber(coordinate.number, config);
}

async function requiredMeta(db) {
  const snapshot = await db.collection(META_COLLECTION).doc(META_DOCUMENT).get();
  if (!snapshot.exists) throw new Error("World map is not initialized.");
  const meta = snapshot.data() || {};
  if (
    meta.initializationStatus !== "READY" ||
    meta.expansionStatus === "EXPANDING" ||
    Number(meta.schemaVersion) !== MAP_SCHEMA_VERSION
  ) {
    throw new Error("World map is not ready for manual editing.");
  }
  return meta;
}

async function setSectorType(db, sectorRaw, typeRaw) {
  const coordinate = parseSectorId(sectorRaw);
  const sector = `${coordinate.letter}${coordinate.number}`;
  const type = normalizedType(typeRaw, "Sector type");
  if (type === "PLAYER_BUNKER") {
    throw new Error(
      "PLAYER_BUNKER sectors must be created through player allocation, not set-sector.",
    );
  }

  const initialMeta = await requiredMeta(db);
  const config = configFromMeta(initialMeta);
  const sectorRef = db.collection(SECTORS_COLLECTION).doc(sector);
  const chunk = candidateChunkForSector(
    coordinate,
    config,
    Number(initialMeta.currentMapNumberMax),
  );
  const chunkRef = chunk
    ? db.collection(SPAWN_CHUNKS_COLLECTION).doc(chunk.id)
    : null;
  const metaRef = db.collection(META_COLLECTION).doc(META_DOCUMENT);

  return db.runTransaction(async (transaction) => {
    const snapshots = chunkRef
      ? await transaction.getAll(metaRef, sectorRef, chunkRef)
      : await transaction.getAll(metaRef, sectorRef);
    const [metaSnapshot, sectorSnapshot, chunkSnapshot] = snapshots;
    const meta = metaSnapshot.data() || {};

    if (
      meta.initializationStatus !== "READY" ||
      meta.expansionStatus === "EXPANDING" ||
      Number(meta.schemaVersion) !== MAP_SCHEMA_VERSION
    ) {
      throw new Error("World map changed while editing. Retry.");
    }
    if (!sectorSnapshot.exists) {
      throw new Error(`Sector ${sector} does not exist in the materialized map.`);
    }

    const current = sectorSnapshot.data() || {};
    if (current.type === "PLAYER_BUNKER" || current.playerId) {
      throw new Error(`Sector ${sector} belongs to a player and cannot be overwritten.`);
    }

    const now = FieldValue.serverTimestamp();
    transaction.update(sectorRef, {
      status: "POPULATED",
      type,
      playerId: null,
      zones: normalizedZones(current.zones, Number(meta.zonesPerSector)),
      populatedAt: current.populatedAt || now,
      updatedAt: now,
    });

    let removedFromSpawnPool = false;
    if (chunkSnapshot?.exists) {
      const candidates = normalizeCandidates(chunkSnapshot.data()?.candidates);
      if (Object.prototype.hasOwnProperty.call(candidates, sector)) {
        delete candidates[sector];
        transaction.update(chunkSnapshot.ref, {
          candidates,
          totalWeight: candidateWeightSum(candidates),
          candidateCount: Object.keys(candidates).length,
          updatedAt: now,
        });
        removedFromSpawnPool = true;
      }
    }

    return {
      sectorId: sector,
      type,
      removedFromSpawnPool,
    };
  });
}

async function setZoneType(db, sectorRaw, zoneRaw, typeRaw) {
  const coordinate = parseSectorId(sectorRaw);
  const sector = `${coordinate.letter}${coordinate.number}`;
  const zoneIndex = Number(zoneRaw);
  const type = normalizedType(typeRaw, "Zone type");
  if (!Number.isInteger(zoneIndex) || zoneIndex < 1) {
    throw new Error("Zone index must be a positive integer.");
  }
  if (type === "PLAYER_BUNKER") {
    throw new Error(
      "PLAYER_BUNKER zones must be created through player allocation, not set-zone.",
    );
  }

  const meta = await requiredMeta(db);
  if (zoneIndex > Number(meta.zonesPerSector)) {
    throw new Error(
      `Zone index must be between 1 and ${Number(meta.zonesPerSector)}.`,
    );
  }

  const sectorRef = db.collection(SECTORS_COLLECTION).doc(sector);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(sectorRef);
    if (!snapshot.exists) {
      throw new Error(`Sector ${sector} does not exist in the materialized map.`);
    }
    const current = snapshot.data() || {};
    if (current.status !== "POPULATED") {
      throw new Error(
        `Sector ${sector} is UNGENERATED. Assign its sector type first with set-sector.`,
      );
    }

    const zones = normalizedZones(current.zones, Number(meta.zonesPerSector));
    const target = zones[zoneIndex - 1];
    if (target?.type === "PLAYER_BUNKER" || target?.playerId) {
      throw new Error(
        `Zone ${sector}-${zoneIndex} is a player bunker and cannot be overwritten.`,
      );
    }

    zones[zoneIndex - 1] = {
      ...target,
      index: zoneIndex,
      type,
      playerId: null,
      status: "RESOLVED",
    };
    transaction.update(sectorRef, {
      zones,
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {
      sectorId: sector,
      zoneIndex,
      coordinate: `${sector}-${zoneIndex}`,
      type,
    };
  });
}

module.exports = {
  normalizedType,
  setSectorType,
  setZoneType,
};
