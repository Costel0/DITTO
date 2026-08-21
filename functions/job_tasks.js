const {createHash} = require("node:crypto");
const {
  applyStatExperienceDelta,
  normalizedStatExperienceDelta,
  normalizedStatRequirements,
} = require("./survivor_progression");

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

function normalizedEffects(value, label) {
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
    statExperienceDelta: normalizedStatExperienceDelta(
      raw.statExperienceDelta,
      `${label}.statExperienceDelta`,
    ),
  };
}

function normalizedSurvivorRequirements(value, taskId) {
  if (value == null) {
    return {min: 1, max: 1, statRequirements: {}};
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
  return {
    min,
    max,
    statRequirements: normalizedStatRequirements(
      value.statRequirements,
      `Task ${taskId} survivorRequirements.statRequirements`,
    ),
  };
}

function normalizedRandomOutcomes(value, taskId, resultId) {
  if (value == null) return [];
  if (!isPlainObject(value)) {
    throw new Error(
      `Task ${taskId} result ${resultId} randomOutcomes must be an object.`,
    );
  }

  return Object.entries(value).map(([outcomeIdRaw, rawOutcome]) => {
    const outcomeId = outcomeIdRaw.trim();
    if (!outcomeId || !isPlainObject(rawOutcome)) {
      throw new Error(
        `Task ${taskId} result ${resultId} contains an invalid random outcome.`,
      );
    }

    const probability = rawOutcome.probability;
    if (
      typeof probability !== "number" ||
      !Number.isFinite(probability) ||
      probability < 0 ||
      probability > 1
    ) {
      throw new Error(
        `Task ${taskId} result ${resultId} random outcome ${outcomeId} ` +
          "probability must be 0..1.",
      );
    }

    return {
      id: outcomeId,
      probability,
      effects: normalizedEffects(
        rawOutcome.effects,
        `Task ${taskId} results.${resultId}.randomOutcomes.${outcomeId}.effects`,
      ),
    };
  });
}

function normalizedResults(rawTask, taskId) {
  // Backwards compatibility with the first task format, where completion was
  // a single guaranteed effect block and there was no explicit result layer.
  if (
    rawTask.results == null &&
    rawTask.outcomes == null &&
    rawTask.completion != null
  ) {
    return {
      resolver: {
        type: "fixed",
        resultId: "default",
      },
      results: {
        default: {
          guaranteedOutcomes: normalizedEffects(
            rawTask.completion,
            `Task ${taskId} completion`,
          ),
          randomOutcomes: [],
        },
      },
    };
  }

  // Backwards compatibility with the previous format where `outcomes` were
  // mutually exclusive top-level results and `outcomeEffects` held effects.
  if (rawTask.results == null && rawTask.outcomes != null) {
    if (!isPlainObject(rawTask.outcomes) || !isPlainObject(rawTask.outcomeEffects)) {
      throw new Error(`Task ${taskId} has an invalid legacy outcomes format.`);
    }

    const results = {};
    for (const [resultIdRaw] of Object.entries(rawTask.outcomes)) {
      const resultId = resultIdRaw.trim();
      if (!resultId) {
        throw new Error(`Task ${taskId} contains an empty result ID.`);
      }
      results[resultId] = {
        guaranteedOutcomes: normalizedEffects(
          rawTask.outcomeEffects[resultId],
          `Task ${taskId} outcomeEffects.${resultId}`,
        ),
        randomOutcomes: [],
      };
    }

    return {
      resolver: {
        type: "random",
        probabilities: {...rawTask.outcomes},
      },
      results,
    };
  }

  if (!isPlainObject(rawTask.results) || Object.keys(rawTask.results).length === 0) {
    throw new Error(`Task ${taskId} results must contain at least one result.`);
  }

  const results = {};
  for (const [resultIdRaw, rawResult] of Object.entries(rawTask.results)) {
    const resultId = resultIdRaw.trim();
    if (!resultId || !isPlainObject(rawResult)) {
      throw new Error(`Task ${taskId} contains an invalid result entry.`);
    }

    results[resultId] = {
      guaranteedOutcomes: normalizedEffects(
        rawResult.guaranteedOutcomes,
        `Task ${taskId} results.${resultId}.guaranteedOutcomes`,
      ),
      randomOutcomes: normalizedRandomOutcomes(
        rawResult.randomOutcomes,
        taskId,
        resultId,
      ),
    };
  }

  const rawResolver = rawTask.resultResolver;
  if (!isPlainObject(rawResolver)) {
    throw new Error(`Task ${taskId} resultResolver must be an object.`);
  }

  const type = typeof rawResolver.type === "string"
    ? rawResolver.type.trim()
    : "";
  const allowedTypes = new Set(["fixed", "random", "server", "combat"]);
  if (!allowedTypes.has(type)) {
    throw new Error(
      `Task ${taskId} resultResolver.type must be fixed, random, server or combat.`,
    );
  }

  const resultIds = new Set(Object.keys(results));
  if (type === "fixed") {
    const resultId = typeof rawResolver.resultId === "string"
      ? rawResolver.resultId.trim()
      : "";
    if (!resultIds.has(resultId)) {
      throw new Error(
        `Task ${taskId} fixed resultResolver references unknown result ${resultId}.`,
      );
    }
    return {
      resolver: {type, resultId},
      results,
    };
  }

  if (type === "random") {
    if (!isPlainObject(rawResolver.probabilities)) {
      throw new Error(
        `Task ${taskId} random resultResolver.probabilities must be an object.`,
      );
    }

    let total = 0;
    const probabilities = {};
    for (const [resultIdRaw, probability] of Object.entries(
      rawResolver.probabilities,
    )) {
      const resultId = resultIdRaw.trim();
      if (!resultIds.has(resultId)) {
        throw new Error(
          `Task ${taskId} resultResolver references unknown result ${resultId}.`,
        );
      }
      if (
        typeof probability !== "number" ||
        !Number.isFinite(probability) ||
        probability < 0 ||
        probability > 1
      ) {
        throw new Error(
          `Task ${taskId} result probability ${resultId} must be 0..1.`,
        );
      }
      probabilities[resultId] = probability;
      total += probability;
    }

    for (const resultId of resultIds) {
      if (!Object.prototype.hasOwnProperty.call(probabilities, resultId)) {
        throw new Error(
          `Task ${taskId} random resolver is missing result ${resultId}.`,
        );
      }
    }
    if (Math.abs(total - 1) > 1e-9) {
      throw new Error(`Task ${taskId} result probabilities must add up to 1.`);
    }

    return {
      resolver: {type, probabilities},
      results,
    };
  }

  const handler = typeof rawResolver.handler === "string"
    ? rawResolver.handler.trim()
    : "";
  if (!handler) {
    throw new Error(
      `Task ${taskId} ${type} resultResolver must define a handler.`,
    );
  }

  return {
    resolver: {type, handler},
    results,
  };
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

  const resultDefinition = normalizedResults(rawTask, normalizedTaskId);

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
    resultResolver: resultDefinition.resolver,
    results: resultDefinition.results,
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
  return digest.readUIntBE(0, 6) / 0x1000000000000;
}

function selectTaskResult(task, executionId, externallyResolvedResultId = null) {
  if (externallyResolvedResultId != null) {
    const resultId = String(externallyResolvedResultId).trim();
    const result = task.results[resultId];
    if (!result) {
      throw new Error(`Task ${task.id} does not define result ${resultId}.`);
    }
    return {id: resultId, ...result};
  }

  if (task.resultResolver.type === "fixed") {
    const resultId = task.resultResolver.resultId;
    return {id: resultId, ...task.results[resultId]};
  }

  if (task.resultResolver.type === "random") {
    const roll = deterministicUnitInterval(`${task.id}:${executionId}:result`);
    let cumulative = 0;

    for (const [resultId, probability] of Object.entries(
      task.resultResolver.probabilities,
    )) {
      cumulative += probability;
      if (roll < cumulative) {
        return {id: resultId, ...task.results[resultId]};
      }
    }

    const fallbackId = Object.keys(task.results).at(-1);
    return {id: fallbackId, ...task.results[fallbackId]};
  }

  throw new Error(
    `Task ${task.id} requires ${task.resultResolver.type} result handler ` +
      `${task.resultResolver.handler}; generic resolution cannot decide it yet.`,
  );
}

function applyEffects(bunker, participantIds, effects) {
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
    throw new Error("Task effects reference an unknown Survivor.");
  }

  for (let index = 0; index < survivors.length; index += 1) {
    const survivor = survivors[index];
    if (!participantSet.has(survivor.id)) continue;

    const currentEnergy = Number.isInteger(survivor.energy) ? survivor.energy : 0;
    const progressedSurvivor = applyStatExperienceDelta(
      survivor,
      effects.statExperienceDelta,
    );
    survivors[index] = {
      ...progressedSurvivor,
      energy: currentEnergy + effects.energyDelta,
    };
  }

  return {
    ...bunker,
    survivors,
    inventory: applyInventoryDelta(
      bunker.inventory,
      effects.inventoryDelta,
    ),
  };
}

function applyTaskCompletionEffects(
  bunker,
  survivorIds,
  task,
  resultId,
  executionId,
) {
  const participantIds = Array.isArray(survivorIds)
    ? survivorIds
    : [survivorIds];
  if (
    participantIds.length === 0 ||
    new Set(participantIds).size !== participantIds.length
  ) {
    throw new Error(`Task ${task.id} requires unique Survivor participants.`);
  }

  const result = task.results[resultId];
  if (!result) {
    throw new Error(`Task ${task.id} does not define result ${resultId}.`);
  }

  let workingBunker = applyEffects(
    bunker,
    participantIds,
    result.guaranteedOutcomes,
  );
  const triggeredRandomOutcomeIds = [];

  for (const randomOutcome of result.randomOutcomes) {
    const roll = deterministicUnitInterval(
      `${task.id}:${executionId}:${resultId}:outcome:${randomOutcome.id}`,
    );
    if (roll >= randomOutcome.probability) continue;

    workingBunker = applyEffects(
      workingBunker,
      participantIds,
      randomOutcome.effects,
    );
    triggeredRandomOutcomeIds.push(randomOutcome.id);
  }

  return {
    bunker: workingBunker,
    triggeredRandomOutcomeIds,
  };
}

module.exports = {
  applyTaskCompletionEffects,
  applyTaskStartCost,
  missingRequiredTaskIds,
  selectTaskResult,
  taskDefinitionFromSnapshot,
};