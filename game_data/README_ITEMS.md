# `items.json`

Catálogo público de objetos del juego.

Archivo: `game_data/items.json`

Se sincroniza con Firestore en `/items/{itemId}` y puede ser leído por la app. No debe contener probabilidades, reglas ocultas ni datos que deban permanecer privados en el servidor.

## Estructura raíz

```json
{
  "schemaVersion": 2,
  "catalogVersion": 2,
  "items": []
}
```

- `schemaVersion`: versión de la estructura del JSON. Cámbiala cuando cambie el formato esperado por el código.
- `catalogVersion`: versión del contenido del catálogo. Se puede incrementar cuando cambian los datos de los objetos.
- `items`: lista de definiciones de objetos.

## Estructura de un objeto

```json
{
  "id": "scrap_metal",
  "type": ["resource"],
  "subtype": ["metal"],
  "value": 2,
  "stackable": true,
  "name": {
    "en": "Scrap metal",
    "es": "Chatarra"
  },
  "description": {
    "en": "Recovered metal pieces useful for repairs and crafting.",
    "es": "Piezas de metal recuperadas, útiles para reparaciones y fabricación."
  },
  "stats": {
    "craftingValue": 1
  }
}
```

### Campos

- `id`: identificador único y estable. Es el ID usado en inventarios, costes, recompensas y referencias desde otros sistemas.
- `type`: lista de categorías principales. Un objeto puede pertenecer a varias, por ejemplo `weapon` y `resource`.
- `subtype`: lista de categorías más concretas, por ejemplo `melee`, `metal`, `food`, etc.
- `value`: valor base del objeto.
- `stackable`: indica si varias unidades pueden compartir una pila de inventario.
- `name`: nombre localizado por idioma.
- `description`: descripción localizada por idioma.
- `stats`: estadísticas propias del objeto. Su contenido depende del tipo de objeto y de los sistemas que lo consuman.

## Recursos

Los recursos no usan un inventario separado. Son objetos normales cuyo `type` incluye `resource`.

Por eso una tarea puede gastar o entregar recursos usando sus IDs dentro de `inventoryDelta` o `cost.inventory`.

## Arte opcional

La definición del objeto no incluye la imagen. La app puede usar arte local siguiendo la convención:

```text
assets/items/item_[ID].png
```

Ejemplo:

```text
assets/items/item_scrap_metal.png
```

## Después de modificarlo

Consulta [`README_WORKFLOW.md`](README_WORKFLOW.md).
