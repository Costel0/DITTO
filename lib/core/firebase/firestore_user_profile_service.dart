import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/profile/domain/user_profile.dart';
import '../../features/profile/domain/user_profile_service.dart';

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
    return UserProfile(
      userId: userId,
      email: data['email'] as String? ?? '',
      username: data['username'] as String?,
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
