const assert = require("node:assert/strict");
const test = require("node:test");
const {
  applyTaskCompletionEffects,
  taskDefinitionFromSnapshot,
} = require("../job_tasks");
const {
  DUPLICATE_BASE_STATS,
  applyStatExperienceDelta,
  effectiveSurvivorStat,
  normalizedStatMods,
  survivorMeetsStatRequirements,
} = require("../survivor_progression");

function snapshotWithTasks(tasks) {
  return {
    data: () => ({tasks}),
  };
}

const testDuplicateId = Object.keys(DUPLICATE_BASE_STATS)[0];

function baseStat(stat) {
  return DUPLICATE_BASE_STATS[testDuplicateId][stat];
}

test("effective stats combine Duplicate base stats and Survivor statMods", () => {
  const survivor = {
    duplicateId: testDuplicateId,
    statMods: {care: 2, strength: 1},
  };

  assert.equal(
    effectiveSurvivorStat(survivor, "care"),
    baseStat("care") + 2,
  );
  assert.equal(
    effectiveSurvivorStat(survivor, "strength"),
    baseStat("strength") + 1,
  );
});

test("legacy stat mod aliases are normalized to current stat names", () => {
  assert.deepEqual(
    normalizedStatMods({agility: 2, endurance: 3, scavenging: 4}),
    {
      strength: 0,
      dexterity: 2,
      constitution: 3,
      stealth: 4,
      care: 0,
      cunning: 0,
      charm: 0,
    },
  );
});

test("stat requirements use an exclusive greater-than comparison", () => {
  const targetEffectiveCare = 5;
  const survivor = {
    duplicateId: testDuplicateId,
    statMods: {
      care: targetEffectiveCare - baseStat("care"),
    },
  };

  assert.equal(
    survivorMeetsStatRequirements(survivor, {care: {greaterThan: 4}}),
    true,
  );
  assert.equal(
    survivorMeetsStatRequirements(survivor, {care: {greaterThan: 5}}),
    false,
  );
});

test("experience reaching 100 increases the stat and keeps remainder", () => {
  const initialCareMod = 4 - baseStat("care");
  const progressed = applyStatExperienceDelta(
    {
      id: "s1",
      duplicateId: testDuplicateId,
      statMods: {care: initialCareMod},
      statExperience: {care: 98},
    },
    {care: 5, strength: 1},
  );

  assert.equal(progressed.statMods.care, initialCareMod + 1);
  assert.equal(progressed.statExperience.care, 3);
  assert.equal(progressed.statExperience.strength, 1);
  assert.equal(effectiveSurvivorStat(progressed, "care"), 5);
});

test("experience cannot raise an effective stat above 10", () => {
  const maxedCareMod = 10 - baseStat("care");
  const progressed = applyStatExperienceDelta(
    {
      id: "s1",
      duplicateId: testDuplicateId,
      statMods: {care: maxedCareMod},
      statExperience: {care: 95},
    },
    {care: 20},
  );

  assert.equal(progressed.statMods.care, maxedCareMod);
  assert.equal(effectiveSurvivorStat(progressed, "care"), 10);
  assert.equal(progressed.statExperience.care, 100);
});

test("task definitions apply stat requirements and XP to every participant", () => {
  const task = taskDefinitionFromSnapshot(
    snapshotWithTasks({
      test_task: {
        activity: "test_task",
        location: "test_area",
        durationSeconds: 300,
        storable: true,
        survivorRequirements: {
          min: 1,
          max: 3,
          statRequirements: {
            care: {greaterThan: 3},
          },
        },
        requiredTaskIds: [],
        cost: {inventory: {}},
        resultResolver: {type: "fixed", resultId: "success"},
        results: {
          success: {
            guaranteedOutcomes: {
              energyDelta: 0,
              inventoryDelta: {},
              statExperienceDelta: {
                care: 5,
                strength: 1,
              },
            },
            randomOutcomes: {},
          },
        },
      },
    }),
    "test_task",
  );

  assert.deepEqual(task.survivorRequirements.statRequirements, {
    care: {greaterThan: 3},
  });

  const completion = applyTaskCompletionEffects(
    {
      survivors: [
        {
          id: "s1",
          duplicateId: testDuplicateId,
          energy: 50,
          statMods: {},
        },
        {
          id: "s2",
          duplicateId: testDuplicateId,
          energy: 50,
          statMods: {},
        },
      ],
      inventory: {},
    },
    ["s1", "s2"],
    task,
    "success",
    "execution-1",
  );

  for (const survivor of completion.bunker.survivors) {
    assert.equal(survivor.statExperience.care, 5);
    assert.equal(survivor.statExperience.strength, 1);
  }
});
