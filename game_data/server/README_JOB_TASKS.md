# `job_tasks.json`

Catálogo privado y autoritativo de tareas del juego.

Archivo: `game_data/server/job_tasks.json`

Se sincroniza con `/serverData/jobTasks`. La app no puede leer este documento directamente; las Cloud Functions exponen únicamente la información necesaria para jugar.

## Estructura raíz

```json
{
  "schemaVersion": 4,
  "dataVersion": 5,
  "tasks": {}
}
```

- `schemaVersion`: versión del formato del archivo.
- `dataVersion`: versión del contenido/configuración. Súbela cuando cambies o añadas contenido manteniendo el mismo esquema.
- `tasks`: mapa `taskId -> definición de tarea`.

## Estructura básica de una tarea

```json
"prepare_garden": {
  "activity": "prepare_garden",
  "location": "garden",
  "durationSeconds": 300,
  "storable": true,
  "survivorRequirements": {
    "min": 1,
    "max": 1
  },
  "requiredTaskIds": [],
  "cost": {
    "inventory": {}
  },
  "resultResolver": {
    "type": "fixed",
    "resultId": "success"
  },
  "results": {}
}
```

### Identidad y duración

- La clave del objeto (`prepare_garden`) es el ID único de la tarea.
- `activity`: actividad que se guarda en la ocupación del Survivor.
- `location`: zona donde sucede.
- `durationSeconds`: duración base de la tarea si participa un único Survivor.

La duración real se divide automáticamente entre el número de Survivors asignados:

```text
duracionReal = ceil(durationSeconds / numeroDeSurvivors)
```

Siempre se conserva un mínimo de 1 segundo.

Ejemplo para una tarea de `300` segundos:

- 1 Survivor -> 300 s.
- 2 Survivors -> 150 s.
- 3 Survivors -> 100 s.

La Cloud Function calcula esta duración de forma autoritativa al iniciar la tarea y todos los participantes reciben el mismo `endsAt`.

### `storable`

- `true`: al terminar, el ID se añade a `completedTaskIds` y la tarea deja de aparecer en la lista de tareas disponibles.
- `false`: no se registra como completada y puede repetirse.

Las tareas usadas en `requiredTaskIds` deben ser `storable: true`.

## Requisitos de Survivors

### Número de Survivors

```json
"survivorRequirements": {
  "min": 1,
  "max": 3
}
```

- `min`: mínimo de Survivors necesarios.
- `max`: máximo permitido.

Para una tarea que **solo puede realizar exactamente un Survivor**, la forma canónica es:

```json
"survivorRequirements": {
  "min": 1,
  "max": 1
}
```

No existe un segundo formato abreviado: mantener siempre `min` y `max` hace que el esquema sea único y evita casos especiales en backend y validadores.

### Requisitos de estadísticas

Una task puede restringir qué Survivors se pueden seleccionar según sus estadísticas:

```json
"survivorRequirements": {
  "min": 1,
  "max": 3,
  "statRequirements": {
    "care": {
      "greaterThan": 3
    }
  }
}
```

En este ejemplo **cada Survivor seleccionado** necesita `care > 3`.

- `greaterThan` es exclusivo: `3` no cumple `> 3`; `4` sí.
- Se pueden incluir varias estadísticas y el Survivor debe cumplirlas todas.
- El valor comprobado es la estadística efectiva: `baseStats del Duplicate + statMods del Survivor`.
- El selector de Flutter deshabilita los Survivors que no cumplen los requisitos, pero el backend vuelve a validarlos siempre y es la autoridad final.

Estadísticas admitidas:

- `strength`
- `dexterity`
- `constitution`
- `stealth`
- `care`
- `cunning`
- `charm`

Los valores de `greaterThan` pueden ir de `0` a `9`.

> Si se modifican las estadísticas base de los Duplicates, hay que mantener sincronizada la tabla autoritativa del backend en `functions/survivor_progression.js` con `lib/features/survivors/domain/duplicate_catalog.dart`.

### Prerrequisitos

```json
"requiredTaskIds": [
  "repair_garden_door",
  "restore_irrigation"
]
```

Todos esos IDs deben estar ya presentes en `completedTaskIds` para poder iniciar la tarea.

### Coste al iniciar

```json
"cost": {
  "inventory": {
    "scrap_metal": 2,
    "wood_plank": 1
  }
}
```

Las cantidades se descuentan una sola vez al comenzar la ejecución compartida, aunque participen varios Survivors.

Los recursos también se representan como objetos de inventario, por lo que se usan aquí igual que cualquier otro item.

## Resolución general: `resultResolver`

Determina primero **qué resultado general** obtiene la tarea. Ese resultado puede ser `success`, `failure` u otro ID definido por la tarea.

### Resultado fijo

```json
"resultResolver": {
  "type": "fixed",
  "resultId": "success"
}
```

Siempre produce ese resultado.

### Resultado aleatorio

```json
"resultResolver": {
  "type": "random",
  "probabilities": {
    "success": 0.8,
    "failure": 0.2
  }
}
```

Las probabilidades de los resultados generales deben sumar `1`.

### Resultado calculado por servidor

```json
"resultResolver": {
  "type": "server",
  "handler": "some_server_handler"
}
```

Reservado para lógica que calcule el resultado en backend.

### Resultado de combate

```json
"resultResolver": {
  "type": "combat",
  "handler": "some_combat_handler"
}
```

Reservado para resultados decididos por un sistema de combate.

`server` y `combat` están contemplados por el esquema, pero requieren que exista el handler correspondiente antes de usarlos en una tarea real.

## `results`

Cada resultado general tiene dos grupos de efectos:

```json
"results": {
  "success": {
    "guaranteedOutcomes": {},
    "randomOutcomes": {}
  },
  "failure": {
    "guaranteedOutcomes": {},
    "randomOutcomes": {}
  }
}
```

### Efectos garantizados

```json
"guaranteedOutcomes": {
  "energyDelta": -5,
  "inventoryDelta": {
    "scrap_metal": 2
  },
  "statExperienceDelta": {
    "care": 5,
    "strength": 1
  }
}
```

- `energyDelta`: se aplica a **cada Survivor participante**.
- `inventoryDelta`: se aplica **una sola vez a la ejecución**, no una vez por Survivor.
- `statExperienceDelta`: experiencia que recibe **cada Survivor participante** en las estadísticas indicadas.
- Un valor positivo añade; `inventoryDelta` también puede usar cantidades negativas cuando un outcome retire objetos.

`statExperienceDelta` es opcional. Sus cantidades deben ser enteros no negativos.

### Experiencia de estadísticas del Survivor

Cada Survivor guarda en servidor un mapa oculto `statExperience` con un medidor independiente para cada estadística.

Ejemplo interno:

```json
"statExperience": {
  "strength": 1,
  "dexterity": 0,
  "constitution": 0,
  "stealth": 0,
  "care": 5,
  "cunning": 0,
  "charm": 0
}
```

Reglas:

1. El usuario no ve este medidor en la interfaz.
2. Survivors antiguos que no tengan `statExperience` se normalizan automáticamente con `0` en todas las estadísticas.
3. Cuando una estadística acumula al menos `100` XP y su valor efectivo es menor que `10`, se consumen `100` XP y se incrementa `statMods` en `+1` para esa estadística.
4. Si queda experiencia sobrante, se conserva para el siguiente nivel.
5. Si una ganancia permite varios niveles y la estadística sigue por debajo de `10`, pueden aplicarse varios incrementos en la misma resolución.
6. Una estadística efectiva nunca sube por este sistema por encima de `10`.
7. Una vez alcanzado `10`, el medidor deja de producir niveles y se mantiene limitado a `100`.

### Outcomes aleatorios dentro del resultado

```json
"randomOutcomes": {
  "minor_accident": {
    "probability": 0.02,
    "effects": {
      "energyDelta": -4,
      "inventoryDelta": {}
    }
  },
  "extra_training": {
    "probability": 0.05,
    "effects": {
      "energyDelta": 0,
      "inventoryDelta": {},
      "statExperienceDelta": {
        "strength": 2
      }
    }
  }
}
```

- `probability` va de `0` a `1` (`0.02` = 2%).
- Cada random outcome se tira de forma **independiente**.
- Sus probabilidades **no tienen que sumar 1**.
- Pueden activarse varios random outcomes en una misma ejecución.
- Las tiradas son deterministas para el mismo `executionId`, de modo que un reintento del backend no vuelve a sortear resultados distintos.
- Los efectos de experiencia funcionan igual dentro de outcomes aleatorios que dentro de `guaranteedOutcomes`.

## Ejemplo: `upgrade_garden`

```json
"upgrade_garden": {
  "activity": "upgrade_garden",
  "location": "garden",
  "durationSeconds": 300,
  "storable": true,
  "survivorRequirements": {
    "min": 1,
    "max": 3,
    "statRequirements": {
      "care": {
        "greaterThan": 3
      }
    }
  },
  "requiredTaskIds": ["prepare_garden"],
  "cost": {
    "inventory": {}
  },
  "resultResolver": {
    "type": "fixed",
    "resultId": "success"
  },
  "results": {
    "success": {
      "guaranteedOutcomes": {
        "energyDelta": 5,
        "inventoryDelta": {},
        "statExperienceDelta": {
          "care": 5,
          "strength": 1
        }
      },
      "randomOutcomes": {}
    }
  }
}
```

Con esta configuración:

- Solo se pueden seleccionar Survivors con `care > 3`.
- Cada participante recibe `+5` XP de `care` y `+1` XP de `strength` al completar la tarea.
- Con 1/2/3 Survivors dura 300/150/100 segundos respectivamente.

## Añadir una nueva task

La lógica autoritativa y el balance pertenecen a `job_tasks.json`; Flutter solo mantiene el registro visual de las tasks que debe enseñar.

Al añadir una task nueva:

1. Añádela a `game_data/server/job_tasks.json` y aumenta `dataVersion`.
2. Registra su `id` y `JobArea` en `lib/features/jobs/domain/job_task.dart`.
3. Añade su título y descripción en `lib/features/jobs/presentation/job_labels.dart`.
4. Añade las traducciones correspondientes en `lib/l10n/app_es.arb` y `lib/l10n/app_en.arb`.

No hace falta tocar `job_area_screen.dart`, Functions ni los tests genéricos mientras la nueva task use estructuras ya soportadas por el esquema actual. Solo hace falta cambiar backend si introduces un nuevo tipo de resolver, efecto o campo con lógica nueva.

## Después de modificarlo

Consulta [`../README_WORKFLOW.md`](../README_WORKFLOW.md).
