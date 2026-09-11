const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  fixStatus,
  normalizedBunkerCoordinates,
  normalizedSurvivor,
} = require("./bunker_status");
const {VALID_DUPLICATE_IDS} = require("./survivor_progression");
const {
  allocatePlayerSectorWithTransaction,
} = require("./map/player_allocation");

const REGION = "europe-west1";
const INITIAL_DUPLICATE_ID_SET = new Set(VALID_DUPLICATE_IDS.slice(0, 4));
const CALLABLE_OPTIONS = {
  region: REGION,
  minInstances: 0,
  maxInstances: 1,
  timeoutSeconds: 30,
  enforceAppCheck: false,
};

class BunkerAlreadyInitializedDuringAllocation extends Error {
  constructor() {
    super("Bunker was initialized while reserving a map sector.");
    this.name = "BunkerAlreadyInitializedDuringAllocation";
  }
}

function validatedSetupRequest(request) {
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

  return {
    uid: request.auth.uid,
    email: typeof request.auth.token.email === "string"
      ? request.auth.token.email
      : "",
    username,
    duplicateId,
  };
}

async function existingBunkerResult(
  db,
  {uid, email, username, duplicateId},
) {
  const userRef = db.collection("users").doc(uid);
  const bunkerRef = userRef.collection("state").doc("bunker");

  return db.runTransaction(async (transaction) => {
    const [userSnapshot, bunkerSnapshot] = await transaction.getAll(
      userRef,
      bunkerRef,
    );
    if (!bunkerSnapshot.exists) return null;

    const user = userSnapshot.data() || {};
    const bunker = bunkerSnapshot.data() || {};
    const survivors = Array.isArray(bunker.survivors) ? bunker.survivors : [];
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

    const survivorRef = userRef.collection("survivors").doc(firstSurvivor.id);
    const survivorSnapshot = await transaction.get(survivorRef);
    const now = FieldValue.serverTimestamp();

    transaction.set(userRef, {
      email,
      username,
      initialDuplicateId: duplicateId,
      updatedAt: now,
    }, {merge: true});

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
      bunkerCoordinates: normalizedBunkerCoordinates(bunker.bunkerCoordinates),
    };
  });
}

async function initializeNewBunker(
  db,
  {uid, email, username, duplicateId},
) {
  const userRef = db.collection("users").doc(uid);
  const bunkerRef = userRef.collection("state").doc("bunker");
  const legacyInitialRef = userRef.collection("survivors").doc("initial");
  // Keep the same generated document ID across Firestore transaction retries.
  const generatedSurvivorRef = userRef.collection("survivors").doc();

  return allocatePlayerSectorWithTransaction(db, {
    playerId: uid,
    transactionHandler: async ({transaction, allocation}) => {
      const [userSnapshot, bunkerSnapshot, legacyInitialSnapshot] =
        await transaction.getAll(
          userRef,
          bunkerRef,
          legacyInitialRef,
        );

      if (bunkerSnapshot.exists) {
        throw new BunkerAlreadyInitializedDuringAllocation();
      }

      const legacySurvivor = legacyInitialSnapshot.exists
        ? legacyInitialSnapshot.data()
        : null;
      const reusesLegacySurvivor = legacySurvivor?.duplicateId === duplicateId;
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

      // fixStatus performs its own authoritative server-config read. Keep it
      // before any transaction writes so Firestore can safely retry the whole
      // onboarding operation.
      const bunker = await fixStatus({
        transaction,
        db,
        now: statusNow,
        bunker: {
          revision: 0,
          survivors: [survivor],
          idleSurvivors: [survivorId],
          busySurvivors: [],
          activeBackgroundTasks: [],
          completedTaskIds: [],
          inventory: {},
          bunkerCoordinates: normalizedBunkerCoordinates(
            allocation.bunkerCoordinates,
          ),
        },
      });

      const profileData = {
        email,
        username,
        initialDuplicateId: duplicateId,
        updatedAt: metadataNow,
      };
      if (!userSnapshot.exists) profileData.createdAt = metadataNow;

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
    },
  });
}

const initializeBunker = onCall(
  CALLABLE_OPTIONS,
  async (request) => {
    const setup = validatedSetupRequest(request);
    const db = getFirestore();

    const existing = await existingBunkerResult(db, setup);
    if (existing) return existing;

    try {
      const allocation = await initializeNewBunker(db, setup);
      return {
        ...allocation.handlerResult,
        sectorId: allocation.sectorId,
        bunkerCoordinates: allocation.bunkerCoordinates,
      };
    } catch (error) {
      // A second concurrent/retried onboarding request may have completed after
      // the initial existence check but before this request reserved a sector.
      if (error instanceof BunkerAlreadyInitializedDuringAllocation) {
        const result = await existingBunkerResult(db, setup);
        if (result) return result;
      }
      if (error instanceof HttpsError) throw error;
      throw new HttpsError(
        "failed-precondition",
        error instanceof Error
          ? error.message
          : "Unable to initialize the bunker and map sector.",
      );
    }
  },
);

module.exports = {
  initializeBunker,
};
