class SurvivorStats {
  const SurvivorStats({
    required this.strength,
    required this.dexterity,
    required this.constitution,
    required this.stealth,
    required this.care,
    required this.cunning,
    required this.charm,
  });

  final int strength;
  final int dexterity;
  final int constitution;
  final int stealth;
  final int care;
  final int cunning;
  final int charm;

  static const zero = SurvivorStats(
    strength: 0,
    dexterity: 0,
    constitution: 0,
    stealth: 0,
    care: 0,
    cunning: 0,
    charm: 0,
  );

  Map<String, int> toMap() => <String, int>{
        'strength': strength,
        'dexterity': dexterity,
        'constitution': constitution,
        'stealth': stealth,
        'care': care,
        'cunning': cunning,
        'charm': charm,
      };

  factory SurvivorStats.fromMap(Map<String, dynamic>? map) {
    final data = map ?? const <String, dynamic>{};
    return SurvivorStats(
      strength: (data['strength'] as num?)?.toInt() ?? 0,
      dexterity: ((data['dexterity'] ?? data['agility']) as num?)?.toInt() ?? 0,
      constitution:
          ((data['constitution'] ?? data['endurance']) as num?)?.toInt() ?? 0,
      stealth: ((data['stealth'] ?? data['scavenging']) as num?)?.toInt() ?? 0,
      care: (data['care'] as num?)?.toInt() ?? 0,
      cunning: (data['cunning'] as num?)?.toInt() ?? 0,
      charm: (data['charm'] as num?)?.toInt() ?? 0,
    );
  }

  List<int> get values => <int>[
        strength,
        dexterity,
        constitution,
        stealth,
        care,
        cunning,
        charm,
      ];
}
