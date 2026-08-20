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

function exampleTask() {
  return taskDefinitionFromSnapshot(
    snapshotWithTasks({
      example_task: {
        activity: "example_task",
        location: "garden",
        durationSeconds: 300,
        storable: true,
        survivorRequirements: {
          min: 1,
          max: 3,
        },
        requiredTaskIds: ["required_task"],
        cost: {
          inventory: {
            scrap_metal: 2,
          },
        },
        resultResolver: {
          type: "random",
          probabilities: {
            success: 0.75,
            failure: 0.25,
          },
        },
        results: {
          success: {
            guaranteedOutcomes: {
              energyDelta: -4,
              inventoryDelta: {
                field_ration: 2,
              },
            },
            randomOutcomes: {
              accident: {
                probability: 0.02,
                effects: {
                  energyDelta: -3,
                  inventoryDelta: {},
                },
              },
            },
          },
          failure: {
            guaranteedOutcomes: {
              energyDelta: -2,
              inventoryDelta: {},
            },
            randomOutcomes: {},
          },
        },
      },
    }),
    "example_task",
  );
}

test("taskDefinitionFromSnapshot normalizes nested result definitions", () => {
  const task = exampleTask();

  assert.equal(task.id, "example_task");
  assert.equal(task.durationSeconds, 300);
  assert.equal(task.storable, true);
  assert.deepEqual(task.survivorRequirements, {min: 1, max: 3});
  assert.deepEqual(task.requiredTaskIds, ["required_task"]);
  assert.deepEqual(task.cost.inventory, {scrap_metal: 2});
  assert.equal(task.resultResolver.type, "random");
  assert.deepEqual(task.resultResolver.probabilities, {
    success: 0.75,
    failure: 0.25,
  });
  assert.equal(task.results.success.randomOutcomes[0].id, "accident");
  assert.equal(task.results.success.randomOutcomes[0].probability, 0.02);
});

test("first completion-only task format remains readable", () => {
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
  assert.deepEqual(task.resultResolver, {type: "fixed", resultId: "default"});
  assert.deepEqual(task.results.default.guaranteedOutcomes, {
    energyDelta: -1,
    inventoryDelta: {scrap_metal: 1},
  });
  assert.deepEqual(task.results.default.randomOutcomes, []);
});

test("legacy mutually exclusive outcomes remain readable", () => {
  const task = taskDefinitionFromSnapshot(
    snapshotWithTasks({
      legacy: {
        activity: "legacy",
        location: "garden",
        durationSeconds: 10,
        outcomes: {
          success: 0.7,
          failure: 0.3,
        },
        outcomeEffects: {
          success: {energyDelta: -1, inventoryDelta: {scrap_metal: 1}},
          failure: {energyDelta: -2, inventoryDelta: {}},
        },
      },
    }),
    "legacy",
  );

  assert.equal(task.resultResolver.type, "random");
  assert.deepEqual(task.resultResolver.probabilities, {
    success: 0.7,
    failure: 0.3,
  });
  assert.equal(task.results.success.guaranteedOutcomes.energyDelta, -1);
  assert.deepEqual(task.results.success.randomOutcomes, []);
});

test("taskDefinitionFromSnapshot returns null for unknown tasks", () => {
  const task = taskDefinitionFromSnapshot(snapshotWithTasks({}), "missing");
  assert.equal(task, null);
});

test("fixed result selection returns configured result", () => {
  const task = taskDefinitionFromSnapshot(
    snapshotWithTasks({
      fixed: {
        location: "garden",
        durationSeconds: 10,
        resultResolver: {type: "fixed", resultId: "success"},
        results: {
          success: {
            guaranteedOutcomes: {energyDelta: 0, inventoryDelta: {}},
            randomOutcomes: {},
          },
        },
      },
    }),
    "fixed",
  );

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
  const task = taskDefinitionFromSnapshot(
    snapshotWithTasks({
      server_task: {
        location: "garden",
        durationSeconds: 10,
        resultResolver: {type: "server", handler: "server_v1"},
        results: {
          success: {
            guaranteedOutcomes: {energyDelta: 0, inventoryDelta: {}},
            randomOutcomes: {},
          },
          failure: {
            guaranteedOutcomes: {energyDelta: 0, inventoryDelta: {}},
            randomOutcomes: {},
          },
        },
      },
    }),
    "server_task",
  );

  assert.throws(
    () => selectTaskResult(task, "execution-1"),
    /generic resolution cannot decide it yet/,
  );
  assert.equal(selectTaskResult(task, "execution-1", "success").id, "success");
});

test("guaranteed and probabilistic effects are evaluated separately", () => {
  const task = taskDefinitionFromSnapshot(
    snapshotWithTasks({
      risky: {
        location: "garden",
        durationSeconds: 10,
        resultResolver: {type: "fixed", resultId: "success"},
        results: {
          success: {
            guaranteedOutcomes: {
              energyDelta: -5,
              inventoryDelta: {scrap_metal: 2},
            },
            randomOutcomes: {
              guaranteed_extra: {
                probability: 1,
                effects: {
                  energyDelta: -2,
                  inventoryDelta: {field_ration: 1},
                },
              },
              impossible: {
                probability: 0,
                effects: {
                  energyDelta: -50,
                  inventoryDelta: {field_ration: 99},
                },
              },
            },
          },
        },
      },
    }),
    "risky",
  );

  const result = applyTaskCompletionEffects(
    {
      survivors: [
        {id: "s1", energy: 20},
        {id: "s2", energy: 10},
      ],
      inventory: {},
    },
    ["s1", "s2"],
    task,
    "success",
    "execution-1",
  );

  assert.equal(result.bunker.survivors[0].energy, 13);
  assert.equal(result.bunker.survivors[1].energy, 3);
  assert.deepEqual(result.bunker.inventory, {
    scrap_metal: 2,
    field_ration: 1,
  });
  assert.deepEqual(result.triggeredRandomOutcomeIds, ["guaranteed_extra"]);
});

test("task start cost is paid once from bunker inventory", () => {
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

test("task start cost rejects insufficient inventory", () => {
  const task = exampleTask();
  assert.throws(
    () => applyTaskStartCost({inventory: {scrap_metal: 1}}, task),
    /negative/,
  );
});

test("missingRequiredTaskIds checks stored task history", () => {
  const task = exampleTask();
  assert.deepEqual(missingRequiredTaskIds({completedTaskIds: []}, task), [
    "required_task",
  ]);
  assert.deepEqual(
    missingRequiredTaskIds(
      {completedTaskIds: ["required_task"]},
      task,
    ),
    [],
  );
});
