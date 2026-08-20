const {createHash} = require("node:crypto");

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function normalizedStringList(value, label) {
  if (value == null) return [];
  if (!Array.isArray(value)) {
    throw new Error(`${label} must be a list of strings.`);
  }

  const normalized = value.map((entry) => {
    if (typeof entry !== "string" || !entry.trim()) {
      throw new Error(`${label} must contain only non-empty strings.`);
    }
    return entry.trim();
  });

  if (new Set(normalized).size !== normalized.length) {
    throw new Error(`${label} cannot contain duplicates.`);
  }
  return normalized;
}

function normalizedInventoryMap(value, label, {positiveOnly = false} = {}) {
  if (value == null) return {};
  if (!isPlainObject(value)) {
    throw new Error(`${label} must be an object.`);
  }

  const normalized = {};
  for (const [itemIdRaw, quantity] of Object.entries(value)) {
    const itemId = itemIdRaw.trim();
    if (!itemId || !Number.isInteger(quantity)) {
      throw new Error(`${label} contains an invalid item quantity.`);
    }
    if (positiveOnly && quantity <= 0) {
      throw new Error(`${label} quantities must be positive integers.`);
    }
    normalized[itemId] = quantity;
  }
  return normalized;
}

function normalizedCompletion(value, label) {
  const raw = value == null ? {} : value;
  if (!isPlainObject(raw)) {
    throw new Error(`${label} must be an object.`);
  }

  const energyDelta = raw.energyDelta ?? 0;
  if (!Number.isInteger(energyDelta)) {
    throw new Error(`${label}.energyDelta must be an integer.`);
  }

  return {
    energyDelta,
    inventoryDelta: normalizedInventoryMap(
      raw.inventoryDelta,
      `${label}.inventoryDelta`,
    ),
  };
}

function normalizedSurvivorRequirements(value, taskId) {
  if (value == null) {
    return {min: 1, max: 1};
  }
  if (!isPlainObject(value)) {
    throw new Error(`Task ${taskId} survivorRequirements must be an object.`);
  }

  const min = value.min;
  const max = value.max;
  if (!Number.isInteger(min) || min < 1) {
    throw new Error(`Task ${taskId} survivorRequirements.min must be >= 1.`);
  }
  if (!Number.isInteger(max) || max < min) {
    throw new Error(
      `Task ${taskId} survivorRequirements.max must be >= min.`,
    );
  }
  return {min, max};
}

function normalizedOutcomes(rawTask, taskId) {
  // Backwards compatibility with the first server task format.
  if (rawTask.outcomes == null) {
    return [
      {
        id: "default",
        probability: 1,
        completion: normalizedCompletion(
          rawTask.completion,
          `Task ${taskId} completion`,
        ),
      },
    ];
  }

  if (!isPlainObject(rawTask.outcomes)) {
    throw new Error(`Task ${taskId} outcomes must be an object.`);
  }
  if (!isPlainObject(rawTask.outcomeEffects)) {
    throw new Error(`Task ${taskId} outcomeEffects must be an object.`);
  }

  const entries = Object.entries(rawTask.outcomes);
  if (entries.length === 0) {
    throw new Error(`Task ${taskId} must define at least one outcome.`);
  }

  let probabilityTotal = 0;
  const outcomes = entries.map(([outcomeIdRaw, probability]) => {
    const outcomeId = outcomeIdRaw.trim();
    if (!outcomeId) {
      throw new Error(`Task ${taskId} contains an empty outcome ID.`);
    }
    if (
      typeof probability !== "number" ||
      !Number.isFinite(probability) ||
      probability < 0 ||
      probability > 1
    ) {
      throw new Error(
        `Task ${taskId} outcome ${outcomeId} probability must be 0..1.`,
      );
    }

    probabilityTotal += probability;
    if (!Object.prototype.hasOwnProperty.call(rawTask.outcomeEffects, outcomeId)) {
      throw new Error(
        `Task ${taskId} outcome ${outcomeId} is missing outcomeEffects.`,
      );
    }

    return {
      id: outcomeId,
      probability,
      completion: normalizedCompletion(
        rawTask.outcomeEffects[outcomeId],
        `Task ${taskId} outcomeEffects.${outcomeId}`,
      ),
    };
  });

  for (const outcomeIdRaw of Object.keys(rawTask.outcomeEffects)) {
    const outcomeId = outcomeIdRaw.trim();
    if (!Object.prototype.hasOwnProperty.call(rawTask.outcomes, outcomeId)) {
      throw new Error(
        `Task ${taskId} has effects for unknown outcome ${outcomeId}.`,
      );
    }
  }

  if (Math.abs(probabilityTotal - 1) > 1e-9) {
    throw new Error(`Task ${taskId} outcome probabilities must add up to 1.`);
  }

  return outcomes;
}

function taskDefinitionFromSnapshot(snapshot, taskId) {
  const normalizedTaskId = typeof taskId === "string" ? taskId.trim() : "";
  if (!normalizedTaskId) return null;

  const rawTask = snapshot.data()?.tasks?.[normalizedTaskId];
  if (!isPlainObject(rawTask)) return null;

  const activity = typeof rawTask.activity === "string" && rawTask.activity.trim()
    ? rawTask.activity.trim()
    : normalizedTaskId;
  const location = typeof rawTask.location === "string"
    ? rawTask.location.trim()
    : "";
  const durationSeconds = rawTask.durationSeconds;

  if (!location) {
    throw new Error(`Task ${normalizedTaskId} must define a location.`);
  }
  if (
    typeof durationSeconds !== "number" ||
    !Number.isFinite(durationSeconds) ||
    durationSeconds <= 0
  ) {
    throw new Error(
      `Task ${normalizedTaskId} must define a positive durationSeconds.`,
    );
  }

  const storable = rawTask.storable ?? false;
  if (typeof storable !== "boolean") {
    throw new Error(`Task ${normalizedTaskId} storable must be a boolean.`);
  }

  const requiredTaskIds = normalizedStringList(
    rawTask.requiredTaskIds,
    `Task ${normalizedTaskId} requiredTaskIds`,
  );
  if (requiredTaskIds.includes(normalizedTaskId)) {
    throw new Error(`Task ${normalizedTaskId} cannot require itself.`);
  }

  const rawCost = rawTask.cost == null ? {} : rawTask.cost;
  if (!isPlainObject(rawCost)) {
    throw new Error(`Task ${normalizedTaskId} cost must be an object.`);
  }

  return {
    id: normalizedTaskId,
    activity,
    location,
    durationSeconds: Math.ceil(durationSeconds),
    storable,
    requiredTaskIds,
    survivorRequirements: normalizedSurvivorRequirements(
      rawTask.survivorRequirements,
      normalizedTaskId,
    ),
    cost: {
      inventory: normalizedInventoryMap(
        rawCost.inventory,
        `Task ${normalizedTaskId} cost.inventory`,
        {positiveOnly: true},
      ),
    },
    outcomes: normalizedOutcomes(rawTask, normalizedTaskId),
  };
}

function missingRequiredTaskIds(bunker, task) {
  const completed = new Set(
    Array.isArray(bunker.completedTaskIds)
      ? bunker.completedTaskIds.filter((id) => typeof id === "string")
      : [],
  );
  return task.requiredTaskIds.filter((taskId) => !completed.has(taskId));
}

function applyInventoryDelta(inventorySource, delta, {rejectNegative = true} = {}) {
  const inventory = isPlainObject(inventorySource) ? {...inventorySource} : {};

  for (const [itemId, quantityDelta] of Object.entries(delta)) {
    const currentQuantity = Number.isInteger(inventory[itemId])
      ? inventory[itemId]
      : 0;
    const nextQuantity = currentQuantity + quantityDelta;
    if (rejectNegative && nextQuantity < 0) {
      throw new Error(`Inventory ${itemId} would become negative.`);
    }
    if (nextQuantity <= 0) {
      delete inventory[itemId];
    } else {
      inventory[itemId] = nextQuantity;
    }
  }

  return inventory;
}

function applyTaskStartCost(bunker, task) {
  const costDelta = Object.fromEntries(
    Object.entries(task.cost.inventory).map(([itemId, quantity]) => [
      itemId,
      -quantity,
    ]),
  );

  return {
    ...bunker,
    inventory: applyInventoryDelta(bunker.inventory, costDelta),
  };
}

function deterministicUnitInterval(seed) {
  const digest = createHash("sha256").update(seed).digest();
  const high = digest.readUInt32BE(0);
  const low = digest.readUInt32BE(4);
  return (high * 0x100000000 + low) / 0x10000000000000000;
}

function selectTaskOutcome(task, executionId) {
  const seed = `${task.id}:${executionId}`;
  const roll = deterministicUnitInterval(seed);
  let cumulative = 0;

  for (const outcome of task.outcomes) {
    cumulative += outcome.probability;
    if (roll < cumulative) return outcome;
  }

  // Floating point rounding can only reach this path by a tiny margin.
  return task.outcomes[task.outcomes.length - 1];
}

function applyTaskCompletionEffects(bunker, survivorIds, task, outcomeId) {
  const participantIds = Array.isArray(survivorIds)
    ? survivorIds
    : [survivorIds];
  if (participantIds.length === 0 || new Set(participantIds).size !== participantIds.length) {
    throw new Error(`Task ${task.id} requires unique Survivor participants.`);
  }

  const outcome = task.outcomes.find((entry) => entry.id === outcomeId);
  if (!outcome) {
    throw new Error(`Task ${task.id} does not define outcome ${outcomeId}.`);
  }

  const participantSet = new Set(participantIds);
  const survivors = Array.isArray(bunker.survivors)
    ? bunker.survivors.map((survivor) => ({...survivor}))
    : [];
  const knownParticipantIds = new Set(
    survivors
      .filter((survivor) => participantSet.has(survivor?.id))
      .map((survivor) => survivor.id),
  );
  if (knownParticipantIds.size !== participantSet.size) {
    throw new Error(`Task ${task.id} references an unknown Survivor.`);
  }

  for (let index = 0; index < survivors.length; index += 1) {
    const survivor = survivors[index];
    if (!participantSet.has(survivor.id)) continue;

    const currentEnergy = Number.isInteger(survivor.energy) ? survivor.energy : 0;
    survivors[index] = {
      ...survivor,
      energy: currentEnergy + outcome.completion.energyDelta,
    };
  }

  return {
    ...bunker,
    survivors,
    inventory: applyInventoryDelta(
      bunker.inventory,
      outcome.completion.inventoryDelta,
    ),
  };
}

module.exports = {
  applyTaskCompletionEffects,
  applyTaskStartCost,
  missingRequiredTaskIds,
  selectTaskOutcome,
  taskDefinitionFromSnapshot,
};
