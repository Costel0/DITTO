# `server_config.json`

Configuración privada global del backend.

Archivo: `game_data/server/server_config.json`

Se sincroniza con `/serverData/serverConfig` y contiene parámetros de balance o comportamiento que no necesitan estar codificados directamente en las Cloud Functions.

## Estructura actual

```json
{
  "schemaVersion": 1,
  "dataVersion": 4,
  "config": {
    "sleepingSecondsPerNegativeEnergy": 60
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
