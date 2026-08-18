/// Development-only configuration for the one-click admin login shortcut.
///
/// These credentials are intentionally hardcoded for the current development
/// phase. The shortcut is rendered only in debug builds and must be removed or
/// replaced by real admin authorization before production.
abstract final class AdminLoginConfig {
  static const String email = 'maxmiralpeix17@gmail.com';
  static const String password = 'password';
}
