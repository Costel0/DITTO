/// Fixed App Check debug tokens used only by DITTO development builds.
///
/// They intentionally keep local Web/Android testing stable across browser
/// profiles and emulator restarts. Remove or replace these before production.
abstract final class AppCheckDebugConfig {
  static const String webToken = 'dfc578ad-0b6e-42a0-b450-3a6379da61e1';
  static const String androidToken = '8c4275f8-1893-45cb-9a73-0f8e56ffc4e5';
}
