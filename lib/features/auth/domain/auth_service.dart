enum AuthFailure {
  emailAlreadyInUse,
  invalidEmail,
  weakPassword,
  invalidCredentials,
  tooManyRequests,
  unknown,
}

class AuthCredentials {
  const AuthCredentials({
    required this.username,
    required this.password,
    this.userId,
    this.email,
  });

  final String username;
  final String password;
  final String? userId;
  final String? email;
}

class AuthResult {
  const AuthResult.success(this.credentials)
      : isSuccess = true,
        failure = null;

  const AuthResult.failure(this.failure)
      : isSuccess = false,
        credentials = null;

  final bool isSuccess;
  final AuthCredentials? credentials;
  final AuthFailure? failure;
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

/// Test/local implementation. The production app uses FirebaseAuthService.
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
