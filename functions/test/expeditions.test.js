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
      bunkerCoordinates: {x: 4, y: 5, z: 6},
      actions: {
        inspect: {
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

  assert.equal(
    availableActionsAtCoordinates(
      definition,
      definition.bunkerCoordinates,
    ).length,
    1,
  );
  assert.deepEqual(
    availableActionsAtCoordinates(
      definition,
      {x: 4, y: 5, z: 7},
    ),
    [],
  );
});

test("selected expedition actions determine duration and completion energy", () => {
  const definition = exampleDefinition();
  const actions = selectedActionDefinitions(
    definition,
    definition.bunkerCoordinates,
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
      ["inspect"],
    ),
    /not available/,
  );
});
