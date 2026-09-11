const {FieldValue} = require("firebase-admin/firestore");
const {
  DEFAULT_CONFIG,
  SECTORS_COLLECTION,
  SPAWN_CHUNKS_COLLECTION,
  spawnChunkForNumber,
} = require("./index");
const {
  letterIndex,
  mapSectorId,
  normalizedMapCoordinates,
} = require("./coordinates");

const TEMPORARY_DISCOVERED_SECTOR_TYPE = "ARID_PLAINS";
const TEMPORARY_DISCOVERED_ZONE_TYPE = "EMPTY_FIELD";

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

function candidateChunkForCoordinates(coordinates, meta) {
  const config = configFromMeta(meta);
  const coordinate = normalizedMapCoordinates(coordinates);
  const li = letterIndex(coordinate.sectorLetter);
  if (
    li < letterIndex(config.spawnLetterMin) ||
    li > letterIndex(config.spawnLetterMax) ||
    coordinate.sectorNumber < config.initialSpawnNumberMin ||
    coordinate.sectorNumber > Number(meta.currentMapNumberMax)
  ) {
    return null;
  }
  return spawnChunkForNumber(coordinate.sectorNumber, config);
}

function discoveryRefs(db, coordinates, meta) {
  const coordinate = normalizedMapCoordinates(coordinates);
  const sectorId = mapSectorId(coordinate);
  const sectorRef = db.collection(SECTORS_COLLECTION).doc(sectorId);
  const chunk = candidateChunkForCoordinates(coordinate, meta);
  return {
    sectorId,
    sectorRef,
    chunkRef: chunk
      ? db.collection(SPAWN_CHUNKS_COLLECTION).doc(chunk.id)
      : null,
  };
}

function generatedAridZones(zonesPerSector) {
  return Array.from({length: zonesPerSector}, (_, index) => ({
    index: index + 1,
    type: TEMPORARY_DISCOVERED_ZONE_TYPE,
    playerId: null,
    status: "RESOLVED",
  }));
}

/**
 * Builds a discovery result from snapshots that were already read by the
 * caller. No Firestore read or write happens here, which lets callers gather
 * every required document before queuing transaction writes.
 */
function planZoneDiscovery({
  coordinates,
  meta,
  sectorSnapshot,
  chunkSnapshot = null,
}) {
  const coordinate = normalizedMapCoordinates(coordinates);
  const zonesPerSector = Number(meta.zonesPerSector);
  if (!Number.isInteger(zonesPerSector) || zonesPerSector < 1) {
    throw new Error("World map has an invalid zonesPerSector configuration.");
  }
  if (coordinate.zoneIndex > zonesPerSector) {
    throw new Error(
      `Zone index must be between 1 and ${zonesPerSector}.`,
    );
  }
  if (!sectorSnapshot?.exists) {
    throw new Error(`Sector ${mapSectorId(coordinate)} is not materialized.`);
  }

  const sector = sectorSnapshot.data() || {};
  if (sector.status === "UNGENERATED") {
    const zones = generatedAridZones(zonesPerSector);
    const sectorUpdate = {
      status: "POPULATED",
      type: TEMPORARY_DISCOVERED_SECTOR_TYPE,
      playerId: null,
      zones,
      populatedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };

    let chunkUpdate = null;
    if (chunkSnapshot?.exists) {
      const candidates = normalizeCandidates(chunkSnapshot.data()?.candidates);
      const sectorId = sectorSnapshot.id;
      if (Object.prototype.hasOwnProperty.call(candidates, sectorId)) {
        delete candidates[sectorId];
        chunkUpdate = {
          candidates,
          totalWeight: candidateWeightSum(candidates),
          candidateCount: Object.keys(candidates).length,
          updatedAt: FieldValue.serverTimestamp(),
        };
      }
    }

    return {
      coordinate,
      zoneType: TEMPORARY_DISCOVERED_ZONE_TYPE,
      generatedSector: true,
      sectorRef: sectorSnapshot.ref,
      sectorUpdate,
      chunkRef: chunkSnapshot?.ref || null,
      chunkUpdate,
    };
  }

  if (sector.status !== "POPULATED") {
    throw new Error(`Sector ${sectorSnapshot.id} has an invalid world status.`);
  }

  const zones = Array.isArray(sector.zones) ? sector.zones : [];
  const zone = zones.find((entry) =>
    Number(entry?.index) === coordinate.zoneIndex,
  );
  if (!zone || typeof zone.type !== "string" || !zone.type.trim()) {
    throw new Error(
      `Zone ${sectorSnapshot.id}-${coordinate.zoneIndex} is missing from the authoritative sector.`,
    );
  }

  return {
    coordinate,
    zoneType: zone.type.trim().toUpperCase(),
    generatedSector: false,
    sectorRef: sectorSnapshot.ref,
    sectorUpdate: null,
    chunkRef: null,
    chunkUpdate: null,
  };
}

function applyZoneDiscoveryPlan(transaction, plan) {
  if (plan.sectorUpdate) {
    transaction.update(plan.sectorRef, plan.sectorUpdate);
  }
  if (plan.chunkRef && plan.chunkUpdate) {
    transaction.update(plan.chunkRef, plan.chunkUpdate);
  }
}

module.exports = {
  TEMPORARY_DISCOVERED_SECTOR_TYPE,
  TEMPORARY_DISCOVERED_ZONE_TYPE,
  applyZoneDiscoveryPlan,
  discoveryRefs,
  planZoneDiscovery,
};
