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
