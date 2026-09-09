# `expeditions.json`

Configuración autoritativa compartida de **tipos/acciones de expedición**.

Archivo: `game_data/server/expeditions.json`

Se sincroniza con Firestore en `/serverData/expeditions`.

## Importante: las coordenadas no viven aquí

La posición del bunker es específica de cada jugador y se guarda en su estado autoritativo:

```text
/users/{uid}/state/bunker.bunkerCoordinates
```

Actualmente, hasta que implementemos la asignación real de posiciones, el backend normaliza cualquier bunker que todavía no tenga coordenadas a:

```json
{"x": 0, "y": 0, "z": 0}
```

El launcher pide las coordenadas al backend. Flutter no decide ni inventa la posición del bunker.

Cuando más adelante se implemente la asignación de coordenadas, bastará con inicializar/actualizar `bunkerCoordinates` para cada usuario; el sistema de expediciones ya compara el destino contra la posición real de ese bunker.

## Estructura compartida

```json
{
  "schemaVersion": 1,
  "dataVersion": 2,
  "actions": {
    "scavenge": {
      "availability": "bunker",
      "durationSeconds": 60,
      "energyDelta": -20
    }
  }
}
```

- `actions`: tipos/acciones que puede ofrecer el lanzador.
- `availability: "bunker"`: la acción solo aparece si el destino elegido coincide exactamente con `bunkerCoordinates` del jugador.
- `durationSeconds`: duración.
- `energyDelta`: cambio de energía aplicado a cada Survivor al resolver la expedición. Un valor negativo consume energía.

El tipo inicial es `scavenge`. La UI de expediciones activas puede tener una card específica por tipo; actualmente solo existe la card de `scavenge`.

Si en el futuro una expedición selecciona varias acciones, la duración y el cambio de energía se acumulan.

## Flujo

1. Flutter solicita el launcher al backend.
2. El backend carga `/users/{uid}/state/bunker` y devuelve sus `bunkerCoordinates`.
3. El popup usa esas coordenadas como destino inicial.
4. Flutter solo muestra `scavenge` cuando el destino coincide con el bunker.
5. Al lanzar, el backend vuelve a leer el bunker y vuelve a comparar el destino contra sus coordenadas actuales.
6. Los Survivors pasan a `busySurvivors` con `activity: "expedition"`.
7. Al llegar `endsAt`, el resolver aplica los efectos y devuelve los Survivors al bunker.

La validación real está en backend: aunque un cliente manipulado intente lanzar una acción no disponible en unas coordenadas, la Cloud Function la rechaza.

## Compatibilidad

El antiguo ID `scout_surroundings` se normaliza internamente a `scavenge` para que una expedición que estuviera activa durante la migración pueda terminar correctamente.

## Después de modificarlo

Ejecuta el flujo descrito en `game_data/README_WORKFLOW.md`. Se recomienda `hard_deploy.cmd`, ya que hay que sincronizar `serverData` y desplegar Functions cuando cambie la lógica asociada.
