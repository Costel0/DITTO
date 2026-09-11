# DITTO map backend

Primera implementación del sistema persistente de mapa descrito en `docs/map/`.

Este módulo vive aislado en `functions/map/` y contiene la lógica reutilizable por Cloud Functions y por las herramientas administrativas. Los scripts no duplican el algoritmo: importan `functions/map/index.js`.

## Colecciones Firestore

- `worldMap/meta`: configuración y estado global del mapa.
- `worldMapSectors/{sectorId}`: una entrada persistente por sector materializado.
- `worldMapSpawnCandidates/{sectorId}`: pool persistente de sectores que todavía pueden recibir un bunker.

Cada sector almacena su `spawnPriority`, calculada una única vez al crear la celda. El pool guarda además esa prioridad para la selección ponderada.

La prioridad inicial usa:

```text
priority = 1 / (1 + distanceToM25)^alpha
```

La primera versión utiliza `alpha = 2`, configurable al inicializar el mapa.

## Reglas ya implementadas

- mapa inicial `A-Z × 1-50`;
- banda de spawn `D-W`;
- ventana inicial `10-40`;
- origen de prioridad `M25`;
- separación estricta entre bunkers `d > 2`;
- selección aleatoria ponderada por prioridad;
- al colocar un bunker se eliminan del pool el sector y todas las celdas con `d <= 2`;
- un sector resuelto por otra mecánica puede eliminarse del pool mediante `markSectorResolved`;
- si se agota la ventana activa, el asignador avanza automáticamente a la siguiente ventana y amplía el mapa si hace falta;
- los sectores `PLAYER_BUNKER` se resuelven completos al asignarlos.

### Composición temporal de `PLAYER_BUNKER`

Hasta que definamos los tipos reales de zonas iniciales, la implementación usa una composición deliberadamente neutral:

```text
zone 1 = PLAYER_BUNKER
rest   = EMPTY
```

Esto permite probar el mapa sin introducir ventajas aleatorias iniciales. Debe sustituirse cuando se diseñe la composición definitiva de los sectores de jugador.

## Comandos desde la raíz del repositorio

En Windows:

```powershell
.\map.cmd init
.\map.cmd expand --max=80
.\map.cmd add-players --count=100
.\map.cmd download
```

También existe `map.ps1`. En Linux/macOS puede utilizarse:

```bash
bash ./map.sh init
bash ./map.sh expand --max=80
bash ./map.sh add-players --count=100
bash ./map.sh download
```

Desde `functions/` se puede ejecutar directamente:

```bash
npm run map -- init
npm run map -- expand --max=80
npm run map -- add-players --count=100
npm run map -- download
```

Todos los comandos aceptan opcionalmente:

```text
--project=FIREBASE_PROJECT_ID
```

La autenticación sigue el mismo patrón que los scripts administrativos existentes del proyecto: Firebase Admin `applicationDefault()`. Por tanto hay que tener disponibles Application Default Credentials o `GOOGLE_APPLICATION_CREDENTIALS`.

## 1. Inicializar mapa

```powershell
.\map.cmd init
```

Valores iniciales:

```text
A-Z
1-50
spawn D-W
spawn numbers 10-40
origin M25
alpha 2
```

Para cambiar temporalmente el máximo inicial o alpha:

```powershell
.\map.cmd init --max=50 --alpha=1.5
```

Si el mapa ya existe, `init` falla deliberadamente. Para borrar el mapa de pruebas y reconstruirlo:

```powershell
.\map.cmd init --force
```

`--force` elimina `worldMapSectors` y `worldMapSpawnCandidates`, así que debe tratarse como una operación destructiva.

## 2. Ampliar mapa

```powershell
.\map.cmd expand --max=80
```

Crea únicamente las nuevas columnas numéricas. Las celdas nacen como `UNGENERATED` y reciben su prioridad una sola vez.

Las nuevas celdas dentro de la banda `D-W` entran en el pool de spawn salvo que una futura integración las invalide inmediatamente por estado del mundo.

## 3. Añadir jugadores simulados

```powershell
.\map.cmd add-players --count=100
```

Los añade **uno a uno**, no en bloque. Cada alta ejecuta la misma ruleta ponderada y actualiza el pool antes de asignar la siguiente.

Los IDs son:

```text
sim-player-000001
sim-player-000002
...
```

Estos registros existen únicamente en el mapa. No crean usuarios de Firebase Auth ni documentos `users/`. El objetivo es poder estudiar y validar el algoritmo antes de conectarlo al alta real de cuentas.

## 4. Descargar mapa

Por defecto:

```powershell
.\map.cmd download
```

crea un JSON en:

```text
functions/map_exports/
```

También se puede pedir CSV o ambos:

```powershell
.\map.cmd download --format=csv
.\map.cmd download --format=both
```

Y elegir ruta:

```powershell
.\map.cmd download --format=both --out=../map_test_100_players
```

El JSON incluye metadatos, contadores y todos los sectores. Cada sector indica también si continúa presente en el pool de spawn.

## Integración futura

La función reutilizable que deberá usar el alta real de una cuenta es:

```js
allocatePlayerSector(db, {playerId: uid})
```

Cuando implementemos reconocimiento real, la resolución autoritativa del sector deberá llamar a:

```js
markSectorResolved(db, sectorId, resolution)
```

para poblarlo y retirarlo del pool de spawn en la misma operación lógica.
