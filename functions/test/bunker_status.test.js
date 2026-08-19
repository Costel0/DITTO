const assert = require("node:assert/strict");
const test = require("node:test");
const {
  fixStatus,
  normalizedSurvivor,
} = require("../bunker_status");

function fakeDb() {
  return {
    collection: () => ({
      doc: () => ({}),
    }),
  };
}

function fakeTransaction(multiplier) {
  return {
    get: async () => ({
      data: () => ({
        config: {
          sleepingSecondsPerNegativeEnergy: multiplier,
        },
      }),
    }),
  };
}

test("new Survivors default to 50 energy", () => {
  const survivor = normalizedSurvivor(null, "s1", "01");
  assert.equal(survivor.energy, 50);
});

test("fixStatus moves negative idle Survivors to sleeping", async () => {
  const now = new Date("2026-08-18T12:00:00.987Z");
  const fixed = await fixStatus({
    transaction: fakeTransaction(10),
    db: fakeDb(),
    now,
    bunker: {
      revision: 7,
      survivors: [
        normalizedSurvivor({energy: -3}, "s1", "01"),
      ],
      idleSurvivors: ["s1"],
      busySurvivors: [],
      inventory: {},
    },
  });

  assert.equal(fixed.schemaVersion, 5);
  assert.equal(fixed.revision, 8);
  assert.deepEqual(fixed.idleSurvivors, []);
  assert.equal(fixed.busySurvivors.length, 1);
  assert.equal(fixed.busySurvivors[0].survivorId, "s1");
  assert.equal(fixed.busySurvivors[0].activity, "sleeping");
  assert.equal(fixed.busySurvivors[0].location, "beds");
  assert.equal(
    fixed.busySurvivors[0].startedAt.toISOString(),
    "2026-08-18T12:00:00.000Z",
  );
  assert.equal(
    fixed.busySurvivors[0].endsAt.toISOString(),
    "2026-08-18T12:00:30.000Z",
  );
});

test("fixStatus leaves completed occupations untouched", async () => {
  const fixed = await fixStatus({
    transaction: fakeTransaction(10),
    db: fakeDb(),
    now: new Date("2026-08-18T12:10:00Z"),
    bunker: {
      revision: 2,
      survivors: [
        normalizedSurvivor({energy: -8}, "s1", "01"),
      ],
      idleSurvivors: [],
      busySurvivors: [
        {
          survivorId: "s1",
          activity: "sleeping",
          startedAt: new Date("2026-08-18T12:00:00Z"),
          endsAt: new Date("2026-08-18T12:08:00Z"),
        },
      ],
      inventory: {},
    },
  });

  assert.deepEqual(fixed.idleSurvivors, []);
  assert.equal(fixed.busySurvivors.length, 1);
  assert.equal(fixed.busySurvivors[0].survivorId, "s1");
  assert.equal(fixed.busySurvivors[0].activity, "sleeping");
  assert.equal(fixed.busySurvivors[0].location, "beds");
  assert.equal(
    fixed.busySurvivors[0].endsAt.toISOString(),
    "2026-08-18T12:08:00.000Z",
  );
  assert.equal(fixed.survivors[0].energy, -8);
});
