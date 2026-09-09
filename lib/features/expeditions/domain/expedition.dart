class ExpeditionCoordinates {
  const ExpeditionCoordinates({
    required this.x,
    required this.y,
    required this.z,
  });

  final int x;
  final int y;
  final int z;

  Map<String, int> toMap() => <String, int>{
        'x': x,
        'y': y,
        'z': z,
      };

  String get displayValue => '$x, $y, $z';

  factory ExpeditionCoordinates.fromMap(Map<String, dynamic> map) {
    int readAxis(String key) {
      final raw = map[key];
      if (raw is! num ||
          !raw.isFinite ||
          raw != raw.toInt() ||
          raw < 0 ||
          raw > 999) {
        throw FormatException(
          'Expedition coordinate $key must be an integer from 0 to 999.',
        );
      }
      return raw.toInt();
    }

    return ExpeditionCoordinates(
      x: readAxis('x'),
      y: readAxis('y'),
      z: readAxis('z'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ExpeditionCoordinates &&
      other.x == x &&
      other.y == y &&
      other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);
}

class ExpeditionActionDefinition {
  const ExpeditionActionDefinition({
    required this.id,
    required this.durationSeconds,
    required this.energyCostPerSurvivor,
  });

  final String id;
  final int durationSeconds;
  final int energyCostPerSurvivor;

  factory ExpeditionActionDefinition.fromMap(Map<String, dynamic> map) {
    final id = map['id'];
    final duration = map['durationSeconds'];
    final energyCost = map['energyCostPerSurvivor'];

    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Expedition action has an invalid ID.');
    }
    if (duration is! num ||
        !duration.isFinite ||
        duration != duration.toInt() ||
        duration <= 0) {
      throw const FormatException(
        'Expedition action duration must be a positive integer.',
      );
    }
    if (energyCost is! num ||
        !energyCost.isFinite ||
        energyCost != energyCost.toInt() ||
        energyCost < 0) {
      throw const FormatException(
        'Expedition action energy cost must be a non-negative integer.',
      );
    }

    return ExpeditionActionDefinition(
      id: id.trim(),
      durationSeconds: duration.toInt(),
      energyCostPerSurvivor: energyCost.toInt(),
    );
  }
}

class ExpeditionLauncherInfo {
  const ExpeditionLauncherInfo({
    required this.bunkerCoordinates,
    required this.bunkerActions,
  });

  final ExpeditionCoordinates bunkerCoordinates;
  final List<ExpeditionActionDefinition> bunkerActions;

  factory ExpeditionLauncherInfo.fromMap(Map<String, dynamic> map) {
    final coordinatesRaw = map['bunkerCoordinates'];
    final actionsRaw = map['bunkerActions'];
    if (coordinatesRaw is! Map || actionsRaw is! List) {
      throw const FormatException('Invalid expedition launcher information.');
    }

    return ExpeditionLauncherInfo(
      bunkerCoordinates: ExpeditionCoordinates.fromMap(
        Map<String, dynamic>.from(coordinatesRaw),
      ),
      bunkerActions: List<ExpeditionActionDefinition>.unmodifiable(
        actionsRaw.map((raw) {
          if (raw is! Map) {
            throw const FormatException('Invalid expedition action.');
          }
          return ExpeditionActionDefinition.fromMap(
            Map<String, dynamic>.from(raw),
          );
        }),
      ),
    );
  }
}
