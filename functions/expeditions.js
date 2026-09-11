const {createHash} = require("node:crypto");
const {
  mapCoordinateId,
  mapCoordinatesFromLocation,
  mapCoordinatesToLegacy,
  mapCoordinatesToWire,
  mapDistance,
  normalizedMapCoordinates,
} = require("./map/coordinates");

const EXPEDITION_ACTIVITY = "expedition";
const EXPEDITION_ID_PATTERN = /^[a-z0-9_]+$/;
const ZONE_TYPE_PATTERN = /^[A-Z][A-Z0-9_]*$/;
const INTERACTIVE_COMPLETION = "interactive_outcome";
const DISCOVER_ZONE_COMPLETION = "discover_zone";
const DEFAULT_EXPEDITION_TRAVEL_SECONDS_PER_DISTANCE_UNIT = 300;

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

/**
 * Compatibility boundary for BunkerState and old callers. Expedition APIs now
 * also accept the modern sector-zone wire shape, but internally the existing
 * bunker state still stores x/y/z where x=A..Z -> 0..25.
 */
function normalizedCoordinates(value, label = "coordinates") {
  return mapCoordinatesToLegacy(normalizedMapCoordinates(value, label));
}

function coordinatesForClient(value) {
  return mapCoordinatesToWire(normalizedMapCoordinates(value));
}

function sameCoordinates(left, right) {
  const a = normalizedCoordinates(left, "leftCoordinates");
  const b = normalizedCoordinates(right, "rightCoordinates");
  return a.x === b.x && a.y === b.y && a.z === b.z;
}

function normalizedInventoryReward(value, label) {
  if (value == null) return {};
  if (!isPlainObject(value)) {
    throw new Error(`${label} must be an object.`);
  }

  const result = {};
  for (const [itemIdRaw, quantity] of Object.entries(value)) {
    const itemId = itemIdRaw.trim();
    if (
      !itemId ||
      !Number.isInteger(quantity) ||
      quantity <= 0
    ) {
      throw new Error(
        `${label} must contain positive integer item quantities.`,
      );
    }
    result[itemId] = quantity;
  }
  return result;
}

function normalizedEventTrigger(value, label) {
  if (value == null) return null;
  if (!isPlainObject(value)) {
    throw new Error(`${label} must be an object.`);
  }
  const poolId = typeof value.poolId === "string" ? value.poolId.trim() : "";
  if (!poolId) {
    throw new Error(`${label}.poolId must be a non-empty string.`);
  }
  return {poolId};
}

function normalizedResolutionOption(
  rawOption,
  actionId,
  outcomeId,
  optionId,
) {
  if (!isPlainObject(rawOption)) {
    throw new Error(
      `Expedition resolution option ${actionId}.${outcomeId}.${optionId} must be an object.`,
    );
  }

  const labelId = typeof rawOption.labelId === "string"
    ? rawOption.labelId.trim()
    : "";
  if (!labelId || !EXPEDITION_ID_PATTERN.test(labelId)) {
    throw new Error(
      `Expedition resolution option ${actionId}.${outcomeId}.${optionId} requires a safe labelId slug.`,
    );
  }

  return {
    id: optionId,
    labelId,
    inventoryDelta: normalizedInventoryReward(
      rawOption.inventoryDelta,
      `Expedition resolution option ${actionId}.${outcomeId}.${optionId}.inventoryDelta`,
    ),
    eventTrigger: normalizedEventTrigger(
      rawOption.eventTrigger,
      `Expedition resolution option ${actionId}.${outcomeId}.${optionId}.eventTrigger`,
    ),
  };
}

function normalizedResolutionOptions(rawOptions, actionId, outcomeId, rawOutcome) {
  // Compatibility with the short-lived schema where the outcome itself owned
  // the reward/event. New data always uses explicit interactive options.
  const source = isPlainObject(rawOptions)
    ? rawOptions
    : {
      accept: {
        labelId: "accept",
        inventoryDelta: rawOutcome.inventoryDelta || {},
        ...(rawOutcome.eventTrigger
          ? {eventTrigger: rawOutcome.eventTrigger}
          : {}),
      },
    };

  if (Object.keys(source).length === 0) {
    throw new Error(
      `Expedition outcome ${actionId}.${outcomeId} must define at least one resolution option.`,
    );
  }

  const options = {};
  for (const [optionIdRaw, rawOption] of Object.entries(source)) {
    const optionId = optionIdRaw.trim();
    if (!optionId || !EXPEDITION_ID_PATTERN.test(optionId)) {
      throw new Error(
        `Expedition outcome ${actionId}.${outcomeId} contains an invalid resolution option ID.`,
      );
    }
    options[optionId] = normalizedResolutionOption(
      rawOption,
      actionId,
      outcomeId,
      optionId,
    );
  }
  return options;
}

function normalizedOutcomeDefinition(rawOutcome, actionId, outcomeId) {
  if (!isPlainObject(rawOutcome)) {
    throw new Error(
      `Expedition outcome ${actionId}.${outcomeId} must be an object.`,
    );
  }

  const probability = rawOutcome.probability;
  if (
    typeof probability !== "number" ||
    !Number.isFinite(probability) ||
    probability <= 0 ||
    probability > 1
  ) {
    throw new Error(
      `Expedition outcome ${actionId}.${outcomeId} probability must be in (0, 1].`,
    );
  }

  const narrativeId = typeof rawOutcome.narrativeId === "string"
    ? rawOutcome.narrativeId.trim()
    : "";
  if (!narrativeId) {
    throw new Error(
      `Expedition outcome ${actionId}.${outcomeId} requires narrativeId.`,
    );
  }

  const imageKey = typeof rawOutcome.imageKey === "string" &&
    rawOutcome.imageKey.trim().length > 0
    ? rawOutcome.imageKey.trim()
    : null;
  if (imageKey && !EXPEDITION_ID_PATTERN.test(imageKey)) {
    throw new Error(
      `Expedition outcome ${actionId}.${outcomeId} imageKey must be a safe slug.`,
    );
  }

  return {
    id: outcomeId,
    probability,
    narrativeId,
    resolutionOptions: normalizedResolutionOptions(
      rawOutcome.resolutionOptions,
      actionId,
      outcomeId,
      rawOutcome,
    ),
    ...(imageKey ? {imageKey} : {}),
  };
}

function normalizedActionOutcomes(rawOutcomes, actionId) {
  if (!isPlainObject(rawOutcomes) || Object.keys(rawOutcomes).length === 0) {
    throw new Error(
      `Expedition action ${actionId} must define at least one outcome.`,
    );
  }

  const outcomes = {};
  let probabilitySum = 0;
  for (const [outcomeIdRaw, rawOutcome] of Object.entries(rawOutcomes)) {
    const outcomeId = outcomeIdRaw.trim();
    if (!outcomeId) {
      throw new Error(
        `Expedition action ${actionId} contains an empty outcome ID.`,
      );
    }
    const outcome = normalizedOutcomeDefinition(
      rawOutcome,
      actionId,
      outcomeId,
    );
    outcomes[outcomeId] = outcome;
    probabilitySum += outcome.probability;
  }

  if (Math.abs(probabilitySum - 1) > 1e-9) {
    throw new Error(
      `Expedition action ${actionId} outcome probabilities must sum to 1.`,
    );
  }

  return outcomes;
}

function normalizedAvailability(rawAvailability, actionId) {
  // Compatibility with dataVersion <= 7.
  if (rawAvailability === "bunker") {
    return {
      unknownZone: false,
      zoneTypes: ["PLAYER_BUNKER"],
    };
  }

  if (!isPlainObject(rawAvailability)) {
    throw new Error(
      `Expedition action ${actionId} availability must be an object.`,
    );
  }

  const unknownZone = rawAvailability.unknownZone === true;
  const zoneTypesRaw = rawAvailability.zoneTypes == null
    ? []
    : rawAvailability.zoneTypes;
  if (!Array.isArray(zoneTypesRaw)) {
    throw new Error(
      `Expedition action ${actionId} availability.zoneTypes must be a list.`,
    );
  }
  const zoneTypes = zoneTypesRaw.map((rawType) =>
    typeof rawType === "string" ? rawType.trim().toUpperCase() : "",
  );
  if (
    zoneTypes.some((type) => !ZONE_TYPE_PATTERN.test(type)) ||
    new Set(zoneTypes).size !== zoneTypes.length
  ) {
    throw new Error(
      `Expedition action ${actionId} availability.zoneTypes contains invalid values.`,
    );
  }
  if (unknownZone === (zoneTypes.length > 0)) {
    throw new Error(
      `Expedition action ${actionId} must target either unknown zones or known zone types, not both/neither.`,
    );
  }

  return {unknownZone, zoneTypes};
}

function normalizedActionDefinition(rawAction, actionId) {
  if (!isPlainObject(rawAction)) {
    throw new Error(`Expedition action ${actionId} must be an object.`);
  }

  const expeditionType = typeof rawAction.expeditionType === "string"
    ? rawAction.expeditionType.trim()
    : "";
  if (!expeditionType || !EXPEDITION_ID_PATTERN.test(expeditionType)) {
    throw new Error(
      `Expedition action ${actionId} must define a safe expeditionType slug.`,
    );
  }

  const availability = normalizedAvailability(rawAction.availability, actionId);
  const completion = rawAction.completion == null
    ? INTERACTIVE_COMPLETION
    : rawAction.completion;
  if (![INTERACTIVE_COMPLETION, DISCOVER_ZONE_COMPLETION].includes(completion)) {
    throw new Error(
      `Expedition action ${actionId} has an unsupported completion mode.`,
    );
  }
  if (completion === DISCOVER_ZONE_COMPLETION && !availability.unknownZone) {
    throw new Error(
      `Expedition action ${actionId} discover_zone completion requires unknownZone availability.`,
    );
  }

  const durationSeconds = rawAction.durationSeconds;
  if (
    !Number.isInteger(durationSeconds) ||
    durationSeconds <= 0
  ) {
    throw new Error(
      `Expedition action ${actionId} durationSeconds must be positive.`,
    );
  }

  const energyDelta = rawAction.energyDelta;
  if (!Number.isInteger(energyDelta)) {
    throw new Error(
      `Expedition action ${actionId} energyDelta must be an integer.`,
    );
  }

  return {
    id: actionId,
    expeditionType,
    availability,
    completion,
    durationSeconds,
    energyDelta,
    outcomes: completion === DISCOVER_ZONE_COMPLETION
      ? {}
      : normalizedActionOutcomes(rawAction.outcomes, actionId),
  };
}

function expeditionDefinitionFromSnapshot(snapshot) {
  const data = snapshot?.data?.();
  if (!isPlainObject(data)) {
    throw new Error("Expedition server configuration is missing.");
  }

  if (!isPlainObject(data.actions)) {
    throw new Error("Expedition actions must be an object.");
  }

  const actions = {};
  for (const [actionIdRaw, rawAction] of Object.entries(data.actions)) {
    const actionId = actionIdRaw.trim();
    if (!actionId || !EXPEDITION_ID_PATTERN.test(actionId)) {
      throw new Error("Expedition action IDs must be safe slugs.");
    }
    actions[actionId] = normalizedActionDefinition(rawAction, actionId);
  }

  return {actions};
}

function normalizedZoneKnowledge(value) {
  if (value == null) return null;
  const zoneType = typeof value.zoneType === "string"
    ? value.zoneType.trim().toUpperCase()
    : "";
  if (!ZONE_TYPE_PATTERN.test(zoneType)) {
    throw new Error("Known zone has an invalid zone type.");
  }
  return {zoneType};
}

function availableActionsForZone(definition, zoneKnowledge) {
  const known = normalizedZoneKnowledge(zoneKnowledge);
  return Object.values(definition.actions).filter((action) => {
    if (known == null) return action.availability.unknownZone;
    return !action.availability.unknownZone &&
      action.availability.zoneTypes.includes(known.zoneType);
  });
}

// Compatibility helper retained for old unit tests/callers. The only known
// location in the old model was the bunker itself.
function availableActionsAtCoordinates(
  definition,
  coordinates,
  bunkerCoordinates,
) {
  if (!sameCoordinates(coordinates, bunkerCoordinates)) return [];
  return availableActionsForZone(definition, {zoneType: "PLAYER_BUNKER"});
}

function normalizedActionIds(value) {
  if (!Array.isArray(value)) {
    throw new Error("actionIds must be a list.");
  }

  const ids = value.map((entry) =>
    typeof entry === "string" ? entry.trim() : "",
  );
  if (
    ids.length === 0 ||
    ids.some((id) => !id) ||
    new Set(ids).size !== ids.length
  ) {
    throw new Error(
      "actionIds must contain unique non-empty action IDs.",
    );
  }
  return ids;
}

function canonicalActionId(actionId) {
  // Compatibility with the short-lived intermediate representation where the
  // expedition type itself was stored as the action ID.
  return actionId === "scavenge" ? "scout_surroundings" : actionId;
}

function actionDefinitionsByIds(definition, actionIds) {
  return normalizedActionIds(actionIds).map((rawActionId) => {
    const actionId = canonicalActionId(rawActionId);
    const action = definition.actions[actionId];
    if (!action) {
      throw new Error(`Unknown expedition action ${rawActionId}.`);
    }
    return action;
  });
}

function selectedActionDefinitionsForZone(
  definition,
  zoneKnowledge,
  actionIds,
) {
  const available = new Map(
    availableActionsForZone(definition, zoneKnowledge)
      .map((action) => [action.id, action]),
  );

  const selected = normalizedActionIds(actionIds).map((rawActionId) => {
    const actionId = canonicalActionId(rawActionId);
    const action = available.get(actionId);
    if (!action) {
      throw new Error(
        `Expedition action ${rawActionId} is not available for this zone.`,
      );
    }
    return action;
  });

  if (selected.some((action) => action.completion === DISCOVER_ZONE_COMPLETION) &&
      selected.length !== 1) {
    throw new Error("Explore must be launched as a single action.");
  }
  return selected;
}

function selectedActionDefinitions(
  definition,
  coordinates,
  bunkerCoordinates,
  actionIds,
) {
  if (!sameCoordinates(coordinates, bunkerCoordinates)) {
    throw new Error("Expedition actions are not available at these coordinates.");
  }
  return selectedActionDefinitionsForZone(
    definition,
    {zoneType: "PLAYER_BUNKER"},
    actionIds,
  );
}

function expeditionTypeForActions(actions) {
  if (!Array.isArray(actions) || actions.length === 0) {
    throw new Error("An expedition requires at least one action.");
  }
  const types = new Set(actions.map((action) => action.expeditionType));
  if (types.size !== 1) {
    throw new Error(
      "All selected expedition actions must belong to the same expedition type.",
    );
  }
  return actions[0].expeditionType;
}

function isExplorationAction(action) {
  return action?.completion === DISCOVER_ZONE_COMPLETION;
}

function deterministicUnitInterval(seed) {
  const digest = createHash("sha256").update(seed).digest();
  return digest.readUIntBE(0, 6) / 0x1000000000000;
}

function selectActionOutcome(action, executionSeed) {
  if (isExplorationAction(action)) return null;
  const roll = deterministicUnitInterval(
    `${action.id}:${executionSeed}:expedition-outcome`,
  );
  let cumulative = 0;

  for (const outcome of Object.values(action.outcomes)) {
    cumulative += outcome.probability;
    if (roll < cumulative) return outcome;
  }

  return Object.values(action.outcomes).at(-1);
}

function selectExpeditionOutcomes(actions, executionSeed) {
  return actions
    .filter((action) => !isExplorationAction(action))
    .map((action) => ({
      actionId: action.id,
      ...selectActionOutcome(action, executionSeed),
    }));
}

function normalizedChoiceSelections(value) {
  if (!isPlainObject(value)) {
    throw new Error("Expedition choices must be an object.");
  }

  const selections = {};
  for (const [actionIdRaw, optionIdRaw] of Object.entries(value)) {
    const actionId = actionIdRaw.trim();
    const optionId = typeof optionIdRaw === "string"
      ? optionIdRaw.trim()
      : "";
    if (
      !actionId ||
      !optionId ||
      !EXPEDITION_ID_PATTERN.test(actionId) ||
      !EXPEDITION_ID_PATTERN.test(optionId)
    ) {
      throw new Error("Expedition choices contain an invalid selection.");
    }
    selections[actionId] = optionId;
  }
  return selections;
}

function selectedResolutionOptions(outcomes, choiceSelections) {
  if (!Array.isArray(outcomes) || outcomes.length === 0) {
    throw new Error("Expedition report must contain outcomes.");
  }
  const choices = normalizedChoiceSelections(choiceSelections);
  const selected = [];

  for (const outcome of outcomes) {
    const actionId = typeof outcome?.actionId === "string"
      ? outcome.actionId.trim()
      : "";
    const options = isPlainObject(outcome?.resolutionOptions)
      ? outcome.resolutionOptions
      : {};
    const optionId = choices[actionId];
    if (!actionId || !optionId || !options[optionId]) {
      throw new Error(
        `A valid resolution option is required for expedition action ${actionId || "unknown"}.`,
      );
    }
    selected.push({
      actionId,
      outcomeId: outcome.outcomeId || outcome.id || "",
      ...options[optionId],
      id: optionId,
    });
  }

  if (Object.keys(choices).length !== selected.length) {
    throw new Error("Expedition choices contain unexpected action IDs.");
  }
  return selected;
}

function aggregateExpeditionResolutionInventoryDelta(selectedOptions) {
  const aggregate = {};
  for (const option of selectedOptions) {
    for (const [itemId, quantity] of Object.entries(
      option.inventoryDelta || {},
    )) {
      aggregate[itemId] = (aggregate[itemId] || 0) + quantity;
    }
  }
  return aggregate;
}

function applyInventoryReward(inventorySource, delta) {
  const inventory = isPlainObject(inventorySource)
    ? {...inventorySource}
    : {};
  for (const [itemId, quantity] of Object.entries(delta)) {
    const current = Number.isInteger(inventory[itemId])
      ? inventory[itemId]
      : 0;
    inventory[itemId] = current + quantity;
  }
  return inventory;
}

function expeditionDurationSeconds(actions, travelSeconds = 0) {
  if (!Number.isInteger(travelSeconds) || travelSeconds < 0) {
    throw new Error("travelSeconds must be a non-negative integer.");
  }
  return actions.reduce(
    (total, action) => total + action.durationSeconds,
    travelSeconds,
  );
}

function expeditionTravelSeconds(
  originCoordinates,
  targetCoordinates,
  secondsPerDistanceUnit = DEFAULT_EXPEDITION_TRAVEL_SECONDS_PER_DISTANCE_UNIT,
) {
  if (
    typeof secondsPerDistanceUnit !== "number" ||
    !Number.isFinite(secondsPerDistanceUnit) ||
    secondsPerDistanceUnit < 0
  ) {
    throw new Error("Expedition travel multiplier must be non-negative.");
  }
  return Math.ceil(
    mapDistance(originCoordinates, targetCoordinates) * secondsPerDistanceUnit,
  );
}

function expeditionTravelSecondsPerDistanceUnitFromConfig(snapshot) {
  const value = snapshot?.data?.()?.config?.expeditionTravelSecondsPerDistanceUnit;
  if (typeof value === "number" && Number.isFinite(value) && value >= 0) {
    return value;
  }
  return DEFAULT_EXPEDITION_TRAVEL_SECONDS_PER_DISTANCE_UNIT;
}

function expeditionEnergyDelta(actions) {
  return actions.reduce(
    (total, action) => total + action.energyDelta,
    0,
  );
}

function expeditionTaskId(actionIds) {
  const canonicalIds = normalizedActionIds(actionIds).map(canonicalActionId);
  return `expedition:${canonicalIds.join("+")}`;
}

function actionIdsFromExpeditionTaskId(taskId) {
  if (typeof taskId !== "string" || !taskId.startsWith("expedition:")) {
    throw new Error("Invalid expedition task ID.");
  }
  return normalizedActionIds(
    taskId.substring("expedition:".length).split("+"),
  ).map(canonicalActionId);
}

function expeditionLocation(coordinates) {
  return mapCoordinateId(normalizedMapCoordinates(coordinates));
}

function coordinatesFromExpeditionLocation(location) {
  return mapCoordinatesToLegacy(mapCoordinatesFromLocation(location));
}

function applyExpeditionAutomaticResolution(
  bunker,
  participantIds,
  actions,
  outcomes = [],
) {
  // The selected outcomes are deliberately part of this boundary even though
  // the current implementation only applies energy. Future unavoidable
  // injuries/deaths can be applied here without involving the user decision.
  void outcomes;
  const participantSet = new Set(participantIds);
  const survivors = Array.isArray(bunker.survivors)
    ? bunker.survivors.map((survivor) => ({...survivor}))
    : [];
  const known = new Set(
    survivors
      .filter((survivor) => participantSet.has(survivor?.id))
      .map((survivor) => survivor.id),
  );
  if (known.size !== participantSet.size) {
    throw new Error("Expedition references an unknown Survivor.");
  }

  const energyDelta = expeditionEnergyDelta(actions);
  for (let index = 0; index < survivors.length; index += 1) {
    const survivor = survivors[index];
    if (!participantSet.has(survivor.id)) continue;

    const currentEnergy = Number.isInteger(survivor.energy)
      ? survivor.energy
      : 0;
    survivors[index] = {
      ...survivor,
      energy: currentEnergy + energyDelta,
    };
  }

  return {
    ...bunker,
    survivors,
  };
}

function applyExpeditionInteractiveResolution(
  bunker,
  outcomes,
  choiceSelections,
) {
  const selectedOptions = selectedResolutionOptions(
    outcomes,
    choiceSelections,
  );
  const inventoryDelta = aggregateExpeditionResolutionInventoryDelta(
    selectedOptions,
  );
  const eventTriggers = selectedOptions
    .filter((option) => option.eventTrigger)
    .map((option) => ({
      actionId: option.actionId,
      outcomeId: option.outcomeId,
      optionId: option.id,
      eventTrigger: option.eventTrigger,
    }));

  return {
    bunker: {
      ...bunker,
      inventory: applyInventoryReward(bunker.inventory, inventoryDelta),
    },
    inventoryDelta,
    selectedOptions,
    eventTriggers,
  };
}

module.exports = {
  DEFAULT_EXPEDITION_TRAVEL_SECONDS_PER_DISTANCE_UNIT,
  DISCOVER_ZONE_COMPLETION,
  EXPEDITION_ACTIVITY,
  actionDefinitionsByIds,
  actionIdsFromExpeditionTaskId,
  aggregateExpeditionResolutionInventoryDelta,
  applyExpeditionAutomaticResolution,
  applyExpeditionInteractiveResolution,
  applyInventoryReward,
  availableActionsAtCoordinates,
  availableActionsForZone,
  canonicalActionId,
  coordinatesForClient,
  coordinatesFromExpeditionLocation,
  expeditionDefinitionFromSnapshot,
  expeditionDurationSeconds,
  expeditionEnergyDelta,
  expeditionLocation,
  expeditionTaskId,
  expeditionTravelSeconds,
  expeditionTravelSecondsPerDistanceUnitFromConfig,
  expeditionTypeForActions,
  isExplorationAction,
  normalizedActionIds,
  normalizedChoiceSelections,
  normalizedCoordinates,
  sameCoordinates,
  selectExpeditionOutcomes,
  selectedActionDefinitions,
  selectedActionDefinitionsForZone,
  selectedResolutionOptions,
};
