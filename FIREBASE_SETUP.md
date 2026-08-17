# Firebase setup for DITTO

DITTO uses Firebase Authentication for account identity, Cloud Firestore for persisted player data, Cloud Functions for trusted lightweight game operations, and Firebase App Check for abuse protection.

## Current architecture

- Email/password login and registration use Firebase Authentication.
- After Authentication, a new user chooses a username and initial Duplicate.
- The Flutter app calls the callable Cloud Function `initializeBunker`.
- The Function validates Firebase Auth + App Check, then atomically creates the profile, initial Survivor and authoritative BunkerState.
- Flutter may read `users/{uid}/state/bunker`, but Firestore rules prevent the client from writing it directly.
- `users/{uid}/survivors/*` is also read-only from Flutter. Survivor creation/mutations must go through trusted backend code.
- Temporary gameplay-bypassing tools are isolated behind a development service in Flutter and `functions/development.js` on the backend.
- Future lightweight operations should normally follow `app -> Cloud Functions -> Firestore`.
- Operations that need heavier simulation or long-running computation can later follow `app -> VM -> Cloud Functions -> Firestore` or another trusted-server path.

The temporary **Skip** button remains local and is not part of the production Firebase flow.

## Firestore layout

```text
items/{itemId}
  type
  subtype
  value
  stackable
  name
  description
  stats

users/{uid}
  email
  username
  initialDuplicateId
  createdAt
  updatedAt

users/{uid}/survivors/{survivorId}
  id
  duplicateId
  statMods
  healthHistory
  equippedItemIds
  createdAt
  updatedAt

users/{uid}/state/bunker
  schemaVersion
  revision
  serverUpdatedAt
  survivors
  idleSurvivors
  busySurvivors
  inventory
```

`BunkerState` schema version 2 is documented in `shared/bunker_state.schema.json`.

Current gameplay fields are:

- `survivors`: complete Survivor list.
- `idleSurvivors`: unique Survivor IDs available for new work.
- `busySurvivors`: occupation/task ID -> Survivor ID list.
- `inventory`: item ID -> owned quantity.

The Dart `Survivor` model also contains `healthHistory` for wounds, mutilations and other persistent health records, plus `equippedItemIds` for equipped items.

## Authentication

In Firebase Console:

1. Open **Authentication**.
2. Open **Sign-in method**.
3. Enable **Email/Password**.

## Cloud Firestore

In Firebase Console:

1. Open **Firestore Database**.
2. Create the default database using **Standard edition** if it does not already exist.
3. Keep note of the database location because the Cloud Functions region should stay close to it.

Firestore collections/documents do not need to be created manually.

Deploy rules with:

```powershell
firebase deploy --only firestore:rules
```

Current rules allow an authenticated user to read their own bunker and Survivor snapshots, but not create, update or delete those documents directly. Cloud Functions uses the Admin SDK for trusted writes.

## Cloud Functions

Functions source lives in:

```text
functions/
  index.js          # normal trusted gameplay entrypoints
  development.js    # removable development-only mutations
  package.json
```

Current callable Functions:

```text
initializeBunker
addSurvivorForTesting   # temporary development helper
addItemForTesting       # temporary development helper
resetUserForTesting     # temporary development helper
```

They run in `europe-west1`, with `minInstances: 0`, `maxInstances: 1`, short timeouts, Firebase Authentication validation and App Check enforcement.

`addItemForTesting` validates that the requested item ID exists in the server `items` catalog before incrementing `BunkerState.inventory`. It also increments the bunker `revision` and updates `serverUpdatedAt`.

### Development-tools access boundary

All gameplay-bypassing backend helpers live in `functions/development.js` and all client calls live behind `DevelopmentService` / `FirebaseFunctionsDevelopmentService`.

The HUB debug widget renders nothing outside Flutter debug builds (`kDebugMode`). This removes the buttons from release/profile builds, but the callable endpoints must still be removed or restricted before production because hiding UI is not a server-side security boundary.

The development Functions can be switched to admin-only access by setting:

```text
DITTO_DEVELOPMENT_TOOLS_REQUIRE_ADMIN=true
```

When enabled, the Functions require the authenticated Firebase user to have the custom claim:

```json
{"admin": true}
```

Custom claims must only be assigned from trusted server/admin tooling. Before production, either enable this admin gate or preferably remove the development module and its exports entirely if the tools are no longer needed.

### One-time setup

1. Keep the Firebase project `ditto-app-project` on the **Blaze** billing plan.
2. Install a supported Node.js version. The repository targets Node.js 22 for Functions.
3. Install/update Firebase CLI:

```powershell
npm install -g firebase-tools
firebase login
```

The repository includes `.firebaserc` with `ditto-app-project` as the default project. Verify it with:

```powershell
firebase use
```

### Install dependencies

From the project root:

```powershell
flutter pub get
cd functions
npm ci
cd ..
```

Keep both `pubspec.lock` and `functions/package-lock.json` under version control after dependency resolution.

## App Check during development

Flutter activates App Check only in debug builds for now:

- Android: debug provider.
- Apple: debug provider once the iOS Firebase app is reconfigured.
- Web: debug provider.

The debug token must be registered in Firebase Console before deploying App-Check-enforced callable Functions.

Recommended Android flow:

1. Run `flutter pub get`.
2. Run the app with `flutter run` and trigger a Firebase request.
3. Copy the App Check debug token printed in the Android logs.
4. Firebase Console -> **Security -> App Check -> Apps** -> Android app -> **Manage debug tokens**.
5. Register the token. Never commit it to Git.
6. Deploy the Functions and Firestore rules.

Deploy current callables and rules with:

```powershell
firebase deploy --only "functions:initializeBunker,functions:addSurvivorForTesting,functions:addItemForTesting,functions:resetUserForTesting,firestore:rules"
```

Cloud Functions has `enforceAppCheck: true`, so calls without a valid App Check token are rejected before game logic executes.

For Cloud Firestore, App Check enforcement is enabled separately from Firebase Console. Enable it only after the debug tokens for every development platform you still use are registered and verified, otherwise those local requests will be rejected.

Before production, replace the debug providers with real attestation providers, primarily Play Integrity on Android and reCAPTCHA Enterprise for Web. Never ship a debug provider/token in a production build.

## Flutter dependencies

DITTO uses:

- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `cloud_functions`
- `firebase_app_check`
- `flutter_secure_storage`
- `flutter_localizations`
- `intl`

After dependency changes run:

```powershell
flutter pub get
flutter analyze
```

## Firebase project configuration and identifiers

Android is the currently configured mobile Firebase target and uses:

```text
com.example.ditto
```

The iOS Xcode bundle identifier has been aligned to the same identifier. The old Firebase iOS mapping for `com.example.gameWiki` was intentionally removed because it no longer matches the project.

Before running Firebase on iOS, register a new iOS app in `ditto-app-project` using bundle ID `com.example.ditto`, then regenerate FlutterFire configuration so the new Firebase iOS App ID replaces the removed stale mapping.

Platform-specific Firebase configuration is generated by FlutterFire and stored at:

```text
lib/core/firebase/firebase_options.dart
```

`firebase.json` points FlutterFire to this location and also configures `functions/` as the Functions source directory.

## BunkerState trust boundary

Flutter's `BunkerState` is intentionally immutable and read-only. The app replaces its local snapshot with newer server data; it does not expose a save/update API for BunkerState.

The Firestore adapter converts Firestore timestamps into the normalized JSON representation consumed by the shared schema. Future VM/backend code should follow the same schema and increment `revision` whenever authoritative bunker state changes.

## Development controls

The three HUB debug controls are currently:

- Reset user Firestore state through `resetUserForTesting` while preserving Firebase Authentication.
- Add the next missing predefined Survivor through `addSurvivorForTesting`.
- Add an arbitrary positive quantity of an existing server-catalog item through `addItemForTesting`.

None of these controls writes authoritative Firestore gameplay data directly from Flutter.

## Future VM

A future VM should authenticate requests using Firebase ID tokens or another trusted server-to-server mechanism. It must never receive or store users' Firebase passwords. Server-only credentials and secrets must not be included in the Flutter/web application.
