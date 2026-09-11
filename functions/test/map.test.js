const test = require("node:test");
const assert = require("node:assert/strict");
const {
  DEFAULT_CONFIG,
  chooseWeightedCandidate,
  chooseWeightedChunk,
  chunksForWindow,
  forbiddenOffsets,
  proximityWeight,
  sectorDistance,
  spawnChunkForNumber,
  spawnWindowForNumber,
} = require("../map");

test("sectorDistance uses Euclidean sector coordinates", () => {
  assert.equal(sectorDistance(
    {letter: "B", number: 11},
    {letter: "C", number: 11},
  ), 1);
  assert.equal(sectorDistance(
    {letter: "B", number: 11},
    {letter: "C", number: 12},
  ), Math.sqrt(2));
});

test("minimum player distance 2 invalidates exactly 13 integer offsets", () => {
  const offsets = forbiddenOffsets(2);
  assert.equal(offsets.length, 13);
  assert.ok(offsets.some(({dx, dy}) => dx === 2 && dy === 0));
  assert.ok(offsets.some(({dx, dy}) => dx === 1 && dy === 1));
  assert.ok(!offsets.some(({dx, dy}) => dx === 2 && dy === 1));
});

test("spawn priority is highest at M25 and falls with distance", () => {
  const center = proximityWeight({letter: "M", number: 25}, DEFAULT_CONFIG);
  const near = proximityWeight({letter: "N", number: 27}, DEFAULT_CONFIG);
  const far = proximityWeight({letter: "W", number: 40}, DEFAULT_CONFIG);
  assert.equal(center, 1);
  assert.ok(center > near);
  assert.ok(near > far);
});

test("spawn windows and chunks respect configured boundaries", () => {
  assert.deepEqual(spawnWindowForNumber(10), {min: 10, max: 40});
  assert.deepEqual(spawnWindowForNumber(40), {min: 10, max: 40});
  assert.deepEqual(spawnWindowForNumber(41), {min: 41, max: 80});
  assert.deepEqual(spawnWindowForNumber(81), {min: 81, max: 120});

  assert.equal(spawnChunkForNumber(10).id, "10-14");
  assert.equal(spawnChunkForNumber(39).id, "35-39");
  assert.equal(spawnChunkForNumber(40).id, "40-40");
  assert.equal(spawnChunkForNumber(41).id, "41-45");

  assert.equal(chunksForWindow(10, 40).length, 7);
  assert.equal(chunksForWindow(41, 80).length, 8);
});

test("distance-two invalidation crosses at most three chunks at window edge", () => {
  const chunkIds = new Set(
    [38, 39, 40, 41, 42].map((number) => spawnChunkForNumber(number).id),
  );
  assert.deepEqual([...chunkIds], ["35-39", "40-40", "41-45"]);
});

test("weighted chunk selector follows chunk total weights", () => {
  const chunks = [
    {id: "A", totalWeight: 1},
    {id: "B", totalWeight: 3},
    {id: "C", totalWeight: 6},
  ];

  assert.equal(chooseWeightedChunk(chunks, () => 0.01).id, "A");
  assert.equal(chooseWeightedChunk(chunks, () => 0.20).id, "B");
  assert.equal(chooseWeightedChunk(chunks, () => 0.90).id, "C");
});

test("weighted candidate selector follows candidate priorities", () => {
  const candidates = {
    A10: 1,
    B10: 3,
    C10: 6,
  };

  assert.equal(chooseWeightedCandidate(candidates, () => 0.01).id, "A10");
  assert.equal(chooseWeightedCandidate(candidates, () => 0.20).id, "B10");
  assert.equal(chooseWeightedCandidate(candidates, () => 0.90).id, "C10");
});
