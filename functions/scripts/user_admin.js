const fs = require("node:fs");
const path = require("node:path");
const {
  applicationDefault,
  initializeApp,
} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

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

function initializeFirebase(explicitProjectId) {
  const projectId = explicitProjectId ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    process.env.GCLOUD_PROJECT ||
    projectIdFromFirebaseRc();

  if (process.env.FIRESTORE_EMULATOR_HOST) {
    initializeApp({projectId: projectId || "ditto-local"});
    return getFirestore();
  }
  if (!projectId) {
    throw new Error("Firebase project ID was not found. Use --project=PROJECT_ID.");
  }
  initializeApp({
    credential: applicationDefault(),
    projectId,
  });
  return getFirestore();
}

async function clearAllUserData(db) {
  // All game/account information created by DITTO is rooted below users/{uid}.
  // This script deliberately never initializes or calls Firebase Auth.
  const snapshot = await db.collection("users").select().get();
  const ids = snapshot.docs.map((doc) => doc.id);

  let cleared = 0;
  for (const uid of ids) {
    await db.recursiveDelete(db.collection("users").doc(uid));
    cleared += 1;
    if (cleared % 25 === 0 || cleared === ids.length) {
      console.log(`Cleared ${cleared}/${ids.length} user data tree(s)...`);
    }
  }
  return {
    firestoreUserTreesFound: ids.length,
    userTreesCleared: cleared,
  };
}

function usage() {
  console.log(`DITTO user administration\n\nUsage:\n  node scripts/user_admin.js clear-data --confirm=DELETE [--project=ID]\n\nclear-data recursively deletes users/{uid} Firestore data for every configured account.\nFirebase Authentication is never accessed or modified. The shared map is NOT reset.\n`);
}

async function main() {
  const {command, options} = parseArgs(process.argv.slice(2));
  if (!command || command === "help" || command === "--help" || command === "-h") {
    usage();
    return;
  }
  if (command !== "clear-data") {
    throw new Error(`Unknown user command: ${command}`);
  }
  if (options.confirm !== "DELETE") {
    throw new Error(
      "Refusing destructive operation. Re-run with --confirm=DELETE.",
    );
  }

  const db = initializeFirebase(options.project);
  const result = await clearAllUserData(db);
  console.log(JSON.stringify(result, null, 2));
  console.log("Firebase Authentication was not accessed or modified.");
  console.log(
    "The shared world map was not changed. Use map init --force separately for a clean world.",
  );
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
