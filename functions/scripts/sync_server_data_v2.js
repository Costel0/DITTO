const fs = require("node:fs");
const path = require("node:path");
const {
  applicationDefault,
  initializeApp,
} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {expeditionDefinitionFromSnapshot} = require("../expeditions");
const {taskDefinitionFromSnapshot} = require("../job_tasks");

function parseArgs(argv) {
  const options = {
    dryRun: false,
    prune: false,
    projectId: null,
  };
  for (const arg of argv) {
    if (arg === "--dry-run") options.dryRun = true;
    else if (arg === "--prune") options.prune = true;
    else if (arg.startsWith("--project=")) {
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

function fakeSnapshot(data) {
  return {data: () => data};
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

function documentIdFromFilename(filename) {
  const basename = path.basename(filename, ".json");
  return basename.replace(/_([a-z0-9])/g, (_, character) =>
    character.toUpperCase(),
  );
}

function loadKnownItemIds() {
  const filePath = path.resolve(__dirname, "../../game_data/items.json");
  const catalog = JSON.parse(fs.readFileSync(filePath, "utf8"));
  if (!Array.isArray(catalog.items)) {
    throw new Error("game_data/items.json.items must be an array.");
  }
  const ids = new Set();
  for (const item of catalog.items) {
    const id = typeof item?.id === "string" ? item.id.trim() : "";
    if (!id || ids.has(id)) {
      throw new Error(
        "game_data/items.json contains an invalid or duplicate item ID.",
      );
    }
    ids.add(id);
  }
  return ids;
}

function assertKnownInventoryItems(inventory, label, knownItemIds) {
  for (const itemId of Object.keys(inventory || {})) {
    if (!knownItemIds.has(itemId)) {
      throw new Error(`${label} references unknown item ${itemId}.`);
    }
  }
}

function validateJobTasks(data, filename, knownItemIds) {
  if (!isPlainObject(data.tasks)) {
    throw new Error(`${filename}.tasks must be an object.`);
  }
  const taskIds = new Set(Object.keys(data.tasks));
  const normalized = new Map();
  for (const taskId of taskIds) {
    const task = taskDefinitionFromSnapshot(fakeSnapshot(data), taskId);
    if (!task) throw new Error(`${filename}.${taskId} is invalid.`);
    normalized.set(taskId, task);

    assertKnownInventoryItems(
      task.cost.inventory,
      `${filename}.${taskId}.cost.inventory`,
      knownItemIds,
    );
    for (const [resultId, result] of Object.entries(task.results)) {
      assertKnownInventoryItems(
        result.guaranteedOutcomes?.inventoryDelta,
        `${filename}.${taskId}.results.${resultId}.guaranteedOutcomes.inventoryDelta`,
        knownItemIds,
      );
      for (const outcome of result.randomOutcomes || []) {
        assertKnownInventoryItems(
          outcome.effects?.inventoryDelta,
          `${filename}.${taskId}.results.${resultId}.randomOutcomes.${outcome.id}.effects.inventoryDelta`,
          knownItemIds,
        );
      }
    }
  }

  for (const [taskId, task] of normalized) {
    for (const requiredTaskId of task.requiredTaskIds) {
      if (!taskIds.has(requiredTaskId)) {
        throw new Error(
          `${filename}.${taskId} requires unknown task ${requiredTaskId}.`,
        );
      }
      if (!normalized.get(requiredTaskId)?.storable) {
        throw new Error(
          `${filename}.${taskId} requires non-storable task ${requiredTaskId}.`,
        );
      }
    }
  }
}

function validateExpeditions(data, filename, knownItemIds) {
  const definition = expeditionDefinitionFromSnapshot(fakeSnapshot(data));
  if (Object.keys(definition.actions).length === 0) {
    throw new Error(`${filename}.actions must contain at least one action.`);
  }

  for (const action of Object.values(definition.actions)) {
    for (const [outcomeId, outcome] of Object.entries(action.outcomes || {})) {
      for (const [optionId, option] of Object.entries(
        outcome.resolutionOptions || {},
      )) {
        assertKnownInventoryItems(
          option.inventoryDelta,
          `${filename}.${action.id}.${outcomeId}.${optionId}.inventoryDelta`,
          knownItemIds,
        );
      }
    }
  }
}

function validateServerConfig(data, filename) {
  if (!isPlainObject(data.config)) {
    throw new Error(`${filename}.config must be an object.`);
  }
  const sleeping = data.config.sleepingSecondsPerNegativeEnergy;
  if (
    sleeping != null &&
    (typeof sleeping !== "number" || !Number.isFinite(sleeping) || sleeping <= 0)
  ) {
    throw new Error(
      `${filename}.config.sleepingSecondsPerNegativeEnergy must be > 0.`,
    );
  }
  const travel = data.config.expeditionTravelSecondsPerDistanceUnit;
  if (
    travel != null &&
    (typeof travel !== "number" || !Number.isFinite(travel) || travel < 0)
  ) {
    throw new Error(
      `${filename}.config.expeditionTravelSecondsPerDistanceUnit must be >= 0.`,
    );
  }
}

function loadServerData(knownItemIds) {
  const dataDirectory = path.resolve(__dirname, "../../game_data/server");
  if (!fs.existsSync(dataDirectory)) {
    throw new Error(`Server data directory not found: ${dataDirectory}`);
  }

  const filenames = fs.readdirSync(dataDirectory)
    .filter((filename) => filename.endsWith(".json"))
    .sort();
  const documents = new Map();

  for (const filename of filenames) {
    const documentId = documentIdFromFilename(filename);
    if (!documentId || documents.has(documentId)) {
      throw new Error(`Invalid or duplicate server data document ID: ${documentId}.`);
    }
    const data = JSON.parse(
      fs.readFileSync(path.join(dataDirectory, filename), "utf8"),
    );
    if (!isPlainObject(data)) {
      throw new Error(`${filename} must contain a JSON object at its root.`);
    }
    if (!Number.isInteger(data.schemaVersion) || data.schemaVersion < 1) {
      throw new Error(`${filename}.schemaVersion must be a positive integer.`);
    }
    if (!Number.isInteger(data.dataVersion) || data.dataVersion < 1) {
      throw new Error(`${filename}.dataVersion must be a positive integer.`);
    }

    if (documentId === "jobTasks") {
      validateJobTasks(data, filename, knownItemIds);
    } else if (documentId === "expeditions") {
      validateExpeditions(data, filename, knownItemIds);
    } else if (documentId === "serverConfig") {
      validateServerConfig(data, filename);
    }
    documents.set(documentId, {filename, data});
  }
  return documents;
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const knownItemIds = loadKnownItemIds();
  const documents = loadServerData(knownItemIds);
  const projectId = resolveProjectId(options.projectId);

  console.log(`Validated ${documents.size} server data file(s):`);
  for (const [documentId, entry] of documents) {
    console.log(`  ${entry.filename} -> /serverData/${documentId}`);
  }

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
  const collection = db.collection("serverData");
  const batch = db.batch();
  for (const [documentId, entry] of documents) {
    batch.set(collection.doc(documentId), entry.data, {merge: false});
  }

  let prunedCount = 0;
  if (options.prune) {
    const existing = await collection.get();
    for (const document of existing.docs) {
      if (!documents.has(document.id)) {
        batch.delete(document.ref);
        prunedCount += 1;
      }
    }
  }
  await batch.commit();

  console.log(
    `Synced ${documents.size} server data document(s) to ${projectId || "emulator"}.` +
      (options.prune ? ` Pruned ${prunedCount} stale document(s).` : ""),
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
