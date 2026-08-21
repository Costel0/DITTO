import 'duplicate_catalog.dart';
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
  Survivor({
    this.id = '',
    required this.duplicateId,
    this.energy = 50,
    this.statMods = SurvivorStats.zero,
    List<SurvivorHealthRecord> healthHistory =
        const <SurvivorHealthRecord>[],
    List<String> equippedItemIds = const <String>[],
  })  : healthHistory = List<SurvivorHealthRecord>.unmodifiable(healthHistory),
        equippedItemIds = List<String>.unmodifiable(equippedItemIds);

  /// Unique ID for this concrete Survivor instance.
  ///
  /// It is different from [duplicateId], which identifies the base archetype.
  final String id;
  final String duplicateId;

  /// Current energy value. Energy is intentionally unbounded at the model
  /// level and may become negative as a consequence of gameplay.
  final int energy;

  final SurvivorStats statMods;
  final List<SurvivorHealthRecord> healthHistory;
  final List<String> equippedItemIds;

  String get idleAssetPath =>
      'assets/characters/survivor_${duplicateId}_idle.png';

  /// Square portrait used by compact reusable Survivor profile views.
  String get profileAssetPath =>
      'assets/characters/survivor_${duplicateId}_profile.png';

  /// Effective visible stat: Duplicate base value + permanent Survivor mods.
  int effectiveStat(String stat) {
    final base = duplicateById(duplicateId)?.baseStats ?? SurvivorStats.zero;
    switch (stat) {
      case 'strength':
        return base.strength + statMods.strength;
      case 'dexterity':
        return base.dexterity + statMods.dexterity;
      case 'constitution':
        return base.constitution + statMods.constitution;
      case 'stealth':
        return base.stealth + statMods.stealth;
      case 'care':
        return base.care + statMods.care;
      case 'cunning':
        return base.cunning + statMods.cunning;
      case 'charm':
        return base.charm + statMods.charm;
      default:
        return 0;
    }
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'duplicateId': duplicateId,
        'energy': energy,
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

    final energyRaw = map['energy'];
    final int energy;
    if (energyRaw == null) {
      // Compatibility with Survivors created before the energy field existed.
      energy = 50;
    } else if (energyRaw is num &&
        energyRaw.isFinite &&
        energyRaw == energyRaw.toInt()) {
      energy = energyRaw.toInt();
    } else {
      throw const FormatException('Survivor energy must be an integer.');
    }

    return Survivor(
      id: map['id'] as String? ?? '',
      duplicateId: map['duplicateId'] as String? ?? '',
      energy: energy,
      statMods: SurvivorStats.fromMap(
        map['statMods'] as Map<String, dynamic>?,
      ),
      healthHistory: healthHistory,
      equippedItemIds: equippedItemIds,
    );
  }
}
