# `expeditions.json`

Configuración autoritativa de expediciones.

Archivo: `game_data/server/expeditions.json`

Se sincroniza con Firestore en `/serverData/expeditions`.

## Estructura

```json
{
  "schemaVersion": 1,
  "dataVersion": 1,
  "bunkerCoordinates": {
    "x": 0,
    "y": 0,
    "z": 0
  },
  "actions": {
    "scout_surroundings": {
      "availability": "bunker",
      "durationSeconds": 60,
      "energyDelta": -20
    }
  }
}
```

- `bunkerCoordinates`: posición actual del bunker. Cada eje admite valores enteros de 0 a 999.
- `actions`: acciones que puede ofrecer el lanzador.
- `availability: "bunker"`: la acción solo aparece si las coordenadas elegidas coinciden exactamente con las del bunker.
- `durationSeconds`: duración de esa acción.
- `energyDelta`: cambio de energía aplicado a cada Survivor al resolver la expedición. Un valor negativo consume energía.

Si en el futuro una expedición selecciona varias acciones, la duración y el cambio de energía se acumulan.

## Flujo actual

1. Flutter solicita la configuración mediante la Cloud Function.
2. El popup parte de las coordenadas del bunker.
3. Si las coordenadas no coinciden con el bunker, la lista de acciones queda vacía.
4. Al lanzar, el backend vuelve a validar Survivors, coordenadas y acciones.
5. Los Survivors pasan a `busySurvivors` con `activity: "expedition"`.
6. Al llegar `endsAt`, el resolver aplica los efectos y devuelve los Survivors al bunker.

## Después de modificarlo

Ejecuta el flujo descrito en `game_data/README_WORKFLOW.md`. Para cambios de esta configuración se recomienda `hard_deploy.cmd`, porque debe sincronizarse `serverData`.
