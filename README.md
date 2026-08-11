# DITTO

Flutter application targeting web and mobile.

Current foundation:

- Firebase Authentication with email/password login and registration.
- Local Skip flow for fast development access.
- Cloud Firestore user profiles with username setup.
- English and Spanish UI localization through Flutter `gen-l10n`.
- Feature-first project structure separating presentation, domain/application logic, and Firebase infrastructure.

## lib structure

```text
lib/
  app/
    ditto_app.dart
    navigation/
  core/
    firebase/
    localization/
  features/
    auth/
      application/
      domain/
      presentation/
    home/
      presentation/
    profile/
      domain/
  l10n/
    app_en.arb
    app_es.arb
  main.dart
```

Firebase setup notes are documented in `FIREBASE_SETUP.md`.
