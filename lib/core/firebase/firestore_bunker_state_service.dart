import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

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

    // The client only decides whether it is worth requesting a resolution.
    // The callable uses server time and is the sole authority on whether any
    // execution is actually complete, so a wrong/manipulated device clock
    // cannot resolve work early.
    if (_hasLocallyExpiredExecution(state)) {
      state = await resolveCompletedOccupations();
    }

    return state;
  }

  @override
  Future<BunkerState> resolveCompletedOccupations() async {
    final callable = _functions.httpsCallable('resolveCompletedOccupations');
    await callable.call();
    return _fetchState();
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

  bool _hasLocallyExpiredExecution(BunkerState state) {
    final now = DateTime.now().toUtc();
    return state.busySurvivors.any(
          (occupation) => !occupation.endsAt.isAfter(now),
        ) ||
        state.activeBackgroundTasks.any(
          (task) => !task.endsAt.isAfter(now),
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
