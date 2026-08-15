import 'survivor_stats.dart';

class Duplicate {
  const Duplicate({
    required this.id,
    required this.baseStats,
  });

  final String id;
  final SurvivorStats baseStats;

  String get dormantAssetPath =>
      'assets/characters/survivor_${id}_Dorment.png';

  String get idleAssetPath => 'assets/characters/survivor_${id}_idle.png';
}
