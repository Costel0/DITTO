import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.email,
    required this.username,
  });

  final String userId;
  final String email;
  final String? username;

  bool get hasUsername => username != null && username!.trim().isNotEmpty;
}

abstract class UserProfileService {
  Future<UserProfile?> loadProfile({required String userId});

  Future<void> saveUsername({
    required String userId,
    required String email,
    required String username,
  });
}

class FirestoreUserProfileService implements UserProfileService {
  FirestoreUserProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  @override
  Future<UserProfile?> loadProfile({required String userId}) async {
    final snapshot = await _users.doc(userId).get();
    if (!snapshot.exists) return null;

    final data = snapshot.data() ?? const <String, dynamic>{};
    final username = data['username'] as String?;
    final email = data['email'] as String? ?? '';

    return UserProfile(
      userId: userId,
      email: email,
      username: username,
    );
  }

  @override
  Future<void> saveUsername({
    required String userId,
    required String email,
    required String username,
  }) async {
    final reference = _users.doc(userId);
    final cleanUsername = username.trim();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = <String, dynamic>{
        'email': email.trim(),
        'username': cleanUsername,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!snapshot.exists) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      transaction.set(reference, data, SetOptions(merge: true));
    });
  }
}
