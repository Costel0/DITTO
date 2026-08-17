# Game data

`items.json` is the versioned source used to publish the shared public item catalog to Firestore.

The Flutter app does not bundle item definitions. It only bundles optional artwork at `assets/items/item_[ID].png`. Runtime item metadata is read from the shared `/items/{itemId}` Firestore collection.

Item `type` and `subtype` are arrays. This lets one item belong to several categories at once, for example:

```json
{
  "type": ["weapon", "resource"],
  "subtype": ["melee", "wood"]
}
```

## Sync items

From the repository root:

```bash
cd functions
npm install
npm run sync:items -- --dry-run
npm run sync:items -- --prune
```

`--dry-run` validates the local JSON without writing to Firestore.

`--prune` treats `game_data/items.json` as the complete source of truth: it writes all local item definitions and deletes `/items` documents whose IDs are no longer present locally.

The script resolves the Firebase project from `--project=...`, the standard Google Cloud project environment variables, or the repository `.firebaserc` (currently `ditto-app-project`).

It uses Firebase Admin Application Default Credentials. Locally, configure `GOOGLE_APPLICATION_CREDENTIALS` with a service-account JSON path or use another Application Default Credentials setup supported by Firebase Admin.

When `FIRESTORE_EMULATOR_HOST` is set, the script targets the Firestore emulator instead.

## Private server data

Backend-only JSON files live in `game_data/server/`.

Initial files:

- `loot_tables.json` -> `/serverData/lootTables`
- `server_config.json` -> `/serverData/serverConfig`

Any additional `.json` file added to `game_data/server/` is picked up automatically. Snake-case filenames are converted to camelCase Firestore document IDs; for example `encounter_rules.json` becomes `/serverData/encounterRules`.

Sync them with:

```bash
cd functions
npm run sync:server-data -- --dry-run
npm run sync:server-data -- --prune
```

Each Firestore `/serverData/{documentId}` document is replaced with exactly the root JSON object from its corresponding local file. `--prune` also deletes remote `/serverData` documents that no longer have a local JSON file.

Client Firestore rules explicitly deny all access to `/serverData`. Cloud Functions and trusted VM processes using Firebase Admin can access it because Admin SDK bypasses client security rules.

## Public vs private game data

Only fields that the client is allowed to know belong in `/items`, for example names, descriptions, visible stats, type, subtype and value.

Loot probabilities, hidden encounter logic, anti-cheat rules, drop weights and other server-only balance/configuration belong in `game_data/server/` and `/serverData`.
