const fs = require("node:fs");
const path = require("node:path");
const {spawn} = require("node:child_process");
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

const MAP_EXPORT_DIRECTORY = path.resolve(__dirname, "..", "map_exports");
const DEFAULT_MAP_EXPORT_BASE = path.join(MAP_EXPORT_DIRECTORY, "latest_map");
const DEFAULT_MAP_RENDER_PATH = path.join(MAP_EXPORT_DIRECTORY, "latest_map.svg");

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
  console.log(`DITTO map administration\n\nUsage:\n  node scripts/map_admin.js init [--force] [--project=ID] [--max=50] [--alpha=2]\n  node scripts/map_admin.js expand --max=80 [--project=ID]\n  node scripts/map_admin.js add-players --count=100 [--project=ID]\n  node scripts/map_admin.js download [--project=ID] [--out=PATH] [--format=json|csv|both]\n  node scripts/map_admin.js render [--in=PATH] [--out=PATH] [--open=true|false]\n\nRoot wrappers:\n  .\\map.cmd init --force\n  .\\map.cmd expand --max=80\n  .\\map.cmd add-players --count=100\n  .\\map.cmd download\n  .\\map.cmd render\n\nDefault local files (overwritten on every run):\n  functions/map_exports/latest_map.json\n  functions/map_exports/latest_map.csv\n  functions/map_exports/latest_map.svg\n`);
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

function normalizedExportBase(rawPath) {
  if (!rawPath) return DEFAULT_MAP_EXPORT_BASE;
  return path.resolve(rawPath).replace(/\.(json|csv)$/i, "");
}

function booleanOption(options, name, fallback) {
  if (options[name] === undefined) return fallback;
  const value = String(options[name]).trim().toLowerCase();
  if (value === "true" || value === "1" || value === "yes") return true;
  if (value === "false" || value === "0" || value === "no") return false;
  throw new Error(`--${name} must be true or false.`);
}

function xmlEscape(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

function buildMapSvg(payload) {
  if (!payload || !Array.isArray(payload.sectors) || payload.sectors.length === 0) {
    throw new Error("Downloaded map contains no sectors to render.");
  }

  const sectors = payload.sectors;
  const letters = [...new Set(sectors.map((sector) => sector.letter))]
    .filter((letter) => typeof letter === "string")
    .sort((a, b) => a.localeCompare(b));
  const numbers = [...new Set(sectors.map((sector) => Number(sector.number)))]
    .filter(Number.isFinite)
    .sort((a, b) => a - b);

  if (letters.length === 0 || numbers.length === 0) {
    throw new Error("Downloaded map has invalid sector coordinates.");
  }

  const cellSize = 22;
  const labelWidth = 42;
  const titleHeight = 64;
  const numberLabelHeight = 24;
  const legendHeight = 42;
  const gridX = labelWidth;
  const gridY = titleHeight + numberLabelHeight;
  const gridWidth = numbers.length * cellSize;
  const gridHeight = letters.length * cellSize;
  const width = gridX + gridWidth + 24;
  const height = gridY + gridHeight + legendHeight + 18;
  const sectorById = new Map(sectors.map((sector) => [sector.id, sector]));

  const counts = payload.counts || {};
  const title = `DITTO map - ${numbers[0]}..${numbers[numbers.length - 1]}`;
  const subtitle = `Sectors: ${counts.sectors ?? sectors.length} | Bunkers: ${counts.playerBunkers ?? "?"} | Populated: ${counts.populated ?? "?"}`;

  const parts = [
    `<?xml version="1.0" encoding="UTF-8"?>`,
    `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">`,
    `<rect width="100%" height="100%" fill="#ffffff"/>`,
    `<text x="18" y="25" font-family="Arial, sans-serif" font-size="18" font-weight="700" fill="#202124">${xmlEscape(title)}</text>`,
    `<text x="18" y="46" font-family="Arial, sans-serif" font-size="11" fill="#5f6368">${xmlEscape(subtitle)}</text>`,
  ];

  numbers.forEach((number, column) => {
    const x = gridX + column * cellSize + cellSize / 2;
    parts.push(
      `<text x="${x}" y="${gridY - 8}" font-family="Arial, sans-serif" font-size="8" text-anchor="middle" fill="#5f6368">${number}</text>`,
    );
  });

  letters.forEach((letter, row) => {
    const centerY = gridY + row * cellSize + cellSize / 2;
    parts.push(
      `<text x="${gridX - 12}" y="${centerY + 3}" font-family="Arial, sans-serif" font-size="9" text-anchor="middle" fill="#5f6368">${xmlEscape(letter)}</text>`,
    );

    numbers.forEach((number, column) => {
      const id = `${letter}${number}`;
      const sector = sectorById.get(id);
      const x = gridX + column * cellSize;
      const y = gridY + row * cellSize;

      let fill = "#f5f6f7";
      let titleText = `${id}: UNGENERATED`;
      if (sector?.type === "PLAYER_BUNKER") {
        fill = "#d85b57";
        titleText = `${id}: PLAYER_BUNKER${sector.playerId ? ` (${sector.playerId})` : ""}`;
      } else if (sector?.status === "POPULATED") {
        fill = "#b8bec7";
        titleText = `${id}: ${sector.type || "POPULATED"}`;
      }

      parts.push(
        `<rect x="${x}" y="${y}" width="${cellSize}" height="${cellSize}" fill="${fill}" stroke="#d0d4d9" stroke-width="1"><title>${xmlEscape(titleText)}</title></rect>`,
      );
    });
  });

  const legendY = gridY + gridHeight + 22;
  const legendItems = [
    {label: "Ungenerated", fill: "#f5f6f7"},
    {label: "Populated", fill: "#b8bec7"},
    {label: "Player bunker", fill: "#d85b57"},
  ];
  let legendX = gridX;
  for (const item of legendItems) {
    parts.push(
      `<rect x="${legendX}" y="${legendY - 10}" width="13" height="13" fill="${item.fill}" stroke="#aeb4bc" stroke-width="1"/>`,
      `<text x="${legendX + 19}" y="${legendY}" font-family="Arial, sans-serif" font-size="10" fill="#3c4043">${xmlEscape(item.label)}</text>`,
    );
    legendX += item.label.length * 6.2 + 44;
  }

  parts.push(`</svg>`);
  return parts.join("\n");
}

function openLocalFile(filePath) {
  let command;
  let args;

  if (process.platform === "win32") {
    command = "cmd.exe";
    args = ["/c", "start", "", filePath];
  } else if (process.platform === "darwin") {
    command = "open";
    args = [filePath];
  } else {
    command = "xdg-open";
    args = [filePath];
  }

  const child = spawn(command, args, {
    detached: true,
    stdio: "ignore",
    windowsHide: true,
  });
  child.unref();
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

  const base = normalizedExportBase(options.out);
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

function runRender(options) {
  const input = options.in
    ? path.resolve(options.in)
    : `${DEFAULT_MAP_EXPORT_BASE}.json`;
  const output = options.out
    ? path.resolve(options.out)
    : DEFAULT_MAP_RENDER_PATH;
  const shouldOpen = booleanOption(options, "open", true);

  if (!fs.existsSync(input)) {
    throw new Error(
      `Downloaded map not found: ${input}. Run map download first or use --in=PATH.`,
    );
  }

  const payload = JSON.parse(fs.readFileSync(input, "utf8"));
  const svg = buildMapSvg(payload);
  fs.mkdirSync(path.dirname(output), {recursive: true});
  fs.writeFileSync(output, `${svg}\n`, "utf8");

  console.log(`Map image written to ${output}`);
  if (shouldOpen) {
    openLocalFile(output);
    console.log("Opened map image with the system default viewer/browser.");
  }
}

async function main() {
  const {command, options} = parseArgs(process.argv.slice(2));
  if (!command || command === "help" || command === "--help" || command === "-h") {
    usage();
    return;
  }

  // render is intentionally local-only: it uses the most recently downloaded
  // JSON file and must not require Firebase credentials or a network call.
  if (command === "render") {
    runRender(options);
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
