const {
  SLEEPING_ACTIVITY,
  normalizedBusySurvivors,
} = require("./bunker_status");

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
 * without resolving them, so no completion outcomes are applied. Sleeping is
 * intentionally preserved because it is a bunker status, not a job task.
 * Inventory, Survivor energy and every other gameplay field are left intact.
 */
function resetTaskTreeStateForTesting(bunker, now = new Date()) {
  const busySurvivors = normalizedBusySurvivors(bunker.busySurvivors, now);
  const sleepingOccupations = busySurvivors.filter(
    (entry) => entry.activity === SLEEPING_ACTIVITY,
  );
  const cancelledTaskOccupations = busySurvivors.filter(
    (entry) => entry.activity !== SLEEPING_ACTIVITY,
  );
  const sleepingSurvivorIds = new Set(
    sleepingOccupations.map((entry) => entry.survivorId),
  );
  const idleSurvivors = new Set(uniqueStringList(bunker.idleSurvivors));

  for (const occupation of cancelledTaskOccupations) {
    if (!sleepingSurvivorIds.has(occupation.survivorId)) {
      idleSurvivors.add(occupation.survivorId);
    }
  }

  return {
    bunker: {
      ...bunker,
      completedTaskIds: [],
      idleSurvivors: [...idleSurvivors],
      busySurvivors: sleepingOccupations,
    },
    cancelledOccupationCount: cancelledTaskOccupations.length,
    clearedCompletedTaskCount: uniqueStringList(bunker.completedTaskIds).length,
  };
}

module.exports = {
  resetTaskTreeStateForTesting,
};
