import 'package:flutter/foundation.dart';

import '../../bunker/domain/bunker_setup_service.dart';
import '../../profile/domain/user_profile_service.dart';
import '../../survivors/domain/duplicate_catalog.dart';
import '../../survivors/domain/survivor.dart';
import '../../survivors/domain/survivor_development_service.dart';
import '../../survivors/domain/survivor_service.dart';
import '../domain/auth_service.dart';

class SessionController extends ChangeNotifier {
  SessionController({
    required AuthService authService,
    BunkerSetupService? bunkerSetupService,
    SurvivorDevelopmentService? survivorDevelopmentService,
    UserProfileService? userProfileService,
    SurvivorService? survivorService,
  }) : this._(
          authService,
          bunkerSetupService,
          survivorDevelopmentService,
          userProfileService,
          survivorService,
        );

  SessionController._(
    this._authService,
    this._bunkerSetupService,
    this._survivorDevelopmentService,
    this._userProfileService,
    this._survivorService,
  );

  final AuthService _authService;
  final BunkerSetupService? _bunkerSetupService;
  final SurvivorDevelopmentService? _survivorDevelopmentService;
  final UserProfileService? _userProfileService;
  final SurvivorService? _survivorService;

  AuthCredentials? _credentials;
  String? _profileUsername;
  String? _initialDuplicateId;
  List<Survivor> _survivors = const <Survivor>[];

  AuthCredentials? get credentials => _credentials;
  bool get isAuthenticated => _credentials != null;
  bool get needsProfileSetup =>
      isAuthenticated &&
      _credentials?.userId != null &&
      ((_profileUsername == null || _profileUsername!.trim().isEmpty) ||
          (_initialDuplicateId == null || _initialDuplicateId!.trim().isEmpty));
  String? get profileUsername => _profileUsername;
  String? get initialDuplicateId => _initialDuplicateId;
  List<Survivor> get survivors => List<Survivor>.unmodifiable(_survivors);
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
    required String duplicateId,
  }) async {
    final credentials = _credentials;
    final userId = credentials?.userId;

    if (credentials == null || userId == null) return false;

    final cleanUsername = username.trim();
    final cleanDuplicateId = duplicateId.trim();
    if (cleanUsername.length < 3 ||
        cleanUsername.length > 24 ||
        duplicateById(cleanDuplicateId) == null) {
      return false;
    }

    try {
      final bunkerSetupService = _bunkerSetupService;
      if (bunkerSetupService != null) {
        final result = await bunkerSetupService.initializeBunker(
          username: cleanUsername,
          duplicateId: cleanDuplicateId,
        );

        _profileUsername = cleanUsername;
        _initialDuplicateId = cleanDuplicateId;

        final survivorService = _survivorService;
        if (survivorService != null) {
          try {
            _survivors = await survivorService.loadSurvivors(userId: userId);
          } catch (_) {
            _survivors = const <Survivor>[];
          }
        }

        if (_survivors.isEmpty) {
          _survivors = <Survivor>[
            Survivor(
              id: result.survivorId,
              duplicateId: cleanDuplicateId,
            ),
          ];
        }

        notifyListeners();
        return true;
      }

      // Compatibility path for tests or alternative builds without a trusted
      // bunker setup service. Production injects the Cloud Functions service.
      final profileService = _userProfileService;
      final survivorService = _survivorService;
      if (profileService == null || survivorService == null) return false;

      final initialSurvivor = Survivor(duplicateId: cleanDuplicateId);
      await survivorService.saveInitialSurvivor(
        userId: userId,
        survivor: initialSurvivor,
      );
      await profileService.saveInitialProfile(
        userId: userId,
        email: credentials.email ?? credentials.username,
        username: cleanUsername,
        initialDuplicateId: cleanDuplicateId,
      );

      _profileUsername = cleanUsername;
      _initialDuplicateId = cleanDuplicateId;
      _survivors = await survivorService.loadSurvivors(userId: userId);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Temporary development-only command. The mutation itself is executed by a
  /// callable Cloud Function so Firestore remains server-authoritative.
  Future<bool> addSurvivorForTesting(String duplicateId) async {
    final developmentService = _survivorDevelopmentService;
    final survivorService = _survivorService;
    final userId = _credentials?.userId;
    final cleanDuplicateId = duplicateId.trim();

    if (developmentService == null ||
        survivorService == null ||
        userId == null ||
        duplicateById(cleanDuplicateId) == null ||
        _survivors.any((survivor) => survivor.duplicateId == cleanDuplicateId)) {
      return false;
    }

    try {
      await developmentService.addSurvivorForTesting(
        duplicateId: cleanDuplicateId,
      );
      _survivors = await survivorService.loadSurvivors(userId: userId);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> clearInitialProfileForTesting() async {
    final profileService = _userProfileService;
    final survivorService = _survivorService;
    final userId = _credentials?.userId;

    if (profileService == null || survivorService == null || userId == null) {
      return false;
    }

    try {
      await survivorService.clearAllSurvivorsForTesting(userId: userId);
      await profileService.clearInitialProfile(userId: userId);
      _profileUsername = null;
      _initialDuplicateId = null;
      _survivors = const <Survivor>[];
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
    _initialDuplicateId = null;
    _survivors = const <Survivor>[];
    notifyListeners();
  }

  Future<void> _applySuccessfulAuth(AuthResult result) async {
    if (!result.isSuccess || result.credentials == null) return;

    _credentials = result.credentials;
    _profileUsername = null;
    _initialDuplicateId = null;
    _survivors = const <Survivor>[];

    final userId = _credentials?.userId;
    final profileService = _userProfileService;
    final survivorService = _survivorService;

    if (userId == null) {
      _profileUsername = _credentials?.username;
    } else {
      if (profileService != null) {
        try {
          final profile = await profileService.loadProfile(userId: userId);
          if (profile?.hasUsername == true) {
            _profileUsername = profile!.username!.trim();
          }
          if (profile?.hasInitialDuplicate == true) {
            _initialDuplicateId = profile!.initialDuplicateId!.trim();
          }
        } catch (_) {
          // Keep the authenticated session. The profile flow can retry later.
        }
      }

      if (survivorService != null) {
        try {
          _survivors = await survivorService.loadSurvivors(userId: userId);

          // One-time compatibility path for profiles created before BunkerState
          // existed. Production repairs/migrates them through the trusted
          // initializeBunker callable rather than writing Survivors directly.
          final duplicateId = _initialDuplicateId;
          final profileUsername = _profileUsername;
          final bunkerSetupService = _bunkerSetupService;
          if (_survivors.isEmpty &&
              duplicateId != null &&
              duplicateById(duplicateId) != null &&
              profileUsername != null &&
              profileUsername.isNotEmpty &&
              bunkerSetupService != null) {
            await bunkerSetupService.initializeBunker(
              username: profileUsername,
              duplicateId: duplicateId,
            );
            _survivors = await survivorService.loadSurvivors(userId: userId);
          }
        } catch (_) {
          // Profile/authentication remains usable even if roster loading fails.
        }
      }
    }

    notifyListeners();
  }
}
