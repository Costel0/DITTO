const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  fixStatus,
  normalizedSurvivor,
} = require("./bunker_status");

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

// All gameplay-bypassing helpers live in one removable development module.
const development = require("./development");

exports.addSurvivorForTesting = development.addSurvivorForTesting;
exports.addItemForTesting = development.addItemForTesting;
exports.resetUserForTesting = development.resetUserForTesting;
