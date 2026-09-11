const test = require("node:test");
const assert = require("node:assert/strict");
const {normalizedType} = require("../map/admin_mutations");

test("manual map types are normalized to uppercase safe slugs", () => {
  assert.equal(normalizedType(" hunting ", "Type"), "HUNTING");
  assert.equal(normalizedType("abandoned_building", "Type"), "ABANDONED_BUILDING");
});

test("manual map types reject invalid or status-like values", () => {
  assert.throws(() => normalizedType("", "Type"), /safe type slug/);
  assert.throws(() => normalizedType("lake-side", "Type"), /safe type slug/);
  assert.throws(() => normalizedType("POPULATED", "Type"), /safe type slug/);
});
