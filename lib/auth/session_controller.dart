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

  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    final result = await _authService.signIn(
      username: username,
      password: password,
    );

    if (result.isSuccess) {
      _credentials = result.credentials;
      notifyListeners();
    }
  }

  Future<void> skip() async {
    final result = await _authService.skip();

    if (result.isSuccess) {
      _credentials = result.credentials;
      notifyListeners();
    }
  }

  void clearSession() {
    _credentials = null;
    notifyListeners();
  }
}
