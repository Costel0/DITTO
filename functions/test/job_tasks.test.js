const assert = require("node:assert/strict");
const test = require("node:test");
const {
  applyTaskCompletionEffects,
  applyTaskStartCost,
  missingRequiredTaskIds,
  selectTaskResult,
  taskDefinitionFromSnapshot,
} = require("../job_tasks");

function snapshotWithTasks(tasks) {
  return {
    data: () => ({tasks}),
  };
}

function rawExampleTask(overrides = {}) {
  return {
    activity: "clear_garden",
    location: "garden",
    durationSeconds: 300,
    storable: true,
    survivorRequirements: {min: 1, max: 3},
    requiredTaskIds: [],
    cost: {inventory: {scrap_metal: 2}},
    resultResolver: {
      type: "random",
      probabilities: {
        success: 0.8,
        failure: 0.2,
      },
    },
    results: {
      success: {
        guaranteedOutcomes: {
          energyDelta: -5,
          inventoryDelta: {field_ration: 2},
        },
        randomOutcomes: {
          minor_accident: {
            probability: 0.02,
            effects: {
              energyDelta: -4,
              inventoryDelta: {},
            },
          },
        },
      },
      failure: {
        guaranteedOutcomes: {
          energyDelta: -3,
          inventoryDelta: {},
        },
        randomOutcomes: {},
      },
    },
    ...overrides,
  };
}

function exampleTask(overrides = {}) {
  return taskDefinitionFromSnapshot(
    snapshotWithTasks({clear_garden: rawExampleTask(overrides)}),
    "clear_garden",
  );
}

test("taskDefinitionFromSnapshot normalizes nested result definitions", () => {
  const task = exampleTask();

  assert.equal(task.id, "clear_garden");
  assert.equal(task.storable, true);
  assert.deepEqual(task.survivorRequirements, {min: 1, max: 3});
  assert.deepEqual(task.cost.inventory, {scrap_metal: 2});
  assert.equal(task.resultResolver.type, "random");
  assert.deepEqual(task.resultResolver.probabilities, {
    success: 0.8,
    failure: 0.2,
  });
  assert.equal(task.results.success.guaranteedOutcomes.energyDelta, -5);
  assert.equal(task.results.success.randomOutcomes[0].id, "minor_accident");
  assert.equal(task.results.success.randomOutcomes[0].probability, 0.02);
});

test("legacy mutually exclusive outcomes remain readable", () => {
  const task = taskDefinitionFromSnapshot(
    snapshotWithTasks({
      legacy: {
        location: "garden",
        durationSeconds: 10,
        outcomes: {success: 0.75, failure: 0.25},
        outcomeEffects: {
          success: {energyDelta: -1, inventoryDelta: {scrap_metal: 1}},
          failure: {energyDelta: -2, inventoryDelta: {}},
        },
      },
    }),
    "legacy",
  );

  assert.equal(task.resultResolver.type, "random");
  assert.equal(task.results.success.guaranteedOutcomes.energyDelta, -1);
  assert.deepEqual(task.results.success.randomOutcomes, []);
});

test("taskDefinitionFromSnapshot returns null for unknown tasks", () => {
  const task = taskDefinitionFromSnapshot(snapshotWithTasks({}), "missing");
  assert.equal(task, null);
});

test("fixed result selection returns configured result", () => {
  const task = exampleTask({
    resultResolver: {type: "fixed", resultId: "success"},
  });

  assert.equal(selectTaskResult(task, "execution-1").id, "success");
});

test("random result selection is deterministic per execution", () => {
  const task = exampleTask();
  const first = selectTaskResult(task, "execution-123");
  const second = selectTaskResult(task, "execution-123");

  assert.equal(first.id, second.id);
  assert.ok(["success", "failure"].includes(first.id));
});

test("server/combat result resolvers require an external result", () => {
  const task = exampleTask({
    resultResolver: {type: "combat", handler: "combat_v1"},
  });

  assert.throws(
    () => selectTaskResult(task, "execution-1"),
    /generic resolution cannot decide/,
  );
  assert.equal(
    selectTaskResult(task, "execution-1", "failure").id,
    "failure",
  );
});

test("guaranteed and probabilistic effects are evaluated separately", () => {
  const task = exampleTask({
    resultResolver: {type: "fixed", resultId: "success"},
    results: {
      success: {
        guaranteedOutcomes: {
          energyDelta: -5,
          inventoryDelta: {field_ration: 2},
        },
        randomOutcomes: {
          guaranteed_test_event: {
            probability: 1,
            effects: {
              energyDelta: -4,
              inventoryDelta: {scrap_metal: 1},
            },
          },
          impossible_test_event: {
            probability: 0,
            effects: {
              energyDelta: -99,
              inventoryDelta: {},
            },
          },
        },
      },
    },
  });

  const bunker = {
    survivors: [
      {id: "s1", energy: 20},
      {id: "s2", energy: 30},
    ],
    inventory: {},
  };

  const completion = applyTaskCompletionEffects(
    bunker,
    ["s1", "s2"],
    task,
    "success",
    "execution-1",
  );

  assert.deepEqual(completion.triggeredRandomOutcomeIds, [
    "guaranteed_test_event",
  ]);
  assert.equal(completion.bunker.survivors[0].energy, 11);
  assert.equal(completion.bunker.survivors[1].energy, 21);
  assert.deepEqual(completion.bunker.inventory, {
    field_ration: 2,
    scrap_metal: 1,
  });
});

test("task start cost is paid once from bunker inventory", () => {
  const task = exampleTask();
  const bunker = {
    inventory: {scrap_metal: 5},
  };

  const result = applyTaskStartCost(bunker, task);
  assert.deepEqual(result.inventory, {scrap_metal: 3});
  assert.deepEqual(bunker.inventory, {scrap_metal: 5});
});

test("task start cost rejects insufficient inventory", () => {
  const task = exampleTask();
  assert.throws(
    () => applyTaskStartCost({inventory: {scrap_metal: 1}}, task),
    /negative/,
  );
});

test("missingRequiredTaskIds checks stored task history", () => {
  const task = exampleTask({requiredTaskIds: ["first", "second"]});

  assert.deepEqual(
    missingRequiredTaskIds({completedTaskIds: ["first"]}, task),
    ["second"],
  );
});
