const {randomUUID} = require("node:crypto");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  SLEEPING_ACTIVITY,
  fixStatus,
  normalizedBunkerCoordinates,
  normalizedBusySurvivors,
  normalizedPendingExpeditionReviews,
  normalizedSurvivor,
  truncateToSecond,
} = require("./bunker_status");
const {
  applyTaskCompletionEffects,
  applyTaskStartCost,
  missingRequiredTaskIds,
  normalizedResourceSelection,
  selectTaskResult,
  taskDefinitionFromSnapshot,
  taskEnergyCostPerSurvivor,
} = require("./job_tasks");
const {
  VALID_DUPLICATE_IDS,
  survivorMeetsStatRequirements,
} = require("./survivor_progression");
const {
  EXPEDITION_ACTIVITY,
  actionDefinitionsByIds,
  aggregateExpeditionInventoryDelta,
  actionIdsFromExpeditionTaskId,
  applyExpeditionCompletion,
  availableActionsAtCoordinates,
  coordinatesFromExpeditionLocation,
  expeditionDefinitionFromSnapshot,
  expeditionDurationSeconds,
  expeditionEnergyDelta,
  expeditionLocation,
  expeditionTaskId,
  expeditionTypeForActions,
  normalizedActionIds,
  normalizedCoordinates,
  selectExpeditionOutcomes,
  selectedActionDefinitions,
} = require("./expeditions");

initializeApp();

const REGION = "europe-west1";
// Only the first four catalog entries are valid starter choices. Later
// Duplicates remain valid elsewhere for acquisition/development flows.
const INITIAL_DUPLICATE_ID_SET = new Set(VALID_DUPLICATE_IDS.slice(0, 4));
const CALLABLE_OPTIONS = {
  region: REGION,
  minInstances: 0,
  maxInstances: 1,
  timeoutSeconds: 15,
  enforceAppCheck: true,
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
    ] = await Promise.all([
      transaction.get(bunkerRef),
      transaction.get(taskCatalogRef),
      transaction.get(expeditionCatalogRef),
    ]);
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

    if (completedGroups.length === 0) {
      return {
        resolvedCount: 0,
        revision: Number.isInteger(bunker.revision) ? bunker.revision : 0,
      };
    }

    let workingBunker = {
      ...bunker,
      busySurvivors,
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
    const resolvedGroupKeys = new Set();
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
            return {
              ...survivor,
              energy: 100,
            };
          })
          : [];
        workingBunker = {
          ...workingBunker,
          survivors,
        };
        resolvedExecutions.push({
          executionId: null,
          taskId: SLEEPING_ACTIVITY,
          result: "rested",
          triggeredRandomOutcomeIds: [],
          survivorIds: participantIds,
        });
      } else if (first.activity === EXPEDITION_ACTIVITY) {
        const expeditionDefinition = expeditionDefinitionFromSnapshot(
          expeditionCatalogSnapshot,
        );
        const actionIds = actionIdsFromExpeditionTaskId(first.taskId);
        const actions = actionDefinitionsByIds(
          expeditionDefinition,
          actionIds,
        );
        const executionSeed = first.executionId || groupKey;
        const outcomes = selectExpeditionOutcomes(actions, executionSeed);
        const inventoryDelta = aggregateExpeditionInventoryDelta(outcomes);
        const expeditionType = first.expeditionType ||
          expeditionTypeForActions(actions);
        const coordinates = coordinatesFromExpeditionLocation(first.location);
        const reviewId = first.executionId || encodeURIComponent(groupKey);

        workingBunker = applyExpeditionCompletion(
          workingBunker,
          participantIds,
          actions,
          outcomes,
        );

        const reviewOutcomes = outcomes.map((outcome) => ({
          actionId: outcome.actionId,
          outcomeId: outcome.id,
          narrativeId: outcome.narrativeId,
          inventoryDelta: outcome.inventoryDelta,
          ...(outcome.imageKey ? {imageKey: outcome.imageKey} : {}),
          ...(outcome.eventTrigger
            ? {eventTrigger: outcome.eventTrigger}
            : {}),
        }));

        const reviewSummary = {
          id: reviewId,
          ...(first.executionId ? {executionId: first.executionId} : {}),
          expeditionType,
          actionIds,
          survivorIds: participantIds,
          coordinates,
          completedAt: now,
        };
        pendingExpeditionReviews.push(reviewSummary);

        // Full outcome details live in a backend-only subcollection. Firestore
        // rules do not grant the client access to this path; the report is
        // returned exactly once by reviewExpeditionResult.
        const privateReviewRef = db
          .collection("users")
          .doc(uid)
          .collection("expeditionReviews")
          .doc(reviewId);
        transaction.set(privateReviewRef, {
          ...reviewSummary,
          inventoryDelta,
          outcomes: reviewOutcomes,
        });

        resolvedExecutions.push({
          executionId: first.executionId || null,
          taskId: first.taskId,
          result: "pending_review",
          triggeredRandomOutcomeIds: [],
          survivorIds: participantIds,
        });
      } else {
        const taskId = first.taskId || first.activity;
        const task = requiredTaskDefinition(taskCatalogSnapshot, taskId);
        const executionSeed = first.executionId || groupKey;
        const result = selectTaskResult(task, executionSeed);
        const completion = applyTaskCompletionEffects(
          workingBunker,
          participantIds,
          task,
          result.id,
          executionSeed,
        );
        workingBunker = completion.bunker;
        if (task.storable) {
          completedTaskIds.add(task.id);
        }
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

    workingBunker = {
      ...workingBunker,
      completedTaskIds: [...completedTaskIds],
      pendingExpeditionReviews,
      idleSurvivors: [...idleSurvivors],
      busySurvivors: busySurvivors.filter(
        (entry) => !resolvedGroupKeys.has(occupationGroupKey(entry)),
      ),
    };

    const fixed = await fixStatus({
      transaction,
      db,
      now,
      bunker: workingBunker,
    });
    transaction.set(bunkerRef, fixed);

    return {
      resolvedCount: resolvedExecutions.length,
      resolvedSurvivorIds: [...resolvedSurvivorIds],
      resolvedExecutions,
      revision: fixed.revision,
    };
  });
}

exports.initializeBunker = onCall(
  CALLABLE_OPTIONS,
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required to initialize a bunker.",
      );
    }

    const username = typeof request.data?.username === "string"
      ? request.data.username.trim()
      : "";
    const duplicateId = typeof request.data?.duplicateId === "string"
      ? request.data.duplicateId.trim()
      : "";

    if (username.length < 3 || username.length > 24) {
      throw new HttpsError(
        "invalid-argument",
        "Username must contain between 3 and 24 characters.",
      );
    }
    if (!INITIAL_DUPLICATE_ID_SET.has(duplicateId)) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid initial Duplicate ID.",
      );
    }

    const uid = request.auth.uid;
    const email = typeof request.auth.token.email === "string"
      ? request.auth.token.email
      : "";
    const db = getFirestore();
    const userRef = db.collection("users").doc(uid);
    const bunkerRef = userRef.collection("state").doc("bunker");
    const legacyInitialRef = userRef.collection("survivors").doc("initial");
    const generatedSurvivorRef = userRef.collection("survivors").doc();

    return db.runTransaction(async (transaction) => {
      const [userSnapshot, bunkerSnapshot, legacyInitialSnapshot] =
        await Promise.all([
          transaction.get(userRef),
          transaction.get(bunkerRef),
          transaction.get(legacyInitialRef),
        ]);

      const user = userSnapshot.data() || {};

      if (bunkerSnapshot.exists) {
        const bunker = bunkerSnapshot.data() || {};
        const survivors = Array.isArray(bunker.survivors)
          ? bunker.survivors
          : [];
        const firstSurvivor = survivors[0];

        if (
          typeof firstSurvivor?.id !== "string" ||
          firstSurvivor.id.length === 0 ||
          firstSurvivor.duplicateId !== duplicateId ||
          (typeof user.initialDuplicateId === "string" &&
            user.initialDuplicateId.length > 0 &&
            user.initialDuplicateId !== duplicateId) ||
          (typeof user.username === "string" &&
            user.username.length > 0 &&
            user.username !== username)
        ) {
          throw new HttpsError(
            "already-exists",
            "This account already has a different bunker configuration.",
          );
        }

        const survivorRef = userRef
          .collection("survivors")
          .doc(firstSurvivor.id);
        const survivorSnapshot = await transaction.get(survivorRef);
        const now = FieldValue.serverTimestamp();

        transaction.set(
          userRef,
          {
            email,
            username,
            initialDuplicateId: duplicateId,
            updatedAt: now,
          },
          {merge: true},
        );

        if (!survivorSnapshot.exists) {
          transaction.set(survivorRef, {
            ...normalizedSurvivor(
              firstSurvivor,
              firstSurvivor.id,
              duplicateId,
            ),
            createdAt: now,
            updatedAt: now,
          });
        }

        return {
          survivorId: firstSurvivor.id,
          created: false,
        };
      }

      const legacySurvivor = legacyInitialSnapshot.exists
        ? legacyInitialSnapshot.data()
        : null;
      const reusesLegacySurvivor =
        legacySurvivor?.duplicateId === duplicateId;
      const survivorRef = reusesLegacySurvivor
        ? legacyInitialRef
        : generatedSurvivorRef;
      const survivorId = survivorRef.id;
      const survivor = normalizedSurvivor(
        reusesLegacySurvivor ? legacySurvivor : null,
        survivorId,
        duplicateId,
      );
      const statusNow = new Date();
      const metadataNow = FieldValue.serverTimestamp();

      const bunker = await fixStatus({
        transaction,
        db,
        now: statusNow,
        bunker: {
          revision: 0,
          survivors: [survivor],
          idleSurvivors: [survivorId],
          busySurvivors: [],
          completedTaskIds: [],
          inventory: {},
          // Temporary assignment seam. Replace this default with the future
          // coordinate allocator; every expedition already reads this
          // per-player bunker field.
          bunkerCoordinates: normalizedBunkerCoordinates(null),
        },
      });

      const profileData = {
        email,
        username,
        initialDuplicateId: duplicateId,
        updatedAt: metadataNow,
      };
      if (!userSnapshot.exists) {
        profileData.createdAt = metadataNow;
      }

      transaction.set(userRef, profileData, {merge: true});
      transaction.set(survivorRef, {
        ...survivor,
        createdAt: reusesLegacySurvivor
          ? legacyInitialSnapshot.get("createdAt") || metadataNow
          : metadataNow,
        updatedAt: metadataNow,
      });
      transaction.create(bunkerRef, bunker);

      return {
        survivorId,
        created: true,
      };
    });
  },
);

exports.getJobTaskStartInfo = onCall(
  CALLABLE_OPTIONS,
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required to inspect a job task.",
      );
    }

    const taskId = typeof request.data?.taskId === "string"
      ? request.data.taskId.trim()
      : "";
    if (!taskId) {
      throw new HttpsError("invalid-argument", "Invalid task ID.");
    }

    const snapshot = await getFirestore()
      .collection("serverData")
      .doc("jobTasks")
      .get();
    const task = requiredTaskDefinition(snapshot, taskId);

    return {
      taskId: task.id,
      minSurvivors: task.survivorRequirements.min,
      maxSurvivors: task.survivorRequirements.max,
      statRequirements: task.survivorRequirements.statRequirements,
      costInventory: task.cost.inventory,
      resourceCraftingValueCost: task.cost.resources.craftingValue,
      energyCostPerSurvivor: taskEnergyCostPerSurvivor(task),
      requiredTaskIds: task.requiredTaskIds,
      storable: task.storable,
    };
  },
);

exports.startJobTask = onCall(
  CALLABLE_OPTIONS,
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required to start a job task.",
      );
    }

    const taskId = typeof request.data?.taskId === "string"
      ? request.data.taskId.trim()
      : "";
    const survivorIds = normalizedRequestedSurvivorIds(request.data);

    let resourceSelection;
    try {
      resourceSelection = normalizedResourceSelection(
        request.data?.resourceItems,
      );
    } catch (error) {
      throw new HttpsError(
        "invalid-argument",
        error instanceof Error ? error.message : "Invalid resource selection.",
      );
    }

    if (!taskId) {
      throw new HttpsError("invalid-argument", "Invalid task ID.");
    }

    const db = getFirestore();
    const executionId = randomUUID();
    const bunkerRef = db
      .collection("users")
      .doc(request.auth.uid)
      .collection("state")
      .doc("bunker");
    const taskCatalogRef = db.collection("serverData").doc("jobTasks");

    return db.runTransaction(async (transaction) => {
      const [bunkerSnapshot, taskCatalogSnapshot] = await Promise.all([
        transaction.get(bunkerRef),
        transaction.get(taskCatalogRef),
      ]);
      if (!bunkerSnapshot.exists) {
        throw new HttpsError("failed-precondition", "Bunker is not initialized.");
      }

      const task = requiredTaskDefinition(taskCatalogSnapshot, taskId);
      const resourceItemDefinitions = {};
      const selectedResourceItemIds = Object.keys(resourceSelection);

      if (
        task.cost.resources.craftingValue === 0 &&
        selectedResourceItemIds.length > 0
      ) {
        throw new HttpsError(
          "invalid-argument",
          `Task ${task.id} does not require generic resources.`,
        );
      }

      for (const itemId of selectedResourceItemIds) {
        const itemSnapshot = await transaction.get(
          db.collection("items").doc(itemId),
        );
        if (!itemSnapshot.exists) {
          throw new HttpsError(
            "failed-precondition",
            `Selected resource item ${itemId} does not exist.`,
          );
        }
        resourceItemDefinitions[itemId] = itemSnapshot.data();
      }

      if (
        survivorIds.length < task.survivorRequirements.min ||
        survivorIds.length > task.survivorRequirements.max
      ) {
        throw new HttpsError(
          "failed-precondition",
          `Task ${task.id} requires between ` +
            `${task.survivorRequirements.min} and ` +
            `${task.survivorRequirements.max} Survivors.`,
        );
      }

      const bunker = bunkerSnapshot.data() || {};
      const completedTaskIds = new Set(
        Array.isArray(bunker.completedTaskIds)
          ? bunker.completedTaskIds.filter((id) => typeof id === "string")
          : [],
      );
      if (task.storable && completedTaskIds.has(task.id)) {
        throw new HttpsError(
          "failed-precondition",
          `Task ${task.id} has already been completed.`,
        );
      }

      const missingPrerequisites = missingRequiredTaskIds(bunker, task);
      if (missingPrerequisites.length > 0) {
        throw new HttpsError(
          "failed-precondition",
          `Missing required tasks: ${missingPrerequisites.join(", ")}.`,
        );
      }

      const survivors = Array.isArray(bunker.survivors) ? bunker.survivors : [];
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
            `Survivor ${survivorId} must recover before starting a task.`,
          );
        }
        if (!survivorMeetsStatRequirements(
          survivor,
          task.survivorRequirements.statRequirements,
        )) {
          throw new HttpsError(
            "failed-precondition",
            `Survivor ${survivorId} does not meet the task stat requirements.`,
          );
        }
      }

      let workingBunker;
      try {
        workingBunker = applyTaskStartCost(
          bunker,
          task,
          {
            resourceSelection,
            itemDefinitions: resourceItemDefinitions,
          },
        );
      } catch (error) {
        throw new HttpsError(
          "failed-precondition",
          error instanceof Error ? error.message : "Task cost cannot be paid.",
        );
      }

      const now = truncateToSecond(new Date()) || new Date();
      const effectiveDurationSeconds = Math.max(
        1,
        Math.ceil(task.durationSeconds / survivorIds.length),
      );
      const endsAt = new Date(
        now.getTime() + effectiveDurationSeconds * 1000,
      );
      const busySurvivors = normalizedBusySurvivors(
        bunker.busySurvivors,
        now,
      );
      for (const survivorId of survivorIds) {
        busySurvivors.push({
          survivorId,
          executionId,
          taskId: task.id,
          activity: task.activity,
          location: task.location,
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
          ...workingBunker,
          idleSurvivors: idleSurvivors.filter((id) => !selectedSet.has(id)),
          busySurvivors,
        },
      });
      transaction.set(bunkerRef, fixed);

      return {
        started: true,
        executionId,
        survivorIds,
        durationSeconds: effectiveDurationSeconds,
        revision: fixed.revision,
      };
    });
  },
);

exports.getExpeditionLauncherInfo = onCall(
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

    const [bunkerSnapshot, expeditionSnapshot] = await Promise.all([
      bunkerRef.get(),
      db.collection("serverData").doc("expeditions").get(),
    ]);
    if (!bunkerSnapshot.exists) {
      throw new HttpsError(
        "failed-precondition",
        "Bunker is not initialized.",
      );
    }

    let definition;
    try {
      definition = expeditionDefinitionFromSnapshot(expeditionSnapshot);
    } catch (error) {
      throw new HttpsError(
        "failed-precondition",
        error instanceof Error
          ? error.message
          : "Invalid expedition configuration.",
      );
    }

    // Coordinates belong to the player bunker, never to the shared expedition
    // catalog. Older bunkers currently migrate to 0,0,0 until coordinate
    // assignment is implemented.
    const bunkerCoordinates = normalizedBunkerCoordinates(
      bunkerSnapshot.data()?.bunkerCoordinates,
    );
    const actions = availableActionsAtCoordinates(
      definition,
      bunkerCoordinates,
      bunkerCoordinates,
    ).map((action) => ({
      id: action.id,
      expeditionType: action.expeditionType,
      durationSeconds: action.durationSeconds,
      energyCostPerSurvivor:
        action.energyDelta < 0 ? Math.abs(action.energyDelta) : 0,
    }));

    return {
      bunkerCoordinates,
      bunkerActions: actions,
    };
  },
);

exports.startExpedition = onCall(
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
    const executionId = randomUUID();
    const bunkerRef = db
      .collection("users")
      .doc(request.auth.uid)
      .collection("state")
      .doc("bunker");
    const expeditionCatalogRef = db.collection("serverData").doc("expeditions");

    return db.runTransaction(async (transaction) => {
      const [bunkerSnapshot, expeditionCatalogSnapshot] = await Promise.all([
        transaction.get(bunkerRef),
        transaction.get(expeditionCatalogRef),
      ]);
      if (!bunkerSnapshot.exists) {
        throw new HttpsError(
          "failed-precondition",
          "Bunker is not initialized.",
        );
      }

      let definition;
      try {
        definition = expeditionDefinitionFromSnapshot(
          expeditionCatalogSnapshot,
        );
      } catch (error) {
        throw new HttpsError(
          "failed-precondition",
          error instanceof Error
            ? error.message
            : "Expedition cannot be launched.",
        );
      }

      const bunker = bunkerSnapshot.data() || {};
      const bunkerCoordinates = normalizedBunkerCoordinates(
        bunker.bunkerCoordinates,
      );
      let actions;
      try {
        actions = selectedActionDefinitions(
          definition,
          coordinates,
          bunkerCoordinates,
          actionIds,
        );
      } catch (error) {
        throw new HttpsError(
          "failed-precondition",
          error instanceof Error
            ? error.message
            : "Expedition cannot be launched.",
        );
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

      const expeditionType = expeditionTypeForActions(actions);
      const now = truncateToSecond(new Date()) || new Date();
      const durationSeconds = expeditionDurationSeconds(actions);
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
        coordinates,
        durationSeconds,
        energyCostPerSurvivor: Math.max(
          0,
          -expeditionEnergyDelta(actions),
        ),
        revision: fixed.revision,
      };
    });
  },
);

exports.reviewExpeditionResult = onCall(
  CALLABLE_OPTIONS,
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required to review an expedition.",
      );
    }

    const reviewId = typeof request.data?.reviewId === "string"
      ? request.data.reviewId.trim()
      : "";
    if (!reviewId) {
      throw new HttpsError("invalid-argument", "Invalid expedition review ID.");
    }

    const db = getFirestore();
    const userRef = db.collection("users").doc(request.auth.uid);
    const bunkerRef = userRef.collection("state").doc("bunker");
    const privateReviewRef = userRef
      .collection("expeditionReviews")
      .doc(reviewId);

    return db.runTransaction(async (transaction) => {
      const [bunkerSnapshot, privateReviewSnapshot] = await Promise.all([
        transaction.get(bunkerRef),
        transaction.get(privateReviewRef),
      ]);
      if (!bunkerSnapshot.exists) {
        throw new HttpsError(
          "failed-precondition",
          "Bunker is not initialized.",
        );
      }

      const bunker = bunkerSnapshot.data() || {};
      const reviews = normalizedPendingExpeditionReviews(
        bunker.pendingExpeditionReviews,
      );
      const reviewIndex = reviews.findIndex((review) => review.id === reviewId);
      if (reviewIndex < 0) {
        throw new HttpsError(
          "not-found",
          "This expedition result is no longer pending review.",
        );
      }

      // Compatibility for any report produced by the brief development version
      // that stored full outcomes directly in BunkerState.
      const rawLegacyReview = Array.isArray(bunker.pendingExpeditionReviews)
        ? bunker.pendingExpeditionReviews.find((entry) =>
          entry && typeof entry === "object" && entry.id === reviewId)
        : null;
      const privateReview = privateReviewSnapshot.exists
        ? privateReviewSnapshot.data()
        : rawLegacyReview &&
          Array.isArray(rawLegacyReview.outcomes) &&
          rawLegacyReview.outcomes.length > 0
          ? rawLegacyReview
          : null;

      if (!privateReview) {
        throw new HttpsError(
          "failed-precondition",
          "The private expedition report is missing.",
        );
      }

      reviews.splice(reviewIndex, 1);
      const now = truncateToSecond(new Date()) || new Date();
      const fixed = await fixStatus({
        transaction,
        db,
        now,
        bunker: {
          ...bunker,
          pendingExpeditionReviews: reviews,
        },
      });

      transaction.set(bunkerRef, fixed);
      if (privateReviewSnapshot.exists) {
        transaction.delete(privateReviewRef);
      }

      const completedAt = truncateToSecond(privateReview.completedAt);
      if (!completedAt) {
        throw new HttpsError(
          "failed-precondition",
          "The expedition report has an invalid completion date.",
        );
      }

      return {
        review: {
          ...privateReview,
          completedAt: completedAt.toISOString(),
        },
        revision: fixed.revision,
      };
    });
  },
);

exports.resolveCompletedOccupations = onCall(
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

// All gameplay-bypassing helpers live in one removable development module.
const development = require("./development");

exports.addSurvivorForTesting = development.addSurvivorForTesting;
exports.addItemForTesting = development.addItemForTesting;
exports.resetTaskTreeForTesting = development.resetTaskTreeForTesting;
exports.resetUserForTesting = development.resetUserForTesting;
