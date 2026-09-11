import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/expeditions/domain/expedition.dart';
import '../../features/expeditions/domain/expedition_review.dart';
import '../../features/expeditions/domain/expedition_service.dart';
import 'firebase_functions_config.dart';

class FirebaseFunctionsExpeditionService implements ExpeditionService {
  FirebaseFunctionsExpeditionService({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _functions = functions ??
            FirebaseFunctions.instanceFor(region: firebaseFunctionsRegion),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _userId {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Authentication is required for expeditions.');
    }
    return uid;
  }

  DocumentReference<Map<String, dynamic>> get _bunkerReference => _firestore
      .collection('users')
      .doc(_userId)
      .collection('state')
      .doc('bunker');

  @override
  Future<ExpeditionLauncherInfo> fetchLauncherInfo() async {
    final callable = _functions.httpsCallable('getExpeditionLauncherInfo');
    final result = await callable.call();
    final data = result.data;
    if (data is! Map) {
      throw const FormatException('Invalid expedition launcher response.');
    }

    // The callable is the single authoritative launcher payload. In
    // particular, it normalizes knownZones and always includes the player's
    // own bunker as PLAYER_BUNKER. Do not overwrite that list with a separate
    // Firestore read, otherwise stale/legacy bunker documents can make the UI
    // incorrectly treat the player's own bunker as an unknown zone.
    return ExpeditionLauncherInfo.fromMap(
      _normalizeMap(Map<String, dynamic>.from(data)),
    );
  }

  @override
  Future<List<ExpeditionReviewSummary>> fetchPendingReviews() async {
    final snapshot = await _bunkerReference.get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw StateError('Bunker is not initialized.');
    }

    final rawReviews = data['pendingExpeditionReviews'];
    if (rawReviews == null) return const <ExpeditionReviewSummary>[];
    if (rawReviews is! List) {
      throw const FormatException(
        'pendingExpeditionReviews must be a list.',
      );
    }

    final reviews = <ExpeditionReviewSummary>[];
    for (final raw in rawReviews) {
      if (raw is! Map) {
        throw const FormatException('Invalid pending expedition review.');
      }
      reviews.add(
        ExpeditionReviewSummary.fromMap(
          _normalizeMap(Map<String, dynamic>.from(raw)),
        ),
      );
    }
    reviews.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return List<ExpeditionReviewSummary>.unmodifiable(reviews);
  }

  @override
  Future<ExpeditionReview> fetchExpeditionReview(String reviewId) async {
    final normalizedId = reviewId.trim();
    if (normalizedId.isEmpty) {
      throw const FormatException('Invalid expedition review ID.');
    }

    final callable = _functions.httpsCallable('getExpeditionReview');
    final result = await callable.call(<String, dynamic>{
      'reviewId': normalizedId,
    });
    final data = result.data;
    if (data is! Map || data['review'] is! Map) {
      throw const FormatException('Invalid expedition review response.');
    }

    return ExpeditionReview.fromMap(
      _normalizeMap(
        Map<String, dynamic>.from(data['review'] as Map),
      ),
    );
  }

  @override
  Future<ExpeditionResolutionResult> resolveExpeditionReview({
    required String reviewId,
    required Map<String, String> choices,
  }) async {
    final normalizedId = reviewId.trim();
    if (normalizedId.isEmpty || choices.isEmpty) {
      throw const FormatException('Invalid expedition resolution request.');
    }

    final callable = _functions.httpsCallable('resolveExpeditionReview');
    final result = await callable.call(<String, dynamic>{
      'reviewId': normalizedId,
      'choices': Map<String, String>.from(choices),
    });
    final data = result.data;
    if (data is! Map) {
      throw const FormatException('Invalid expedition resolution response.');
    }

    return ExpeditionResolutionResult.fromMap(
      _normalizeMap(Map<String, dynamic>.from(data)),
    );
  }

  @override
  Future<void> startExpedition({
    required List<String> survivorIds,
    required ExpeditionCoordinates coordinates,
    required List<String> actionIds,
  }) async {
    final callable = _functions.httpsCallable('startExpedition');
    await callable.call(<String, dynamic>{
      'survivorIds': survivorIds.map((id) => id.trim()).toList(growable: false),
      'coordinates': coordinates.toMap(),
      'actionIds': actionIds.map((id) => id.trim()).toList(growable: false),
    });
  }

  Map<String, dynamic> _normalizeMap(Map<String, dynamic> source) {
    return source.map(
      (key, value) => MapEntry(key, _normalizeValue(value)),
    );
  }

  dynamic _normalizeValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toUtc().toIso8601String();
    }
    if (value is Map) {
      return value.map(
        (key, nestedValue) => MapEntry(
          key.toString(),
          _normalizeValue(nestedValue),
        ),
      );
    }
    if (value is List) {
      return value.map(_normalizeValue).toList(growable: false);
    }
    return value;
  }
}
