const SURVIVOR_STAT_KEYS = Object.freeze([
  "strength",
  "dexterity",
  "constitution",
  "stealth",
  "care",
  "cunning",
  "charm",
]);

const SURVIVOR_STAT_KEY_SET = new Set(SURVIVOR_STAT_KEYS);

// Server-authoritative copy of the base Duplicate stats used by Flutter.
// Effective Survivor stats are baseStats + statMods.
const DUPLICATE_BASE_STATS = Object.freeze({
  "01": Object.freeze({
    strength: 2,
    dexterity: 4,
    constitution: 2,
    stealth: 4,
    care: 4,
    cunning: 3,
    charm: 4,
  }),
  "02": Object.freeze({
    strength: 5,
    dexterity: 2,
    constitution: 5,
    stealth: 1,
    care: 2,
    cunning: 3,
    charm: 3,
  }),
  "03": Object.freeze({
    strength: 3,
    dexterity: 5,
    constitution: 2,
    stealth: 3,
    care: 4,
    cunning: 3,
    charm: 4,
  }),
  "04": Object.freeze({
    strength: 0,
    dexterity: 0,
    constitution: 0,
    stealth: 0,
    care: 0,
    cunning: 0,
    charm: 0,
  }),
  "05": Object.freeze({
    strength: 0,
    dexterity: 0,
    constitution: 0,
    stealth: 0,
    care: 0,
    cunning: 0,
    charm: 0,
  }),
});

const VALID_DUPLICATE_IDS = Object.freeze(Object.keys(DUPLICATE_BASE_STATS));

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function zeroStatMap() {
  return Object.fromEntries(SURVIVOR_STAT_KEYS.map((stat) => [stat, 0]));
}

function normalizedStatMods(value) {
  const source = isPlainObject(value) ? value : {};
  const normalized = zeroStatMap();
  const sourceValues = {
    strength: source.strength,
    dexterity: source.dexterity ?? source.agility,
    constitution: source.constitution ?? source.endurance,
    stealth: source.stealth ?? source.scavenging,
    care: source.care,
    cunning: source.cunning,
    charm: source.charm,
  };

  for (const stat of SURVIVOR_STAT_KEYS) {
    if (Number.isInteger(sourceValues[stat])) {
      normalized[stat] = sourceValues[stat];
    }
  }
  return normalized;
}

function normalizedStatExperience(value) {
  const source = isPlainObject(value) ? value : {};
  const normalized = zeroStatMap();
  for (const stat of SURVIVOR_STAT_KEYS) {
    const experience = source[stat];
    if (Number.isInteger(experience) && experience >= 0) {
      normalized[stat] = Math.min(experience, 100);
    }
  }
  return normalized;
}

function normalizedStatRequirements(value, label) {
  if (value == null) return {};
  if (!isPlainObject(value)) {
    throw new Error(`${label} must be an object.`);
  }

  const normalized = {};
  for (const [statRaw, requirement] of Object.entries(value)) {
    const stat = statRaw.trim();
    if (!SURVIVOR_STAT_KEY_SET.has(stat) || !isPlainObject(requirement)) {
      throw new Error(`${label} contains an invalid stat requirement.`);
    }

    const greaterThan = requirement.greaterThan;
    if (!Number.isInteger(greaterThan) || greaterThan < 0 || greaterThan > 9) {
      throw new Error(
        `${label}.${stat}.greaterThan must be an integer from 0 to 9.`,
      );
    }
    normalized[stat] = {greaterThan};
  }
  return normalized;
}

function normalizedStatExperienceDelta(value, label) {
  if (value == null) return {};
  if (!isPlainObject(value)) {
    throw new Error(`${label} must be an object.`);
  }

  const normalized = {};
  for (const [statRaw, amount] of Object.entries(value)) {
    const stat = statRaw.trim();
    if (!SURVIVOR_STAT_KEY_SET.has(stat)) {
      throw new Error(`${label} contains an unknown Survivor stat: ${statRaw}.`);
    }
    if (!Number.isInteger(amount) || amount < 0) {
      throw new Error(`${label}.${stat} must be a non-negative integer.`);
    }
    if (amount > 0) normalized[stat] = amount;
  }
  return normalized;
}

function baseStatValue(duplicateId, stat) {
  if (!SURVIVOR_STAT_KEY_SET.has(stat)) return 0;
  const duplicateStats = DUPLICATE_BASE_STATS[duplicateId];
  return Number.isInteger(duplicateStats?.[stat]) ? duplicateStats[stat] : 0;
}

function effectiveSurvivorStat(survivor, stat) {
  if (!SURVIVOR_STAT_KEY_SET.has(stat)) return 0;
  const duplicateId = typeof survivor?.duplicateId === "string"
    ? survivor.duplicateId
    : "";
  const mods = normalizedStatMods(survivor?.statMods);
  return baseStatValue(duplicateId, stat) + mods[stat];
}

function survivorMeetsStatRequirements(survivor, statRequirements) {
  const requirements = isPlainObject(statRequirements) ? statRequirements : {};
  return Object.entries(requirements).every(([stat, requirement]) =>
    effectiveSurvivorStat(survivor, stat) > requirement.greaterThan,
  );
}

function applyStatExperienceDelta(survivor, delta) {
  const statMods = normalizedStatMods(survivor?.statMods);
  const statExperience = normalizedStatExperience(survivor?.statExperience);
  const duplicateId = typeof survivor?.duplicateId === "string"
    ? survivor.duplicateId
    : "";

  for (const stat of SURVIVOR_STAT_KEYS) {
    const gained = Number.isInteger(delta?.[stat]) ? delta[stat] : 0;
    if (gained <= 0) continue;

    let experience = statExperience[stat] + gained;
    let effectiveStat = baseStatValue(duplicateId, stat) + statMods[stat];

    while (experience >= 100 && effectiveStat < 10) {
      experience -= 100;
      statMods[stat] += 1;
      effectiveStat += 1;
    }

    // Once the effective stat reaches 10 there are no further level-ups.
    // Keeping at most 100 still respects the hidden 0..100 meter contract.
    statExperience[stat] = effectiveStat >= 10
      ? Math.min(experience, 100)
      : Math.min(experience, 99);
  }

  return {
    ...survivor,
    statMods,
    statExperience,
  };
}

module.exports = {
  DUPLICATE_BASE_STATS,
  SURVIVOR_STAT_KEYS,
  VALID_DUPLICATE_IDS,
  applyStatExperienceDelta,
  effectiveSurvivorStat,
  normalizedStatExperience,
  normalizedStatExperienceDelta,
  normalizedStatMods,
  normalizedStatRequirements,
  survivorMeetsStatRequirements,
  zeroStatMap,
};
