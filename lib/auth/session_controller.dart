import 'package:flutter/foundation.dart';

import 'auth_service.dart';

class SessionController extends ChangeNotifier {
  SessionController({required AuthService authService})
      : _authService = authService;

  final AuthService _authService;

  AuthCredentials? _credentials;

  AuthCredentials? get credentials => _credentials;
  bool get isAuthenticated => _credentials != null;
  String get username => _credentials?.username ?? '';

  Future<AuthResult> signIn({
    required String username,
    required String password,
  }) async {
    final result = await _authService.signIn(
      username: username,
      password: password,
    );

    if (result.isSuccess && result.credentials != null) {
      _credentials = result.credentials;
      notifyListeners();
    }

    return result;
  }

  Future<AuthResult> skip() async {
    final result = await _authService.skip();

    if (result.isSuccess && result.credentials != null) {
      _credentials = result.credentials;
      notifyListeners();
    }

    return result;
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _credentials = null;
    notifyListeners();
  }
}
