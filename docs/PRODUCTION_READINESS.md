# DITTO — Production readiness checklist

> Living document. Update this file whenever development introduces a new production requirement, temporary debug mechanism, migration, credential, Firebase setting, deployment step, or release risk.
>
> **Do not execute these tasks during normal development unless we explicitly decide to prepare a production release.**
>
> Last updated: 2026-08-18

## Status legend

- [ ] Pending
- [x] Completed for production
- **CRITICAL**: production must not be released until resolved.

---

# 1. Critical production blockers

## 1.1 Remove or fully isolate development Cloud Functions — CRITICAL

Current state:

- `functions/development.js` exposes development-only callables such as:
  - `addSurvivorForTesting`
  - `addItemForTesting`
  - `resetUserForTesting`
- They bypass normal gameplay acquisition/progression rules.
- App Check is enforced, but the optional administrator requirement only applies when `DITTO_DEVELOPMENT_TOOLS_REQUIRE_ADMIN=true`.
- Without that production-side restriction, an authenticated user could potentially call these development endpoints directly even if the Flutter debug UI is hidden.

Before production:

- [ ] Decide whether development functions will be completely removed from production or retained only in a separate development/staging environment.
- [ ] Preferred production approach: stop exporting/deploying the development callables to the production Firebase project.
- [ ] Remove/undeploy already deployed development callables from the production project.
- [ ] If any administrative callable must remain, require a trusted Firebase Auth custom claim such as `{admin: true}` and verify authorization server-side.
- [ ] Never rely only on hiding debug buttons in the Flutter client.

Relevant files:

- `functions/development.js`
- `functions/index.js`
- `lib/features/development/`

## 1.2 Remove development login credentials — CRITICAL

Current state:

- `lib/features/development/domain/admin_login_config.dart` contains hardcoded credentials for the one-click development login.
- The shortcut is intended only for debug builds, but the credential has existed in source control.

Before production:

- [ ] Remove the hardcoded development credentials from the application source.
- [ ] Remove the one-click debug/admin login shortcut from production code paths.
- [ ] Change/rotate the Firebase Auth password of the affected development account before release, because deleting the source line does not invalidate a credential that has already been committed.
- [ ] Decide how real administrative access will work if the product needs it. Authorization must be server-side, not based on a client-side label such as “admin”.

Relevant file:

- `lib/features/development/domain/admin_login_config.dart`

## 1.3 Remove and revoke App Check debug tokens — CRITICAL

Current state:

- Fixed App Check debug tokens are stored in `AppCheckDebugConfig` to keep local Web and Android testing deterministic.
- Those tokens have been committed to the repository and registered in Firebase App Check.
- They are appropriate for development only.

Before production:

- [ ] Remove fixed App Check debug tokens from application source.
- [ ] Revoke/delete the registered Web debug token in Firebase App Check.
- [ ] Revoke/delete the registered Android debug token in Firebase App Check.
- [ ] Remove any older temporary debug tokens that were registered while diagnosing App Check.
- [ ] Confirm production builds cannot activate `WebDebugProvider`, `AndroidDebugProvider`, or `AppleDebugProvider`.
- [ ] Treat revocation as mandatory even if the source file is deleted, because the values exist in Git history.

Relevant files:

- `lib/features/development/domain/app_check_debug_config.dart`
- `lib/main.dart`

## 1.4 Configure real production App Check providers — CRITICAL

Current state:

- `lib/main.dart` activates App Check only inside `kDebugMode`.
- Debug builds use fixed Web/Android debug providers.
- Release builds currently do **not** activate a production App Check provider.
- Cloud Functions already use `enforceAppCheck: true`, so a release client without a valid production App Check token can be rejected.

Before production:

- [ ] Android release: activate the production Play Integrity App Check provider.
- [ ] Web release: activate the production reCAPTCHA Enterprise App Check provider using the configured Site Key.
- [ ] Keep debug providers available only to local/debug builds.
- [ ] Verify the release build can obtain an App Check token before calling protected Functions.
- [ ] Verify App Check enforcement for every Firebase backend used by the production client where protection is intended, especially Cloud Functions and Firestore.
- [ ] Confirm App Check metrics show valid production traffic before final rollout.

Relevant file:

- `lib/main.dart`

## 1.5 Configure real Android release signing — CRITICAL

Current state:

- `android/app/build.gradle.kts` currently signs the `release` build with the debug signing configuration.

Before production:

- [ ] Create the final Android upload/release keystore according to the chosen Play Store signing strategy.
- [ ] Store keystore credentials outside source control.
- [ ] Configure the Flutter/Gradle release signing configuration.
- [ ] Remove `signingConfig = signingConfigs.getByName("debug")` from the release build.
- [ ] Back up the upload key securely.
- [ ] Build and verify a signed release `.aab`.

Relevant file:

- `android/app/build.gradle.kts`

## 1.6 Finalize the Android package/application ID — CRITICAL before store registration

Current state:

- Android namespace/application ID is still `com.example.ditto`.
- Firebase Android is currently registered against that package.

Before production:

- [ ] Decide the permanent Android package ID before publishing to Google Play.
- [ ] If it changes, update `namespace` and `applicationId`.
- [ ] Register a new Firebase Android app for the final package ID.
- [ ] Download/replace the matching `google-services.json`.
- [ ] Regenerate/update FlutterFire Firebase options for Android.
- [ ] Reconfigure App Check / Play Integrity for the final Firebase Android app.
- [ ] Re-test Authentication, Firestore, Cloud Functions and App Check after the package change.

Important: once an app is published under a package ID, changing that ID effectively creates a different Android app.

Relevant files:

- `android/app/build.gradle.kts`
- `android/app/google-services.json`
- `lib/core/firebase/firebase_options.dart`

---

# 2. Firebase project and environment strategy

## 2.1 Separate development and production environments

Current state:

- Development currently uses Firebase project `ditto-app-project`.
- Debug data, debug App Check tokens, development Functions and real application data currently share the same project context.

Before production:

- [ ] Decide whether `ditto-app-project` becomes production or remains development/staging.
- [ ] Recommended: use separate Firebase projects for development/staging and production so debug tools cannot accidentally affect production data.
- [ ] If a new production Firebase project is created, configure independently:
  - Firebase Auth
  - Firestore
  - Firestore Rules
  - Cloud Functions
  - Firebase Hosting
  - App Check
  - Android app registration
  - Web app registration
  - production catalog/server data
- [ ] Add an explicit environment/configuration strategy so debug builds cannot silently point at production services.
- [ ] Verify all Firebase IDs/options before every release build.

## 2.2 Firebase Web app mapping

Current known correct DITTO Web Firebase app:

- Display name: `Ditto app web`
- App ID: `1:14378781761:web:494fbdafb1e3ee52614ac0`

A legacy Web app named `game_wiki (web)` also exists in the current Firebase project and previously caused DITTO to initialize against the wrong App Check registration.

Before production:

- [ ] Confirm production `firebase_options.dart` references the intended DITTO Web app, not the legacy `game_wiki (web)` app.
- [ ] Decide whether unused legacy Firebase app registrations should be removed after verifying no other product depends on them.
- [ ] Do not delete legacy Firebase apps without first confirming they are unused elsewhere.

## 2.3 Firebase Android app mapping

Current Android Firebase app:

- Display name: `ditto (android)`
- App ID: `1:14378781761:android:0a5e0306a5894f1d614ac0`
- Current package: `com.example.ditto`

Before production:

- [ ] Re-check this mapping after the final Android package ID decision.

---

# 3. App Check production configuration

## 3.1 Web / reCAPTCHA Enterprise

Current state:

- A reCAPTCHA Enterprise configuration has been created for DITTO Web.
- Debug provider is currently used for local Flutter Web development.

Before production:

- [ ] Store/configure the production reCAPTCHA Enterprise Site Key in a production-appropriate configuration path.
- [ ] Initialize `ReCaptchaEnterpriseProvider(...)` in Web release builds.
- [ ] Add/verify the final production Web domains in the reCAPTCHA Enterprise key configuration.
- [ ] Verify Firebase Hosting domains if they are used:
  - `ditto-app-project.web.app`
  - `ditto-app-project.firebaseapp.com`
- [ ] Add the final custom domain if DITTO later uses one.
- [ ] Do not use the App Check debug provider in production.
- [ ] Test App Check from the deployed HTTPS site, not only from localhost.

## 3.2 Android / Play Integrity

Before production:

- [ ] Configure the final Android Firebase app to use Play Integrity.
- [ ] Activate the production Play Integrity provider in Flutter release builds.
- [ ] Complete any required Google Play / Firebase linkage for the final package.
- [ ] Test App Check using a release-signed build distributed through the appropriate Play testing track if required by the final setup.
- [ ] Verify protected callable Functions receive valid App Check assertions.

---

# 4. Development/debug surface cleanup

Before production:

- [ ] Verify all development UI is absent from release builds:
  - add item
  - add survivor
  - reset profile
  - one-click admin login
  - debug error/clipboard helpers
- [ ] Remove debug-only text, credentials and token configuration that is no longer needed.
- [ ] Remove or production-gate development service wiring if it should not exist in release code.
- [ ] Search the repository for `DEBUG`, `Testing`, `ForTesting`, `DebugProvider`, hardcoded credentials and temporary bypasses before release.
- [ ] Verify no development endpoint can be invoked merely by reverse-engineering the production client.

Relevant areas:

- `lib/features/development/`
- `lib/features/hub/presentation/widgets/hub_debug_controls.dart`
- `lib/core/firebase/firebase_functions_development_service.dart`
- `functions/development.js`

---

# 5. Firestore and backend security

Before production:

- [ ] Review all Firestore Security Rules against the final data model.
- [ ] Confirm users can read only data they are intended to read.
- [ ] Confirm authoritative gameplay state cannot be directly mutated from an untrusted client where server-side mutation is intended.
- [ ] Add automated Firestore Rules tests for sensitive collections before release.
- [ ] Deploy the exact reviewed Firestore Rules to the production Firebase project.
- [ ] Review all callable Functions for:
  - authentication checks
  - authorization checks
  - App Check enforcement
  - argument validation
  - transaction consistency
  - abuse/rate/cost exposure
- [ ] Confirm no server-side secret is bundled in Flutter/Web assets.
- [ ] Review Cloud Functions environment variables and secrets separately from source control.

Current architecture to preserve:

- bunker/gameplay state is server-authoritative for protected mutations.
- user bunker state lives under `users/{uid}/state/bunker`.
- development mutations must not survive as unrestricted production functionality.

---

# 6. Production game data

Before production:

- [ ] Define a controlled way to deploy/sync the final item catalog to production Firestore.
- [ ] Verify `game_data/items.json` and Firestore `/items` are synchronized before release.
- [ ] Verify server-only data under `game_data/server/` is deployed to the intended backend environment.
- [ ] Validate all item IDs referenced by gameplay/assets exist in the production catalog.
- [ ] Validate all survivor/equipment references against the production item catalog.
- [ ] Define how future schema/catalog migrations will be versioned and applied without corrupting existing users.
- [ ] Verify `BunkerState` schema/version migrations before changing production schema versions.

Relevant areas:

- `game_data/`
- `functions/scripts/`
- `shared/bunker_state.schema.json`
- `lib/features/bunker/domain/bunker_state.dart`

---

# 7. Android production release

Before production:

- [ ] Final package ID.
- [ ] Final app display name.
- [ ] Final launcher icon/adaptive icon assets.
- [ ] Correct production Firebase Android configuration.
- [ ] Release signing configured.
- [ ] Set proper `versionName` and increment `versionCode` for every Play release.
- [ ] Review `minSdk`, `targetSdk` and Play Store requirements at release time.
- [ ] Review Android permissions and remove anything unnecessary.
- [ ] Verify `android:allowBackup` and other security/privacy manifest settings match the final product decision.
- [ ] Build with `flutter build appbundle --release`.
- [ ] Install/test a release-signed build on a real Android device.
- [ ] Test Play Integrity/App Check in the release distribution path.
- [ ] Create/configure the Google Play Console application.
- [ ] Complete Play Store listing, screenshots, content rating and required declarations.
- [ ] Complete Google Play Data Safety information based on the actual production data flows.

---

# 8. Web production release

Before production:

- [ ] Configure production App Check with reCAPTCHA Enterprise.
- [ ] Confirm DITTO uses the correct production Firebase Web App ID.
- [ ] Build with `flutter build web --release`.
- [ ] Deploy the release build to Firebase Hosting or the final hosting provider.
- [ ] Verify HTTPS and final domains.
- [ ] Configure/verify Firebase Auth authorized domains for the final deployment.
- [ ] Verify reCAPTCHA Enterprise allowed domains for the final deployment.
- [ ] Review `web/manifest.json`:
  - application name
  - short name
  - icons
  - theme/background colors
  - PWA behavior if desired
- [ ] Verify favicon and production Web icons.
- [ ] Test hard refresh/direct navigation behavior on the deployed site.
- [ ] Test current major Chromium browsers and at least one non-Chromium browser supported by Flutter Web.
- [ ] Test responsive layouts at the target desktop/mobile browser sizes.
- [ ] Confirm no development token, debug credential or source-only diagnostic appears in generated Web assets.

---

# 9. Authentication and account security

Before production:

- [ ] Review which Firebase Auth providers are enabled and disable unused providers.
- [ ] Remove/rotate development account credentials that were committed or shared during development.
- [ ] Confirm registration/login/logout/password-recovery flows for production.
- [ ] Decide whether email verification is required and implement it if needed.
- [ ] Decide account deletion requirements and implement the user-facing flow if required by platform/privacy policy.
- [ ] Verify administrative privileges use trusted server-side authorization/custom claims if an admin system exists.
- [ ] Never treat possession of a debug UI or known email address as authorization.

---

# 10. Privacy, legal and store requirements

Before public release:

- [ ] Publish a privacy policy describing the data DITTO actually collects/stores.
- [ ] Add the privacy policy URL to Google Play and the Web application where required.
- [ ] Complete required Google Play disclosures/data safety declarations.
- [ ] Determine whether Terms of Service are needed.
- [ ] Review whether analytics, crash reporting, advertising, cookies or other future SDKs add consent/disclosure requirements.
- [ ] Keep this section updated whenever a new third-party SDK or data collection feature is added.

---

# 11. Monitoring, reliability and cost controls

Before production:

- [ ] Configure Firebase/Google Cloud billing budget alerts.
- [ ] Review Cloud Functions limits (`minInstances`, `maxInstances`, timeout) for real production traffic.
- [ ] Review Firestore usage/cost characteristics of polling and listeners.
- [ ] Decide on production error/crash monitoring (for example Crashlytics on supported platforms) before launch.
- [ ] Ensure server logs contain enough information to diagnose failures without logging auth tokens, App Check tokens, passwords or other secrets.
- [ ] Define a basic rollback strategy for Web deployments and backend changes.
- [ ] Define a backup/recovery strategy for important Firestore production data.

---

# 12. Release validation checklist

Run this only when preparing an actual release candidate.

## Code quality

- [ ] `flutter analyze` returns no issues.
- [ ] Run all automated tests.
- [ ] Add/fix tests for critical authentication, parsing and state behavior where missing.
- [ ] Review dependency updates/security advisories deliberately; do not blindly upgrade immediately before release.

## Android release candidate

- [ ] `flutter build appbundle --release` succeeds.
- [ ] Release bundle uses production signing.
- [ ] Release bundle points to the intended Firebase project/app.
- [ ] App Check works with Play Integrity.
- [ ] Register/login/logout works.
- [ ] Bunker initialization works.
- [ ] Character/survivor state loads correctly.
- [ ] Inventory loads, can be reopened repeatedly, and stays synchronized.
- [ ] Equipment UI resolves catalog items correctly.
- [ ] Protected Functions work without debug App Check tokens.
- [ ] No debug controls are visible or callable.

## Web release candidate

- [ ] `flutter build web --release` succeeds.
- [ ] Deployed Web app points to the intended Firebase Web App ID.
- [ ] reCAPTCHA Enterprise App Check works from the real domain.
- [ ] Register/login/logout works.
- [ ] Bunker initialization works.
- [ ] Character/survivor state loads correctly.
- [ ] Inventory loads, can be reopened repeatedly, and stays synchronized.
- [ ] Equipment UI resolves catalog items correctly.
- [ ] Protected Functions work without debug App Check tokens.
- [ ] No debug controls, debug credentials or debug tokens are present in generated assets.

---

# 13. Known temporary development decisions to revisit

This section is a quick reminder of intentionally temporary choices currently present in the project.

- [ ] Fixed Web App Check debug token exists in source.
- [ ] Fixed Android App Check debug token exists in source.
- [ ] One-click debug login has hardcoded credentials.
- [ ] Development callable Functions exist and can bypass normal gameplay acquisition rules.
- [ ] Development Functions have an optional admin-claim gate but are not inherently safe merely because the client UI is hidden.
- [ ] App Check production providers are not yet initialized by release builds.
- [ ] Android package ID is still `com.example.ditto`.
- [ ] Android release currently uses debug signing.
- [ ] iOS Firebase configuration is intentionally unsupported until it is re-registered for the final iOS bundle identifier. This is not an Android/Web launch blocker unless iOS becomes part of the same release scope.
- [ ] Decide whether development and production should use separate Firebase projects.

---

# 14. Change log for this document

## 2026-08-18

Initial checklist created after stabilizing:

- Firebase App Check debug flow on Web/Android.
- Correct DITTO Firebase Web app selection.
- Development callable authentication/App Check diagnostics.
- Server-authoritative debug inventory mutation.
- Inventory/catalog re-subscription behavior.

Future production-related findings should be added here and to the relevant checklist section when discovered.
