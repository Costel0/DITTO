import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SavedLoginCredentials {
  const SavedLoginCredentials({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;
}

class LocalLoginCredentialsStore {
  LocalLoginCredentialsStore({FlutterSecureStorage? storage})
      : _storage = storage ?? FlutterSecureStorage();

  static const _emailKey = 'ditto.last_login.email';
  static const _passwordKey = 'ditto.last_login.password';

  final FlutterSecureStorage _storage;

  Future<SavedLoginCredentials?> load() async {
    try {
      final email = await _storage.read(key: _emailKey);
      final password = await _storage.read(key: _passwordKey);

      if (email == null ||
          email.trim().isEmpty ||
          password == null ||
          password.isEmpty) {
        return null;
      }

      return SavedLoginCredentials(
        email: email.trim(),
        password: password,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || password.isEmpty) return;

    try {
      await _storage.write(key: _emailKey, value: cleanEmail);
      await _storage.write(key: _passwordKey, value: password);
    } catch (_) {
      // Credential persistence must never block a successful authentication.
    }
  }
}
