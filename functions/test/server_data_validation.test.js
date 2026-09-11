const assert = require("node:assert/strict");
const {spawnSync} = require("node:child_process");
const path = require("node:path");
const test = require("node:test");

test("server data dry-run validation succeeds", () => {
  const result = spawnSync(
    process.execPath,
    ["scripts/sync_server_data_v2.js", "--dry-run"],
    {
      cwd: path.resolve(__dirname, ".."),
      encoding: "utf8",
    },
  );

  assert.equal(
    result.status,
    0,
    [
      "sync_server_data_v2.js --dry-run failed.",
      result.stdout,
      result.stderr,
    ].filter(Boolean).join("\n"),
  );
});
