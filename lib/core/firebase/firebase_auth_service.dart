import 'package:firebase_auth/firebase_auth.dart';

import '../../features/auth/domain/auth_service.dart';

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
      return _successFromUser(result.user, username);
    } on FirebaseAuthException catch (error) {
      return AuthResult.failure(_mapFailure(error.code));
    }
  }

  @override
  Future<AuthResult> register({
    required String username,
    required String password,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: username.trim(),
        password: password,
      );
      return _successFromUser(result.user, username);
    } on FirebaseAuthException catch (error) {
      return AuthResult.failure(_mapFailure(error.code));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  AuthResult _successFromUser(User? user, String fallbackEmail) {
    final email = user?.email ?? fallbackEmail.trim();
    return AuthResult.success(
      AuthCredentials(
        username: email,
        password: '',
        userId: user?.uid,
        email: email,
      ),
    );
  }

  AuthFailure _mapFailure(String code) {
    switch (code) {
      case 'email-already-in-use':
        return AuthFailure.emailAlreadyInUse;
      case 'invalid-email':
        return AuthFailure.invalidEmail;
      case 'weak-password':
        return AuthFailure.weakPassword;
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return AuthFailure.invalidCredentials;
      case 'too-many-requests':
        return AuthFailure.tooManyRequests;
      default:
        return AuthFailure.unknown;
    }
  }
}
