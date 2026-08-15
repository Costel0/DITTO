import 'survivor_stats.dart';

class SurvivorHealthRecord {
  const SurvivorHealthRecord({
    required this.id,
    required this.type,
    required this.recordedAt,
    this.details,
  });

  final String id;
  final String type;
  final DateTime recordedAt;
  final String? details;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'type': type,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        if (details != null) 'details': details,
      };

  factory SurvivorHealthRecord.fromMap(Map<String, dynamic> map) {
    final recordedAtRaw = map['recordedAt'];
    final recordedAt = recordedAtRaw is String
        ? DateTime.tryParse(recordedAtRaw)?.toUtc()
        : null;

    if (recordedAt == null) {
      throw const FormatException(
        'Survivor health record recordedAt must be an ISO-8601 string.',
      );
    }

    return SurvivorHealthRecord(
      id: map['id'] as String? ?? '',
      type: map['type'] as String? ?? '',
      recordedAt: recordedAt,
      details: map['details'] as String?,
    );
  }
}

class Survivor {
  const Survivor({
    this.id = '',
    required this.duplicateId,
    this.statMods = SurvivorStats.zero,
    this.healthHistory = const <SurvivorHealthRecord>[],
    this.equippedItemIds = const <String>[],
  });

  /// Unique ID for this concrete Survivor instance.
  ///
  /// It is different from [duplicateId], which identifies the base archetype.
  final String id;
  final String duplicateId;
  final SurvivorStats statMods;
  final List<SurvivorHealthRecord> healthHistory;
  final List<String> equippedItemIds;

  String get idleAssetPath =>
      'assets/characters/survivor_${duplicateId}_idle.png';

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'duplicateId': duplicateId,
        'statMods': statMods.toMap(),
        'healthHistory': healthHistory
            .map((record) => record.toMap())
            .toList(growable: false),
        'equippedItemIds': List<String>.from(equippedItemIds),
      };

  factory Survivor.fromMap(Map<String, dynamic> map) {
    final healthHistoryRaw = map['healthHistory'];
    final healthHistory = <SurvivorHealthRecord>[];
    if (healthHistoryRaw is List) {
      for (final rawRecord in healthHistoryRaw) {
        if (rawRecord is Map) {
          healthHistory.add(
            SurvivorHealthRecord.fromMap(
              Map<String, dynamic>.from(rawRecord),
            ),
          );
        }
      }
    }

    final equippedItemsRaw = map['equippedItemIds'];
    final equippedItemIds = equippedItemsRaw is List
        ? equippedItemsRaw.whereType<String>().toList(growable: false)
        : const <String>[];

    return Survivor(
      id: map['id'] as String? ?? '',
      duplicateId: map['duplicateId'] as String? ?? '',
      statMods: SurvivorStats.fromMap(
        map['statMods'] as Map<String, dynamic>?,
      ),
      healthHistory: healthHistory,
      equippedItemIds: equippedItemIds,
    );
  }
}
