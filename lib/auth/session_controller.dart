import 'package:flutter/foundation.dart';

import '../profile/user_profile_service.dart';
import 'auth_service.dart';

class SessionController extends ChangeNotifier {
  SessionController({
    required AuthService authService,
    UserProfileService? userProfileService,
  })  : _authService = authService,
        _userProfileService = userProfileService;

  final AuthService _authService;
  final UserProfileService? _userProfileService;

  AuthCredentials? _credentials;
  String? _profileUsername;

  AuthCredentials? get credentials => _credentials;
  bool get isAuthenticated => _credentials != null;
  bool get needsUsername =>
      isAuthenticated &&
      _credentials?.userId != null &&
      (_profileUsername == null || _profileUsername!.trim().isEmpty);
  String get username => _profileUsername ?? _credentials?.username ?? '';
  String get email => _credentials?.email ?? _credentials?.username ?? '';

  Future<AuthResult> signIn({
    required String username,
    required String password,
  }) async {
    final result = await _authService.signIn(
      username: username,
      password: password,
    );

    await _applySuccessfulAuth(result);
    return result;
  }

  Future<AuthResult> register({
    required String username,
    required String password,
  }) async {
    final result = await _authService.register(
      username: username,
      password: password,
    );

    await _applySuccessfulAuth(result);
    return result;
  }

  Future<AuthResult> skip() async {
    final result = await _authService.skip();

    await _applySuccessfulAuth(result);
    return result;
  }

  Future<String?> saveUsername(String username) async {
    final credentials = _credentials;
    final service = _userProfileService;
    final userId = credentials?.userId;

    if (credentials == null || service == null || userId == null) {
      return 'Unable to save the user profile.';
    }

    try {
      await service.saveUsername(
        userId: userId,
        email: credentials.email ?? credentials.username,
        username: username.trim(),
      );
      _profileUsername = username.trim();
      notifyListeners();
      return null;
    } catch (_) {
      return 'Unable to save the username. Please try again.';
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _credentials = null;
    _profileUsername = null;
    notifyListeners();
  }

  Future<void> _applySuccessfulAuth(AuthResult result) async {
    if (!result.isSuccess || result.credentials == null) return;

    _credentials = result.credentials;
    _profileUsername = null;

    final userId = _credentials?.userId;
    final profileService = _userProfileService;

    if (userId == null) {
      _profileUsername = _credentials?.username;
    } else if (profileService != null) {
      try {
        final profile = await profileService.loadProfile(userId: userId);
        if (profile?.hasUsername == true) {
          _profileUsername = profile!.username!.trim();
        }
      } catch (_) {
        // Authentication remains valid. The profile setup screen can retry
        // once Firestore becomes available again.
      }
    }

    notifyListeners();
  }
}
