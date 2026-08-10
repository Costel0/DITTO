# Firebase setup for DITTO

The Flutter project already includes `firebase_core` and `firebase_auth`, plus a Firebase-backed authentication adapter at `lib/auth/firebase_auth_service.dart`.

The app intentionally continues to use `PlaceholderAuthService` until a Firebase project is linked. This keeps local/web development working before Firebase configuration exists.

## 1. Create the Firebase project

Create a Firebase project named `DITTO` in the Firebase Console.

Analytics is optional for now.

## 2. Enable Authentication

In Firebase Console:

1. Open **Authentication**.
2. Open **Sign-in method**.
3. Enable **Email/Password**.

Do not remove the temporary Skip flow from DITTO yet.

## 3. Install the CLIs

Install the Firebase CLI and authenticate:

```bash
npm install -g firebase-tools
firebase login
firebase projects:list
```

Install FlutterFire CLI:

```bash
dart pub global activate flutterfire_cli
```

## 4. Link DITTO

From the root directory of this repository:

```bash
flutter pub get
flutterfire configure
```

Select the DITTO Firebase project and configure at least:

- Web
- Android
- iOS

FlutterFire will generate `lib/firebase_options.dart` and register the selected platform apps.

## 5. Activate Firebase in the app

Once `firebase_options.dart` exists, initialize Firebase before `runApp` in `lib/main.dart`:

```dart
WidgetsFlutterBinding.ensureInitialized();
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

Then replace:

```dart
PlaceholderAuthService()
```

with:

```dart
FirebaseAuthService()
```

The normal login form will then authenticate against Firebase Email/Password. The temporary Skip button will continue creating the local `user/password` development session without contacting Firebase.

## Backend note

DITTO's future Python backend on OVHcloud should validate Firebase ID tokens sent by authenticated clients rather than receiving or storing Firebase passwords. Server-only credentials and secrets must never be included in the Flutter/web application.
