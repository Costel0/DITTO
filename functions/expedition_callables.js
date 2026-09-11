const {randomUUID} = require("node:crypto");
const {getFirestore} = require("firebase-admin/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  SLEEPING_ACTIVITY,
  fixStatus,
  knownZoneAt,
  normalizedActiveBackgroundTasks,
  normalizedBunkerCoordinates,
  normalizedBusySurvivors,
  normalizedPendingExpeditionReviews,
  truncateToSecond,
  upsertKnownZone,
} = require("./bunker_status");
const {
  applyTaskCompletionEffects,
  selectTaskResult,
  taskDefinitionFromSnapshot,
} = require("./job_tasks");
const {
  EXPEDITION_ACTIVITY,
  actionDefinitionsByIds,
  actionIdsFromExpeditionTaskId,
  applyExpeditionAutomaticResolution,
  availableActionsForZone,
  coordinatesForClient,
  coordinatesFromExpeditionLocation,
  expeditionDefinitionFromSnapshot,
  expeditionDurationSeconds,
  expeditionEnergyDelta,
  expeditionLocation,
  expeditionTaskId,
  expeditionTravelSeconds,
  expeditionTravelSecondsPerDistanceUnitFromConfig,
  expeditionTypeForActions,
  isExplorationAction,
  normalizedActionIds,
  normalizedCoordinates,
  selectExpeditionOutcomes,
  selectedActionDefinitionsForZone,
} = require("./expeditions");
const {
  MAP_SCHEMA_VERSION,
  META_COLLECTION,
  META_DOCUMENT,
  SECTORS_COLLECTION,
  expandMap,
  letterIndex,
} = require("./map");
const {
  mapCoordinateId,
  mapCoordinatesToLegacy,
  mapSectorId,
  normalizedMapCoordinates,
} = require("./map/coordinates");
const {
  applyZoneDiscoveryPlan,
  discoveryRefs,
  planZoneDiscovery,
} = require("./map/discovery");

const REGION = "europe-west1";
const CALLABLE_OPTIONS = {
  region: REGION,
  minInstances: 0,
  maxInstances: 1,
  timeoutSeconds: 30,
  enforceAppCheck: false,
};

function requiredTaskDefinition(snapshot, taskId) {
  try {
    const task = taskDefinitionFromSnapshot(snapshot, taskId);
    if (!task) {
      throw new HttpsError(
        "failed-precondition",
        `Task ${taskId} is missing from the server job catalog.`,
      );
    }
    return task;
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError(
      "failed-precondition",
      error instanceof Error ? error.message : "Invalid server job catalog.",
    );
  }
}

function normalizedRequestedSurvivorIds(data) {
  const raw = Array.isArray(data?.survivorIds)
    ? data.survivorIds
    : typeof data?.survivorId === "string"
      ? [data.survivorId]
      : [];
  const survivorIds = raw.map((value) =>
    typeof value === "string" ? value.trim() : "",
  );
  if (
    survivorIds.length === 0 ||
    survivorIds.some((id) => !id) ||
    new Set(survivorIds).size !== survivorIds.length
  ) {
    throw new HttpsError(
      "invalid-argument",
      "survivorIds must contain unique non-empty Survivor IDs.",
    );
  }
  return survivorIds;
}

function occupationGroupKey(entry) {
  if (entry.activity === SLEEPING_ACTIVITY) {
    return `sleeping:${entry.survivorId}:${entry.endsAt.getTime()}`;
  }
  if (entry.executionId) return `execution:${entry.executionId}`;
  const taskId = entry.taskId || entry.activity;
  return [
    "legacy",
    entry.survivorId,
    taskId,
    entry.startedAt.getTime(),
    entry.endsAt.getTime(),
  ].join(":");
}

function groupedOccupations(busySurvivors) {
  const groups = new Map();
  for (const entry of busySurvivors) {
    const key = occupationGroupKey(entry);
    const group = groups.get(key) || [];
    group.push(entry);
    groups.set(key, group);
  }
  return groups;
}

function mapMetaRef(db) {
  return db.collection(META_COLLECTION).doc(META_DOCUMENT);
}

function validateMapTarget(meta, coordinates) {
  if (
    !meta ||
    Number(meta.schemaVersion) !== MAP_SCHEMA_VERSION ||
    meta.initializationStatus !== "READY" ||
    meta.expansionStatus === "EXPANDING"
  ) {
    throw new Error("World map is not ready.");
  }

  const coordinate = normalizedMapCoordinates(coordinates);
  const x = letterIndex(coordinate.sectorLetter);
  if (
    x < letterIndex(meta.letterMin) ||
    x > letterIndex(meta.letterMax)
  ) {
    throw new Error("Target sector is outside the map letter range.");
  }
  if (
    coordinate.sectorNumber < Number(meta.initialNumberMin) ||
    coordinate.sectorNumber > Number(meta.currentMapNumberMax)
  ) {
    throw new Error("Target sector is outside the materialized map.");
  }
  if (
    coordinate.zoneIndex < 1 ||
    coordinate.zoneIndex > Number(meta.zonesPerSector)
  ) {
    throw new Error(
      `Zone index must be between 1 and ${Number(meta.zonesPerSector)}.`,
    );
  }
  return coordinate;
}

async function ensureMapCoversTarget(db, coordinates) {
  const target = normalizedMapCoordinates(coordinates);
  let snapshot = await mapMetaRef(db).get();
  if (!snapshot.exists) {
    throw new Error("World map is not initialized.");
  }
  let meta = snapshot.data() || {};
  if (
    Number(meta.schemaVersion) !== MAP_SCHEMA_VERSION ||
    meta.initializationStatus !== "READY" ||
    meta.expansionStatus === "EXPANDING"
  ) {
    throw new Error("World map is not ready.");
  }

  const x = letterIndex(target.sectorLetter);
  if (x < letterIndex(meta.letterMin) || x > letterIndex(meta.letterMax)) {
    throw new Error("Target sector is outside the map letter range.");
  }
  if (target.sectorNumber < Number(meta.initialNumberMin)) {
    throw new Error("Target sector number is invalid.");
  }
  if (target.zoneIndex > Number(meta.zonesPerSector)) {
    throw new Error(
      `Zone index must be between 1 and ${Number(meta.zonesPerSector)}.`,
    );
  }

  if (target.sectorNumber > Number(meta.currentMapNumberMax)) {
    await expandMap(db, target.sectorNumber);
    snapshot = await mapMetaRef(db).get();
    meta = snapshot.data() || {};
  }
  validateMapTarget(meta, target);
  return meta;
}

function zoneTypeFromAuthoritativeSector(sectorSnapshot, coordinates) {
  if (!sectorSnapshot?.exists) {
    throw new Error(`Sector ${mapSectorId(coordinates)} is not materialized.`);
  }
  const sector = sectorSnapshot.data() || {};
  if (sector.status !== "POPULATED") return null;
  const target = normalizedMapCoordinates(coordinates);
  const zones = Array.isArray(sector.zones) ? sector.zones : [];
  const zone = zones.find((entry) => Number(entry?.index) === target.zoneIndex);
  const zoneType = typeof zone?.type === "string"
    ? zone.type.trim().toUpperCase()
    : "";
  if (!zoneType) {
    throw new Error(
      `Authoritative zone ${sectorSnapshot.id}-${target.zoneIndex} is missing.`,
    );
  }
  return zoneType;
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
      mapMetaRef(db).get(),
    ]);
    if (!bunkerSnapshot.exists) {
      throw new HttpsError("failed-precondition", "Bunker is not initialized.");
    }
    if (!mapSnapshot.exists) {
      throw new HttpsError("failed-precondition", "World map is not initialized.");
    }

    try {
      const definition = expeditionDefinitionFromSnapshot(expeditionSnapshot);
      const bunkerCoordinates = normalizedBunkerCoordinates(
        bunkerSnapshot.data()?.bunkerCoordinates,
      );
      const mapMeta = mapSnapshot.data() || {};
      validateMapTarget(mapMeta, bunkerCoordinates);
      const actions = Object.values(definition.actions).map(publicAction);
      const bunkerActions = availableActionsForZone(
        definition,
        {zoneType: "PLAYER_BUNKER"},
      ).map(publicAction);

      return {
        bunkerCoordinates: coordinatesForClient(bunkerCoordinates),
        zonesPerSector: Number(mapMeta.zonesPerSector),
        travelSecondsPerDistanceUnit:
          expeditionTravelSecondsPerDistanceUnitFromConfig(serverConfigSnapshot),
        actions,
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

const startExpedition = onCall(
  CALLABLE_OPTIONS,
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required to start an expedition.",
      );
    }

    const survivorIds = normalizedRequestedSurvivorIds(request.data);
    let coordinates;
    let actionIds;
    try {
      coordinates = normalizedCoordinates(request.data?.coordinates);
      actionIds = normalizedActionIds(request.data?.actionIds);
    } catch (error) {
      throw new HttpsError(
        "invalid-argument",
        error instanceof Error ? error.message : "Invalid expedition request.",
      );
    }

    const db = getFirestore();
    try {
      await ensureMapCoversTarget(db, coordinates);
    } catch (error) {
      throw new HttpsError(
        "failed-precondition",
        error instanceof Error ? error.message : "World map is not ready.",
      );
    }

    const executionId = randomUUID();
    const bunkerRef = db
      .collection("users")
      .doc(request.auth.uid)
      .collection("state")
      .doc("bunker");
    const expeditionCatalogRef = db.collection("serverData").doc("expeditions");
    const serverConfigRef = db.collection("serverData").doc("serverConfig");
    const targetSectorRef = db
      .collection(SECTORS_COLLECTION)
      .doc(mapSectorId(coordinates));

    return db.runTransaction(async (transaction) => {
      const [
        bunkerSnapshot,
        expeditionCatalogSnapshot,
        serverConfigSnapshot,
        mapSnapshot,
        targetSectorSnapshot,
      ] = await transaction.getAll(
        bunkerRef,
        expeditionCatalogRef,
        serverConfigRef,
        mapMetaRef(db),
        targetSectorRef,
      );
      if (!bunkerSnapshot.exists) {
        throw new HttpsError("failed-precondition", "Bunker is not initialized.");
      }

      try {
        const mapMeta = mapSnapshot.data() || {};
        validateMapTarget(mapMeta, coordinates);
        if (!targetSectorSnapshot.exists) {
          throw new Error("Target sector is not materialized.");
        }

        const definition = expeditionDefinitionFromSnapshot(
          expeditionCatalogSnapshot,
        );
        const bunker = bunkerSnapshot.data() || {};
        const bunkerCoordinates = normalizedBunkerCoordinates(
          bunker.bunkerCoordinates,
        );
        const knownZone = knownZoneAt(
          bunker.knownZones,
          coordinates,
          bunkerCoordinates,
        );
        const actions = selectedActionDefinitionsForZone(
          definition,
          knownZone,
          actionIds,
        );

        if (knownZone) {
          const authoritativeType = zoneTypeFromAuthoritativeSector(
            targetSectorSnapshot,
            coordinates,
          );
          if (!authoritativeType || authoritativeType !== knownZone.zoneType) {
            throw new Error(
              "Player zone knowledge does not match the authoritative world.",
            );
          }
        } else if (!actions.every(isExplorationAction)) {
          throw new Error("Unknown zones may only be explored.");
        }

        const survivors = Array.isArray(bunker.survivors)
          ? bunker.survivors
          : [];
        const survivorById = new Map(
          survivors
            .filter((entry) => typeof entry?.id === "string")
            .map((entry) => [entry.id, entry]),
        );
        const idleSurvivors = Array.isArray(bunker.idleSurvivors)
          ? bunker.idleSurvivors.filter((id) => typeof id === "string")
          : [];
        const idleSet = new Set(idleSurvivors);

        for (const survivorId of survivorIds) {
          const survivor = survivorById.get(survivorId);
          if (!survivor) {
            throw new HttpsError(
              "not-found",
              `Survivor ${survivorId} does not exist in bunker.`,
            );
          }
          if (!idleSet.has(survivorId)) {
            throw new HttpsError(
              "failed-precondition",
              `Survivor ${survivorId} is not idle.`,
            );
          }
          if (Number.isInteger(survivor.energy) && survivor.energy < 0) {
            throw new HttpsError(
              "failed-precondition",
              `Survivor ${survivorId} must recover before an expedition.`,
            );
          }
        }

        const travelSecondsPerDistanceUnit =
          expeditionTravelSecondsPerDistanceUnitFromConfig(serverConfigSnapshot);
        const travelSeconds = expeditionTravelSeconds(
          bunkerCoordinates,
          coordinates,
          travelSecondsPerDistanceUnit,
        );
        const durationSeconds = expeditionDurationSeconds(
          actions,
          travelSeconds,
        );
        const expeditionType = expeditionTypeForActions(actions);
        const now = truncateToSecond(new Date()) || new Date();
        const endsAt = new Date(now.getTime() + durationSeconds * 1000);
        const busySurvivors = normalizedBusySurvivors(
          bunker.busySurvivors,
          now,
        );
        const taskId = expeditionTaskId(actionIds);
        const location = expeditionLocation(coordinates);

        for (const survivorId of survivorIds) {
          busySurvivors.push({
            survivorId,
            executionId,
            taskId,
            activity: EXPEDITION_ACTIVITY,
            expeditionType,
            location,
            startedAt: now,
            endsAt,
          });
        }

        const selectedSet = new Set(survivorIds);
        const fixed = await fixStatus({
          transaction,
          db,
          now,
          bunker: {
            ...bunker,
            idleSurvivors: idleSurvivors.filter(
              (id) => !selectedSet.has(id),
            ),
            busySurvivors,
          },
        });
        transaction.set(bunkerRef, fixed);

        return {
          started: true,
          executionId,
          survivorIds,
          actionIds,
          expeditionType,
          coordinates: coordinatesForClient(coordinates),
          travelSeconds,
          durationSeconds,
          energyCostPerSurvivor: Math.max(
            0,
            -expeditionEnergyDelta(actions),
          ),
          revision: fixed.revision,
        };
      } catch (error) {
        if (error instanceof HttpsError) throw error;
        throw new HttpsError(
          "failed-precondition",
          error instanceof Error
            ? error.message
            : "Expedition cannot be launched.",
        );
      }
    });
  },
);

async function resolveCompletedOccupationsForUser(db, uid) {
  const bunkerRef = db
    .collection("users")
    .doc(uid)
    .collection("state")
    .doc("bunker");
  const taskCatalogRef = db.collection("serverData").doc("jobTasks");
  const expeditionCatalogRef = db.collection("serverData").doc("expeditions");

  return db.runTransaction(async (transaction) => {
    const [
      bunkerSnapshot,
      taskCatalogSnapshot,
      expeditionCatalogSnapshot,
    ] = await transaction.getAll(
      bunkerRef,
      taskCatalogRef,
      expeditionCatalogRef,
    );
    if (!bunkerSnapshot.exists) {
      throw new HttpsError("failed-precondition", "Bunker is not initialized.");
    }

    const now = truncateToSecond(new Date()) || new Date();
    const bunker = bunkerSnapshot.data() || {};
    const busySurvivors = normalizedBusySurvivors(
      bunker.busySurvivors,
      now,
    );
    const groups = groupedOccupations(busySurvivors);
    const completedGroups = [...groups.entries()].filter(([, entries]) =>
      entries.every((entry) => entry.endsAt.getTime() <= now.getTime()),
    );
    const activeBackgroundTasks = normalizedActiveBackgroundTasks(
      bunker.activeBackgroundTasks,
      now,
    );
    const completedBackgroundTasks = activeBackgroundTasks.filter(
      (entry) => entry.endsAt.getTime() <= now.getTime(),
    );

    if (
      completedGroups.length === 0 &&
      completedBackgroundTasks.length === 0
    ) {
      return {
        resolvedCount: 0,
        revision: Number.isInteger(bunker.revision) ? bunker.revision : 0,
      };
    }

    // Resolve expedition definitions up-front and collect every world document
    // needed by completed Explore missions. Firestore requires all reads before
    // writes, so discovery planning happens before any mutation is queued.
    let expeditionDefinition = null;
    const expeditionGroupMetadata = new Map();
    const explorationCoordinates = new Map();
    for (const [groupKey, entries] of completedGroups) {
      const first = entries[0];
      if (first.activity !== EXPEDITION_ACTIVITY) continue;
      if (!expeditionDefinition) {
        expeditionDefinition = expeditionDefinitionFromSnapshot(
          expeditionCatalogSnapshot,
        );
      }
      const actionIds = actionIdsFromExpeditionTaskId(first.taskId);
      const actions = actionDefinitionsByIds(expeditionDefinition, actionIds);
      const coordinates = coordinatesFromExpeditionLocation(first.location);
      const exploration = actions.length === 1 && isExplorationAction(actions[0]);
      expeditionGroupMetadata.set(groupKey, {
        actionIds,
        actions,
        coordinates,
        exploration,
      });
      if (exploration) {
        explorationCoordinates.set(
          mapCoordinateId(normalizedMapCoordinates(coordinates)),
          coordinates,
        );
      }
    }

    let mapMeta = null;
    const discoveryPlans = new Map();
    if (explorationCoordinates.size > 0) {
      const mapSnapshot = await transaction.get(mapMetaRef(db));
      if (!mapSnapshot.exists) {
        throw new Error("World map is not initialized.");
      }
      mapMeta = mapSnapshot.data() || {};

      const refsByPath = new Map();
      const refSetsByCoordinate = new Map();
      for (const [coordinateId, coordinates] of explorationCoordinates) {
        validateMapTarget(mapMeta, coordinates);
        const refs = discoveryRefs(db, coordinates, mapMeta);
        refsByPath.set(refs.sectorRef.path, refs.sectorRef);
        if (refs.chunkRef) refsByPath.set(refs.chunkRef.path, refs.chunkRef);
        refSetsByCoordinate.set(coordinateId, refs);
      }

      const worldRefs = [...refsByPath.values()];
      const worldSnapshots = worldRefs.length > 0
        ? await transaction.getAll(...worldRefs)
        : [];
      const snapshotsByPath = new Map(
        worldSnapshots.map((snapshot) => [snapshot.ref.path, snapshot]),
      );

      for (const [coordinateId, coordinates] of explorationCoordinates) {
        const refs = refSetsByCoordinate.get(coordinateId);
        const sectorSnapshot = snapshotsByPath.get(refs.sectorRef.path);
        const chunkSnapshot = refs.chunkRef
          ? snapshotsByPath.get(refs.chunkRef.path)
          : null;
        if (refs.chunkRef && !chunkSnapshot?.exists && sectorSnapshot?.data()?.status === "UNGENERATED") {
          throw new Error(
            `Spawn index is missing for unexplored sector ${refs.sectorId}.`,
          );
        }
        discoveryPlans.set(coordinateId, planZoneDiscovery({
          coordinates,
          meta: mapMeta,
          sectorSnapshot,
          chunkSnapshot,
        }));
      }
    }

    let workingBunker = {
      ...bunker,
      busySurvivors,
      activeBackgroundTasks,
    };
    const idleSurvivors = new Set(
      Array.isArray(bunker.idleSurvivors)
        ? bunker.idleSurvivors.filter((id) => typeof id === "string")
        : [],
    );
    const completedTaskIds = new Set(
      Array.isArray(bunker.completedTaskIds)
        ? bunker.completedTaskIds.filter((id) => typeof id === "string")
        : [],
    );
    const pendingExpeditionReviews = normalizedPendingExpeditionReviews(
      bunker.pendingExpeditionReviews,
    );
    const privateExpeditionReviewWrites = [];
    const resolvedGroupKeys = new Set();
    const resolvedBackgroundExecutionIds = new Set();
    const resolvedSurvivorIds = new Set();
    const resolvedExecutions = [];

    for (const [groupKey, entries] of completedGroups) {
      const first = entries[0];
      const participantIds = entries.map((entry) => entry.survivorId);

      if (first.activity === SLEEPING_ACTIVITY) {
        const participantSet = new Set(participantIds);
        const survivors = Array.isArray(workingBunker.survivors)
          ? workingBunker.survivors.map((survivor) => {
            if (!participantSet.has(survivor?.id)) return survivor;
            return {...survivor, energy: 100};
          })
          : [];
        workingBunker = {...workingBunker, survivors};
        resolvedExecutions.push({
          executionId: null,
          taskId: SLEEPING_ACTIVITY,
          result: "rested",
          triggeredRandomOutcomeIds: [],
          survivorIds: participantIds,
        });
      } else if (first.activity === EXPEDITION_ACTIVITY) {
        const metadata = expeditionGroupMetadata.get(groupKey);
        if (!metadata) {
          throw new Error("Completed expedition metadata is missing.");
        }
        const {actionIds, actions, coordinates, exploration} = metadata;
        const executionSeed = first.executionId || groupKey;
        const outcomes = selectExpeditionOutcomes(actions, executionSeed);
        const expeditionType = first.expeditionType ||
          expeditionTypeForActions(actions);

        workingBunker = applyExpeditionAutomaticResolution(
          workingBunker,
          participantIds,
          actions,
          outcomes,
        );

        if (exploration) {
          const coordinateId = mapCoordinateId(
            normalizedMapCoordinates(coordinates),
          );
          const plan = discoveryPlans.get(coordinateId);
          if (!plan) throw new Error("Zone discovery plan is missing.");
          workingBunker = {
            ...workingBunker,
            knownZones: upsertKnownZone(
              workingBunker.knownZones,
              mapCoordinatesToLegacy(plan.coordinate),
              plan.zoneType,
              workingBunker.bunkerCoordinates,
            ),
          };
          resolvedExecutions.push({
            executionId: first.executionId || null,
            taskId: first.taskId,
            result: "zone_discovered",
            zoneType: plan.zoneType,
            coordinates: coordinatesForClient(coordinates),
            generatedSector: plan.generatedSector,
            triggeredRandomOutcomeIds: [],
            survivorIds: participantIds,
          });
        } else {
          const reviewId = first.executionId || encodeURIComponent(groupKey);
          const reviewOutcomes = outcomes.map((outcome) => ({
            actionId: outcome.actionId,
            outcomeId: outcome.id,
            narrativeId: outcome.narrativeId,
            resolutionOptions: outcome.resolutionOptions,
            ...(outcome.imageKey ? {imageKey: outcome.imageKey} : {}),
          }));
          const reviewSummary = {
            id: reviewId,
            ...(first.executionId ? {executionId: first.executionId} : {}),
            expeditionType,
            actionIds,
            survivorIds: participantIds,
            coordinates,
            completedAt: now,
            resolutionStatus: "pending_interactive",
          };
          pendingExpeditionReviews.push(reviewSummary);

          const privateReviewRef = db
            .collection("users")
            .doc(uid)
            .collection("expeditionReviews")
            .doc(reviewId);
          privateExpeditionReviewWrites.push({
            ref: privateReviewRef,
            data: {
              ...reviewSummary,
              automaticResolution: {
                status: "resolved",
                resolvedAt: now,
              },
              interactiveResolution: {status: "pending"},
              outcomes: reviewOutcomes,
            },
          });
          resolvedExecutions.push({
            executionId: first.executionId || null,
            taskId: first.taskId,
            result: "automatic_resolution_complete",
            triggeredRandomOutcomeIds: [],
            survivorIds: participantIds,
          });
        }
      } else {
        const taskId = first.taskId || first.activity;
        const task = requiredTaskDefinition(taskCatalogSnapshot, taskId);
        const executionSeed = first.executionId || groupKey;
        const result = selectTaskResult(task, executionSeed);
        const executionCount = Number.isInteger(first.taskExecutionCount)
          ? first.taskExecutionCount
          : 1;
        const completion = applyTaskCompletionEffects(
          workingBunker,
          participantIds,
          task,
          result.id,
          executionSeed,
          executionCount,
        );
        workingBunker = completion.bunker;
        if (task.storable) completedTaskIds.add(task.id);
        resolvedExecutions.push({
          executionId: first.executionId || null,
          taskId: task.id,
          result: result.id,
          triggeredRandomOutcomeIds: completion.triggeredRandomOutcomeIds,
          survivorIds: participantIds,
        });
      }

      for (const survivorId of participantIds) {
        idleSurvivors.add(survivorId);
        resolvedSurvivorIds.add(survivorId);
      }
      resolvedGroupKeys.add(groupKey);
    }

    for (const backgroundTask of completedBackgroundTasks) {
      const task = requiredTaskDefinition(
        taskCatalogSnapshot,
        backgroundTask.taskId,
      );
      const result = selectTaskResult(task, backgroundTask.executionId);
      const completion = applyTaskCompletionEffects(
        workingBunker,
        [backgroundTask.startedBySurvivorId],
        task,
        result.id,
        backgroundTask.executionId,
        1,
      );
      workingBunker = completion.bunker;
      if (task.storable) completedTaskIds.add(task.id);
      resolvedBackgroundExecutionIds.add(backgroundTask.executionId);
      resolvedExecutions.push({
        executionId: backgroundTask.executionId,
        taskId: task.id,
        result: result.id,
        triggeredRandomOutcomeIds: completion.triggeredRandomOutcomeIds,
        survivorIds: [backgroundTask.startedBySurvivorId],
        background: true,
      });
    }

    workingBunker = {
      ...workingBunker,
      completedTaskIds: [...completedTaskIds],
      pendingExpeditionReviews,
      idleSurvivors: [...idleSurvivors],
      busySurvivors: busySurvivors.filter(
        (entry) => !resolvedGroupKeys.has(occupationGroupKey(entry)),
      ),
      activeBackgroundTasks: activeBackgroundTasks.filter(
        (entry) => !resolvedBackgroundExecutionIds.has(entry.executionId),
      ),
    };

    // fixStatus performs the final serverConfig read. Only after it returns do
    // we queue writes, preserving Firestore's read-before-write requirement.
    const fixed = await fixStatus({
      transaction,
      db,
      now,
      bunker: workingBunker,
    });
    transaction.set(bunkerRef, fixed);

    const appliedWorldRefs = new Set();
    for (const plan of discoveryPlans.values()) {
      const key = plan.sectorRef.path;
      if (appliedWorldRefs.has(key)) continue;
      applyZoneDiscoveryPlan(transaction, plan);
      appliedWorldRefs.add(key);
    }
    for (const privateWrite of privateExpeditionReviewWrites) {
      transaction.set(privateWrite.ref, privateWrite.data);
    }

    return {
      resolvedCount: resolvedExecutions.length,
      resolvedSurvivorIds: [...resolvedSurvivorIds],
      resolvedExecutions,
      revision: fixed.revision,
    };
  });
}

const resolveCompletedOccupations = onCall(
  CALLABLE_OPTIONS,
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required to resolve occupations.",
      );
    }
    return resolveCompletedOccupationsForUser(
      getFirestore(),
      request.auth.uid,
    );
  },
);

module.exports = {
  getExpeditionLauncherInfo,
  resolveCompletedOccupations,
  resolveCompletedOccupationsForUser,
  startExpedition,
};
