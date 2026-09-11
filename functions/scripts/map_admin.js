const fs = require("node:fs");
const path = require("node:path");
const {
  applicationDefault,
  initializeApp,
} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {
  addSimulatedPlayers,
  expandMap,
  exportMap,
  initializeMap,
} = require("../map");

function parseArgs(argv) {
  const [command, ...rest] = argv;
  if (!command) return {command: null, options: {}};

  const options = {};
  for (const arg of rest) {
    if (arg === "--force") {
      options.force = true;
      continue;
    }
    if (!arg.startsWith("--") || !arg.includes("=")) {
      throw new Error(`Unknown argument: ${arg}`);
    }
    const separator = arg.indexOf("=");
    const key = arg.substring(2, separator);
    const value = arg.substring(separator + 1);
    options[key] = value;
  }

  return {command, options};
}

function integerOption(options, name, fallback = null) {
  if (options[name] === undefined) return fallback;
  const value = Number(options[name]);
  if (!Number.isInteger(value)) {
    throw new Error(`--${name} must be an integer.`);
  }
  return value;
}

function numberOption(options, name, fallback = null) {
  if (options[name] === undefined) return fallback;
  const value = Number(options[name]);
  if (!Number.isFinite(value)) {
    throw new Error(`--${name} must be a number.`);
  }
  return value;
}

function usage() {
  console.log(`DITTO map administration\n\nUsage:\n  node scripts/map_admin.js init [--force] [--project=ID] [--max=50] [--alpha=2]\n  node scripts/map_admin.js expand --max=80 [--project=ID]\n  node scripts/map_admin.js add-players --count=100 [--project=ID]\n  node scripts/map_admin.js download [--project=ID] [--out=PATH] [--format=json|csv|both]\n\nRoot wrappers:\n  .\\map.cmd init --force\n  .\\map.cmd expand --max=80\n  .\\map.cmd add-players --count=100\n  .\\map.cmd download\n`);
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

function initializeFirebase(projectId) {
  if (process.env.FIRESTORE_EMULATOR_HOST) {
    initializeApp({projectId: projectId || "ditto-local"});
    return getFirestore();
  }

  if (!projectId) {
    throw new Error(
      "Firebase project ID was not found. Use --project=PROJECT_ID, an environment variable, or .firebaserc.",
    );
  }

  initializeApp({
    credential: applicationDefault(),
    projectId,
  });
  return getFirestore();
}

function csvEscape(value) {
  if (value === null || value === undefined) return "";
  const text = String(value);
  if (/[",\n\r]/.test(text)) return `"${text.replaceAll('"', '""')}"`;
  return text;
}

function mapToCsv(payload) {
  const header = [
    "id",
    "letter",
    "number",
    "status",
    "type",
    "playerId",
    "spawnPriority",
    "isSpawnCandidate",
    "zones",
  ];
  const rows = payload.sectors.map((sector) => [
    sector.id,
    sector.letter,
    sector.number,
    sector.status,
    sector.type,
    sector.playerId,
    sector.spawnPriority,
    sector.isSpawnCandidate,
    JSON.stringify(sector.zones || []),
  ]);
  return [header, ...rows]
    .map((row) => row.map(csvEscape).join(","))
    .join("\n");
}

function defaultExportBase() {
  const stamp = new Date().toISOString().replaceAll(":", "-").replaceAll(".", "-");
  return path.resolve(__dirname, "..", "map_exports", `map_${stamp}`);
}

async function runInit(db, options) {
  const max = integerOption(options, "max", 50);
  const alpha = numberOption(options, "alpha", 2);
  const result = await initializeMap(db, {
    force: options.force === true,
    config: {
      initialNumberMax: max,
      priorityAlpha: alpha,
    },
  });
  console.log(JSON.stringify(result, null, 2));
}

async function runExpand(db, options) {
  const max = integerOption(options, "max");
  if (max === null) throw new Error("expand requires --max=N.");
  const result = await expandMap(db, max);
  console.log(JSON.stringify(result, null, 2));
}

async function runAddPlayers(db, options) {
  const count = integerOption(options, "count");
  if (count === null) throw new Error("add-players requires --count=N.");
  const players = await addSimulatedPlayers(db, count);
  for (const player of players) {
    console.log(`${player.playerId} -> ${player.sectorId} (priority=${player.priority})`);
  }
  console.log(`Added ${players.length} simulated player(s).`);
}

async function runDownload(db, options) {
  const payload = await exportMap(db);
  const format = String(options.format || "json").toLowerCase();
  if (!new Set(["json", "csv", "both"]).has(format)) {
    throw new Error("--format must be json, csv, or both.");
  }

  const requestedOut = options.out ? path.resolve(options.out) : null;
  const base = requestedOut
    ? requestedOut.replace(/\.(json|csv)$/i, "")
    : defaultExportBase();
  fs.mkdirSync(path.dirname(base), {recursive: true});

  const written = [];
  if (format === "json" || format === "both") {
    const file = `${base}.json`;
    fs.writeFileSync(file, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
    written.push(file);
  }
  if (format === "csv" || format === "both") {
    const file = `${base}.csv`;
    fs.writeFileSync(file, `${mapToCsv(payload)}\n`, "utf8");
    written.push(file);
  }

  console.log(`Map exported. Sectors: ${payload.counts.sectors}; players: ${payload.counts.playerBunkers}; candidates: ${payload.counts.spawnCandidates}`);
  for (const file of written) console.log(file);
}

async function main() {
  const {command, options} = parseArgs(process.argv.slice(2));
  if (!command || command === "help" || command === "--help" || command === "-h") {
    usage();
    return;
  }

  const explicitProjectId = typeof options.project === "string" && options.project.trim()
    ? options.project.trim()
    : null;
  const projectId = resolveProjectId(explicitProjectId);
  const db = initializeFirebase(projectId);

  if (command === "init") return runInit(db, options);
  if (command === "expand") return runExpand(db, options);
  if (command === "add-players") return runAddPlayers(db, options);
  if (command === "download") return runDownload(db, options);

  throw new Error(`Unknown map command: ${command}`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
