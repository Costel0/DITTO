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

    final normalized = _normalizeFirestoreMap(data);
    return BunkerState.fromJson(normalized);
  }

  Map<String, dynamic> _normalizeFirestoreMap(Map<String, dynamic> source) {
    return source.map(
      (key, value) => MapEntry(key, _normalizeFirestoreValue(value)),
    );
  }

  dynamic _normalizeFirestoreValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toUtc().toIso8601String();
    }
    if (value is Map) {
      return value.map(
        (key, nestedValue) => MapEntry(
          key.toString(),
          _normalizeFirestoreValue(nestedValue),
        ),
      );
    }
    if (value is List) {
      return value.map(_normalizeFirestoreValue).toList(growable: false);
    }
    return value;
  }
}
