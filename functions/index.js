const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");

initializeApp();

const REGION = "europe-west1";
const VALID_DUPLICATE_IDS = new Set(["01", "02", "03", "04"]);

exports.initializeBunker = onCall(
  {
    region: REGION,
    minInstances: 0,
    maxInstances: 5,
    timeoutSeconds: 15,
  },
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

      if (bunkerSnapshot.exists) {
        const bunker = bunkerSnapshot.data() || {};
        const user = userSnapshot.data() || {};
        const survivors = Array.isArray(bunker.survivors)
          ? bunker.survivors
          : [];
        const firstSurvivor = survivors[0];

        if (
          user.username !== username ||
          user.initialDuplicateId !== duplicateId ||
          typeof firstSurvivor?.id !== "string" ||
          firstSurvivor.id.length === 0
        ) {
          throw new HttpsError(
            "already-exists",
            "This account already has a different bunker configuration.",
          );
        }

        return {
          survivorId: firstSurvivor.id,
          created: false,
        };
      }

      let survivorRef = generatedSurvivorRef;
      const legacySurvivor = legacyInitialSnapshot.exists
        ? legacyInitialSnapshot.data()
        : null;
      if (
        legacySurvivor &&
        legacySurvivor.duplicateId === duplicateId
      ) {
        survivorRef = legacyInitialRef;
      }

      const survivorId = survivorRef.id;
      const statMods = {
        strength: 0,
        dexterity: 0,
        constitution: 0,
        stealth: 0,
        care: 0,
        cunning: 0,
        charm: 0,
      };
      const survivor = {
        id: survivorId,
        duplicateId,
        statMods,
        healthHistory: [],
        equippedItemIds: [],
      };
      const now = FieldValue.serverTimestamp();

      const profileData = {
        email,
        username,
        initialDuplicateId: duplicateId,
        updatedAt: now,
      };
      if (!userSnapshot.exists) {
        profileData.createdAt = now;
      }

      transaction.set(userRef, profileData, {merge: true});
      transaction.set(
        survivorRef,
        {
          ...survivor,
          createdAt: legacyInitialSnapshot.exists
            ? legacyInitialSnapshot.get("createdAt") || now
            : now,
          updatedAt: now,
        },
        {merge: true},
      );
      transaction.create(bunkerRef, {
        schemaVersion: 2,
        revision: 1,
        serverUpdatedAt: now,
        survivors: [survivor],
        idleSurvivors: [survivorId],
        busySurvivors: {},
        inventory: {},
      });

      return {
        survivorId,
        created: true,
      };
    });
  },
);
