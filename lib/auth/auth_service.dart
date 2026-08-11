class AuthCredentials {
  const AuthCredentials({
    required this.username,
    required this.password,
  });

  final String username;
  final String password;
}

class AuthResult {
  const AuthResult.success(this.credentials)
      : isSuccess = true,
        errorMessage = null;

  const AuthResult.failure(this.errorMessage)
      : isSuccess = false,
        credentials = null;

  final bool isSuccess;
  final AuthCredentials? credentials;
  final String? errorMessage;
}

abstract class AuthService {
  Future<AuthResult> signIn({
    required String username,
    required String password,
  });

  Future<AuthResult> register({
    required String username,
    required String password,
  });

  Future<AuthResult> skip();

  Future<void> signOut();
}

/// Temporary implementation kept for tests and local development helpers.
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
  Future<AuthResult> register({
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

  @override
  Future<void> signOut() async {}
}
