const {getFirestore} = require("firebase-admin/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  normalizedBunkerCoordinates,
} = require("./bunker_status");
const {
  availableActionsForZone,
  coordinatesForClient,
  expeditionDefinitionFromSnapshot,
  expeditionTravelSecondsPerDistanceUnitFromConfig,
} = require("./expeditions");
const {
  MAP_SCHEMA_VERSION,
  META_COLLECTION,
  META_DOCUMENT,
  letterIndex,
} = require("./map");

const REGION = "europe-west1";
const CALLABLE_OPTIONS = {
  region: REGION,
  minInstances: 0,
  maxInstances: 1,
  timeoutSeconds: 30,
  enforceAppCheck: false,
};

function playableCoordinates(value) {
  return value &&
    Number.isInteger(value.x) &&
    value.x >= 0 &&
    value.x <= 25 &&
    Number.isSafeInteger(value.y) &&
    value.y >= 1 &&
    Number.isSafeInteger(value.z) &&
    value.z >= 1;
}

function knownZoneKey(coordinates) {
  return `${coordinates.x}:${coordinates.y}:${coordinates.z}`;
}

function publicKnownZones(source, bunkerCoordinates) {
  const byCoordinate = new Map();
  if (Array.isArray(source)) {
    for (const entry of source) {
      if (!entry || typeof entry !== "object" || Array.isArray(entry)) continue;
      const coordinates = normalizedBunkerCoordinates(entry.coordinates);
      const zoneType = typeof entry.zoneType === "string"
        ? entry.zoneType.trim().toUpperCase()
        : "";
      if (!playableCoordinates(coordinates) || !/^[A-Z][A-Z0-9_]*$/.test(zoneType)) {
        continue;
      }
      byCoordinate.set(knownZoneKey(coordinates), {
        coordinates: coordinatesForClient(coordinates),
        zoneType,
      });
    }
  }

  const ownCoordinates = normalizedBunkerCoordinates(bunkerCoordinates);
  if (playableCoordinates(ownCoordinates)) {
    byCoordinate.set(knownZoneKey(ownCoordinates), {
      coordinates: coordinatesForClient(ownCoordinates),
      zoneType: "PLAYER_BUNKER",
    });
  }

  return [...byCoordinate.values()];
}

function publicAction(action) {
  return {
    id: action.id,
    expeditionType: action.expeditionType,
    durationSeconds: action.durationSeconds,
    energyCostPerSurvivor: action.energyDelta < 0
      ? Math.abs(action.energyDelta)
      : 0,
    availability: {
      unknownZone: action.availability.unknownZone,
      zoneTypes: action.availability.zoneTypes,
    },
    completion: action.completion,
  };
}

function validateMapTarget(meta, bunkerCoordinates) {
  if (
    !meta ||
    Number(meta.schemaVersion) !== MAP_SCHEMA_VERSION ||
    meta.initializationStatus !== "READY" ||
    meta.expansionStatus === "EXPANDING"
  ) {
    throw new Error("World map is not ready.");
  }

  const coordinates = normalizedBunkerCoordinates(bunkerCoordinates);
  if (!playableCoordinates(coordinates)) {
    throw new Error("Bunker coordinates are not a playable map position.");
  }

  if (
    coordinates.x < letterIndex(meta.letterMin) ||
    coordinates.x > letterIndex(meta.letterMax) ||
    coordinates.y < Number(meta.initialNumberMin) ||
    coordinates.y > Number(meta.currentMapNumberMax) ||
    coordinates.z > Number(meta.zonesPerSector)
  ) {
    throw new Error("Bunker coordinates are outside the materialized map.");
  }
  return coordinates;
}

const getExpeditionLauncherInfo = onCall(
  CALLABLE_OPTIONS,
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required to inspect expeditions.",
      );
    }

    const db = getFirestore();
    const bunkerRef = db
      .collection("users")
      .doc(request.auth.uid)
      .collection("state")
      .doc("bunker");
    const [
      bunkerSnapshot,
      expeditionSnapshot,
      serverConfigSnapshot,
      mapSnapshot,
    ] = await Promise.all([
      bunkerRef.get(),
      db.collection("serverData").doc("expeditions").get(),
      db.collection("serverData").doc("serverConfig").get(),
      db.collection(META_COLLECTION).doc(META_DOCUMENT).get(),
    ]);

    if (!bunkerSnapshot.exists) {
      throw new HttpsError("failed-precondition", "Bunker is not initialized.");
    }
    if (!mapSnapshot.exists) {
      throw new HttpsError("failed-precondition", "World map is not initialized.");
    }

    try {
      const bunker = bunkerSnapshot.data() || {};
      const bunkerCoordinates = validateMapTarget(
        mapSnapshot.data() || {},
        bunker.bunkerCoordinates,
      );
      const definition = expeditionDefinitionFromSnapshot(expeditionSnapshot);
      const actions = Object.values(definition.actions).map(publicAction);
      const knownZones = publicKnownZones(
        bunker.knownZones,
        bunkerCoordinates,
      );
      const bunkerActions = availableActionsForZone(
        definition,
        {zoneType: "PLAYER_BUNKER"},
      ).map(publicAction);

      return {
        bunkerCoordinates: coordinatesForClient(bunkerCoordinates),
        zonesPerSector: Number(mapSnapshot.data()?.zonesPerSector),
        travelSecondsPerDistanceUnit:
          expeditionTravelSecondsPerDistanceUnitFromConfig(serverConfigSnapshot),
        actions,
        knownZones,
        // Kept temporarily for old clients during this schema transition.
        bunkerActions,
      };
    } catch (error) {
      throw new HttpsError(
        "failed-precondition",
        error instanceof Error
          ? error.message
          : "Invalid expedition configuration.",
      );
    }
  },
);

module.exports = {
  getExpeditionLauncherInfo,
  publicKnownZones,
};
