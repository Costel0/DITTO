const EXPEDITION_ACTIVITY = "expedition";

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function normalizedCoordinates(value, label = "coordinates") {
  if (!isPlainObject(value)) {
    throw new Error(`${label} must be an object.`);
  }

  const result = {};
  for (const axis of ["x", "y", "z"]) {
    const coordinate = value[axis];
    if (
      !Number.isInteger(coordinate) ||
      coordinate < 0 ||
      coordinate > 999
    ) {
      throw new Error(
        `${label}.${axis} must be an integer from 0 to 999.`,
      );
    }
    result[axis] = coordinate;
  }
  return result;
}

function sameCoordinates(left, right) {
  return left.x === right.x && left.y === right.y && left.z === right.z;
}

function normalizedActionDefinition(rawAction, actionId) {
  if (!isPlainObject(rawAction)) {
    throw new Error(`Expedition action ${actionId} must be an object.`);
  }

  const availability = rawAction.availability;
  if (availability !== "bunker") {
    throw new Error(
      `Expedition action ${actionId} has unsupported availability.`,
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
    availability,
    durationSeconds,
    energyDelta,
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
    if (!actionId) {
      throw new Error("Expedition action IDs cannot be empty.");
    }
    actions[actionId] = normalizedActionDefinition(rawAction, actionId);
  }

  return {actions};
}

function availableActionsAtCoordinates(
  definition,
  coordinates,
  bunkerCoordinates,
) {
  const normalizedTarget = normalizedCoordinates(coordinates);
  const normalizedBunker = normalizedCoordinates(
    bunkerCoordinates,
    "bunkerCoordinates",
  );

  if (!sameCoordinates(normalizedTarget, normalizedBunker)) {
    return [];
  }
  return Object.values(definition.actions)
    .filter((action) => action.availability === "bunker");
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
  return actionId === "scout_surroundings" ? "scavenge" : actionId;
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

function selectedActionDefinitions(
  definition,
  coordinates,
  bunkerCoordinates,
  actionIds,
) {
  const available = new Map(
    availableActionsAtCoordinates(
      definition,
      coordinates,
      bunkerCoordinates,
    ).map((action) => [action.id, action]),
  );

  return normalizedActionIds(actionIds).map((rawActionId) => {
    const actionId = canonicalActionId(rawActionId);
    const action = available.get(actionId);
    if (!action) {
      throw new Error(
        `Expedition action ${rawActionId} is not available at these coordinates.`,
      );
    }
    return action;
  });
}

function expeditionDurationSeconds(actions) {
  return actions.reduce(
    (total, action) => total + action.durationSeconds,
    0,
  );
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
  const normalized = normalizedCoordinates(coordinates);
  return `${normalized.x},${normalized.y},${normalized.z}`;
}

function coordinatesFromExpeditionLocation(location) {
  if (typeof location !== "string") {
    throw new Error("Invalid expedition location.");
  }
  const parts = location.split(",").map((value) => Number(value));
  if (parts.length !== 3) {
    throw new Error("Invalid expedition location.");
  }
  return normalizedCoordinates({
    x: parts[0],
    y: parts[1],
    z: parts[2],
  });
}

function applyExpeditionCompletion(
  bunker,
  participantIds,
  actions,
) {
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

module.exports = {
  EXPEDITION_ACTIVITY,
  actionDefinitionsByIds,
  actionIdsFromExpeditionTaskId,
  applyExpeditionCompletion,
  availableActionsAtCoordinates,
  canonicalActionId,
  coordinatesFromExpeditionLocation,
  expeditionDefinitionFromSnapshot,
  expeditionDurationSeconds,
  expeditionEnergyDelta,
  expeditionLocation,
  expeditionTaskId,
  normalizedActionIds,
  normalizedCoordinates,
  sameCoordinates,
  selectedActionDefinitions,
};
