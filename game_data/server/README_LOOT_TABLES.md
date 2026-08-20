# `loot_tables.json`

Configuración privada destinada a las tablas de loot del juego.

Archivo: `game_data/server/loot_tables.json`

Se sincroniza con `/serverData/lootTables` y no es accesible directamente desde la app.

## Estructura actual

```json
{
  "schemaVersion": 1,
  "dataVersion": 1,
  "lootTables": []
}
```

- `schemaVersion`: versión de la estructura del archivo.
- `dataVersion`: versión del contenido/configuración.
- `lootTables`: lista de tablas de loot.

## Estado actual

La colección `lootTables` existe como punto de configuración, pero **todavía no hay una estructura de entrada de loot implementada ni consumida por el backend**.

Por tanto, de momento el formato válido y seguro es:

```json
"lootTables": []
```

No añadas campos inventados dentro de `lootTables` esperando que tengan efecto en el juego: primero hay que implementar el modelo, su validador y la lógica de resolución correspondiente.

Cuando se implemente el sistema de loot, este README debe ampliarse con:

- ID de cada tabla.
- Entradas posibles.
- Pesos/probabilidades.
- Cantidades mínimas/máximas.
- Referencias a IDs de `items.json`.
- Reglas especiales, si existen.

## Privacidad

Las probabilidades y pesos de loot deben permanecer aquí, en datos privados de servidor, y no en `items.json` ni en datos directamente legibles por el cliente.

## Después de modificarlo

Consulta [`../README_WORKFLOW.md`](../README_WORKFLOW.md).
