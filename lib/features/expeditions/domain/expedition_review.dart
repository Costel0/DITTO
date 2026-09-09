import 'expedition.dart';

DateTime _requiredReviewDate(Object? raw, String field) {
  final parsed = raw is String ? DateTime.tryParse(raw)?.toUtc() : null;
  if (parsed == null) {
    throw FormatException('$field must be an ISO-8601 timestamp.');
  }
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
  );
}

Map<String, int> _positiveInventoryMap(Object? raw, String field) {
  if (raw is! Map) {
    throw FormatException('$field must be an object.');
  }

  final result = <String, int>{};
  for (final entry in raw.entries) {
    if (entry.key is! String || entry.value is! num) {
      throw FormatException('$field contains an invalid item quantity.');
    }
    final quantity = (entry.value as num).toInt();
    if (quantity <= 0) continue;
    result[entry.key as String] = quantity;
  }
  return Map<String, int>.unmodifiable(result);
}

class ExpeditionReviewSummary {
  const ExpeditionReviewSummary({
    required this.id,
    required this.expeditionType,
    required this.actionIds,
    required this.survivorIds,
    required this.coordinates,
    required this.completedAt,
    this.executionId,
  });

  final String id;
  final String? executionId;
  final String expeditionType;
  final List<String> actionIds;
  final List<String> survivorIds;
  final ExpeditionCoordinates coordinates;
  final DateTime completedAt;

  factory ExpeditionReviewSummary.fromMap(Map<String, dynamic> map) {
    String requiredString(String field) {
      final raw = map[field];
      if (raw is! String || raw.trim().isEmpty) {
        throw FormatException('$field must be a non-empty string.');
      }
      return raw.trim();
    }

    List<String> stringList(String field) {
      final raw = map[field];
      if (raw is! List || raw.any((value) => value is! String)) {
        throw FormatException('$field must be a list of strings.');
      }
      return List<String>.unmodifiable(
        raw.cast<String>().map((value) => value.trim()).where(
              (value) => value.isNotEmpty,
            ),
      );
    }

    final coordinatesRaw = map['coordinates'];
    if (coordinatesRaw is! Map) {
      throw const FormatException('Invalid expedition review summary.');
    }

    final rawExecutionId = map['executionId'];
    return ExpeditionReviewSummary(
      id: requiredString('id'),
      executionId: rawExecutionId is String && rawExecutionId.trim().isNotEmpty
          ? rawExecutionId.trim()
          : null,
      expeditionType: requiredString('expeditionType'),
      actionIds: stringList('actionIds'),
      survivorIds: stringList('survivorIds'),
      coordinates: ExpeditionCoordinates.fromMap(
        Map<String, dynamic>.from(coordinatesRaw),
      ),
      completedAt: _requiredReviewDate(map['completedAt'], 'completedAt'),
    );
  }
}

class ExpeditionOutcomeReview {
  const ExpeditionOutcomeReview({
    required this.actionId,
    required this.outcomeId,
    required this.narrativeId,
    required this.inventoryDelta,
    this.imageKey,
    this.eventPoolId,
  });

  final String actionId;
  final String outcomeId;
  final String narrativeId;
  final Map<String, int> inventoryDelta;
  final String? imageKey;

  /// Reserved hook for the future event system. The current implementation
  /// records the event pool selected by the backend but does not resolve it.
  final String? eventPoolId;

  factory ExpeditionOutcomeReview.fromMap(Map<String, dynamic> map) {
    String requiredString(String field) {
      final raw = map[field];
      if (raw is! String || raw.trim().isEmpty) {
        throw FormatException('$field must be a non-empty string.');
      }
      return raw.trim();
    }

    final eventTriggerRaw = map['eventTrigger'];
    String? eventPoolId;
    if (eventTriggerRaw is Map) {
      final rawPoolId = eventTriggerRaw['poolId'];
      if (rawPoolId is String && rawPoolId.trim().isNotEmpty) {
        eventPoolId = rawPoolId.trim();
      }
    }

    final rawImageKey = map['imageKey'];
    return ExpeditionOutcomeReview(
      actionId: requiredString('actionId'),
      outcomeId: requiredString('outcomeId'),
      narrativeId: requiredString('narrativeId'),
      inventoryDelta: _positiveInventoryMap(
        map['inventoryDelta'] ?? const <String, int>{},
        'inventoryDelta',
      ),
      imageKey: rawImageKey is String && rawImageKey.trim().isNotEmpty
          ? rawImageKey.trim()
          : null,
      eventPoolId: eventPoolId,
    );
  }
}

class ExpeditionReview {
  const ExpeditionReview({
    required this.id,
    required this.expeditionType,
    required this.actionIds,
    required this.survivorIds,
    required this.coordinates,
    required this.completedAt,
    required this.inventoryDelta,
    required this.outcomes,
    this.executionId,
  });

  final String id;
  final String? executionId;
  final String expeditionType;
  final List<String> actionIds;
  final List<String> survivorIds;
  final ExpeditionCoordinates coordinates;
  final DateTime completedAt;
  final Map<String, int> inventoryDelta;
  final List<ExpeditionOutcomeReview> outcomes;

  factory ExpeditionReview.fromMap(Map<String, dynamic> map) {
    String requiredString(String field) {
      final raw = map[field];
      if (raw is! String || raw.trim().isEmpty) {
        throw FormatException('$field must be a non-empty string.');
      }
      return raw.trim();
    }

    List<String> stringList(String field) {
      final raw = map[field];
      if (raw is! List || raw.any((value) => value is! String)) {
        throw FormatException('$field must be a list of strings.');
      }
      return List<String>.unmodifiable(
        raw.cast<String>().map((value) => value.trim()).where(
              (value) => value.isNotEmpty,
            ),
      );
    }

    final coordinatesRaw = map['coordinates'];
    final outcomesRaw = map['outcomes'];
    if (coordinatesRaw is! Map || outcomesRaw is! List) {
      throw const FormatException('Invalid expedition review payload.');
    }

    final rawExecutionId = map['executionId'];
    return ExpeditionReview(
      id: requiredString('id'),
      executionId: rawExecutionId is String && rawExecutionId.trim().isNotEmpty
          ? rawExecutionId.trim()
          : null,
      expeditionType: requiredString('expeditionType'),
      actionIds: stringList('actionIds'),
      survivorIds: stringList('survivorIds'),
      coordinates: ExpeditionCoordinates.fromMap(
        Map<String, dynamic>.from(coordinatesRaw),
      ),
      completedAt: _requiredReviewDate(map['completedAt'], 'completedAt'),
      inventoryDelta: _positiveInventoryMap(
        map['inventoryDelta'] ?? const <String, int>{},
        'inventoryDelta',
      ),
      outcomes: List<ExpeditionOutcomeReview>.unmodifiable(
        outcomesRaw.map((raw) {
          if (raw is! Map) {
            throw const FormatException('Invalid expedition outcome review.');
          }
          return ExpeditionOutcomeReview.fromMap(
            Map<String, dynamic>.from(raw),
          );
        }),
      ),
    );
  }
}
