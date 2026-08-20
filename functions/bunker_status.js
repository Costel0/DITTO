const BUNKER_SCHEMA_VERSION = 6;
const DEFAULT_SURVIVOR_ENERGY = 50;
const DEFAULT_SLEEPING_SECONDS_PER_NEGATIVE_ENERGY = 60;
const SLEEPING_ACTIVITY = "sleeping";
const SLEEPING_LOCATION = "beds";
const UNKNOWN_LOCATION = "unknown";

function zeroStatMods() {
  return {
    strength: 0,
    dexterity: 0,
    constitution: 0,
    stealth: 0,
    care: 0,
    cunning: 0,
    charm: 0,
  };
}

function normalizedSurvivor(source, survivorId, duplicateId) {
  const healthHistory = Array.isArray(source?.healthHistory)
    ? source.healthHistory
    : [];
  const equippedItemIds = Array.isArray(source?.equippedItemIds)
    ? source.equippedItemIds
    : [];
  const statMods = source?.statMods && typeof source.statMods === "object"
    ? source.statMods
    : zeroStatMods();
  const energy = Number.isInteger(source?.energy)
    ? source.energy
    : DEFAULT_SURVIVOR_ENERGY;

  return {
    id: survivorId,
    duplicateId,
    energy,
    statMods,
    healthHistory,
    equippedItemIds,
  };
}

function normalizedBunkerSurvivors(source) {
  if (!Array.isArray(source)) return [];

  return source.map((survivor) => normalizedSurvivor(
    survivor,
    typeof survivor?.id === "string" ? survivor.id : "",
    typeof survivor?.duplicateId === "string" ? survivor.duplicateId : "",
  ));
}

function dateFromValue(value) {
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value;
  }
  if (value && typeof value.toDate === "function") {
    const converted = value.toDate();
    if (converted instanceof Date && !Number.isNaN(converted.getTime())) {
      return converted;
    }
  }
  if (typeof value === "string") {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) return parsed;
  }
  return null;
}

function truncateToSecond(value) {
  const date = dateFromValue(value);
  if (!date) return null;
  return new Date(Math.floor(date.getTime() / 1000) * 1000);
}

function legacyLocationForActivity(activity) {
  return activity === SLEEPING_ACTIVITY ? SLEEPING_LOCATION : UNKNOWN_LOCATION;
}

function normalizedBusySurvivors(source, fallbackDate = new Date()) {
  const fallback = truncateToSecond(fallbackDate) || new Date(0);

  if (Array.isArray(source)) {
    return source
      .filter((entry) =>
        entry &&
        typeof entry === "object" &&
        typeof entry.survivorId === "string" &&
        entry.survivorId.trim().length > 0 &&
        typeof entry.activity === "string" &&
        entry.activity.trim().length > 0,
      )
      .map((entry) => {
        const activity = entry.activity.trim();
        const location = typeof entry.location === "string" &&
          entry.location.trim().length > 0
          ? entry.location.trim()
          : legacyLocationForActivity(activity);
        const normalized = {
          survivorId: entry.survivorId.trim(),
          activity,
          location,
          startedAt: truncateToSecond(entry.startedAt) || fallback,
          endsAt: truncateToSecond(entry.endsAt) || fallback,
        };
        if (typeof entry.taskId === "string" && entry.taskId.trim().length > 0) {
          normalized.taskId = entry.taskId.trim();
        }
        if (
          typeof entry.executionId === "string" &&
          entry.executionId.trim().length > 0
        ) {
          normalized.executionId = entry.executionId.trim();
        }
        return normalized;
      });
  }

  // Compatibility migration for schema v2:
  // activity -> [survivorId, ...]
  if (source && typeof source === "object") {
    const result = [];
    for (const [activityRaw, survivorIds] of Object.entries(source)) {
      const activity = activityRaw.trim();
      if (!Array.isArray(survivorIds) || activity.length === 0) continue;
      for (const survivorId of survivorIds) {
        if (typeof survivorId !== "string" || survivorId.trim().length === 0) {
          continue;
        }
        result.push({
          survivorId: survivorId.trim(),
          activity,
          location: legacyLocationForActivity(activity),
          startedAt: fallback,
          endsAt: fallback,
        });
      }
    }
    return result;
  }

  return [];
}

function uniqueStringList(source) {
  if (!Array.isArray(source)) return [];
  return [...new Set(source
    .filter((value) => typeof value === "string")
    .map((value) => value.trim())
    .filter((value) => value.length > 0))];
}

function sleepingMultiplierFromConfig(snapshot) {
  const value = snapshot.data()?.config?.sleepingSecondsPerNegativeEnergy;
  if (typeof value === "number" && Number.isFinite(value) && value > 0) {
    return value;
  }
  return DEFAULT_SLEEPING_SECONDS_PER_NEGATIVE_ENERGY;
}

/**
 * Applies server-authoritative invariants to a bunker snapshot immediately
 * before it is persisted. Every backend mutation of BunkerState should pass
 * through this function.
 *
 * Occupation completion is intentionally not resolved here. Busy entries stay
 * busy even after endsAt until the dedicated occupation-resolution flow handles
 * their results and moves the Survivor to its next state.
 */
async function fixStatus({transaction, db, bunker, now = new Date()}) {
  const fixedNow = truncateToSecond(now) || new Date();
  const serverConfigSnapshot = await transaction.get(
    db.collection("serverData").doc("serverConfig"),
  );
  const sleepingSecondsPerNegativeEnergy =
    sleepingMultiplierFromConfig(serverConfigSnapshot);

  const survivors = normalizedBunkerSurvivors(bunker.survivors);
  const survivorById = new Map(
    survivors.map((survivor) => [survivor.id, survivor]),
  );
  const knownSurvivorIds = new Set(survivorById.keys());
  const idleSurvivors = new Set(
    uniqueStringList(bunker.idleSurvivors)
      .filter((survivorId) => knownSurvivorIds.has(survivorId)),
  );

  const busyBySurvivorId = new Map();
  for (const busySurvivor of normalizedBusySurvivors(
    bunker.busySurvivors,
    fixedNow,
  )) {
    if (!knownSurvivorIds.has(busySurvivor.survivorId)) continue;
    if (busyBySurvivorId.has(busySurvivor.survivorId)) continue;

    idleSurvivors.delete(busySurvivor.survivorId);
    busyBySurvivorId.set(busySurvivor.survivorId, busySurvivor);
  }

  for (const survivorId of [...idleSurvivors]) {
    const survivor = survivorById.get(survivorId);
    if (!survivor || survivor.energy >= 0) continue;

    idleSurvivors.delete(survivorId);
    const durationSeconds = Math.max(
      1,
      Math.ceil(
        Math.abs(survivor.energy) * sleepingSecondsPerNegativeEnergy,
      ),
    );
    busyBySurvivorId.set(survivorId, {
      survivorId,
      activity: SLEEPING_ACTIVITY,
      location: SLEEPING_LOCATION,
      startedAt: fixedNow,
      endsAt: new Date(fixedNow.getTime() + durationSeconds * 1000),
    });
  }

  const currentRevision = Number.isInteger(bunker.revision)
    ? bunker.revision
    : 0;

  return {
    ...bunker,
    schemaVersion: BUNKER_SCHEMA_VERSION,
    revision: currentRevision + 1,
    serverUpdatedAt: fixedNow,
    survivors,
    idleSurvivors: [...idleSurvivors],
    busySurvivors: [...busyBySurvivorId.values()],
    completedTaskIds: uniqueStringList(bunker.completedTaskIds),
  };
}

module.exports = {
  BUNKER_SCHEMA_VERSION,
  DEFAULT_SURVIVOR_ENERGY,
  DEFAULT_SLEEPING_SECONDS_PER_NEGATIVE_ENERGY,
  SLEEPING_ACTIVITY,
  SLEEPING_LOCATION,
  fixStatus,
  normalizedBunkerSurvivors,
  normalizedBusySurvivors,
  normalizedSurvivor,
  truncateToSecond,
};
