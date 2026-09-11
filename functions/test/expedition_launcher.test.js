const assert = require("node:assert/strict");
const test = require("node:test");
const {publicKnownZones} = require("../expedition_launcher");

test("expedition launcher always exposes the player's own bunker as known", () => {
  const zones = publicKnownZones([], {x: 12, y: 25, z: 1});

  assert.deepEqual(zones, [
    {
      coordinates: {
        sectorLetter: "M",
        sectorNumber: 25,
        zoneIndex: 1,
      },
      zoneType: "PLAYER_BUNKER",
    },
  ]);
});

test("expedition launcher preserves discovered zones and forces bunker type", () => {
  const zones = publicKnownZones(
    [
      {
        coordinates: {x: 12, y: 25, z: 1},
        zoneType: "EMPTY_FIELD",
      },
      {
        coordinates: {x: 13, y: 26, z: 2},
        zoneType: "EMPTY_FIELD",
      },
    ],
    {x: 12, y: 25, z: 1},
  );

  assert.deepEqual(
    zones.find((zone) => zone.coordinates.sectorLetter === "M"),
    {
      coordinates: {
        sectorLetter: "M",
        sectorNumber: 25,
        zoneIndex: 1,
      },
      zoneType: "PLAYER_BUNKER",
    },
  );
  assert.deepEqual(
    zones.find((zone) => zone.coordinates.sectorLetter === "N"),
    {
      coordinates: {
        sectorLetter: "N",
        sectorNumber: 26,
        zoneIndex: 2,
      },
      zoneType: "EMPTY_FIELD",
    },
  );
});
