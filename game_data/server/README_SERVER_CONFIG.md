# `server_config.json`

Configuración privada global del backend.

Archivo: `game_data/server/server_config.json`

Se sincroniza con `/serverData/serverConfig` y contiene parámetros de balance o comportamiento que no necesitan estar codificados directamente en las Cloud Functions.

## Estructura actual

```json
{
  "schemaVersion": 1,
  "dataVersion": 5,
  "config": {
    "sleepingSecondsPerNegativeEnergy": 60,
    "expeditionTravelSecondsPerDistanceUnit": 300
  }
}
```

- `schemaVersion`: versión de la estructura del archivo.
- `dataVersion`: versión del contenido/configuración.
- `config`: mapa de parámetros globales del servidor.

## `sleepingSecondsPerNegativeEnergy`

Controla cuánto dura el `sleeping` automático de un Survivor cuya energía haya quedado por debajo de `0`.

```json
"sleepingSecondsPerNegativeEnergy": 60
```

La duración se calcula aproximadamente como:

```text
segundos de sleeping = abs(energía negativa) × sleepingSecondsPerNegativeEnergy
```

Ejemplo con valor `60`:

```text
energía = -8
sleeping = 8 × 60 = 480 segundos
```

Cuando esa ocupación de `sleeping` se resuelve, la energía del Survivor pasa a `100`.

## `expeditionTravelSecondsPerDistanceUnit`

Controla el tiempo de desplazamiento de expediciones por cada unidad de distancia y **por trayecto**.

```json
"expeditionTravelSecondsPerDistanceUnit": 300
```

`300` equivale a 5 minutos por unidad de distancia. Como una expedición sale del bunker y vuelve al bunker, el tiempo total de viaje es:

```text
segundos de viaje = ceil(
  distancia(bunker, destino)
  × expeditionTravelSecondsPerDistanceUnit
  × 2
)
```

El `× 2` representa ida y vuelta y pertenece a la lógica de expediciones, no al valor de configuración. Por tanto, el parámetro debe seguir expresando el coste de **un solo trayecto**.

Ejemplos con `300`:

```text
distancia 1.0  -> 10 min de viaje total
distancia 0.1  -> 1 min de viaje total
distancia √2   -> ceil(√2 × 300 × 2) = 849 s
```

A ese viaje se suma después la duración base de las acciones de la expedición. `Explore`, por ejemplo, añade actualmente 60 segundos.

## Añadir nuevos parámetros

Los nuevos valores globales de balance que solo necesite el backend pueden añadirse dentro de `config`, pero no basta con escribir una clave nueva: el código que la consume y, cuando corresponda, el validador deben conocerla.

Usa nombres explícitos y con unidad cuando sea posible, por ejemplo:

```text
...Seconds
...Minutes
...Percent
...Multiplier
```

Esto evita ambigüedades al modificar balance más adelante.

## Versionado

- Incrementa `dataVersion` cuando cambies valores/configuración de juego.
- Incrementa `schemaVersion` únicamente si cambia la estructura que espera el código.

## Después de modificarlo

Consulta [`../README_WORKFLOW.md`](../README_WORKFLOW.md).
