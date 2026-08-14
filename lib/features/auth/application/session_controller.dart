import 'package:flutter/foundation.dart';

import '../../profile/domain/user_profile_service.dart';
import '../domain/auth_service.dart';

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
  String? _profileCharacterId;

  AuthCredentials? get credentials => _credentials;
  bool get isAuthenticated => _credentials != null;
  bool get needsProfileSetup =>
      isAuthenticated &&
      _credentials?.userId != null &&
      ((_profileUsername == null || _profileUsername!.trim().isEmpty) ||
          (_profileCharacterId == null || _profileCharacterId!.trim().isEmpty));
  String? get profileUsername => _profileUsername;
  String? get characterId => _profileCharacterId;
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

  Future<bool> saveInitialProfile({
    required String username,
    required String characterId,
  }) async {
    final credentials = _credentials;
    final service = _userProfileService;
    final userId = credentials?.userId;

    if (credentials == null || service == null || userId == null) {
      return false;
    }

    try {
      final cleanUsername = username.trim();
      final cleanCharacterId = characterId.trim();
      await service.saveInitialProfile(
        userId: userId,
        email: credentials.email ?? credentials.username,
        username: cleanUsername,
        characterId: cleanCharacterId,
      );
      _profileUsername = cleanUsername;
      _profileCharacterId = cleanCharacterId;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> clearInitialProfileForTesting() async {
    final service = _userProfileService;
    final userId = _credentials?.userId;

    if (service == null || userId == null) {
      return false;
    }

    try {
      await service.clearInitialProfile(userId: userId);
      _profileUsername = null;
      _profileCharacterId = null;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _credentials = null;
    _profileUsername = null;
    _profileCharacterId = null;
    notifyListeners();
  }

  Future<void> _applySuccessfulAuth(AuthResult result) async {
    if (!result.isSuccess || result.credentials == null) return;

    _credentials = result.credentials;
    _profileUsername = null;
    _profileCharacterId = null;

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
        if (profile?.hasCharacter == true) {
          _profileCharacterId = profile!.characterId!.trim();
        }
      } catch (_) {
        // Keep the authenticated session. The profile flow can retry later.
      }
    }

    notifyListeners();
  }
}
