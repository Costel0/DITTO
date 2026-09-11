const assert = require("node:assert/strict");
const test = require("node:test");
const {
  availableActionsForZone,
  expeditionDefinitionFromSnapshot,
  expeditionDurationSeconds,
  expeditionTravelSeconds,
  selectedActionDefinitionsForZone,
} = require("../expeditions");
const {
  mapCoordinateId,
  mapDistance,
} = require("../map/coordinates");

function definition() {
  return expeditionDefinitionFromSnapshot({
    data: () => ({
      actions: {
        explore: {
          expeditionType: "exploration",
          availability: {unknownZone: true},
          completion: "discover_zone",
          durationSeconds: 60,
          energyDelta: 0,
        },
        inspect_field: {
          expeditionType: "scavenge",
          availability: {zoneTypes: ["EMPTY_FIELD"]},
          completion: "interactive_outcome",
          durationSeconds: 30,
          energyDelta: -2,
          outcomes: {
            nothing: {
              probability: 1,
              narrativeId: "nothing",
              resolutionOptions: {
                continue: {
                  labelId: "continue",
                  inventoryDelta: {},
                },
              },
            },
          },
        },
        bunker_action: {
          expeditionType: "scavenge",
          availability: {zoneTypes: ["PLAYER_BUNKER"]},
          completion: "interactive_outcome",
          durationSeconds: 40,
          energyDelta: -1,
          outcomes: {
            nothing: {
              probability: 1,
              narrativeId: "nothing",
              resolutionOptions: {
                continue: {
                  labelId: "continue",
                  inventoryDelta: {},
                },
              },
            },
          },
        },
      },
    }),
  });
}

const M25_1 = {sectorLetter: "M", sectorNumber: 25, zoneIndex: 1};

test("map expedition distance follows canonical sector-zone rules", () => {
  assert.equal(mapDistance(M25_1, M25_1), 0);
  assert.equal(
    mapDistance(M25_1, {sectorLetter: "M", sectorNumber: 25, zoneIndex: 4}),
    0.1,
  );
  assert.equal(
    mapDistance(M25_1, {sectorLetter: "N", sectorNumber: 26, zoneIndex: 5}),
    Math.sqrt(2),
  );
});

test("travel time uses configured seconds per distance unit for both legs", () => {
  assert.equal(
    expeditionTravelSeconds(
      M25_1,
      {sectorLetter: "N", sectorNumber: 25, zoneIndex: 3},
      300,
    ),
    600,
  );
  assert.equal(
    expeditionTravelSeconds(
      M25_1,
      {sectorLetter: "M", sectorNumber: 25, zoneIndex: 2},
      300,
    ),
    60,
  );
  assert.equal(
    expeditionTravelSeconds(
      M25_1,
      {sectorLetter: "N", sectorNumber: 26, zoneIndex: 5},
      300,
    ),
    Math.ceil(Math.sqrt(2) * 300 * 2),
  );
});

test("Explore is the only action exposed for an unknown zone", () => {
  const actions = availableActionsForZone(definition(), null);
  assert.deepEqual(actions.map((action) => action.id), ["explore"]);
  assert.equal(actions[0].completion, "discover_zone");
});

test("known zones expose only actions configured for their zone type", () => {
  assert.deepEqual(
    availableActionsForZone(definition(), {zoneType: "EMPTY_FIELD"})
      .map((action) => action.id),
    ["inspect_field"],
  );
  assert.deepEqual(
    availableActionsForZone(definition(), {zoneType: "PLAYER_BUNKER"})
      .map((action) => action.id),
    ["bunker_action"],
  );
  assert.deepEqual(
    availableActionsForZone(definition(), {zoneType: "EMPTY"})
      .map((action) => action.id),
    [],
  );
});

test("Explore cannot be combined with another action", () => {
  const catalog = definition();
  assert.throws(
    () => selectedActionDefinitionsForZone(
      catalog,
      null,
      ["explore", "bunker_action"],
    ),
    /not available|single action/,
  );
});

test("Explore duration is one minute plus round-trip travel", () => {
  const [explore] = availableActionsForZone(definition(), null);
  const adjacentTravel = expeditionTravelSeconds(
    M25_1,
    {sectorLetter: "N", sectorNumber: 25, zoneIndex: 1},
    300,
  );
  const sameSectorTravel = expeditionTravelSeconds(
    M25_1,
    {sectorLetter: "M", sectorNumber: 25, zoneIndex: 2},
    300,
  );
  assert.equal(expeditionDurationSeconds([explore], adjacentTravel), 660);
  assert.equal(expeditionDurationSeconds([explore], sameSectorTravel), 120);
});

test("expedition locations use the sector-zone coordinate format", () => {
  assert.equal(mapCoordinateId(M25_1), "M25-1");
});
