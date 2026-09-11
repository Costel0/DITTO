# DITTO — Rendimiento y escalabilidad del mapa

La asignación de un `PLAYER_BUNKER` no debe depender del tamaño histórico del mundo ni del número total de jugadores.

## Asignación individual

El índice de spawn usa `worldMapSpawnChunks` con bloques de 5 columnas.

Con la configuración actual:

```text
D-W = 20 filas
ventana inicial 10-40 = 7 chunks
ventanas posteriores de 40 columnas = 8 chunks
```

Una asignación real normal hace aproximadamente:

```text
1 read de meta
7-8 reads de chunks activos

transacción:
  1 read de meta
  1 read del sector elegido
  1-3 reads de chunks afectados

writes:
  1 sector PLAYER_BUNKER
  1-3 chunks modificados
```

Por tanto, normalmente hablamos de unas **11-14 lecturas** y **2-4 escrituras** de Firestore por alta real, más la invocación de Cloud Functions cuando se conecte al onboarding.

No se leen otros jugadores ni todos los sectores de la ventana.

La ruleta se realiza en dos niveles —chunk y candidato— usando las mismas prioridades, por lo que la distribución probabilística es equivalente a una ruleta global.

## Concurrencia

La existencia de un candidato dentro de un chunk es parte de la validación autoritativa de spawn.

Dos altas que intenten crear bunkers a `d <= 2` necesariamente afectan al menos un mismo chunk. Las transacciones de Firestore entran en conflicto y una de ellas debe reintentarse con el estado actualizado.

La expansión usa `expansionStatus` para impedir la carrera entre crear nuevas celdas en el borde y asignar simultáneamente un bunker cercano.

## `add-players --count=X`

Sigue siendo `O(X)` porque cada jugador se confirma en su propia transacción.

Durante el mismo proceso se reutilizan en memoria los chunks de la ventana activa, de modo que los 7-8 chunks no se vuelven a descargar para cada jugador simulado salvo que haya un conflicto o cambie la ventana.

## Operaciones que sí crecen con el mapa

- `init`: proporcional al número de sectores materializados.
- `expand`: proporcional únicamente a las nuevas columnas añadidas.
- `download`: proporcional al total de sectores, porque descarga el mapa completo.
- `render`: proporcional al total de sectores descargados, pero es local.

Resolver o descubrir un único sector sigue siendo `O(1)` respecto al tamaño global.

## Escalabilidad

Mientras se mantenga aproximadamente el tamaño actual de ventana y chunk:

- 1.000 jugadores históricos no hacen más cara una nueva asignación;
- 100.000 jugadores históricos tampoco;
- que el mapa llegue a columnas numéricas muy altas tampoco incrementa el coste normal de spawn.

Lo que sí puede aumentar la latencia son los reintentos de transacción si muchas altas concurrentes compiten por los mismos chunks. Con 7-8 chunks activos la contención está distribuida y es muy inferior a guardar todo el pool en un único documento.
