const assert = require("node:assert/strict");
const test = require("node:test");
const {
  applyExpeditionCompletion,
  availableActionsAtCoordinates,
  expeditionDefinitionFromSnapshot,
  expeditionDurationSeconds,
  selectedActionDefinitions,
} = require("../expeditions");

function exampleDefinition() {
  return expeditionDefinitionFromSnapshot({
    data: () => ({
      actions: {
        inspect: {
          expeditionType: "test_type",
          availability: "bunker",
          durationSeconds: 17,
          energyDelta: -7,
        },
      },
    }),
  });
}

test("expedition actions are only available at their configured location", () => {
  const definition = exampleDefinition();

  const bunkerCoordinates = {x: 4, y: 5, z: 6};
  assert.equal(
    availableActionsAtCoordinates(
      definition,
      bunkerCoordinates,
      bunkerCoordinates,
    ).length,
    1,
  );
  assert.deepEqual(
    availableActionsAtCoordinates(
      definition,
      {x: 4, y: 5, z: 7},
      bunkerCoordinates,
    ),
    [],
  );
});

test("selected expedition actions determine duration and completion energy", () => {
  const definition = exampleDefinition();
  const bunkerCoordinates = {x: 4, y: 5, z: 6};
  const actions = selectedActionDefinitions(
    definition,
    bunkerCoordinates,
    bunkerCoordinates,
    ["inspect"],
  );
  const survivor = {id: "s1", energy: 30};
  const result = applyExpeditionCompletion(
    {survivors: [survivor]},
    ["s1"],
    actions,
  );

  assert.equal(expeditionDurationSeconds(actions), actions[0].durationSeconds);
  assert.equal(
    result.survivors[0].energy,
    survivor.energy + actions[0].energyDelta,
  );
});

test("expedition actions are rejected outside their available coordinates", () => {
  const definition = exampleDefinition();

  assert.throws(
    () => selectedActionDefinitions(
      definition,
      {x: 0, y: 0, z: 0},
      {x: 4, y: 5, z: 6},
      ["inspect"],
    ),
    /not available/,
  );
});

test("intermediate scavenge action IDs resolve to scout surroundings", () => {
  const definition = expeditionDefinitionFromSnapshot({
    data: () => ({
      actions: {
        scout_surroundings: {
          expeditionType: "scavenge",
          availability: "bunker",
          durationSeconds: 9,
          energyDelta: -3,
        },
      },
    }),
  });

  const actions = selectedActionDefinitions(
    definition,
    {x: 2, y: 2, z: 2},
    {x: 2, y: 2, z: 2},
    ["scavenge"],
  );

  assert.equal(actions.length, 1);
  assert.equal(actions[0].id, "scout_surroundings");
  assert.equal(actions[0].expeditionType, "scavenge");
});
