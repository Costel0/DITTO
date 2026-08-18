/// Development-only configuration for the one-click admin login shortcut.
///
/// The email is not sensitive and has a convenient default. The password must
/// be injected locally with --dart-define or --dart-define-from-file so it is
/// never committed to the repository or shipped as source code.
abstract final class AdminLoginConfig {
  static const String email = String.fromEnvironment(
    'DITTO_ADMIN_EMAIL',
    defaultValue: 'maxmiralpeix17@gmail.com',
  );

  static const String password = String.fromEnvironment(
    'DITTO_ADMIN_PASSWORD',
  );

  static bool get isConfigured => password.isNotEmpty;
}
