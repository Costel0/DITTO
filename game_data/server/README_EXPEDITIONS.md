# `expeditions.json`

Configuración autoritativa compartida de expediciones.

Archivo: `game_data/server/expeditions.json`

Se sincroniza con Firestore en `/serverData/expeditions`.

## Coordenadas del bunker

La posición del bunker es específica de cada jugador y **no** vive en este JSON. Se guarda en:

```text
/users/{uid}/state/bunker.bunkerCoordinates
```

Actualmente no existe todavía el asignador real de posiciones. Al crear o normalizar un bunker, el backend usa temporalmente:

```json
{"x": 0, "y": 0, "z": 0}
```

El launcher pide siempre la posición al backend. Cuando se implemente el asignador de coordenadas, solo habrá que sustituir esa asignación temporal al crear el bunker; la disponibilidad y validación de expediciones ya usa el campo individual del jugador.

## Tipos y acciones

`expeditionType` y la acción son conceptos distintos.

La configuración actual es:

```json
{
  "schemaVersion": 1,
  "dataVersion": 3,
  "actions": {
    "scout_surroundings": {
      "expeditionType": "scavenge",
      "availability": "bunker",
      "durationSeconds": 60,
      "energyDelta": -20
    }
  }
}
```

Actualmente existe un solo tipo:

```text
scavenge
```

y dentro de él una sola acción:

```text
scout_surroundings
```

Esta separación permite que más adelante un tipo de expedición tenga varias acciones y, a la vez, que la lista de expediciones activas use una presentación específica para cada `expeditionType`.

### Campos

- `expeditionType`: tipo visual/lógico de la expedición. Actualmente `scavenge`.
- `availability: "bunker"`: la acción solo está disponible si el destino coincide con `bunkerCoordinates` del jugador.
- `durationSeconds`: duración de la acción.
- `energyDelta`: cambio de energía aplicado a cada Survivor al resolverla. Un valor negativo consume energía.

Si se seleccionan varias acciones, todas deben pertenecer al mismo `expeditionType`. La duración y el cambio de energía se acumulan.

## Flujo actual

1. Flutter solicita el launcher al backend.
2. El backend lee `/users/{uid}/state/bunker.bunkerCoordinates`.
3. Esas coordenadas llegan al popup y son el destino inicial.
4. Si el jugador cambia el destino, Flutter oculta las acciones que no son válidas allí.
5. Al lanzar, el backend vuelve a leer las coordenadas reales del bunker y repite la validación.
6. Cada ocupación guarda tanto las acciones como `expeditionType`.
7. La UI de expediciones activas escoge una card específica según `expeditionType`.
8. Al llegar `endsAt`, el resolver aplica los efectos y devuelve los Survivors.

## Compatibilidad

Durante el desarrollo existió brevemente `expedition:scavenge` como si `scavenge` fuera la acción. El backend lo normaliza a `scout_surroundings` para que esas ocupaciones puedan resolverse si existieran.

Las expediciones anteriores sin `expeditionType` también se reconocen mediante su `taskId`.

## Después de modificarlo

Ejecuta el flujo descrito en `game_data/README_WORKFLOW.md`. Se recomienda `hard_deploy.cmd` cuando cambie este archivo o su lógica, porque hay que sincronizar `serverData` y Functions.
