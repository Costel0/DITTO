const assert = require("node:assert/strict");
const test = require("node:test");
const {resetTaskTreeStateForTesting} = require("../development_state");

test("resetTaskTreeStateForTesting clears completed jobs and cancels active jobs", () => {
  const now = new Date("2026-08-20T10:00:00Z");
  const bunker = {
    completedTaskIds: ["prepare_garden", "repair_door"],
    idleSurvivors: ["s3"],
    busySurvivors: [
      {
        survivorId: "s1",
        taskId: "prepare_garden",
        executionId: "exec-1",
        activity: "prepare_garden",
        location: "garden",
        startedAt: now,
        endsAt: new Date(now.getTime() + 300000),
      },
      {
        survivorId: "s2",
        activity: "sleeping",
        location: "beds",
        startedAt: now,
        endsAt: new Date(now.getTime() + 60000),
      },
    ],
    inventory: {scrap_metal: 4},
    survivors: [
      {id: "s1", energy: 25},
      {id: "s2", energy: -2},
      {id: "s3", energy: 40},
    ],
  };

  const result = resetTaskTreeStateForTesting(bunker, now);

  assert.deepEqual(result.bunker.completedTaskIds, []);
  assert.deepEqual(new Set(result.bunker.idleSurvivors), new Set(["s1", "s3"]));
  assert.equal(result.bunker.busySurvivors.length, 1);
  assert.equal(result.bunker.busySurvivors[0].activity, "sleeping");
  assert.equal(result.bunker.busySurvivors[0].survivorId, "s2");
  assert.deepEqual(result.bunker.inventory, {scrap_metal: 4});
  assert.deepEqual(result.bunker.survivors, bunker.survivors);
  assert.equal(result.cancelledOccupationCount, 1);
  assert.equal(result.clearedCompletedTaskCount, 2);
});

test("resetTaskTreeStateForTesting does not resolve or mutate task effects", () => {
  const now = new Date("2026-08-20T10:00:00Z");
  const bunker = {
    completedTaskIds: [],
    idleSurvivors: [],
    busySurvivors: [
      {
        survivorId: "s1",
        taskId: "dangerous_job",
        executionId: "exec-2",
        activity: "dangerous_job",
        location: "workshop",
        startedAt: now,
        endsAt: new Date(now.getTime() - 1000),
      },
    ],
    inventory: {field_ration: 2},
    survivors: [{id: "s1", energy: 17}],
  };

  const result = resetTaskTreeStateForTesting(bunker, now);

  assert.deepEqual(result.bunker.busySurvivors, []);
  assert.deepEqual(result.bunker.idleSurvivors, ["s1"]);
  assert.deepEqual(result.bunker.inventory, {field_ration: 2});
  assert.equal(result.bunker.survivors[0].energy, 17);
});
