const assert = require("node:assert/strict");
const test = require("node:test");
const {
  applyTaskCompletionEffects,
  taskDefinitionFromSnapshot,
} = require("../job_tasks");

function snapshotWithTasks(tasks) {
  return {
    data: () => ({tasks}),
  };
}

test("taskDefinitionFromSnapshot normalizes server task definitions", () => {
  const task = taskDefinitionFromSnapshot(
    snapshotWithTasks({
      clear_garden: {
        activity: "clear_garden",
        location: "garden",
        durationSeconds: 300,
        completion: {
          energyDelta: -4,
          inventoryDelta: {
            scrap_metal: 2,
          },
        },
      },
    }),
    "clear_garden",
  );

  assert.deepEqual(task, {
    id: "clear_garden",
    activity: "clear_garden",
    location: "garden",
    durationSeconds: 300,
    completion: {
      energyDelta: -4,
      inventoryDelta: {
        scrap_metal: 2,
      },
    },
  });
});

test("taskDefinitionFromSnapshot returns null for unknown tasks", () => {
  const task = taskDefinitionFromSnapshot(snapshotWithTasks({}), "missing");
  assert.equal(task, null);
});

test("applyTaskCompletionEffects updates energy and inventory immutably", () => {
  const bunker = {
    survivors: [
      {
        id: "s1",
        duplicateId: "01",
        energy: 12,
      },
    ],
    inventory: {
      scrap_metal: 1,
      field_ration: 2,
    },
  };
  const task = {
    id: "clear_garden",
    completion: {
      energyDelta: -5,
      inventoryDelta: {
        scrap_metal: 3,
        field_ration: -1,
      },
    },
  };

  const result = applyTaskCompletionEffects(bunker, "s1", task);

  assert.equal(result.survivors[0].energy, 7);
  assert.deepEqual(result.inventory, {
    scrap_metal: 4,
    field_ration: 1,
  });
  assert.equal(bunker.survivors[0].energy, 12);
  assert.equal(bunker.inventory.scrap_metal, 1);
});

test("applyTaskCompletionEffects rejects negative resulting inventory", () => {
  assert.throws(
    () => applyTaskCompletionEffects(
      {
        survivors: [{id: "s1", energy: 10}],
        inventory: {},
      },
      "s1",
      {
        id: "consume",
        completion: {
          energyDelta: 0,
          inventoryDelta: {field_ration: -1},
        },
      },
    ),
    /negative/,
  );
});
