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
      return _successFromUser(result.user, username);
    } on FirebaseAuthException catch (error) {
      return AuthResult.failure(_messageFor(error));
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
      return AuthResult.failure(_messageFor(error));
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

  AuthResult _successFromUser(User? user, String fallbackEmail) {
    return AuthResult.success(
      AuthCredentials(
        username: user?.email ?? fallbackEmail.trim(),
        password: '',
      ),
    );
  }

  String _messageFor(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'weak-password':
        return 'Choose a stronger password.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }
}
