const assert = require("node:assert/strict");
const test = require("node:test");
const {
  BUNKER_SCHEMA_VERSION,
  fixStatus,
  normalizedActiveBackgroundTasks,
  normalizedBusySurvivors,
  normalizedPendingExpeditionReviews,
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

  assert.equal(fixed.schemaVersion, BUNKER_SCHEMA_VERSION);
  assert.equal(fixed.revision, 8);
  assert.deepEqual(fixed.idleSurvivors, []);
  assert.deepEqual(fixed.completedTaskIds, []);
  assert.deepEqual(fixed.activeBackgroundTasks, []);
  assert.deepEqual(fixed.bunkerCoordinates, {x: 0, y: 0, z: 0});
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

test("normalizedBusySurvivors preserves task and execution IDs", () => {
  const [busy] = normalizedBusySurvivors([
    {
      survivorId: "s1",
      taskId: "test_task",
      executionId: "exec-1",
      expeditionType: "test_expedition",
      activity: "test_task",
      location: "test_area",
      startedAt: new Date("2026-08-18T12:00:00Z"),
      endsAt: new Date("2026-08-18T12:05:00Z"),
    },
  ]);

  assert.equal(busy.taskId, "test_task");
  assert.equal(busy.executionId, "exec-1");
  assert.equal(busy.expeditionType, "test_expedition");
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
      completedTaskIds: ["test_task", "test_task"],
      inventory: {},
    },
  });

  assert.deepEqual(fixed.idleSurvivors, []);
  assert.deepEqual(fixed.completedTaskIds, ["test_task"]);
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

test("fixStatus preserves assigned bunker coordinates", async () => {
  const assigned = {x: 7, y: 8, z: 9};
  const fixed = await fixStatus({
    transaction: fakeTransaction(10),
    db: fakeDb(),
    bunker: {
      revision: 1,
      survivors: [],
      idleSurvivors: [],
      busySurvivors: [],
      completedTaskIds: [],
      inventory: {},
      bunkerCoordinates: assigned,
    },
  });

  assert.deepEqual(fixed.bunkerCoordinates, assigned);
});

test("pending expedition summaries never expose outcome details", () => {
  const [summary] = normalizedPendingExpeditionReviews([
    {
      id: "review-1",
      executionId: "exec-1",
      expeditionType: "test_type",
      actionIds: ["inspect"],
      survivorIds: ["s1"],
      coordinates: {x: 1, y: 2, z: 3},
      completedAt: new Date("2026-09-09T12:00:00Z"),
      inventoryDelta: {secret_item: 4},
      outcomes: [
        {
          actionId: "inspect",
          outcomeId: "secret",
          narrativeId: "secret_narrative",
          inventoryDelta: {secret_item: 4},
        },
      ],
    },
  ]);

  assert.equal(summary.id, "review-1");
  assert.equal(summary.expeditionType, "test_type");
  assert.equal(summary.resolutionStatus, "pending_interactive");
  assert.deepEqual(summary.coordinates, {x: 1, y: 2, z: 3});
  assert.equal("inventoryDelta" in summary, false);
  assert.equal("outcomes" in summary, false);
  assert.equal("resolutionOptions" in summary, false);
});


test("busy normalization preserves positive taskExecutionCount", () => {
  const [busy] = normalizedBusySurvivors([
    {
      survivorId: "s1",
      activity: "craft_electronics_from_scrap",
      location: "workshop",
      taskId: "craft_electronics_from_scrap",
      taskExecutionCount: 7,
      startedAt: new Date("2026-09-09T12:00:00Z"),
      endsAt: new Date("2026-09-09T12:03:30Z"),
    },
  ]);

  assert.equal(busy.taskExecutionCount, 7);
});


test("background task normalization preserves timing without occupying starter", async () => {
  const now = new Date("2026-09-09T12:00:00Z");
  const background = normalizedActiveBackgroundTasks([
    {
      executionId: "crop-1",
      taskId: "plant_potatoes",
      activity: "plant_potatoes",
      location: "garden",
      startedBySurvivorId: "s1",
      startedAt: now,
      endsAt: new Date("2026-09-09T12:01:00Z"),
    },
  ]);

  assert.equal(background.length, 1);
  assert.equal(background[0].startedBySurvivorId, "s1");

  const fixed = await fixStatus({
    transaction: fakeTransaction(10),
    db: fakeDb(),
    now,
    bunker: {
      revision: 1,
      survivors: [normalizedSurvivor({energy: 50}, "s1", "01")],
      idleSurvivors: ["s1"],
      busySurvivors: [],
      activeBackgroundTasks: background,
      completedTaskIds: [],
      inventory: {},
    },
  });

  assert.deepEqual(fixed.idleSurvivors, ["s1"]);
  assert.deepEqual(fixed.busySurvivors, []);
  assert.equal(fixed.activeBackgroundTasks.length, 1);
  assert.equal(
    fixed.activeBackgroundTasks[0].endsAt.toISOString(),
    "2026-09-09T12:01:00.000Z",
  );
});
