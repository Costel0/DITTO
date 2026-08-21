const fs = require("fs");
const path = require("path");
const {
  applicationDefault,
  initializeApp,
} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

const SURVIVOR_STAT_KEYS = new Set([
  "strength",
  "dexterity",
  "constitution",
  "stealth",
  "care",
  "cunning",
  "charm",
]);

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

function validateStatRequirements(value, label) {
  if (value == null) return;
  if (!isPlainObject(value)) {
    throw new Error(`${label} must be an object.`);
  }

  for (const [stat, requirement] of Object.entries(value)) {
    if (!SURVIVOR_STAT_KEYS.has(stat) || !isPlainObject(requirement)) {
      throw new Error(`${label} contains an invalid stat requirement.`);
    }
    if (
      !Number.isInteger(requirement.greaterThan) ||
      requirement.greaterThan < 0 ||
      requirement.greaterThan > 9
    ) {
      throw new Error(
        `${label}.${stat}.greaterThan must be an integer from 0 to 9.`,
      );
    }
  }
}

function validateStatExperienceDelta(value, label) {
  if (value == null) return;
  if (!isPlainObject(value)) {
    throw new Error(`${label} must be an object.`);
  }

  for (const [stat, amount] of Object.entries(value)) {
    if (!SURVIVOR_STAT_KEYS.has(stat)) {
      throw new Error(`${label} contains an unknown Survivor stat: ${stat}.`);
    }
    if (!Number.isInteger(amount) || amount < 0) {
      throw new Error(`${label}.${stat} must be a non-negative integer.`);
    }
  }
}

function validateEffects(value, label) {
  if (!isPlainObject(value)) {
    throw new Error(`${label} must be an object.`);
  }
  if (!Number.isInteger(value.energyDelta)) {
    throw new Error(`${label}.energyDelta must be an integer.`);
  }
  validateInventoryMap(value.inventoryDelta, `${label}.inventoryDelta`);
  validateStatExperienceDelta(
    value.statExperienceDelta,
    `${label}.statExperienceDelta`,
  );
}

function validateTaskResults(task, filename, taskId) {
  const label = `${filename}.${taskId}`;
  if (!isPlainObject(task.results) || Object.keys(task.results).length === 0) {
    throw new Error(`${label}.results must contain at least one result.`);
  }

  const resultIds = new Set(Object.keys(task.results));
  for (const [resultId, result] of Object.entries(task.results)) {
    if (!resultId.trim() || !isPlainObject(result)) {
      throw new Error(`${label}.results contains an invalid result.`);
    }

    validateEffects(
      result.guaranteedOutcomes,
      `${label}.results.${resultId}.guaranteedOutcomes`,
    );

    if (!isPlainObject(result.randomOutcomes)) {
      throw new Error(
        `${label}.results.${resultId}.randomOutcomes must be an object.`,
      );
    }
    for (const [outcomeId, outcome] of Object.entries(result.randomOutcomes)) {
      const outcomeLabel =
        `${label}.results.${resultId}.randomOutcomes.${outcomeId}`;
      if (!outcomeId.trim() || !isPlainObject(outcome)) {
        throw new Error(`${outcomeLabel} must be an object.`);
      }
      if (
        typeof outcome.probability !== "number" ||
        !Number.isFinite(outcome.probability) ||
        outcome.probability < 0 ||
        outcome.probability > 1
      ) {
        throw new Error(`${outcomeLabel}.probability must be 0..1.`);
      }
      validateEffects(outcome.effects, `${outcomeLabel}.effects`);
    }
  }

  if (!isPlainObject(task.resultResolver)) {
    throw new Error(`${label}.resultResolver must be an object.`);
  }
  const type = task.resultResolver.type;
  if (!["fixed", "random", "server", "combat"].includes(type)) {
    throw new Error(
      `${label}.resultResolver.type must be fixed, random, server or combat.`,
    );
  }

  if (type === "fixed") {
    if (
      typeof task.resultResolver.resultId !== "string" ||
      !resultIds.has(task.resultResolver.resultId.trim())
    ) {
      throw new Error(`${label}.resultResolver.resultId is not a known result.`);
    }
    return;
  }

  if (type === "random") {
    const probabilities = task.resultResolver.probabilities;
    if (!isPlainObject(probabilities)) {
      throw new Error(`${label}.resultResolver.probabilities must be an object.`);
    }

    const probabilityIds = new Set(Object.keys(probabilities));
    if (
      probabilityIds.size !== resultIds.size ||
      [...resultIds].some((resultId) => !probabilityIds.has(resultId))
    ) {
      throw new Error(
        `${label}.resultResolver.probabilities must define every result exactly once.`,
      );
    }

    let total = 0;
    for (const [resultId, probability] of Object.entries(probabilities)) {
      if (
        typeof probability !== "number" ||
        !Number.isFinite(probability) ||
        probability < 0 ||
        probability > 1
      ) {
        throw new Error(
          `${label}.resultResolver.probabilities.${resultId} must be 0..1.`,
        );
      }
      total += probability;
    }
    if (Math.abs(total - 1) > 1e-9) {
      throw new Error(`${label} result probabilities must add up to 1.`);
    }
    return;
  }

  if (
    typeof task.resultResolver.handler !== "string" ||
    !task.resultResolver.handler.trim()
  ) {
    throw new Error(
      `${label}.${type} resultResolver must define a non-empty handler.`,
    );
  }
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
    validateStatRequirements(
      task.survivorRequirements.statRequirements,
      `${filename}.${taskId}.survivorRequirements.statRequirements`,
    );

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

    validateTaskResults(task, filename, taskId);
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