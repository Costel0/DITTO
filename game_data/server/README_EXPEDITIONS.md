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

## Tipos, acciones y outcomes

`expeditionType`, la acción y el outcome son conceptos distintos.

Ejemplo simplificado:

```json
{
  "actions": {
    "scout_surroundings": {
      "expeditionType": "scavenge",
      "availability": "bunker",
      "durationSeconds": 60,
      "energyDelta": -20,
      "outcomes": {
        "example_reward": {
          "probability": 0.25,
          "narrativeId": "scavenge_example_reward",
          "inventoryDelta": {
            "scrap_metal": 1
          },
          "imageKey": "optional_special_image"
        }
      }
    }
  }
}
```

### Campos de acción

- `expeditionType`: tipo visual/lógico de la expedición. Actualmente `scavenge`.
- `availability: "bunker"`: la acción solo está disponible si el destino coincide con `bunkerCoordinates` del jugador.
- `durationSeconds`: duración de la acción.
- `energyDelta`: cambio de energía aplicado a cada Survivor al resolverla. Un valor negativo consume energía.
- `outcomes`: resultados posibles decididos exclusivamente por backend.

Las probabilidades de todos los outcomes de una acción deben sumar exactamente `1`.

### Campos de outcome

- `probability`: probabilidad entre `0` y `1`.
- `narrativeId`: identificador de la narración que presenta Flutter.
- `inventoryDelta`: recompensa de objetos. El backend la mantiene privada y la entrega al revisar el informe.
- `imageKey`: opcional. Permite una imagen especial para un outcome concreto.
- `eventTrigger.poolId`: hook reservado para el futuro sistema de eventos. Actualmente se registra en el informe, pero no ejecuta ninguna lógica adicional.

El pool inicial para eventos comunes se identifica como `evento_comun`.

## Resolución e informes pendientes

1. Al llegar `endsAt`, la Cloud Function selecciona el outcome usando una tirada determinista derivada del `executionId`.
2. Se aplica el coste de energía y la expedición desaparece de `busySurvivors`.
3. En `BunkerState.pendingExpeditionReviews` se guarda **solo un resumen opaco**: tipo, acciones, participantes, coordenadas y fecha. No contiene outcome ni recompensa.
4. El informe completo se guarda en `/users/{uid}/expeditionReviews/{reviewId}`. Las reglas de Firestore niegan todo acceso cliente a esa subcolección.
5. Flutter muestra la expedición como **resuelta / pendiente de revisar** sin conocer el resultado.
6. Al pulsarla, Flutter llama `reviewExpeditionResult`.
7. La callable entrega la recompensa, elimina el resumen pendiente y consume el informe privado en una única transacción.
8. Flutter recibe el informe y abre el popup con narración, recompensa e imagen.
9. El informe ya no puede volver a cobrarse ni aparece otra vez en la lista.

## Imágenes de resultado

La UI intenta primero una imagen específica del outcome y después la general del tipo:

```text
assets/expeditions/results/scavenge_<imageKey>.png
assets/expeditions/results/scavenge.png
```

Para el outcome de comida actual:

```text
assets/expeditions/results/scavenge_dead_bird.png
```

Si la imagen especial no existe, cae a `scavenge.png`. Si tampoco existe la general, Flutter muestra una ilustración fallback para que el popup siga funcionando.

## Compatibilidad

Durante el desarrollo existió brevemente `expedition:scavenge` como si `scavenge` fuera la acción. El backend lo normaliza a `scout_surroundings` para que esas ocupaciones puedan resolverse si existieran.

## Después de modificarlo

Ejecuta el flujo descrito en `game_data/README_WORKFLOW.md`. Se recomienda `hard_deploy.cmd` cuando cambie este archivo o su lógica, porque hay que sincronizar `serverData` y Functions.

