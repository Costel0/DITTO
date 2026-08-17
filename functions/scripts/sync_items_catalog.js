const fs = require("fs");
const path = require("path");
const {
  applicationDefault,
  initializeApp,
} = require("firebase-admin/app");
const {
  FieldValue,
  getFirestore,
} = require("firebase-admin/firestore");

const VALID_TYPES = new Set(["weapon", "equipment", "resource", "food"]);
const ITEM_ID_PATTERN = /^[a-z0-9_]+$/;
const BATCH_SIZE = 400;

function parseArgs(argv) {
  const options = {
    dryRun: false,
    prune: false,
    projectId: null,
  };

  for (const arg of argv) {
    if (arg === "--dry-run") {
      options.dryRun = true;
    } else if (arg === "--prune") {
      options.prune = true;
    } else if (arg.startsWith("--project=")) {
      options.projectId = arg.substring("--project=".length).trim() || null;
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return options;
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function validateLocalizedText(value, field, itemId, allowEmpty = false) {
  if (!isPlainObject(value)) {
    throw new Error(`${itemId}.${field} must be an object keyed by language code.`);
  }

  const entries = Object.entries(value);
  if (!allowEmpty && entries.length === 0) {
    throw new Error(`${itemId}.${field} must contain at least one language.`);
  }

  for (const [language, text] of entries) {
    if (!language.trim() || typeof text !== "string") {
      throw new Error(`${itemId}.${field} contains an invalid localized entry.`);
    }
  }
}

function validateStringList(value, field, itemId, allowEmpty = true) {
  if (!Array.isArray(value)) {
    throw new Error(`${itemId}.${field} must be an array of strings.`);
  }
  if (!allowEmpty && value.length === 0) {
    throw new Error(`${itemId}.${field} must contain at least one value.`);
  }

  const seen = new Set();
  for (const entry of value) {
    if (typeof entry !== "string" || !entry.trim()) {
      throw new Error(`${itemId}.${field} contains an invalid value.`);
    }
    if (seen.has(entry)) {
      throw new Error(`${itemId}.${field} contains duplicate value: ${entry}`);
    }
    seen.add(entry);
  }
}

function validateCatalog(catalog) {
  if (!Number.isInteger(catalog.schemaVersion) || catalog.schemaVersion < 1) {
    throw new Error("schemaVersion must be a positive integer.");
  }
  if (!Number.isInteger(catalog.catalogVersion) || catalog.catalogVersion < 1) {
    throw new Error("catalogVersion must be a positive integer.");
  }
  if (!Array.isArray(catalog.items)) {
    throw new Error("items must be an array.");
  }

  const ids = new Set();
  for (const item of catalog.items) {
    if (!isPlainObject(item)) {
      throw new Error("Every item must be an object.");
    }
    if (typeof item.id !== "string" || !ITEM_ID_PATTERN.test(item.id)) {
      throw new Error(`Invalid item id: ${item.id}`);
    }
    if (ids.has(item.id)) {
      throw new Error(`Duplicate item id: ${item.id}`);
    }
    ids.add(item.id);

    validateStringList(item.type, "type", item.id, false);
    for (const type of item.type) {
      if (!VALID_TYPES.has(type)) {
        throw new Error(`Unsupported type for ${item.id}: ${type}`);
      }
    }
    validateStringList(item.subtype, "subtype", item.id, true);

    if (!Number.isInteger(item.value) || item.value < 0) {
      throw new Error(`${item.id}.value must be a non-negative integer.`);
    }
    if (typeof item.stackable !== "boolean") {
      throw new Error(`${item.id}.stackable must be boolean.`);
    }
    validateLocalizedText(item.name, "name", item.id);
    validateLocalizedText(item.description, "description", item.id, true);
    if (!isPlainObject(item.stats)) {
      throw new Error(`${item.id}.stats must be an object.`);
    }
  }

  return ids;
}

function projectIdFromFirebaseRc() {
  const firebaseRcPath = path.resolve(__dirname, "../../.firebaserc");
  if (!fs.existsSync(firebaseRcPath)) return null;

  try {
    const firebaseRc = JSON.parse(fs.readFileSync(firebaseRcPath, "utf8"));
    const projectId = firebaseRc?.projects?.default;
    return typeof projectId === "string" && projectId.trim()
      ? projectId.trim()
      : null;
  } catch (_) {
    return null;
  }
}

function resolveProjectId(explicitProjectId) {
  return explicitProjectId ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    process.env.GCLOUD_PROJECT ||
    projectIdFromFirebaseRc() ||
    null;
}

function initializeAdmin(projectId) {
  if (process.env.FIRESTORE_EMULATOR_HOST) {
    initializeApp({projectId: projectId || "ditto-local"});
    return;
  }

  initializeApp({
    credential: applicationDefault(),
    ...(projectId ? {projectId} : {}),
  });
}

async function commitOperations(db, operations) {
  for (let start = 0; start < operations.length; start += BATCH_SIZE) {
    const batch = db.batch();
    for (const operation of operations.slice(start, start + BATCH_SIZE)) {
      if (operation.type === "set") {
        batch.set(operation.ref, operation.data, {merge: false});
      } else {
        batch.delete(operation.ref);
      }
    }
    await batch.commit();
  }
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const catalogPath = path.resolve(__dirname, "../../game_data/items.json");
  const catalog = JSON.parse(fs.readFileSync(catalogPath, "utf8"));
  const sourceIds = validateCatalog(catalog);
  const projectId = resolveProjectId(options.projectId);

  console.log(
    `Catalog v${catalog.catalogVersion}: ${catalog.items.length} valid items.`,
  );

  if (options.dryRun) {
    console.log("Dry run complete. Firestore was not modified.");
    return;
  }

  if (!projectId && !process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error(
      "Firebase project ID was not found. Use --project=PROJECT_ID, an environment variable, or .firebaserc.",
    );
  }

  initializeAdmin(projectId);
  const db = getFirestore();
  const operations = [];

  for (const item of catalog.items) {
    const {id, ...definition} = item;
    operations.push({
      type: "set",
      ref: db.collection("items").doc(id),
      data: {
        ...definition,
        schemaVersion: catalog.schemaVersion,
        catalogVersion: catalog.catalogVersion,
        updatedAt: FieldValue.serverTimestamp(),
      },
    });
  }

  let prunedCount = 0;
  if (options.prune) {
    const existing = await db.collection("items").get();
    for (const document of existing.docs) {
      if (!sourceIds.has(document.id)) {
        operations.push({type: "delete", ref: document.ref});
        prunedCount += 1;
      }
    }
  }

  await commitOperations(db, operations);

  await db.collection("gameData").doc("itemCatalog").set({
    schemaVersion: catalog.schemaVersion,
    catalogVersion: catalog.catalogVersion,
    itemCount: catalog.items.length,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: false});

  console.log(
    `Synced ${catalog.items.length} items to /items in ${projectId || "emulator"}.` +
      (options.prune ? ` Pruned ${prunedCount} stale items.` : ""),
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
