class SurvivorStats {
  const SurvivorStats({
    required this.strength,
    required this.agility,
    required this.endurance,
    required this.scavenging,
  });

  final int strength;
  final int agility;
  final int endurance;
  final int scavenging;

  static const zero = SurvivorStats(
    strength: 0,
    agility: 0,
    endurance: 0,
    scavenging: 0,
  );

  Map<String, int> toMap() => <String, int>{
        'strength': strength,
        'agility': agility,
        'endurance': endurance,
        'scavenging': scavenging,
      };

  factory SurvivorStats.fromMap(Map<String, dynamic>? map) {
    final data = map ?? const <String, dynamic>{};
    return SurvivorStats(
      strength: (data['strength'] as num?)?.toInt() ?? 0,
      agility: (data['agility'] as num?)?.toInt() ?? 0,
      endurance: (data['endurance'] as num?)?.toInt() ?? 0,
      scavenging: (data['scavenging'] as num?)?.toInt() ?? 0,
    );
  }

  List<int> get values => <int>[
        strength,
        agility,
        endurance,
        scavenging,
      ];
}
