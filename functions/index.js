const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  SLEEPING_ACTIVITY,
  fixStatus,
  normalizedBusySurvivors,
  normalizedSurvivor,
  truncateToSecond,
} = require("./bunker_status");
const {
  applyTaskCompletionEffects,
  taskDefinitionFromSnapshot,
} = require("./job_tasks");

initializeApp();

const REGION = "europe-west1";
const VALID_DUPLICATE_IDS = new Set(["01", "02", "03", "04"]);
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

async function resolveCompletedOccupationsForUser(db, uid) {
  const bunkerRef = db
    .collection("users")
    .doc(uid)
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

    const now = truncateToSecond(new Date()) || new Date();
    const bunker = bunkerSnapshot.data() || {};
    const busySurvivors = normalizedBusySurvivors(
      bunker.busySurvivors,
      now,
    );
    const completed = busySurvivors.filter(
      (entry) => entry.endsAt.getTime() <= now.getTime(),
    );

    if (completed.length === 0) {
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
    const resolvedSurvivorIds = [];

    for (const completedOccupation of completed) {
      const survivorId = completedOccupation.survivorId;

      if (completedOccupation.activity === SLEEPING_ACTIVITY) {
        const survivors = Array.isArray(workingBunker.survivors)
          ? workingBunker.survivors.map((survivor) => {
            if (survivor?.id !== survivorId) return survivor;
            return {
              ...survivor,
              energy: 0,
            };
          })
          : [];
        workingBunker = {
          ...workingBunker,
          survivors,
        };
      } else {
        const taskId = completedOccupation.taskId ||
          completedOccupation.activity;
        const task = requiredTaskDefinition(taskCatalogSnapshot, taskId);
        workingBunker = applyTaskCompletionEffects(
          workingBunker,
          survivorId,
          task,
        );
      }

      idleSurvivors.add(survivorId);
      resolvedSurvivorIds.push(survivorId);
    }

    const completedSurvivorIds = new Set(resolvedSurvivorIds);
    workingBunker = {
      ...workingBunker,
      idleSurvivors: [...idleSurvivors],
      busySurvivors: busySurvivors.filter(
        (entry) => !completedSurvivorIds.has(entry.survivorId),
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
      resolvedCount: resolvedSurvivorIds.length,
      resolvedSurvivorIds,
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
    if (!VALID_DUPLICATE_IDS.has(duplicateId)) {
      throw new HttpsError("invalid-argument", "Invalid Duplicate ID.");
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
          inventory: {},
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
    const survivorId = typeof request.data?.survivorId === "string"
      ? request.data.survivorId.trim()
      : "";

    if (!taskId || survivorId.length === 0) {
      throw new HttpsError("invalid-argument", "Invalid task or Survivor ID.");
    }

    const db = getFirestore();
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
      const bunker = bunkerSnapshot.data() || {};
      const survivors = Array.isArray(bunker.survivors) ? bunker.survivors : [];
      const survivor = survivors.find((entry) => entry?.id === survivorId);
      if (!survivor) {
        throw new HttpsError("not-found", "Survivor does not exist in bunker.");
      }

      const idleSurvivors = Array.isArray(bunker.idleSurvivors)
        ? bunker.idleSurvivors.filter((id) => typeof id === "string")
        : [];
      if (!idleSurvivors.includes(survivorId)) {
        throw new HttpsError("failed-precondition", "Survivor is not idle.");
      }
      if (Number.isInteger(survivor.energy) && survivor.energy < 0) {
        throw new HttpsError(
          "failed-precondition",
          "Survivor must recover before starting a task.",
        );
      }

      const now = truncateToSecond(new Date()) || new Date();
      const busySurvivors = normalizedBusySurvivors(
        bunker.busySurvivors,
        now,
      );
      busySurvivors.push({
        survivorId,
        taskId: task.id,
        activity: task.activity,
        location: task.location,
        startedAt: now,
        endsAt: new Date(now.getTime() + task.durationSeconds * 1000),
      });

      const fixed = await fixStatus({
        transaction,
        db,
        now,
        bunker: {
          ...bunker,
          idleSurvivors: idleSurvivors.filter((id) => id !== survivorId),
          busySurvivors,
        },
      });
      transaction.set(bunkerRef, fixed);

      return {
        started: true,
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
exports.resetUserForTesting = development.resetUserForTesting;
