const test = require("node:test");
const assert = require("node:assert/strict");
const {normalizedBunkerCoordinates} = require("../bunker_status");
const {normalizedCoordinates} = require("../expeditions");

test("bunker coordinates accept safe integers beyond the legacy 999 limit", () => {
  assert.deepEqual(
    normalizedBunkerCoordinates({x: 12, y: 100000, z: 3}),
    {x: 12, y: 100000, z: 3},
  );
});

test("bunker coordinates still reject invalid negative values", () => {
  assert.deepEqual(
    normalizedBunkerCoordinates({x: -1, y: 25, z: 1}),
    {x: 0, y: 25, z: 1},
  );
});

test("expedition coordinates accept the map's unbounded numeric axis", () => {
  assert.deepEqual(
    normalizedCoordinates({x: 12, y: 100000, z: 3}),
    {x: 12, y: 100000, z: 3},
  );
  assert.throws(
    () => normalizedCoordinates({x: 12, y: -1, z: 3}),
    /positive safe integer/,
  );
});