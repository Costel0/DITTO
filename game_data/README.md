# Game data

`items.json` is the versioned source used to publish the shared public item catalog to Firestore.

The Flutter app does not bundle item definitions. It only bundles optional artwork at `assets/items/item_[ID].png`. Runtime item metadata is read from the shared `/items/{itemId}` Firestore collection.

## Sync items

From the repository root:

```bash
cd functions
npm install
npm run sync:items -- --dry-run
npm run sync:items -- --project=YOUR_FIREBASE_PROJECT_ID
```

The script uses Firebase Admin Application Default Credentials. Locally, configure `GOOGLE_APPLICATION_CREDENTIALS` with a service-account JSON path or use another Application Default Credentials setup supported by Firebase Admin.

Use `--prune` only when `game_data/items.json` should be treated as the exact complete catalog; it deletes Firestore `/items` documents whose IDs are absent from the JSON.

```bash
npm run sync:items -- --project=YOUR_FIREBASE_PROJECT_ID --prune
```

When `FIRESTORE_EMULATOR_HOST` is set, the script targets the Firestore emulator instead.

## Public vs private game data

Only fields that the client is allowed to know belong in `/items`, for example names, descriptions, visible stats, type, subtype and value. Loot probabilities, hidden encounter logic, anti-cheat rules or other server-only balance data should live in backend-only collections/configuration and must not be exposed through the client-readable item documents.
