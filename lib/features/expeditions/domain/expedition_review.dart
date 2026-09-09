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
    final rawQuantity = entry.value as num;
    if (!rawQuantity.isFinite || rawQuantity != rawQuantity.toInt()) {
      throw FormatException('$field quantities must be integers.');
    }
    final quantity = rawQuantity.toInt();
    if (quantity <= 0) continue;
    result[entry.key as String] = quantity;
  }
  return Map<String, int>.unmodifiable(result);
}

String _requiredString(Map<String, dynamic> map, String field) {
  final raw = map[field];
  if (raw is! String || raw.trim().isEmpty) {
    throw FormatException('$field must be a non-empty string.');
  }
  return raw.trim();
}

List<String> _stringList(Map<String, dynamic> map, String field) {
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

class ExpeditionReviewSummary {
  const ExpeditionReviewSummary({
    required this.id,
    required this.expeditionType,
    required this.actionIds,
    required this.survivorIds,
    required this.coordinates,
    required this.completedAt,
    required this.resolutionStatus,
    this.executionId,
  });

  final String id;
  final String? executionId;
  final String expeditionType;
  final List<String> actionIds;
  final List<String> survivorIds;
  final ExpeditionCoordinates coordinates;
  final DateTime completedAt;

  /// This summary exists only between the automatic and interactive phases.
  final String resolutionStatus;

  factory ExpeditionReviewSummary.fromMap(Map<String, dynamic> map) {
    final coordinatesRaw = map['coordinates'];
    if (coordinatesRaw is! Map) {
      throw const FormatException('Invalid expedition review summary.');
    }

    final rawExecutionId = map['executionId'];
    final rawStatus = map['resolutionStatus'];
    return ExpeditionReviewSummary(
      id: _requiredString(map, 'id'),
      executionId: rawExecutionId is String && rawExecutionId.trim().isNotEmpty
          ? rawExecutionId.trim()
          : null,
      expeditionType: _requiredString(map, 'expeditionType'),
      actionIds: _stringList(map, 'actionIds'),
      survivorIds: _stringList(map, 'survivorIds'),
      coordinates: ExpeditionCoordinates.fromMap(
        Map<String, dynamic>.from(coordinatesRaw),
      ),
      completedAt: _requiredReviewDate(map['completedAt'], 'completedAt'),
      resolutionStatus:
          rawStatus is String && rawStatus.trim().isNotEmpty
              ? rawStatus.trim()
              : 'pending_interactive',
    );
  }
}

class ExpeditionResolutionOption {
  const ExpeditionResolutionOption({
    required this.id,
    required this.labelId,
    required this.inventoryDelta,
    this.eventPoolId,
  });

  final String id;
  final String labelId;
  final Map<String, int> inventoryDelta;

  /// Reserved for the future event engine. Choosing the option may emit this
  /// hook, but the current backend deliberately performs no event logic.
  final String? eventPoolId;

  factory ExpeditionResolutionOption.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    final eventTriggerRaw = map['eventTrigger'];
    String? eventPoolId;
    if (eventTriggerRaw is Map) {
      final rawPoolId = eventTriggerRaw['poolId'];
      if (rawPoolId is String && rawPoolId.trim().isNotEmpty) {
        eventPoolId = rawPoolId.trim();
      }
    }

    return ExpeditionResolutionOption(
      id: id,
      labelId: _requiredString(map, 'labelId'),
      inventoryDelta: _positiveInventoryMap(
        map['inventoryDelta'] ?? const <String, int>{},
        'inventoryDelta',
      ),
      eventPoolId: eventPoolId,
    );
  }
}

class ExpeditionOutcomeReview {
  const ExpeditionOutcomeReview({
    required this.actionId,
    required this.outcomeId,
    required this.narrativeId,
    required this.resolutionOptions,
    this.imageKey,
  });

  final String actionId;
  final String outcomeId;
  final String narrativeId;
  final List<ExpeditionResolutionOption> resolutionOptions;
  final String? imageKey;

  factory ExpeditionOutcomeReview.fromMap(Map<String, dynamic> map) {
    final optionsRaw = map['resolutionOptions'];
    if (optionsRaw is! Map || optionsRaw.isEmpty) {
      throw const FormatException(
        'Expedition outcome must contain resolution options.',
      );
    }

    final options = <ExpeditionResolutionOption>[];
    for (final entry in optionsRaw.entries) {
      if (entry.key is! String || entry.value is! Map) {
        throw const FormatException('Invalid expedition resolution option.');
      }
      final optionId = (entry.key as String).trim();
      if (optionId.isEmpty) {
        throw const FormatException('Resolution option ID cannot be empty.');
      }
      options.add(
        ExpeditionResolutionOption.fromMap(
          optionId,
          Map<String, dynamic>.from(entry.value as Map),
        ),
      );
    }

    final rawImageKey = map['imageKey'];
    return ExpeditionOutcomeReview(
      actionId: _requiredString(map, 'actionId'),
      outcomeId: _requiredString(map, 'outcomeId'),
      narrativeId: _requiredString(map, 'narrativeId'),
      resolutionOptions:
          List<ExpeditionResolutionOption>.unmodifiable(options),
      imageKey: rawImageKey is String && rawImageKey.trim().isNotEmpty
          ? rawImageKey.trim()
          : null,
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
    required this.automaticResolvedAt,
    required this.interactiveResolutionStatus,
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

  /// First resolution: automatic and already completed before this report can
  /// appear in the list.
  final DateTime automaticResolvedAt;

  /// Second resolution: remains pending while the popup can be reopened.
  final String interactiveResolutionStatus;

  final List<ExpeditionOutcomeReview> outcomes;

  factory ExpeditionReview.fromMap(Map<String, dynamic> map) {
    final coordinatesRaw = map['coordinates'];
    final outcomesRaw = map['outcomes'];
    final automaticRaw = map['automaticResolution'];
    final interactiveRaw = map['interactiveResolution'];
    if (coordinatesRaw is! Map ||
        outcomesRaw is! List ||
        outcomesRaw.isEmpty ||
        automaticRaw is! Map ||
        interactiveRaw is! Map) {
      throw const FormatException('Invalid expedition review payload.');
    }

    final automaticMap = Map<String, dynamic>.from(automaticRaw);
    final interactiveMap = Map<String, dynamic>.from(interactiveRaw);
    if (_requiredString(automaticMap, 'status') != 'resolved') {
      throw const FormatException(
        'Expedition automatic resolution must already be resolved.',
      );
    }

    final rawExecutionId = map['executionId'];
    return ExpeditionReview(
      id: _requiredString(map, 'id'),
      executionId: rawExecutionId is String && rawExecutionId.trim().isNotEmpty
          ? rawExecutionId.trim()
          : null,
      expeditionType: _requiredString(map, 'expeditionType'),
      actionIds: _stringList(map, 'actionIds'),
      survivorIds: _stringList(map, 'survivorIds'),
      coordinates: ExpeditionCoordinates.fromMap(
        Map<String, dynamic>.from(coordinatesRaw),
      ),
      completedAt: _requiredReviewDate(map['completedAt'], 'completedAt'),
      automaticResolvedAt: _requiredReviewDate(
        automaticMap['resolvedAt'],
        'automaticResolution.resolvedAt',
      ),
      interactiveResolutionStatus:
          _requiredString(interactiveMap, 'status'),
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

class ExpeditionResolutionResult {
  const ExpeditionResolutionResult({
    required this.reviewId,
    required this.inventoryDelta,
    required this.revision,
  });

  final String reviewId;
  final Map<String, int> inventoryDelta;
  final int revision;

  factory ExpeditionResolutionResult.fromMap(Map<String, dynamic> map) {
    final revisionRaw = map['revision'];
    if (revisionRaw is! num ||
        !revisionRaw.isFinite ||
        revisionRaw != revisionRaw.toInt()) {
      throw const FormatException('Invalid expedition resolution revision.');
    }

    return ExpeditionResolutionResult(
      reviewId: _requiredString(map, 'reviewId'),
      inventoryDelta: _positiveInventoryMap(
        map['inventoryDelta'] ?? const <String, int>{},
        'inventoryDelta',
      ),
      revision: revisionRaw.toInt(),
    );
  }
}
