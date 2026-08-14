import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/profile/domain/user_profile.dart';
import '../../features/profile/domain/user_profile_service.dart';

class FirestoreUserProfileService implements UserProfileService {
  FirestoreUserProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  String? _readInitialDuplicateId(Map<String, dynamic> data) {
    final current = data['initialDuplicateId'] as String?;
    if (current != null && current.trim().isNotEmpty) {
      return current.trim();
    }

    // Temporary compatibility for profiles created before Duplicate IDs existed.
    final legacyCharacterId = data['characterId'] as String?;
    if (legacyCharacterId == null || legacyCharacterId.trim().isEmpty) {
      return null;
    }
    final legacy = legacyCharacterId.trim();
    return legacy.startsWith('survivor_')
        ? legacy.substring('survivor_'.length)
        : legacy;
  }

  @override
  Future<UserProfile?> loadProfile({required String userId}) async {
    final snapshot = await _users.doc(userId).get();
    if (!snapshot.exists) return null;

    final data = snapshot.data() ?? const <String, dynamic>{};
    return UserProfile(
      userId: userId,
      email: data['email'] as String? ?? '',
      username: data['username'] as String?,
      initialDuplicateId: _readInitialDuplicateId(data),
    );
  }

  @override
  Future<void> saveInitialProfile({
    required String userId,
    required String email,
    required String username,
    required String initialDuplicateId,
  }) async {
    final reference = _users.doc(userId);
    final cleanUsername = username.trim();
    final cleanDuplicateId = initialDuplicateId.trim();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = <String, dynamic>{
        'email': email.trim(),
        'username': cleanUsername,
        'initialDuplicateId': cleanDuplicateId,
        'characterId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!snapshot.exists) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      transaction.set(reference, data, SetOptions(merge: true));
    });
  }

  @override
  Future<void> clearInitialProfile({required String userId}) async {
    final reference = _users.doc(userId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) return;

      transaction.update(reference, <String, dynamic>{
        'username': FieldValue.delete(),
        'initialDuplicateId': FieldValue.delete(),
        'characterId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
