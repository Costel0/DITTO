import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/bunker/domain/bunker_state.dart';
import '../../features/bunker/domain/bunker_state_service.dart';

class FirestoreBunkerStateService implements BunkerStateService {
  FirestoreBunkerStateService({
    required this.userId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String userId;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _reference => _firestore
      .collection('users')
      .doc(userId)
      .collection('state')
      .doc('bunker');

  @override
  Future<BunkerState> fetchBunkerState() async {
    final snapshot = await _reference.get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw StateError('No bunker state exists for user $userId.');
    }

    final normalized = Map<String, dynamic>.from(data);
    final updatedAt = normalized['serverUpdatedAt'];
    if (updatedAt is Timestamp) {
      normalized['serverUpdatedAt'] = updatedAt.toDate().toUtc().toIso8601String();
    }

    return BunkerState.fromJson(normalized);
  }
}
