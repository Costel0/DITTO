# Map implementation v1

This document records the first executable implementation of the map/spawn design. The conceptual design remains in `README.md` and `SPAWN_PLACEMENT.md`.

## Scope

Implemented now:

1. initialize the persistent map;
2. expand its numeric length;
3. add simulated players one by one through the weighted spawn allocator;
4. export/download the complete map to JSON and/or CSV.

The implementation intentionally does **not** yet connect the allocator to Firebase Auth / real account onboarding. This allows the distribution algorithm to be tested independently before changing live player creation.

## Backend module

Code lives in:

```text
functions/map/index.js
```

The administrative CLI imports this same module, so command-line tests exercise the same allocation code intended for later Cloud Functions integration.

No destructive map-management callable is exposed to clients.

## Firestore model

```text
worldMap/meta
worldMapSectors/{sectorId}
worldMapSpawnCandidates/{sectorId}
```

### `worldMap/meta`

Stores configuration and mutable global state such as:

- map limits currently materialized;
- active spawn number window;
- `D-W` spawn letter band;
- origin `M25`;
- minimum player distance `2`;
- priority alpha;
- simulated-player sequence;
- initialization state.

### `worldMapSectors`

One persistent document per materialized cell.

Initial map:

```text
A-Z × 1-50 = 1300 sector documents
```

Every sector stores its static `spawnPriority`, even when it is not currently a spawn candidate.

### `worldMapSpawnCandidates`

Persistent pool of sectors that may still become `PLAYER_BUNKER`.

The pool initially contains sectors in the permitted spawn letter band and usable numeric direction. Actual allocation additionally filters by the active numeric spawn window.

A candidate disappears from this collection when:

- it becomes a bunker;
- it lies at `d <= 2` from a newly created bunker;
- it is resolved by another world mechanic, e.g. recognition;
- validation detects that a stale pool entry is no longer legal.

## Priority

Priority is static and calculated once when the cell is materialized:

```text
priority = 1 / (1 + distance(cell, M25))^alpha
```

V1 defaults to:

```text
alpha = 2
```

This is intentionally configurable so distributions with different alpha values can be tested later.

## Player allocation

For each player, sequentially:

```text
load candidates in active spawn window
→ weighted random choice using persisted priority
→ transactionally revalidate sector and d > 2
→ populate selected sector as PLAYER_BUNKER
→ remove selected candidate and all candidate neighbours with d <= 2
→ commit
```

If a pool entry is stale, it is removed/ignored and selection retries.

If the active spawn window has no candidates, the allocator advances to the next numeric window and expands the map when required.

## Temporary player-sector composition

Until the actual balanced initial-zone catalogue is designed, every simulated player sector is resolved neutrally as:

```text
zone 1 = PLAYER_BUNKER
zones 2..N = EMPTY
```

This is deliberately temporary and avoids introducing random initial advantages while testing spatial distribution.

## Recognition integration seam

The reusable function:

```js
markSectorResolved(db, sectorId, resolution)
```

populates an `UNGENERATED` sector and removes its coordinate from the spawn pool.

When recognition is implemented, its authoritative backend resolution should use this seam or equivalent transactional logic.

## Real-account integration seam

The reusable allocator is:

```js
allocatePlayerSector(db, {playerId: uid})
```

It is not connected to `initializeBunker` yet because that requires deciding the atomic relationship between map allocation and the existing account/bunker transaction. Simulated players use the same allocator without creating Auth accounts.

## Commands

From repository root on Windows:

```powershell
.\map.cmd init
.\map.cmd expand --max=80
.\map.cmd add-players --count=100
.\map.cmd download
```

PowerShell wrapper:

```powershell
.\map.ps1 add-players --count=100
```

Linux/macOS:

```bash
bash ./map.sh add-players --count=100
```

Or from `functions/`:

```bash
npm run map -- init
npm run map -- expand --max=80
npm run map -- add-players --count=100
npm run map -- download
```

### Reset/reinitialize

```powershell
.\map.cmd init --force
```

This is destructive for map collections.

### Different alpha

```powershell
.\map.cmd init --force --alpha=1.5
```

### Download formats

```powershell
.\map.cmd download --format=json
.\map.cmd download --format=csv
.\map.cmd download --format=both
```

Default exports are written under `functions/map_exports/`, which is ignored by Git.

## Tests

Pure map rules have unit tests in:

```text
functions/test/map.test.js
```

They cover Euclidean sector distance, the 13 forbidden integer offsets for `d <= 2`, priority decay from `M25`, and weighted-candidate selection.
