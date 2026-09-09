const {
  SLEEPING_ACTIVITY,
  normalizedActiveBackgroundTasks,
  normalizedBusySurvivors,
} = require("./bunker_status");
const {EXPEDITION_ACTIVITY} = require("./expeditions");

function uniqueStringList(source) {
  if (!Array.isArray(source)) return [];
  return [...new Set(source
    .filter((value) => typeof value === "string")
    .map((value) => value.trim())
    .filter((value) => value.length > 0))];
}

/**
 * Development-only task-tree reset.
 *
 * Completed job IDs are forgotten and active job occupations are cancelled
 * without resolving them, so no completion outcomes are applied. Sleeping and
 * expeditions are intentionally preserved because neither belongs to the job
 * task tree.
 * Inventory, Survivor energy and every other gameplay field are left intact.
 */
function resetTaskTreeStateForTesting(bunker, now = new Date()) {
  const busySurvivors = normalizedBusySurvivors(bunker.busySurvivors, now);
  const activeBackgroundTasks = normalizedActiveBackgroundTasks(
    bunker.activeBackgroundTasks,
    now,
  );
  const preservedOccupations = busySurvivors.filter(
    (entry) =>
      entry.activity === SLEEPING_ACTIVITY ||
      entry.activity === EXPEDITION_ACTIVITY,
  );
  const cancelledTaskOccupations = busySurvivors.filter(
    (entry) =>
      entry.activity !== SLEEPING_ACTIVITY &&
      entry.activity !== EXPEDITION_ACTIVITY,
  );
  const preservedSurvivorIds = new Set(
    preservedOccupations.map((entry) => entry.survivorId),
  );
  const idleSurvivors = new Set(uniqueStringList(bunker.idleSurvivors));

  for (const occupation of cancelledTaskOccupations) {
    if (!preservedSurvivorIds.has(occupation.survivorId)) {
      idleSurvivors.add(occupation.survivorId);
    }
  }

  return {
    bunker: {
      ...bunker,
      completedTaskIds: [],
      idleSurvivors: [...idleSurvivors],
      busySurvivors: preservedOccupations,
      activeBackgroundTasks: [],
    },
    cancelledOccupationCount:
      cancelledTaskOccupations.length + activeBackgroundTasks.length,
    clearedCompletedTaskCount: uniqueStringList(bunker.completedTaskIds).length,
  };
}

module.exports = {
  resetTaskTreeStateForTesting,
};
