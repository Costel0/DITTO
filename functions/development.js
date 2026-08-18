const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");

// DEVELOPMENT-ONLY SERVER SURFACE.
//
// This module contains every callable that bypasses normal gameplay acquisition
// rules. Production can remove this file + the three exports in index.js, or
// set DITTO_DEVELOPMENT_TOOLS_REQUIRE_ADMIN=true and grant the Firebase Auth
// custom claim {admin: true} only to trusted accounts.
const REGION = "europe-west1";
const BUNKER_SCHEMA_VERSION = 3;
const DEVELOPMENT_TOOLS_REQUIRE_ADMIN =
  process.env.DITTO_DEVELOPMENT_TOOLS_REQUIRE_ADMIN === "true";
const VALID_DUPLICATE_IDS = new Set(["01", "02", "03", "04"]);
const ITEM_ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;
const MAX_INVENTORY_QUANTITY = 1000000000;

const DEVELOPMENT_CALLABLE_OPTIONS = {
  region: REGION,
  minInstances: 0,
  maxInstances: 1,
  timeoutSeconds: 15,
  enforceAppCheck: true,
};
const RESET_CALLABLE_OPTIONS = {
  ...DEVELOPMENT_CALLABLE_OPTIONS,
  timeoutSeconds: 30,
};

function requireDevelopmentAccess(request) {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication is required to use development tools.",
    );
  }

  if (
    DEVELOPMENT_TOOLS_REQUIRE_ADMIN &&
    request.auth.token.admin !== true
  ) {
    throw new HttpsError(
      "permission-denied",
      "Administrator access is required to use development tools.",
    );
  }
}

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
  const energy = Number.isInteger(source?.energy) ? source.energy : 0;

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

function normalizedBusySurvivors(source) {
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
      .map((entry) => ({
        survivorId: entry.survivorId.trim(),
        activity: entry.activity.trim(),
      }));
  }

  // Compatibility migration for schema v2:
  // activity -> [survivorId, ...]
  if (source && typeof source === "object") {
    const result = [];
    for (const [activity, survivorIds] of Object.entries(source)) {
      if (!Array.isArray(survivorIds) || activity.trim().length === 0) continue;
      for (const survivorId of survivorIds) {
        if (typeof survivorId !== "string" || survivorId.trim().length === 0) {
          continue;
        }
        result.push({
          survivorId: survivorId.trim(),
          activity: activity.trim(),
        });
      }
    }
    return result;
  }

  return [];
}

exports.addSurvivorForTesting = onCall(
  DEVELOPMENT_CALLABLE_OPTIONS,
  async (request) => {
    requireDevelopmentAccess(request);

    const duplicateId = typeof request.data?.duplicateId === "string"
      ? request.data.duplicateId.trim()
      : "";
    if (!VALID_DUPLICATE_IDS.has(duplicateId)) {
      throw new HttpsError("invalid-argument", "Invalid Duplicate ID.");
    }

    const uid = request.auth.uid;
    const db = getFirestore();
    const userRef = db.collection("users").doc(uid);
    const bunkerRef = userRef.collection("state").doc("bunker");
    const survivorRef = userRef.collection("survivors").doc();

    return db.runTransaction(async (transaction) => {
      const bunkerSnapshot = await transaction.get(bunkerRef);
      if (!bunkerSnapshot.exists) {
        throw new HttpsError(
          "failed-precondition",
          "The bunker must be initialized before adding Survivors.",
        );
      }

      const bunker = bunkerSnapshot.data() || {};
      const survivors = normalizedBunkerSurvivors(bunker.survivors);
      if (survivors.some((survivor) => survivor.duplicateId === duplicateId)) {
        throw new HttpsError(
          "already-exists",
          "This Duplicate is already part of the bunker.",
        );
      }

      const survivorId = survivorRef.id;
      const survivor = normalizedSurvivor(null, survivorId, duplicateId);
      const idleSurvivors = Array.isArray(bunker.idleSurvivors)
        ? bunker.idleSurvivors.filter((id) => typeof id === "string")
        : [];
      const revision = Number.isInteger(bunker.revision)
        ? bunker.revision + 1
        : 1;
      const now = FieldValue.serverTimestamp();

      transaction.create(survivorRef, {
        ...survivor,
        createdAt: now,
        updatedAt: now,
      });
      transaction.update(bunkerRef, {
        schemaVersion: BUNKER_SCHEMA_VERSION,
        survivors: [...survivors, survivor],
        idleSurvivors: [...new Set([...idleSurvivors, survivorId])],
        busySurvivors: normalizedBusySurvivors(bunker.busySurvivors),
        revision,
        serverUpdatedAt: now,
      });

      return {
        survivorId,
        duplicateId,
        created: true,
      };
    });
  },
);

exports.addItemForTesting = onCall(
  DEVELOPMENT_CALLABLE_OPTIONS,
  async (request) => {
    requireDevelopmentAccess(request);

    const itemId = typeof request.data?.itemId === "string"
      ? request.data.itemId.trim()
      : "";
    const quantity = request.data?.quantity;

    if (!ITEM_ID_PATTERN.test(itemId)) {
      throw new HttpsError(
        "invalid-argument",
        "Item ID must contain only letters, numbers, underscores or hyphens.",
      );
    }
    if (!Number.isInteger(quantity) || quantity <= 0) {
      throw new HttpsError(
        "invalid-argument",
        "Quantity must be a positive integer.",
      );
    }

    const db = getFirestore();
    const userRef = db.collection("users").doc(request.auth.uid);
    const bunkerRef = userRef.collection("state").doc("bunker");
    const itemRef = db.collection("items").doc(itemId);

    return db.runTransaction(async (transaction) => {
      const [bunkerSnapshot, itemSnapshot] = await Promise.all([
        transaction.get(bunkerRef),
        transaction.get(itemRef),
      ]);

      if (!bunkerSnapshot.exists) {
        throw new HttpsError(
          "failed-precondition",
          "The bunker must be initialized before adding items.",
        );
      }
      if (!itemSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          `Item ${itemId} does not exist in the server catalog.`,
        );
      }

      const bunker = bunkerSnapshot.data() || {};
      const inventory =
        bunker.inventory &&
        typeof bunker.inventory === "object" &&
        !Array.isArray(bunker.inventory)
          ? {...bunker.inventory}
          : {};
      const currentQuantity = Number.isInteger(inventory[itemId]) &&
        inventory[itemId] >= 0
        ? inventory[itemId]
        : 0;
      const nextQuantity = currentQuantity + quantity;

      if (nextQuantity > MAX_INVENTORY_QUANTITY) {
        throw new HttpsError(
          "out-of-range",
          `Inventory quantity cannot exceed ${MAX_INVENTORY_QUANTITY}.`,
        );
      }

      inventory[itemId] = nextQuantity;
      const revision = Number.isInteger(bunker.revision)
        ? bunker.revision + 1
        : 1;

      transaction.update(bunkerRef, {
        schemaVersion: BUNKER_SCHEMA_VERSION,
        survivors: normalizedBunkerSurvivors(bunker.survivors),
        busySurvivors: normalizedBusySurvivors(bunker.busySurvivors),
        inventory,
        revision,
        serverUpdatedAt: FieldValue.serverTimestamp(),
      });

      return {
        itemId,
        addedQuantity: quantity,
        quantity: nextQuantity,
        revision,
      };
    });
  },
);

exports.resetUserForTesting = onCall(
  RESET_CALLABLE_OPTIONS,
  async (request) => {
    requireDevelopmentAccess(request);

    if (request.data?.confirm !== true) {
      throw new HttpsError(
        "failed-precondition",
        "Explicit confirmation is required to reset user data.",
      );
    }

    const db = getFirestore();
    const userRef = db.collection("users").doc(request.auth.uid);

    await db.recursiveDelete(userRef);

    return {
      deleted: true,
    };
  },
);
