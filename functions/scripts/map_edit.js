const fs = require("node:fs");
const path = require("node:path");
const {
  applicationDefault,
  initializeApp,
} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {
  setSectorType,
  setZoneType,
} = require("../map/admin_mutations");

function parseArgs(argv) {
  const [command, ...rest] = argv;
  const options = {};
  for (const arg of rest) {
    if (!arg.startsWith("--") || !arg.includes("=")) {
      throw new Error(`Unknown argument: ${arg}`);
    }
    const separator = arg.indexOf("=");
    options[arg.substring(2, separator)] = arg.substring(separator + 1);
  }
  return {command, options};
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

function initializeFirebase(projectId) {
  const resolvedProjectId = projectId ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    process.env.GCLOUD_PROJECT ||
    projectIdFromFirebaseRc();

  if (process.env.FIRESTORE_EMULATOR_HOST) {
    initializeApp({projectId: resolvedProjectId || "ditto-local"});
    return getFirestore();
  }
  if (!resolvedProjectId) {
    throw new Error("Firebase project ID was not found. Use --project=PROJECT_ID.");
  }
  initializeApp({
    credential: applicationDefault(),
    projectId: resolvedProjectId,
  });
  return getFirestore();
}

function usage() {
  console.log(`DITTO manual map editing\n\nUsage:\n  node scripts/map_edit.js set-sector --sector=H28 --type=HUNTING [--project=ID]\n  node scripts/map_edit.js set-zone --sector=H28 --zone=3 --type=LAKE [--project=ID]\n\nPLAYER_BUNKER cannot be created or overwritten with these commands.\n`);
}

async function main() {
  const {command, options} = parseArgs(process.argv.slice(2));
  if (!command || command === "help" || command === "--help" || command === "-h") {
    usage();
    return;
  }

  const db = initializeFirebase(options.project);
  if (command === "set-sector") {
    if (!options.sector || !options.type) {
      throw new Error("set-sector requires --sector=ID and --type=TYPE.");
    }
    const result = await setSectorType(db, options.sector, options.type);
    console.log(JSON.stringify(result, null, 2));
    return;
  }

  if (command === "set-zone") {
    if (!options.sector || options.zone === undefined || !options.type) {
      throw new Error(
        "set-zone requires --sector=ID, --zone=N and --type=TYPE.",
      );
    }
    const result = await setZoneType(
      db,
      options.sector,
      options.zone,
      options.type,
    );
    console.log(JSON.stringify(result, null, 2));
    return;
  }

  throw new Error(`Unknown map edit command: ${command}`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
