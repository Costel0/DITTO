const assert = require("node:assert/strict");
const test = require("node:test");
const {
  applyExpeditionAutomaticResolution,
  applyExpeditionInteractiveResolution,
  availableActionsAtCoordinates,
  expeditionDefinitionFromSnapshot,
  expeditionDurationSeconds,
  selectExpeditionOutcomes,
  selectedActionDefinitions,
} = require("../expeditions");

function testOutcomes() {
  return {
    empty: {
      probability: 0.5,
      narrativeId: "test_empty",
      resolutionOptions: {
        accept: {
          labelId: "accept",
          inventoryDelta: {},
        },
      },
    },
    reward: {
      probability: 0.5,
      narrativeId: "test_reward",
      resolutionOptions: {
        accept: {
          labelId: "accept",
          inventoryDelta: {test_item: 2},
        },
        decline: {
          labelId: "decline",
          inventoryDelta: {},
        },
      },
    },
  };
}

function exampleDefinition() {
  return expeditionDefinitionFromSnapshot({
    data: () => ({
      actions: {
        inspect: {
          expeditionType: "test_type",
          availability: "bunker",
          durationSeconds: 17,
          energyDelta: -7,
          outcomes: testOutcomes(),
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

test("selected expedition actions determine duration and automatic energy", () => {
  const definition = exampleDefinition();
  const bunkerCoordinates = {x: 4, y: 5, z: 6};
  const actions = selectedActionDefinitions(
    definition,
    bunkerCoordinates,
    bunkerCoordinates,
    ["inspect"],
  );
  const survivor = {id: "s1", energy: 30};
  const result = applyExpeditionAutomaticResolution(
    {survivors: [survivor], inventory: {test_item: 3}},
    ["s1"],
    actions,
  );

  assert.equal(expeditionDurationSeconds(actions), actions[0].durationSeconds);
  assert.equal(
    result.survivors[0].energy,
    survivor.energy + actions[0].energyDelta,
  );
  assert.deepEqual(
    result.inventory,
    {test_item: 3},
    "automatic resolution must not apply interactive rewards",
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
          outcomes: testOutcomes(),
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

test("server outcome selection is deterministic for the same execution seed", () => {
  const definition = exampleDefinition();
  const action = definition.actions.inspect;

  const first = selectExpeditionOutcomes([action], "execution-123");
  const second = selectExpeditionOutcomes([action], "execution-123");

  assert.deepEqual(first, second);
  assert.equal(first.length, 1);
  assert.ok(["empty", "reward"].includes(first[0].id));
});

test("interactive resolution applies only the selected option", () => {
  const outcomes = [
    {
      actionId: "inspect",
      outcomeId: "reward",
      narrativeId: "test_reward",
      resolutionOptions: {
        accept: {
          id: "accept",
          labelId: "accept",
          inventoryDelta: {test_item: 2},
          eventTrigger: null,
        },
        decline: {
          id: "decline",
          labelId: "decline",
          inventoryDelta: {},
          eventTrigger: null,
        },
      },
    },
  ];

  const accepted = applyExpeditionInteractiveResolution(
    {inventory: {test_item: 3}},
    outcomes,
    {inspect: "accept"},
  );
  const declined = applyExpeditionInteractiveResolution(
    {inventory: {test_item: 3}},
    outcomes,
    {inspect: "decline"},
  );

  assert.equal(accepted.bunker.inventory.test_item, 5);
  assert.equal(declined.bunker.inventory.test_item, 3);
  assert.deepEqual(accepted.inventoryDelta, {test_item: 2});
  assert.deepEqual(declined.inventoryDelta, {});
});

test("interactive resolution requires one valid choice per outcome", () => {
  const outcomes = [
    {
      actionId: "inspect",
      outcomeId: "reward",
      resolutionOptions: {
        accept: {
          id: "accept",
          labelId: "accept",
          inventoryDelta: {test_item: 2},
        },
      },
    },
  ];

  assert.throws(
    () => applyExpeditionInteractiveResolution(
      {inventory: {}},
      outcomes,
      {},
    ),
    /valid resolution option/,
  );
  assert.throws(
    () => applyExpeditionInteractiveResolution(
      {inventory: {}},
      outcomes,
      {inspect: "unknown"},
    ),
    /valid resolution option/,
  );
});
