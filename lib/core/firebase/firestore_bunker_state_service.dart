import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../features/bunker/domain/bunker_state.dart';
import '../../features/bunker/domain/bunker_state_service.dart';
import 'firebase_functions_config.dart';

class FirestoreBunkerStateService implements BunkerStateService {
  FirestoreBunkerStateService({
    required this.userId,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: firebaseFunctionsRegion);

  final String userId;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  DocumentReference<Map<String, dynamic>> get _reference => _firestore
      .collection('users')
      .doc(userId)
      .collection('state')
      .doc('bunker');

  @override
  Future<BunkerState> fetchBunkerState() async {
    var state = await _fetchState();

    // Temporary development fallback. Production completion should be triggered
    // by trusted backend infrastructure, but the resolver itself remains the
    // same server-authoritative and idempotent Cloud Function.
    if (kDebugMode && _hasLocallyExpiredOccupation(state)) {
      final callable = _functions.httpsCallable('resolveCompletedOccupations');
      await callable.call();
      state = await _fetchState();
    }

    return state;
  }

  Future<BunkerState> _fetchState() async {
    final snapshot = await _reference.get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw StateError('No bunker state exists for user $userId.');
    }

    final normalized = _normalizeFirestoreMap(data);
    return BunkerState.fromJson(normalized);
  }

  bool _hasLocallyExpiredOccupation(BunkerState state) {
    final now = DateTime.now().toUtc();
    return state.busySurvivors.any(
      (occupation) => !occupation.endsAt.isAfter(now),
    );
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
