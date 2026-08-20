const fs = require("fs");
const path = require("path");
const {
  applicationDefault,
  initializeApp,
} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

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

function validateStringList(value, label) {
  if (!Array.isArray(value)) {
    throw new Error(`${label} must be a list.`);
  }
  const normalized = value.map((entry) => {
    if (typeof entry !== "string" || !entry.trim()) {
      throw new Error(`${label} must contain non-empty strings.`);
    }
    return entry.trim();
  });
  if (new Set(normalized).size !== normalized.length) {
    throw new Error(`${label} cannot contain duplicates.`);
  }
  return normalized;
}

function validateInventoryMap(value, label, {positiveOnly = false} = {}) {
  if (!isPlainObject(value)) {
    throw new Error(`${label} must be an object.`);
  }
  for (const [itemId, quantity] of Object.entries(value)) {
    if (!itemId.trim() || !Number.isInteger(quantity)) {
      throw new Error(`${label} contains an invalid item quantity.`);
    }
    if (positiveOnly && quantity <= 0) {
      throw new Error(`${label} quantities must be positive integers.`);
    }
  }
}

function validateCompletion(value, label) {
  if (!isPlainObject(value)) {
    throw new Error(`${label} must be an object.`);
  }
  if (!Number.isInteger(value.energyDelta)) {
    throw new Error(`${label}.energyDelta must be an integer.`);
  }
  validateInventoryMap(value.inventoryDelta, `${label}.inventoryDelta`);
}

function validateJobTasks(data, filename) {
  if (!isPlainObject(data.tasks)) {
    throw new Error(`${filename}.tasks must be an object.`);
  }

  const taskEntries = Object.entries(data.tasks);
  const taskIds = new Set(taskEntries.map(([taskId]) => taskId));
  const storableByTaskId = new Map();
  const requirementsByTaskId = new Map();

  for (const [taskId, task] of taskEntries) {
    if (!taskId.trim() || !isPlainObject(task)) {
      throw new Error(`${filename} contains an invalid task entry.`);
    }
    if (typeof task.activity !== "string" || !task.activity.trim()) {
      throw new Error(`${filename}.${taskId}.activity must be a string.`);
    }
    if (typeof task.location !== "string" || !task.location.trim()) {
      throw new Error(`${filename}.${taskId}.location must be a string.`);
    }
    if (
      typeof task.durationSeconds !== "number" ||
      !Number.isFinite(task.durationSeconds) ||
      task.durationSeconds <= 0
    ) {
      throw new Error(
        `${filename}.${taskId}.durationSeconds must be a positive number.`,
      );
    }
    if (typeof task.storable !== "boolean") {
      throw new Error(`${filename}.${taskId}.storable must be a boolean.`);
    }
    storableByTaskId.set(taskId, task.storable);

    if (!isPlainObject(task.survivorRequirements)) {
      throw new Error(
        `${filename}.${taskId}.survivorRequirements must be an object.`,
      );
    }
    const {min, max} = task.survivorRequirements;
    if (!Number.isInteger(min) || min < 1) {
      throw new Error(
        `${filename}.${taskId}.survivorRequirements.min must be >= 1.`,
      );
    }
    if (!Number.isInteger(max) || max < min) {
      throw new Error(
        `${filename}.${taskId}.survivorRequirements.max must be >= min.`,
      );
    }

    const requiredTaskIds = validateStringList(
      task.requiredTaskIds,
      `${filename}.${taskId}.requiredTaskIds`,
    );
    if (requiredTaskIds.includes(taskId)) {
      throw new Error(`${filename}.${taskId} cannot require itself.`);
    }
    requirementsByTaskId.set(taskId, requiredTaskIds);

    if (!isPlainObject(task.cost)) {
      throw new Error(`${filename}.${taskId}.cost must be an object.`);
    }
    validateInventoryMap(
      task.cost.inventory,
      `${filename}.${taskId}.cost.inventory`,
      {positiveOnly: true},
    );

    if (!isPlainObject(task.outcomes) || Object.keys(task.outcomes).length === 0) {
      throw new Error(
        `${filename}.${taskId}.outcomes must contain at least one outcome.`,
      );
    }
    if (!isPlainObject(task.outcomeEffects)) {
      throw new Error(`${filename}.${taskId}.outcomeEffects must be an object.`);
    }

    let totalProbability = 0;
    for (const [outcomeId, probability] of Object.entries(task.outcomes)) {
      if (!outcomeId.trim()) {
        throw new Error(`${filename}.${taskId} contains an empty outcome ID.`);
      }
      if (
        typeof probability !== "number" ||
        !Number.isFinite(probability) ||
        probability < 0 ||
        probability > 1
      ) {
        throw new Error(
          `${filename}.${taskId}.outcomes.${outcomeId} must be 0..1.`,
        );
      }
      totalProbability += probability;
      if (!Object.prototype.hasOwnProperty.call(task.outcomeEffects, outcomeId)) {
        throw new Error(
          `${filename}.${taskId}.${outcomeId} is missing outcomeEffects.`,
        );
      }
      validateCompletion(
        task.outcomeEffects[outcomeId],
        `${filename}.${taskId}.outcomeEffects.${outcomeId}`,
      );
    }

    if (Math.abs(totalProbability - 1) > 1e-9) {
      throw new Error(
        `${filename}.${taskId} outcome probabilities must add up to 1.`,
      );
    }

    for (const outcomeId of Object.keys(task.outcomeEffects)) {
      if (!Object.prototype.hasOwnProperty.call(task.outcomes, outcomeId)) {
        throw new Error(
          `${filename}.${taskId} has effects for unknown outcome ${outcomeId}.`,
        );
      }
    }
  }

  for (const [taskId, requiredTaskIds] of requirementsByTaskId) {
    for (const requiredTaskId of requiredTaskIds) {
      if (!taskIds.has(requiredTaskId)) {
        throw new Error(
          `${filename}.${taskId} requires unknown task ${requiredTaskId}.`,
        );
      }
      if (!storableByTaskId.get(requiredTaskId)) {
        throw new Error(
          `${filename}.${taskId} requires non-storable task ${requiredTaskId}.`,
        );
      }
    }
  }
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

function loadServerData() {
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
    if (!documentId) {
      throw new Error(`Unable to derive document ID from ${filename}.`);
    }
    if (documents.has(documentId)) {
      throw new Error(`Duplicate server data document ID: ${documentId}.`);
    }

    const filePath = path.join(dataDirectory, filename);
    const data = JSON.parse(fs.readFileSync(filePath, "utf8"));
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
      validateJobTasks(data, filename);
    }

    documents.set(documentId, {filename, data});
  }

  return documents;
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const documents = loadServerData();
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
