class AuthCredentials {
  const AuthCredentials({
    required this.username,
    required this.password,
  });

  final String username;
  final String password;
}

class AuthResult {
  const AuthResult.success(this.credentials) : isSuccess = true;

  final bool isSuccess;
  final AuthCredentials credentials;
}

abstract class AuthService {
  Future<AuthResult> signIn({
    required String username,
    required String password,
  });

  Future<AuthResult> skip();
}

/// Temporary implementation used while the real authentication flow is pending.
///
/// Every username/password pair is currently accepted. Replacing this class
/// with an API, Firebase Auth, OAuth, etc. will not require changing the UI.
class PlaceholderAuthService implements AuthService {
  @override
  Future<AuthResult> signIn({
    required String username,
    required String password,
  }) async {
    return AuthResult.success(
      AuthCredentials(username: username, password: password),
    );
  }

  @override
  Future<AuthResult> skip() async {
    return const AuthResult.success(
      AuthCredentials(username: 'user', password: 'password'),
    );
  }
}
