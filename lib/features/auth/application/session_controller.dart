import 'package:flutter/foundation.dart';

import '../../profile/domain/user_profile_service.dart';
import '../../survivors/domain/duplicate_catalog.dart';
import '../../survivors/domain/survivor.dart';
import '../../survivors/domain/survivor_service.dart';
import '../domain/auth_service.dart';

class SessionController extends ChangeNotifier {
  SessionController({
    required AuthService authService,
    UserProfileService? userProfileService,
    SurvivorService? survivorService,
  })  : _authService = authService,
        _userProfileService = userProfileService,
        _survivorService = survivorService;

  final AuthService _authService;
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
    final profileService = _userProfileService;
    final survivorService = _survivorService;
    final userId = credentials?.userId;

    if (credentials == null ||
        profileService == null ||
        survivorService == null ||
        userId == null) {
      return false;
    }

    final cleanUsername = username.trim();
    final cleanDuplicateId = duplicateId.trim();
    if (duplicateById(cleanDuplicateId) == null) return false;

    try {
      final initialSurvivor = Survivor(duplicateId: cleanDuplicateId);

      // The initial document has a deterministic ID, so retrying this flow does
      // not create duplicate Survivor instances. A future trusted server can
      // replace this client-side creation without changing the domain model.
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

  /// Temporary client-side helper used only by development controls.
  ///
  /// Production acquisition will eventually be server-authoritative. Keeping
  /// this method explicit makes the temporary trust boundary easy to remove.
  Future<bool> addSurvivorForTesting(String duplicateId) async {
    final survivorService = _survivorService;
    final userId = _credentials?.userId;
    final cleanDuplicateId = duplicateId.trim();

    if (survivorService == null ||
        userId == null ||
        duplicateById(cleanDuplicateId) == null ||
        _survivors.any((survivor) => survivor.duplicateId == cleanDuplicateId)) {
      return false;
    }

    try {
      await survivorService.addSurvivor(
        userId: userId,
        survivor: Survivor(duplicateId: cleanDuplicateId),
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

          // One-time compatibility path for profiles created before Survivors
          // were stored as their own Firestore documents.
          final duplicateId = _initialDuplicateId;
          if (_survivors.isEmpty &&
              duplicateId != null &&
              duplicateById(duplicateId) != null) {
            final migrated = Survivor(duplicateId: duplicateId);
            await survivorService.saveInitialSurvivor(
              userId: userId,
              survivor: migrated,
            );
            _survivors = <Survivor>[migrated];
          }
        } catch (_) {
          // Profile/authentication remains usable even if roster loading fails.
        }
      }
    }

    notifyListeners();
  }
}
