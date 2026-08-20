const assert = require("node:assert/strict");
const test = require("node:test");
const {
  applyTaskCompletionEffects,
  applyTaskStartCost,
  missingRequiredTaskIds,
  selectTaskOutcome,
  taskDefinitionFromSnapshot,
} = require("../job_tasks");

function snapshotWithTasks(tasks) {
  return {
    data: () => ({tasks}),
  };
}

function exampleTask() {
  return taskDefinitionFromSnapshot(
    snapshotWithTasks({
      clear_garden: {
        activity: "clear_garden",
        location: "garden",
        durationSeconds: 300,
        storable: true,
        survivorRequirements: {
          min: 1,
          max: 3,
        },
        requiredTaskIds: ["prepare_garden"],
        cost: {
          inventory: {
            scrap_metal: 2,
          },
        },
        outcomes: {
          success: 0.75,
          failure: 0.25,
        },
        outcomeEffects: {
          success: {
            energyDelta: -4,
            inventoryDelta: {
              field_ration: 2,
            },
          },
          failure: {
            energyDelta: -2,
            inventoryDelta: {},
          },
        },
      },
    }),
    "clear_garden",
  );
}

test("taskDefinitionFromSnapshot normalizes expanded server task definitions", () => {
  const task = exampleTask();

  assert.equal(task.id, "clear_garden");
  assert.equal(task.durationSeconds, 300);
  assert.equal(task.storable, true);
  assert.deepEqual(task.survivorRequirements, {min: 1, max: 3});
  assert.deepEqual(task.requiredTaskIds, ["prepare_garden"]);
  assert.deepEqual(task.cost.inventory, {scrap_metal: 2});
  assert.deepEqual(
    task.outcomes.map(({id, probability}) => ({id, probability})),
    [
      {id: "success", probability: 0.75},
      {id: "failure", probability: 0.25},
    ],
  );
});

test("taskDefinitionFromSnapshot remains compatible with legacy completion", () => {
  const task = taskDefinitionFromSnapshot(
    snapshotWithTasks({
      legacy: {
        activity: "legacy",
        location: "garden",
        durationSeconds: 10,
        completion: {
          energyDelta: -1,
          inventoryDelta: {scrap_metal: 1},
        },
      },
    }),
    "legacy",
  );

  assert.equal(task.storable, false);
  assert.deepEqual(task.survivorRequirements, {min: 1, max: 1});
  assert.equal(task.outcomes.length, 1);
  assert.equal(task.outcomes[0].id, "default");
  assert.equal(task.outcomes[0].probability, 1);
});

test("taskDefinitionFromSnapshot rejects outcome probabilities that do not sum to 1", () => {
  assert.throws(
    () => taskDefinitionFromSnapshot(
      snapshotWithTasks({
        invalid: {
          location: "garden",
          durationSeconds: 10,
          outcomes: {success: 0.7, failure: 0.2},
          outcomeEffects: {
            success: {energyDelta: 0, inventoryDelta: {}},
            failure: {energyDelta: 0, inventoryDelta: {}},
          },
        },
      }),
      "invalid",
    ),
    /add up to 1/,
  );
});

test("taskDefinitionFromSnapshot returns null for unknown tasks", () => {
  const task = taskDefinitionFromSnapshot(snapshotWithTasks({}), "missing");
  assert.equal(task, null);
});

test("applyTaskStartCost consumes inventory once", () => {
  const task = exampleTask();
  const bunker = {
    inventory: {
      scrap_metal: 5,
      field_ration: 1,
    },
  };

  const result = applyTaskStartCost(bunker, task);

  assert.deepEqual(result.inventory, {
    scrap_metal: 3,
    field_ration: 1,
  });
  assert.equal(bunker.inventory.scrap_metal, 5);
});

test("applyTaskStartCost rejects insufficient inventory", () => {
  const task = exampleTask();
  assert.throws(
    () => applyTaskStartCost({inventory: {scrap_metal: 1}}, task),
    /negative/,
  );
});

test("missingRequiredTaskIds uses the stored completed task registry", () => {
  const task = exampleTask();
  assert.deepEqual(missingRequiredTaskIds({completedTaskIds: []}, task), [
    "prepare_garden",
  ]);
  assert.deepEqual(
    missingRequiredTaskIds(
      {completedTaskIds: ["prepare_garden"]},
      task,
    ),
    [],
  );
});

test("selectTaskOutcome is deterministic for one execution", () => {
  const task = exampleTask();
  const first = selectTaskOutcome(task, "execution-123");
  const second = selectTaskOutcome(task, "execution-123");

  assert.equal(first.id, second.id);
  assert.ok(["success", "failure"].includes(first.id));
});

test("applyTaskCompletionEffects affects every participant but inventory once", () => {
  const task = exampleTask();
  const bunker = {
    survivors: [
      {id: "s1", duplicateId: "01", energy: 12},
      {id: "s2", duplicateId: "02", energy: 9},
      {id: "s3", duplicateId: "03", energy: 20},
    ],
    inventory: {
      field_ration: 1,
    },
  };

  const result = applyTaskCompletionEffects(
    bunker,
    ["s1", "s2"],
    task,
    "success",
  );

  assert.equal(result.survivors[0].energy, 8);
  assert.equal(result.survivors[1].energy, 5);
  assert.equal(result.survivors[2].energy, 20);
  assert.deepEqual(result.inventory, {field_ration: 3});
  assert.equal(bunker.survivors[0].energy, 12);
  assert.equal(bunker.inventory.field_ration, 1);
});
