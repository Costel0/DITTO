# `job_tasks.json`

Catálogo privado y autoritativo de tareas del juego.

Archivo: `game_data/server/job_tasks.json`

Se sincroniza con `/serverData/jobTasks`. La app no puede leer este documento directamente; las Cloud Functions exponen únicamente la información necesaria para jugar.

## Estructura raíz

```json
{
  "schemaVersion": 3,
  "dataVersion": 4,
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
- `durationSeconds`: duración total en segundos.

### `storable`

- `true`: al terminar, el ID se añade a `completedTaskIds` y la tarea deja de aparecer en la lista de tareas disponibles.
- `false`: no se registra como completada y puede repetirse.

Las tareas usadas en `requiredTaskIds` deben ser `storable: true`.

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
  }
}
```

- `energyDelta`: se aplica a **cada Survivor participante**.
- `inventoryDelta`: se aplica **una sola vez a la ejecución**, no una vez por Survivor.
- Un valor positivo añade; uno negativo resta.

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
  "extra_scrap": {
    "probability": 0.05,
    "effects": {
      "energyDelta": 0,
      "inventoryDelta": {
        "scrap_metal": 1
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

## Ejemplo completo

```json
"explore_storage": {
  "activity": "explore_storage",
  "location": "storage",
  "durationSeconds": 600,
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
    "type": "random",
    "probabilities": {
      "success": 0.9,
      "failure": 0.1
    }
  },
  "results": {
    "success": {
      "guaranteedOutcomes": {
        "energyDelta": -5,
        "inventoryDelta": {
          "scrap_metal": 2
        }
      },
      "randomOutcomes": {
        "minor_accident": {
          "probability": 0.02,
          "effects": {
            "energyDelta": -4,
            "inventoryDelta": {}
          }
        }
      }
    },
    "failure": {
      "guaranteedOutcomes": {
        "energyDelta": -3,
        "inventoryDelta": {}
      },
      "randomOutcomes": {}
    }
  }
}
```

## Añadir una nueva task

La lógica autoritativa y el balance pertenecen a `job_tasks.json`; Flutter solo mantiene el registro visual de las tasks que debe enseñar.

Al añadir una task nueva:

1. Añádela a `game_data/server/job_tasks.json` y aumenta `dataVersion`.
2. Registra su `id` y `JobArea` en `lib/features/jobs/domain/job_task.dart`.
3. Añade su título y descripción en `lib/features/jobs/presentation/job_labels.dart`.
4. Añade las traducciones correspondientes en `lib/l10n/app_es.arb` y `lib/l10n/app_en.arb`.

No hace falta tocar `job_area_screen.dart`, `hub_jobs.dart`, Functions ni los tests genéricos mientras la nueva task use estructuras ya soportadas por el esquema actual. Solo hace falta cambiar backend si introduces un nuevo tipo de resolver, efecto o campo con lógica nueva.

## Después de modificarlo

Consulta [`../README_WORKFLOW.md`](../README_WORKFLOW.md).
