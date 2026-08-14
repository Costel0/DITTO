import 'survivor_stats.dart';

class Survivor {
  const Survivor({
    required this.duplicateId,
    this.statMods = SurvivorStats.zero,
  });

  final String duplicateId;
  final SurvivorStats statMods;

  String get idleAssetPath =>
      'assets/characters/survivor_${duplicateId}_idle.png';

  Map<String, dynamic> toMap() => <String, dynamic>{
        'duplicateId': duplicateId,
        'statMods': statMods.toMap(),
      };

  factory Survivor.fromMap(Map<String, dynamic> map) {
    return Survivor(
      duplicateId: map['duplicateId'] as String? ?? '',
      statMods: SurvivorStats.fromMap(
        map['statMods'] as Map<String, dynamic>?,
      ),
    );
  }
}
