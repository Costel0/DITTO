import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Future<AuthResult> signIn({
    required String username,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: username.trim(),
        password: password,
      );
      return AuthResult.success(
        AuthCredentials(
          username: result.user?.email ?? username.trim(),
          password: '',
        ),
      );
    } on FirebaseAuthException catch (error) {
      return AuthResult.failure(error.message ?? 'Unable to sign in.');
    }
  }

  @override
  Future<AuthResult> skip() async {
    return const AuthResult.success(
      AuthCredentials(username: 'user', password: 'password'),
    );
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
