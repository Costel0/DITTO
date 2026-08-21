const assert = require("node:assert/strict");
const test = require("node:test");
const jobTasksConfig = require("../../game_data/server/job_tasks.json");
const {taskDefinitionFromSnapshot} = require("../job_tasks");

function configSnapshot() {
  return {
    data: () => ({tasks: jobTasksConfig.tasks}),
  };
}

test("current garden tasks consume 5 energy per participating Survivor", () => {
  const expectedTaskIds = [
    "prepare_garden",
    "upgrade_garden",
    "upgrade_garden_2",
    "upgrade_garden_3",
    "upgrade_garden_4",
    "upgrade_garden_5",
    "upgrade_garden_6",
  ];

  for (const taskId of expectedTaskIds) {
    const task = taskDefinitionFromSnapshot(configSnapshot(), taskId);
    assert.ok(task, `Missing configured task ${taskId}`);
    assert.equal(
      task.results.success.guaranteedOutcomes.energyDelta,
      -5,
      `${taskId} should subtract 5 energy`,
    );
  }
});
