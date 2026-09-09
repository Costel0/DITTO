# `expeditions.json`

Configuración autoritativa compartida de expediciones.

Archivo: `game_data/server/expeditions.json`

Se sincroniza con Firestore en `/serverData/expeditions`.

## Coordenadas del bunker

La posición del bunker es específica de cada jugador y no vive en este JSON:

```text
/users/{uid}/state/bunker.bunkerCoordinates
```

Hasta que exista el asignador real de posiciones, el backend inicializa/normaliza temporalmente todos los bunkers en:

```json
{"x": 0, "y": 0, "z": 0}
```

El launcher siempre recibe las coordenadas desde backend y el backend vuelve a validarlas al iniciar la expedición.

## Tipo, acción, outcome y opción de resolución

Son cuatro conceptos distintos:

```text
expeditionType
  └─ action
      └─ outcome (lo decide el backend al terminar)
          └─ resolutionOptions (las elige el usuario después)
```

Ejemplo:

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
          "probability": 1.0,
          "narrativeId": "scavenge_example_reward",
          "imageKey": "optional_special_image",
          "resolutionOptions": {
            "accept": {
              "labelId": "accept",
              "inventoryDelta": {
                "scrap_metal": 1
              }
            }
          }
        }
      }
    }
  }
}
```

### Action

- `expeditionType`: tipo visual/lógico. Actualmente `scavenge`.
- `availability: "bunker"`: solo disponible si el destino coincide con las coordenadas reales del bunker.
- `durationSeconds`: duración.
- `energyDelta`: efecto automático e inevitable aplicado a cada Survivor al terminar.
- `outcomes`: resultados posibles decididos exclusivamente por backend.

Las probabilidades de los outcomes de una acción deben sumar exactamente `1`.

### Outcome

- `probability`: probabilidad.
- `narrativeId`: texto narrativo que verá el jugador al abrir el informe.
- `imageKey`: opcional; permite una imagen especial.
- `resolutionOptions`: decisiones disponibles para la **segunda resolución**, la interactiva.

El outcome se decide y queda congelado al terminar la expedición. Abrir/cerrar el popup no vuelve a tirar el outcome.

### Resolution option

- ID del objeto (`accept`, `leave`, etc.): ID autoritativo enviado de vuelta al backend.
- `labelId`: identificador de texto para Flutter.
- `inventoryDelta`: recompensa/coste que solo se aplica si el usuario escoge esa opción.
- `eventTrigger.poolId`: hook reservado para eventos. Actualmente se devuelve al resolver, pero todavía no ejecuta lógica de eventos.

Todos los IDs de recompensa se validan contra `game_data/items.json` durante `sync:server-data:check`.

## Las dos resoluciones

### 1. Resolución automática

Ocurre cuando `endsAt` se alcanza y se ejecuta el mismo flujo de resolución de ocupaciones que usa trabajos/sueño.

Hace:

1. decide el outcome mediante backend;
2. devuelve a los Survivors de la expedición;
3. aplica energía;
4. en el futuro aplicará aquí heridas, muertes u otros efectos inevitables;
5. elimina la expedición de `busySurvivors`;
6. crea un resumen opaco en `pendingExpeditionReviews`;
7. guarda el informe completo en:
   `/users/{uid}/expeditionReviews/{reviewId}`.

El informe privado guarda explícitamente:

```text
automaticResolution.status = resolved
interactiveResolution.status = pending
```

La recompensa dependiente de la elección **no** se aplica en esta fase.

### 2. Resolución interactiva

La card aparece como expedición finalizada pendiente de decisión.

Al pulsarla:

1. Flutter llama `getExpeditionReview`;
2. el backend devuelve el informe de forma **solo lectura**;
3. se abre el popup;
4. cerrar por X o "Cerrar y decidir más tarde" no modifica absolutamente nada;
5. la card sigue en la lista y el popup puede abrirse otra vez;
6. el jugador selecciona una opción por outcome;
7. Flutter llama `resolveExpeditionReview` con esas elecciones;
8. el backend valida las opciones contra el informe congelado;
9. aplica los efectos de las opciones seleccionadas;
10. elimina `pendingExpeditionReviews` y el documento privado;
11. la expedición desaparece definitivamente de la lista.

Actualmente todos los outcomes de `scout_surroundings` tienen una única opción `accept`, por lo que el popup termina en un botón **Aceptar**. El mismo modelo admite varias opciones futuras sin cambiar el ciclo de vida.

## Seguridad del informe

El documento visible `BunkerState` contiene solo un resumen opaco. Outcome, narración y opciones viven en:

```text
/users/{uid}/expeditionReviews/{reviewId}
```

Las reglas de Firestore bloquean lectura/escritura del cliente sobre esa subcolección. Solo Cloud Functions accede mediante Admin SDK.

## Imágenes

La imagen general por tipo sigue siendo:

```text
assets/expeditions/results/scavenge.png
```

Cada outcome puede definir `imageKey`. Flutter intenta primero:

```text
assets/expeditions/results/<expeditionType>_<imageKey>.png
```

Para los outcomes actuales de `scout_surroundings`:

```text
nothing          -> assets/expeditions/results/scavenge_nothing_found.png
scrap_and_trash  -> assets/expeditions/results/scavenge_scrap_and_trash.png
scrap_metal_2    -> assets/expeditions/results/scavenge_scrap_metal.png
wood_plank       -> assets/expeditions/results/scavenge_wood_plank.png
small_dead_animal -> assets/expeditions/results/scavenge_small_dead_animal.png
common_event     -> assets/expeditions/results/scavenge_common_event.png
```

Fallback:

```text
imagen específica
        ↓ si falta
assets/expeditions/results/scavenge.png
        ↓ si falta
ilustración fallback de Flutter
```

Por tanto, una imagen específica ausente nunca rompe el popup.

## Compatibilidad

Durante el desarrollo existieron representaciones breves anteriores:
- `expedition:scavenge` como ID de acción;
- rewards directamente en el outcome;
- un flujo que consumía el informe al abrirlo.

El backend mantiene compatibilidad defensiva con esos datos, evitando volver a entregar recompensas si no puede demostrar que seguían pendientes.

## Después de modificarlo

Consulta `game_data/README_WORKFLOW.md`.

Para cambios de expediciones usa:

```powershell
.\hard_deploy.cmd -ValidateOnly
```

y después:

```powershell
.\hard_deploy.cmd
```

porque intervienen Functions, serverData y, según el cambio, reglas/Flutter.
