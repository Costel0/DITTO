function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
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

  const rawCompletion = isPlainObject(rawTask.completion)
    ? rawTask.completion
    : {};
  const energyDelta = rawCompletion.energyDelta ?? 0;
  if (!Number.isInteger(energyDelta)) {
    throw new Error(
      `Task ${normalizedTaskId} completion.energyDelta must be an integer.`,
    );
  }

  const rawInventoryDelta = rawCompletion.inventoryDelta ?? {};
  if (!isPlainObject(rawInventoryDelta)) {
    throw new Error(
      `Task ${normalizedTaskId} completion.inventoryDelta must be an object.`,
    );
  }

  const inventoryDelta = {};
  for (const [itemIdRaw, quantityDelta] of Object.entries(rawInventoryDelta)) {
    const itemId = itemIdRaw.trim();
    if (!itemId || !Number.isInteger(quantityDelta)) {
      throw new Error(
        `Task ${normalizedTaskId} has an invalid inventory delta.`,
      );
    }
    inventoryDelta[itemId] = quantityDelta;
  }

  return {
    id: normalizedTaskId,
    activity,
    location,
    durationSeconds: Math.ceil(durationSeconds),
    completion: {
      energyDelta,
      inventoryDelta,
    },
  };
}

function applyTaskCompletionEffects(bunker, survivorId, task) {
  const survivors = Array.isArray(bunker.survivors)
    ? bunker.survivors.map((survivor) => ({...survivor}))
    : [];
  const survivorIndex = survivors.findIndex(
    (survivor) => survivor?.id === survivorId,
  );
  if (survivorIndex < 0) {
    throw new Error(`Survivor ${survivorId} does not exist in bunker.`);
  }

  const survivor = survivors[survivorIndex];
  const currentEnergy = Number.isInteger(survivor.energy) ? survivor.energy : 0;
  survivors[survivorIndex] = {
    ...survivor,
    energy: currentEnergy + task.completion.energyDelta,
  };

  const inventory = isPlainObject(bunker.inventory) ? {...bunker.inventory} : {};
  for (const [itemId, quantityDelta] of Object.entries(
    task.completion.inventoryDelta,
  )) {
    const currentQuantity = Number.isInteger(inventory[itemId])
      ? inventory[itemId]
      : 0;
    const nextQuantity = currentQuantity + quantityDelta;
    if (nextQuantity < 0) {
      throw new Error(
        `Task ${task.id} would make inventory ${itemId} negative.`,
      );
    }
    if (nextQuantity === 0) {
      delete inventory[itemId];
    } else {
      inventory[itemId] = nextQuantity;
    }
  }

  return {
    ...bunker,
    survivors,
    inventory,
  };
}

module.exports = {
  applyTaskCompletionEffects,
  taskDefinitionFromSnapshot,
};
