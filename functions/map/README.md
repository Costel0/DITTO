# DITTO map backend

El mapa autoritativo sigue almacenándose por sector en Firestore. El índice de spawn está separado y optimizado para que asignar un bunker no requiera leer cientos de documentos.

## Colecciones

- `worldMap/meta`: configuración y estado global.
- `worldMapSectors/{sectorId}`: verdad persistente del mundo, un documento por sector.
- `worldMapSpawnChunks/{chunkId}`: índice auxiliar de candidatos de spawn agrupados por bloques numéricos.

La colección antigua `worldMapSpawnCandidates` queda obsoleta con `schemaVersion = 2` y se elimina al ejecutar `init --force`.

## Chunks de spawn

Con `spawnChunkWidth = 5`, la ventana inicial `10-40` se divide en 7 chunks y las ventanas posteriores de 40 columnas en 8 chunks.

Cada chunk contiene un mapa de candidato a prioridad:

```text
candidates = {
  D41: priority,
  E41: priority,
  ...
}
```

Una asignación individual:

1. lee los 7-8 chunks de la ventana activa;
2. elige un chunk ponderadamente por la suma de sus candidatos;
3. elige un candidato dentro de ese chunk por su prioridad;
4. en transacción relee `meta`, el sector elegido y solo los 1-3 chunks afectados por `d <= 2`;
5. convierte el sector en `PLAYER_BUNKER` y elimina de esos chunks los candidatos invalidados.

La selección en dos pasos conserva exactamente la misma probabilidad que una única ruleta sobre todos los candidatos.

El mapa completo no se consulta para asignar un jugador y tampoco se recorren jugadores históricos.

## Concurrencia

Los chunks forman parte de la validación autoritativa. Dos asignaciones incompatibles necesariamente leen/escriben al menos un mismo chunk, por lo que Firestore obliga a reintentar una de las transacciones.

La expansión marca temporalmente `expansionStatus = EXPANDING` para impedir que una alta concurrente cree un bunker justo mientras nacen nuevas celdas en el borde del mapa.

Después de bajar esta versión hay que reconstruir una vez el mapa de pruebas porque cambia el esquema del índice de spawn:

```powershell
.\map.cmd init --force
```

## Comandos

```powershell
.\map.cmd init
.\map.cmd expand --max=80
.\map.cmd add-players --count=100
.\map.cmd download
.\map.cmd render
```

`add-players` sigue asignando estrictamente uno a uno. Durante una misma ejecución reutiliza en memoria los chunks ya leídos.

`download` sobrescribe por defecto `functions/map_exports/latest_map.json` y `render` sobrescribe `latest_map.svg`.

`render` es completamente local y no consume Firebase.

## Integración con altas reales

La función reutilizable para el alta real sigue siendo:

```js
allocatePlayerSector(db, {playerId: uid})
```

Con `playerId` real no se actualiza `simulatedPlayerSequence`, evitando una escritura y un punto de contención innecesarios en `worldMap/meta`.

Cuando un reconocimiento resuelva un sector debe utilizar:

```js
markSectorResolved(db, sectorId, resolution)
```

para poblarlo y retirarlo del chunk de spawn en la misma transacción lógica.
