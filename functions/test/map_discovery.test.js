const assert = require("node:assert/strict");
const test = require("node:test");
const {
  TEMPORARY_DISCOVERED_SECTOR_TYPE,
  TEMPORARY_DISCOVERED_ZONE_TYPE,
  planZoneDiscovery,
} = require("../map/discovery");

function snapshot(id, data) {
  return {
    id,
    exists: true,
    ref: {path: `worldMapSectors/${id}`},
    data: () => data,
  };
}

const meta = {
  zonesPerSector: 5,
  currentMapNumberMax: 50,
  spawnLetterMin: "D",
  spawnLetterMax: "W",
  initialSpawnNumberMin: 10,
  initialSpawnNumberMax: 40,
  subsequentSpawnWindowSize: 40,
  spawnChunkWidth: 5,
};

test("discovering an UNGENERATED sector temporarily resolves all zones", () => {
  const plan = planZoneDiscovery({
    coordinates: {sectorLetter: "H", sectorNumber: 28, zoneIndex: 3},
    meta,
    sectorSnapshot: snapshot("H28", {
      status: "UNGENERATED",
      type: null,
      zones: [],
    }),
  });

  assert.equal(plan.generatedSector, true);
  assert.equal(plan.zoneType, TEMPORARY_DISCOVERED_ZONE_TYPE);
  assert.equal(plan.sectorUpdate.type, TEMPORARY_DISCOVERED_SECTOR_TYPE);
  assert.equal(plan.sectorUpdate.status, "POPULATED");
  assert.equal(plan.sectorUpdate.zones.length, 5);
  assert.ok(plan.sectorUpdate.zones.every(
    (zone) => zone.type === TEMPORARY_DISCOVERED_ZONE_TYPE,
  ));
});

test("discovering an already populated sector reveals the authoritative zone", () => {
  const plan = planZoneDiscovery({
    coordinates: {sectorLetter: "H", sectorNumber: 28, zoneIndex: 2},
    meta,
    sectorSnapshot: snapshot("H28", {
      status: "POPULATED",
      type: "HUNTING",
      zones: [
        {index: 1, type: "EMPTY_FIELD", status: "RESOLVED"},
        {index: 2, type: "LAKE", status: "RESOLVED"},
        {index: 3, type: "EMPTY_FIELD", status: "RESOLVED"},
        {index: 4, type: "EMPTY_FIELD", status: "RESOLVED"},
        {index: 5, type: "EMPTY_FIELD", status: "RESOLVED"},
      ],
    }),
  });

  assert.equal(plan.generatedSector, false);
  assert.equal(plan.zoneType, "LAKE");
  assert.equal(plan.sectorUpdate, null);
});
