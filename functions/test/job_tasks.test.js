const assert = require("node:assert/strict");
const test = require("node:test");
const {
  applyTaskCompletionEffects,
  applyTaskStartCost,
  missingRequiredTaskIds,
  normalizedTaskExecutionCount,
  selectTaskResult,
  taskDefinitionFromSnapshot,
  taskDurationSecondsForExecution,
  taskEnergyCostPerSurvivor,
  taskFixedOutputInventory,
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

test("generic resource cost uses selected item crafting values", () => {
  const task = taskDefinitionFromSnapshot(
    snapshotWithTasks({
      build: {
        location: "workshop",
        durationSeconds: 10,
        cost: {
          inventory: {fixed_component: 2},
          resources: {craftingValue: 5},
        },
        resultResolver: {type: "fixed", resultId: "done"},
        results: {
          done: {
            guaranteedOutcomes: {energyDelta: 0, inventoryDelta: {}},
            randomOutcomes: {},
          },
        },
      },
    }),
    "build",
  );

  const result = applyTaskStartCost(
    {
      inventory: {
        fixed_component: 3,
        low_resource: 1,
        high_resource: 2,
      },
    },
    task,
    {
      resourceSelection: {
        low_resource: 1,
        high_resource: 2,
      },
      itemDefinitions: {
        low_resource: {
          type: ["resource"],
          stats: {craftingValue: 1},
        },
        high_resource: {
          type: ["resource"],
          stats: {craftingValue: 2},
        },
      },
    },
  );

  assert.deepEqual(result.inventory, {fixed_component: 1});
});

test("generic resource cost rejects insufficient crafting value", () => {
  const task = taskDefinitionFromSnapshot(
    snapshotWithTasks({
      build: {
        location: "workshop",
        durationSeconds: 10,
        cost: {
          inventory: {},
          resources: {craftingValue: 5},
        },
        resultResolver: {type: "fixed", resultId: "done"},
        results: {
          done: {
            guaranteedOutcomes: {energyDelta: 0, inventoryDelta: {}},
            randomOutcomes: {},
          },
        },
      },
    }),
    "build",
  );

  assert.throws(
    () => applyTaskStartCost(
      {inventory: {resource_a: 2}},
      task,
      {
        resourceSelection: {resource_a: 2},
        itemDefinitions: {
          resource_a: {
            type: ["resource"],
            stats: {craftingValue: 2},
          },
        },
      },
    ),
    /requires 5/,
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

test("fixed task energy cost reflects its guaranteed energy delta", () => {
  const task = taskDefinitionFromSnapshot(
    snapshotWithTasks({
      energy_test: {
        location: "test",
        durationSeconds: 10,
        resultResolver: {type: "fixed", resultId: "done"},
        results: {
          done: {
            guaranteedOutcomes: {
              energyDelta: -13,
              inventoryDelta: {},
            },
            randomOutcomes: {},
          },
        },
      },
    }),
    "energy_test",
  );

  assert.equal(
    taskEnergyCostPerSurvivor(task),
    Math.abs(task.results.done.guaranteedOutcomes.energyDelta),
  );
});


function batchTask() {
  return taskDefinitionFromSnapshot(
    snapshotWithTasks({
      batch_craft: {
        location: "workshop",
        durationSeconds: 30,
        storable: false,
        execution: {type: "batch", maxCount: 99},
        survivorRequirements: {min: 1, max: 1},
        requiredTaskIds: [],
        cost: {inventory: {scrap_metal: 4}},
        resultResolver: {type: "fixed", resultId: "success"},
        results: {
          success: {
            guaranteedOutcomes: {
              energyDelta: -5,
              inventoryDelta: {electronics: 1},
            },
            randomOutcomes: {},
          },
        },
      },
    }),
    "batch_craft",
  );
}

test("normal tasks remain single-execution by default", () => {
  const task = exampleTask();
  assert.deepEqual(task.execution, {type: "single", maxCount: 1});
  assert.equal(normalizedTaskExecutionCount(task, null), 1);
  assert.throws(
    () => normalizedTaskExecutionCount(task, 2),
    /does not support batch execution/,
  );
});

test("batch task count scales cost duration energy and fixed output", () => {
  const task = batchTask();
  const count = normalizedTaskExecutionCount(task, 3);

  assert.equal(count, 3);
  assert.deepEqual(task.execution, {type: "batch", maxCount: 99});
  assert.equal(taskDurationSecondsForExecution(task, count, 1), 90);
  assert.equal(taskEnergyCostPerSurvivor(task, count), 15);
  assert.deepEqual(taskFixedOutputInventory(task), {electronics: 1});

  const paid = applyTaskStartCost(
    {inventory: {scrap_metal: 20}},
    task,
    {executionCount: count},
  );
  assert.deepEqual(paid.inventory, {scrap_metal: 8});

  const completed = applyTaskCompletionEffects(
    {
      survivors: [{id: "s1", energy: 40}],
      inventory: paid.inventory,
    },
    ["s1"],
    task,
    "success",
    "execution-batch-1",
    count,
  );
  assert.equal(completed.bunker.survivors[0].energy, 25);
  assert.deepEqual(completed.bunker.inventory, {
    scrap_metal: 8,
    electronics: 3,
  });
});

test("batch task count is bounded by its configured maximum", () => {
  const task = batchTask();
  assert.throws(
    () => normalizedTaskExecutionCount(task, 0),
    /positive integer/,
  );
  assert.throws(
    () => normalizedTaskExecutionCount(task, 100),
    /cannot exceed 99/,
  );
});

test("batch task definitions reject storable or random variants", () => {
  assert.throws(
    () => taskDefinitionFromSnapshot(
      snapshotWithTasks({
        invalid_batch: {
          location: "workshop",
          durationSeconds: 10,
          storable: true,
          execution: {type: "batch", maxCount: 5},
          resultResolver: {type: "fixed", resultId: "done"},
          results: {
            done: {
              guaranteedOutcomes: {energyDelta: 0, inventoryDelta: {}},
              randomOutcomes: {},
            },
          },
        },
      }),
      "invalid_batch",
    ),
    /cannot be storable/,
  );

  assert.throws(
    () => taskDefinitionFromSnapshot(
      snapshotWithTasks({
        invalid_random_batch: {
          location: "workshop",
          durationSeconds: 10,
          storable: false,
          execution: {type: "batch", maxCount: 5},
          resultResolver: {type: "fixed", resultId: "done"},
          results: {
            done: {
              guaranteedOutcomes: {energyDelta: 0, inventoryDelta: {}},
              randomOutcomes: {
                surprise: {
                  probability: 0.5,
                  effects: {energyDelta: 0, inventoryDelta: {}},
                },
              },
            },
          },
        },
      }),
      "invalid_random_batch",
    ),
    /cannot use random outcomes yet/,
  );
});

test("batch generic resource requirements scale with execution count", () => {
  const task = taskDefinitionFromSnapshot(
    snapshotWithTasks({
      batch_resources: {
        location: "workshop",
        durationSeconds: 10,
        storable: false,
        execution: {type: "batch", maxCount: 10},
        cost: {
          inventory: {},
          resources: {craftingValue: 2},
        },
        resultResolver: {type: "fixed", resultId: "done"},
        results: {
          done: {
            guaranteedOutcomes: {energyDelta: 0, inventoryDelta: {}},
            randomOutcomes: {},
          },
        },
      },
    }),
    "batch_resources",
  );

  assert.throws(
    () => applyTaskStartCost(
      {inventory: {resource_a: 2}},
      task,
      {
        executionCount: 3,
        resourceSelection: {resource_a: 2},
        itemDefinitions: {
          resource_a: {
            type: ["resource"],
            stats: {craftingValue: 2},
          },
        },
      },
    ),
    /requires 6/,
  );

  const paid = applyTaskStartCost(
    {inventory: {resource_a: 3}},
    task,
    {
      executionCount: 3,
      resourceSelection: {resource_a: 3},
      itemDefinitions: {
        resource_a: {
          type: ["resource"],
          stats: {craftingValue: 2},
        },
      },
    },
  );

  assert.deepEqual(paid.inventory, {});
});


test("background tasks require one Survivor but do not support batch counts", () => {
  const task = taskDefinitionFromSnapshot(
    snapshotWithTasks({
      passive_crop: {
        location: "garden",
        durationSeconds: 60,
        storable: false,
        execution: {type: "background"},
        survivorRequirements: {
          min: 1,
          max: 1,
          statRequirements: {
            care: {greaterThan: 3},
          },
        },
        requiredTaskIds: ["prepare_garden"],
        cost: {inventory: {}},
        resultResolver: {type: "fixed", resultId: "success"},
        results: {
          success: {
            guaranteedOutcomes: {
              energyDelta: 0,
              inventoryDelta: {food: 10},
            },
            randomOutcomes: {},
          },
        },
      },
    }),
    "passive_crop",
  );

  assert.deepEqual(task.execution, {type: "background", maxCount: 1});
  assert.equal(normalizedTaskExecutionCount(task, 1), 1);
  assert.equal(taskDurationSecondsForExecution(task, 1, 1), 60);
  assert.equal(taskEnergyCostPerSurvivor(task), 0);
  assert.deepEqual(taskFixedOutputInventory(task), {food: 10});
  assert.deepEqual(task.requiredTaskIds, ["prepare_garden"]);
  assert.deepEqual(task.survivorRequirements.statRequirements, {
    care: {greaterThan: 3},
  });
  assert.throws(
    () => normalizedTaskExecutionCount(task, 2),
    /does not support batch execution/,
  );
});

test("background tasks reject multi-Survivor definitions", () => {
  assert.throws(
    () => taskDefinitionFromSnapshot(
      snapshotWithTasks({
        invalid_passive: {
          location: "garden",
          durationSeconds: 60,
          execution: {type: "background"},
          survivorRequirements: {min: 1, max: 2},
          resultResolver: {type: "fixed", resultId: "success"},
          results: {
            success: {
              guaranteedOutcomes: {energyDelta: 0, inventoryDelta: {}},
              randomOutcomes: {},
            },
          },
        },
      }),
      "invalid_passive",
    ),
    /requires exactly one Survivor/,
  );
});
