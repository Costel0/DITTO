const MAP_LETTER_PATTERN = /^[A-Z]$/;
const MAP_LOCATION_PATTERN = /^([A-Z])(\d+)-(\d+)$/;

function letterIndex(letter) {
  if (typeof letter !== "string" || !MAP_LETTER_PATTERN.test(letter)) {
    throw new Error(`Invalid map letter: ${letter}`);
  }
  return letter.charCodeAt(0) - 65;
}

function indexLetter(index) {
  if (!Number.isInteger(index) || index < 0 || index > 25) {
    throw new Error(`Invalid map letter index: ${index}`);
  }
  return String.fromCharCode(65 + index);
}

function positiveSafeInteger(value, label) {
  if (!Number.isSafeInteger(value) || value < 1) {
    throw new Error(`${label} must be a positive safe integer.`);
  }
  return value;
}

/**
 * Canonical game coordinate: sector letter + sector number + zone index.
 *
 * The modern wire shape is:
 *   {sectorLetter: "M", sectorNumber: 25, zoneIndex: 3}
 *
 * During the migration we also accept the previous internal {x,y,z} shape,
 * where x is A=0..Z=25, y is the sector number and z is the zone index.
 */
function normalizedMapCoordinates(value, label = "coordinates") {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${label} must be an object.`);
  }

  let sectorLetter;
  let sectorNumber;
  let zoneIndex;

  if (
    Object.prototype.hasOwnProperty.call(value, "sectorLetter") ||
    Object.prototype.hasOwnProperty.call(value, "sectorNumber") ||
    Object.prototype.hasOwnProperty.call(value, "zoneIndex")
  ) {
    sectorLetter = typeof value.sectorLetter === "string"
      ? value.sectorLetter.trim().toUpperCase()
      : "";
    sectorNumber = value.sectorNumber;
    zoneIndex = value.zoneIndex;
    letterIndex(sectorLetter);
  } else {
    if (!Number.isInteger(value.x) || value.x < 0 || value.x > 25) {
      throw new Error(`${label}.x must be an integer from 0 to 25.`);
    }
    sectorLetter = indexLetter(value.x);
    sectorNumber = value.y;
    zoneIndex = value.z;
  }

  positiveSafeInteger(sectorNumber, `${label}.sectorNumber`);
  positiveSafeInteger(zoneIndex, `${label}.zoneIndex`);

  return {
    sectorLetter,
    sectorNumber,
    zoneIndex,
  };
}

function mapCoordinatesToLegacy(coordinates) {
  const normalized = normalizedMapCoordinates(coordinates);
  return {
    x: letterIndex(normalized.sectorLetter),
    y: normalized.sectorNumber,
    z: normalized.zoneIndex,
  };
}

function mapCoordinatesToWire(coordinates) {
  const normalized = normalizedMapCoordinates(coordinates);
  return {
    sectorLetter: normalized.sectorLetter,
    sectorNumber: normalized.sectorNumber,
    zoneIndex: normalized.zoneIndex,
  };
}

function mapSectorId(coordinates) {
  const normalized = normalizedMapCoordinates(coordinates);
  return `${normalized.sectorLetter}${normalized.sectorNumber}`;
}

function mapCoordinateId(coordinates) {
  const normalized = normalizedMapCoordinates(coordinates);
  return `${normalized.sectorLetter}${normalized.sectorNumber}-${normalized.zoneIndex}`;
}

function mapCoordinatesFromLocation(location) {
  if (typeof location !== "string") {
    throw new Error("Invalid expedition location.");
  }

  const normalizedLocation = location.trim().toUpperCase();
  const modern = MAP_LOCATION_PATTERN.exec(normalizedLocation);
  if (modern) {
    return normalizedMapCoordinates({
      sectorLetter: modern[1],
      sectorNumber: Number(modern[2]),
      zoneIndex: Number(modern[3]),
    });
  }

  // Compatibility with expedition occupations created before sector-zone
  // notation was introduced.
  const legacyParts = location.split(",").map((entry) => Number(entry.trim()));
  if (legacyParts.length === 3 && legacyParts.every(Number.isInteger)) {
    return normalizedMapCoordinates({
      x: legacyParts[0],
      y: legacyParts[1],
      z: legacyParts[2],
    });
  }

  throw new Error("Invalid expedition location.");
}

function mapDistance(left, right) {
  const a = normalizedMapCoordinates(left, "originCoordinates");
  const b = normalizedMapCoordinates(right, "targetCoordinates");

  if (
    a.sectorLetter === b.sectorLetter &&
    a.sectorNumber === b.sectorNumber
  ) {
    return a.zoneIndex === b.zoneIndex ? 0 : 0.1;
  }

  const dx = letterIndex(a.sectorLetter) - letterIndex(b.sectorLetter);
  const dy = a.sectorNumber - b.sectorNumber;
  return Math.sqrt(dx * dx + dy * dy);
}

module.exports = {
  indexLetter,
  letterIndex,
  mapCoordinateId,
  mapCoordinatesFromLocation,
  mapCoordinatesToLegacy,
  mapCoordinatesToWire,
  mapDistance,
  mapSectorId,
  normalizedMapCoordinates,
};
