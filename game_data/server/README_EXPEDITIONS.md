# `expeditions.json`

Configuración autoritativa compartida de expediciones.

Archivo: `game_data/server/expeditions.json`

Se sincroniza con Firestore en `/serverData/expeditions`.

## Coordenadas

Las expediciones usan las coordenadas sector-zona del mapa:

```text
M25-1
N26-4
```

La distancia se calcula con la utilidad canónica del mapa:

```text
misma localización                  -> 0
zonas distintas del mismo sector   -> 0.1
sectores distintos                  -> distancia euclídea entre sectores
```

El índice de zona no afecta a la distancia entre sectores.

La posición del bunker del jugador se obtiene de:

```text
/users/{uid}/state/bunker.bunkerCoordinates
```

El cliente puede usar su copia local para presentar información, pero el backend vuelve a validar coordenadas, conocimiento y acciones al iniciar una expedición.

## Tiempo de viaje

`server_config.json` define:

```json
"expeditionTravelSecondsPerDistanceUnit": 300
```

Ese valor representa segundos por unidad de distancia **por trayecto**. Cada expedición incluye ida y vuelta:

```text
travelSeconds = ceil(
  distance(bunker, target)
  × expeditionTravelSecondsPerDistanceUnit
  × 2
)
```

Con `300`, cada trayecto tarda 5 minutos por unidad de distancia.

La duración total es:

```text
duration = travelSeconds + suma(durationSeconds de las acciones)
```

Para `Explore`, cuya duración base es 60 segundos:

```text
distancia 1.0 -> 60 s + 600 s = 11 min
distancia 0.1 -> 60 s + 60 s  = 2 min
```

## Conocimiento del jugador

El mundo autoritativo y lo que conoce cada jugador son conceptos distintos.

Firestore persiste el conocimiento individual dentro de `BunkerState.knownZones`. El jugador conoce únicamente las zonas descubiertas y su `zoneType`; no necesita conocer el tipo principal del sector.

Ejemplo conceptual:

```text
M25-1 -> PLAYER_BUNKER
M25-2 -> EMPTY
N26-4 -> EMPTY_FIELD
```

El bunker propio está siempre descubierto como `PLAYER_BUNKER`.

En Flutter, `BunkerState` actúa como snapshot local. Al seleccionar coordenadas, la UI consulta ese estado local para decidir qué acciones mostrar sin hacer una lectura de Firestore por cada cambio de coordenadas.

## Zonas desconocidas y `Explore`

Una zona que no está en `knownZones` se considera desconocida para ese jugador.

En una zona desconocida solo pueden aparecer acciones cuya disponibilidad sea:

```json
{
  "unknownZone": true
}
```

Actualmente la acción especial es:

```json
"explore": {
  "expeditionType": "exploration",
  "availability": {
    "unknownZone": true
  },
  "completion": "discover_zone",
  "durationSeconds": 60,
  "energyDelta": 0
}
```

`Explore` debe lanzarse sola y el servidor rechaza intentos de combinarla con otras acciones.

Al completarse, el resolver de ocupaciones debe descubrir obligatoriamente la zona. La actualización del mundo y de `knownZones` se realiza de forma autoritativa en servidor.

## Generación temporal al explorar

Mientras no exista el generador aleatorio definitivo:

- si el sector objetivo sigue `UNGENERATED`, se resuelve completo como `ARID_PLAINS`;
- sus zonas se generan como `EMPTY_FIELD`;
- solo la zona concreta explorada se añade a `knownZones` del jugador;
- si el sector ya estaba `POPULATED`, nunca se rerollean ni sobrescriben sus zonas: se revela el tipo real ya persistido.

Los nuevos sectores `PLAYER_BUNKER` creados desde esta versión usan:

```text
zona 1 -> PLAYER_BUNKER
resto  -> EMPTY_FIELD
```

Sectores de jugador creados anteriormente pueden conservar zonas legacy `EMPTY`. No se migran ni se cambian automáticamente. `EMPTY` es un tipo conocido válido, pero no debe incluirse en la disponibilidad de ninguna misión; por tanto una zona `EMPTY` descubierta no ofrece acciones.

`EMPTY_FIELD` es el tipo canónico para nuevas zonas vacías y podrá recibir acciones específicas en `expeditions.json` cuando se diseñen.

## Acciones para zonas conocidas

Una acción normal declara los tipos de zona conocidos en los que es válida:

```json
"availability": {
  "zoneTypes": [
    "PLAYER_BUNKER"
  ]
}
```

El cliente filtra las opciones con el `zoneType` conocido localmente. Al iniciar la misión, el backend vuelve a comprobar:

1. que la zona figura realmente en `knownZones` del usuario, salvo que sea una exploración;
2. que el tipo guardado en `knownZones` coincide con el tipo de zona del mundo autoritativo;
3. que cada acción solicitada está permitida para ese tipo de zona;
4. que los Survivors y el resto de requisitos siguen siendo válidos.

Modificar el cliente o su caché local no permite saltarse estas reglas.

## Tipo, acción, outcome y opción de resolución

Para acciones interactivas normales siguen existiendo cuatro conceptos:

```text
expeditionType
  └─ action
      └─ outcome
          └─ resolutionOptions
```

Ejemplo simplificado:

```json
{
  "scout_surroundings": {
    "expeditionType": "scavenge",
    "availability": {
      "zoneTypes": ["PLAYER_BUNKER"]
    },
    "completion": "interactive_outcome",
    "durationSeconds": 60,
    "energyDelta": -20,
    "outcomes": {
      "nothing": {
        "probability": 1.0,
        "narrativeId": "scavenge_nothing",
        "resolutionOptions": {
          "continue": {
            "labelId": "continue",
            "inventoryDelta": {}
          }
        }
      }
    }
  }
}
```

Las probabilidades de los outcomes de una acción interactiva deben sumar `1`.

`completion: "discover_zone"` es especial y no necesita outcomes interactivos.

## Resolución de expediciones interactivas

Las expediciones con `completion: "interactive_outcome"` mantienen dos fases:

1. al llegar `endsAt`, el backend resuelve efectos inevitables y congela el outcome;
2. el informe completo queda privado en `/users/{uid}/expeditionReviews/{reviewId}`;
3. el cliente puede abrirlo sin consumirlo;
4. al elegir una `resolutionOption`, el backend valida la opción y aplica la recompensa/efecto asociado.

Las reglas de Firestore impiden que el cliente lea o modifique directamente los informes privados.

## Validación y sincronización

Los comandos públicos siguen siendo:

```powershell
cd functions
npm run sync:server-data:check
npm run sync:server-data:exact
```

Ambos usan `scripts/sync_server_data_v2.js`, que valida `expeditions.json` mediante los mismos parsers que utiliza el runtime del servidor.

Para cambios que afectan también a Functions o Flutter, usa:

```powershell
.\hard_deploy.cmd -ValidateOnly
```

y, si todo pasa:

```powershell
.\hard_deploy.cmd
```

Consulta también `game_data/README_WORKFLOW.md`.
