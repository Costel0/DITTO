const test = require("node:test");
const assert = require("node:assert/strict");
const {
  DEFAULT_CONFIG,
  chooseWeightedCandidate,
  forbiddenOffsets,
  proximityWeight,
  sectorDistance,
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

test("weighted selector follows cumulative priority", () => {
  const fakeDoc = (id, priority) => ({
    id,
    data: () => ({priority}),
  });
  const docs = [fakeDoc("A", 1), fakeDoc("B", 3), fakeDoc("C", 6)];

  assert.equal(chooseWeightedCandidate(docs, () => 0.01).id, "A");
  assert.equal(chooseWeightedCandidate(docs, () => 0.20).id, "B");
  assert.equal(chooseWeightedCandidate(docs, () => 0.90).id, "C");
});
