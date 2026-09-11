const fs = require("node:fs");
const path = require("node:path");
const {
  applicationDefault,
  initializeApp,
} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
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
    return {db: getFirestore(), auth: getAuth()};
  }
  if (!projectId) {
    throw new Error("Firebase project ID was not found. Use --project=PROJECT_ID.");
  }
  initializeApp({
    credential: applicationDefault(),
    projectId,
  });
  return {db: getFirestore(), auth: getAuth()};
}

async function allAuthUserIds(auth) {
  const ids = [];
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    ids.push(...page.users.map((user) => user.uid));
    pageToken = page.pageToken;
  } while (pageToken);
  return ids;
}

async function allFirestoreUserIds(db) {
  const snapshot = await db.collection("users").select().get();
  return snapshot.docs.map((doc) => doc.id);
}

async function clearAllUserData(db, auth) {
  // Union both sources: Auth guarantees that even an account with a missing
  // parent user document but surviving subcollections gets cleaned; Firestore
  // also catches stale game data whose Auth account was previously removed.
  const [authIds, firestoreIds] = await Promise.all([
    allAuthUserIds(auth),
    allFirestoreUserIds(db),
  ]);
  const ids = [...new Set([...authIds, ...firestoreIds])];

  let cleared = 0;
  for (const uid of ids) {
    await db.recursiveDelete(db.collection("users").doc(uid));
    cleared += 1;
    if (cleared % 25 === 0 || cleared === ids.length) {
      console.log(`Cleared ${cleared}/${ids.length} user data tree(s)...`);
    }
  }
  return {
    authAccountsPreserved: authIds.length,
    firestoreRootsFound: firestoreIds.length,
    userTreesCleared: cleared,
  };
}

function usage() {
  console.log(`DITTO user administration\n\nUsage:\n  node scripts/user_admin.js clear-data --confirm=DELETE [--project=ID]\n\nclear-data recursively deletes users/{uid} Firestore data for every account.\nFirebase Authentication accounts are NOT deleted. The shared map is NOT reset.\n`);
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

  const {db, auth} = initializeFirebase(options.project);
  const result = await clearAllUserData(db, auth);
  console.log(JSON.stringify(result, null, 2));
  console.log("Firebase Authentication accounts were preserved.");
  console.log(
    "The shared world map was not changed. Use map init --force separately for a clean world.",
  );
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
