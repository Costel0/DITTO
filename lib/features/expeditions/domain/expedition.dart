import 'dart:math' as math;

class ExpeditionCoordinates {
  const ExpeditionCoordinates({
    required this.sectorLetter,
    required this.sectorNumber,
    required this.zoneIndex,
  });

  final String sectorLetter;
  final int sectorNumber;
  final int zoneIndex;

  /// Compatibility accessors for the existing internal bunker coordinate
  /// representation (A=0 .. Z=25).
  int get x => sectorLetter.codeUnitAt(0) - 65;
  int get y => sectorNumber;
  int get z => zoneIndex;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'sectorLetter': sectorLetter,
        'sectorNumber': sectorNumber,
        'zoneIndex': zoneIndex,
      };

  String get displayValue => '$sectorLetter$sectorNumber-$zoneIndex';

  double distanceTo(ExpeditionCoordinates other) {
    if (sectorLetter == other.sectorLetter && sectorNumber == other.sectorNumber) {
      return zoneIndex == other.zoneIndex ? 0 : 0.1;
    }
    final dx = x - other.x;
    final dy = sectorNumber - other.sectorNumber;
    return math.sqrt(dx * dx + dy * dy);
  }

  factory ExpeditionCoordinates.fromLegacy({
    required int x,
    required int y,
    required int z,
  }) {
    if (x < 0 || x > 25 || y < 1 || z < 1) {
      throw const FormatException('Invalid legacy expedition coordinates.');
    }
    return ExpeditionCoordinates(
      sectorLetter: String.fromCharCode(65 + x),
      sectorNumber: y,
      zoneIndex: z,
    );
  }

  factory ExpeditionCoordinates.fromMap(Map<String, dynamic> map) {
    if (map.containsKey('sectorLetter') ||
        map.containsKey('sectorNumber') ||
        map.containsKey('zoneIndex')) {
      final rawLetter = map['sectorLetter'];
      final rawNumber = map['sectorNumber'];
      final rawZone = map['zoneIndex'];
      final letter = rawLetter is String ? rawLetter.trim().toUpperCase() : '';
      if (!RegExp(r'^[A-Z]$').hasMatch(letter)) {
        throw const FormatException('Invalid expedition sector letter.');
      }
      final sectorNumber = _positiveInt(rawNumber, 'sectorNumber');
      final zoneIndex = _positiveInt(rawZone, 'zoneIndex');
      return ExpeditionCoordinates(
        sectorLetter: letter,
        sectorNumber: sectorNumber,
        zoneIndex: zoneIndex,
      );
    }

    final x = _nonNegativeInt(map['x'], 'x');
    final y = _positiveInt(map['y'], 'y');
    final z = _positiveInt(map['z'], 'z');
    if (x > 25) {
      throw const FormatException('Expedition coordinate x must map to A-Z.');
    }
    return ExpeditionCoordinates.fromLegacy(x: x, y: y, z: z);
  }

  static int _positiveInt(Object? raw, String label) {
    if (raw is! num ||
        !raw.isFinite ||
        raw != raw.toInt() ||
        raw.toInt() < 1) {
      throw FormatException('$label must be a positive integer.');
    }
    return raw.toInt();
  }

  static int _nonNegativeInt(Object? raw, String label) {
    if (raw is! num ||
        !raw.isFinite ||
        raw != raw.toInt() ||
        raw.toInt() < 0) {
      throw FormatException('$label must be a non-negative integer.');
    }
    return raw.toInt();
  }

  @override
  bool operator ==(Object other) =>
      other is ExpeditionCoordinates &&
      other.sectorLetter == sectorLetter &&
      other.sectorNumber == sectorNumber &&
      other.zoneIndex == zoneIndex;

  @override
  int get hashCode => Object.hash(sectorLetter, sectorNumber, zoneIndex);
}

class ExpeditionKnownZone {
  const ExpeditionKnownZone({
    required this.coordinates,
    required this.zoneType,
  });

  final ExpeditionCoordinates coordinates;
  final String zoneType;

  factory ExpeditionKnownZone.fromMap(Map<String, dynamic> map) {
    final coordinatesRaw = map['coordinates'];
    final zoneTypeRaw = map['zoneType'];
    if (coordinatesRaw is! Map || zoneTypeRaw is! String) {
      throw const FormatException('Invalid known expedition zone.');
    }
    final zoneType = zoneTypeRaw.trim().toUpperCase();
    if (!RegExp(r'^[A-Z][A-Z0-9_]*$').hasMatch(zoneType)) {
      throw const FormatException('Invalid known expedition zone type.');
    }
    return ExpeditionKnownZone(
      coordinates: ExpeditionCoordinates.fromMap(
        Map<String, dynamic>.from(coordinatesRaw),
      ),
      zoneType: zoneType,
    );
  }
}

class ExpeditionActionDefinition {
  const ExpeditionActionDefinition({
    required this.id,
    required this.expeditionType,
    required this.durationSeconds,
    required this.energyCostPerSurvivor,
    required this.availableForUnknownZone,
    required this.zoneTypes,
    required this.completion,
  });

  final String id;
  final String expeditionType;
  final int durationSeconds;
  final int energyCostPerSurvivor;
  final bool availableForUnknownZone;
  final Set<String> zoneTypes;
  final String completion;

  bool get isExploration => completion == 'discover_zone';

  bool isAvailableForZone(String? zoneType) {
    if (zoneType == null) return availableForUnknownZone;
    return !availableForUnknownZone && zoneTypes.contains(zoneType.toUpperCase());
  }

  factory ExpeditionActionDefinition.fromMap(Map<String, dynamic> map) {
    final id = map['id'];
    final expeditionType = map['expeditionType'];
    final duration = map['durationSeconds'];
    final energyCost = map['energyCostPerSurvivor'];
    final availabilityRaw = map['availability'];
    final completionRaw = map['completion'];

    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Expedition action has an invalid ID.');
    }
    if (expeditionType is! String || expeditionType.trim().isEmpty) {
      throw const FormatException(
        'Expedition action has an invalid expedition type.',
      );
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
    if (availabilityRaw is! Map) {
      throw const FormatException('Invalid expedition action availability.');
    }
    final availability = Map<String, dynamic>.from(availabilityRaw);
    final unknownZone = availability['unknownZone'] == true;
    final zoneTypesRaw = availability['zoneTypes'];
    if (zoneTypesRaw is! List || zoneTypesRaw.any((entry) => entry is! String)) {
      throw const FormatException('Invalid expedition zone type availability.');
    }
    final zoneTypes = zoneTypesRaw
        .cast<String>()
        .map((entry) => entry.trim().toUpperCase())
        .where((entry) => entry.isNotEmpty)
        .toSet();
    if (unknownZone == zoneTypes.isNotEmpty) {
      throw const FormatException(
        'An expedition action must target unknown or known zones.',
      );
    }
    final completion = completionRaw is String && completionRaw.trim().isNotEmpty
        ? completionRaw.trim()
        : 'interactive_outcome';

    return ExpeditionActionDefinition(
      id: id.trim(),
      expeditionType: expeditionType.trim(),
      durationSeconds: duration.toInt(),
      energyCostPerSurvivor: energyCost.toInt(),
      availableForUnknownZone: unknownZone,
      zoneTypes: Set<String>.unmodifiable(zoneTypes),
      completion: completion,
    );
  }
}

class ExpeditionLauncherInfo {
  const ExpeditionLauncherInfo({
    required this.bunkerCoordinates,
    required this.zonesPerSector,
    required this.travelSecondsPerDistanceUnit,
    required this.actions,
    required this.knownZones,
  });

  final ExpeditionCoordinates bunkerCoordinates;
  final int zonesPerSector;
  final double travelSecondsPerDistanceUnit;
  final List<ExpeditionActionDefinition> actions;
  final List<ExpeditionKnownZone> knownZones;

  ExpeditionKnownZone? knownZoneAt(ExpeditionCoordinates coordinates) {
    for (final zone in knownZones) {
      if (zone.coordinates == coordinates) return zone;
    }
    return null;
  }

  List<ExpeditionActionDefinition> actionsForCoordinates(
    ExpeditionCoordinates coordinates,
  ) {
    final zoneType = knownZoneAt(coordinates)?.zoneType;
    return List<ExpeditionActionDefinition>.unmodifiable(
      actions.where((action) => action.isAvailableForZone(zoneType)),
    );
  }

  int travelSecondsTo(ExpeditionCoordinates coordinates) =>
      (bunkerCoordinates.distanceTo(coordinates) * travelSecondsPerDistanceUnit)
          .ceil();

  int durationSecondsFor(
    ExpeditionCoordinates coordinates,
    Iterable<ExpeditionActionDefinition> selectedActions,
  ) =>
      travelSecondsTo(coordinates) +
      selectedActions.fold<int>(
        0,
        (sum, action) => sum + action.durationSeconds,
      );

  factory ExpeditionLauncherInfo.fromMap(Map<String, dynamic> map) {
    final coordinatesRaw = map['bunkerCoordinates'];
    final actionsRaw = map['actions'] ?? map['bunkerActions'];
    final knownZonesRaw = map['knownZones'] ?? const <dynamic>[];
    final zonesRaw = map['zonesPerSector'] ?? 1;
    final travelRaw = map['travelSecondsPerDistanceUnit'] ?? 300;
    if (coordinatesRaw is! Map ||
        actionsRaw is! List ||
        knownZonesRaw is! List) {
      throw const FormatException('Invalid expedition launcher information.');
    }
    if (zonesRaw is! num ||
        !zonesRaw.isFinite ||
        zonesRaw != zonesRaw.toInt() ||
        zonesRaw < 1) {
      throw const FormatException('Invalid zonesPerSector.');
    }
    if (travelRaw is! num || !travelRaw.isFinite || travelRaw < 0) {
      throw const FormatException('Invalid expedition travel multiplier.');
    }

    return ExpeditionLauncherInfo(
      bunkerCoordinates: ExpeditionCoordinates.fromMap(
        Map<String, dynamic>.from(coordinatesRaw),
      ),
      zonesPerSector: zonesRaw.toInt(),
      travelSecondsPerDistanceUnit: travelRaw.toDouble(),
      actions: List<ExpeditionActionDefinition>.unmodifiable(
        actionsRaw.map((raw) {
          if (raw is! Map) {
            throw const FormatException('Invalid expedition action.');
          }
          return ExpeditionActionDefinition.fromMap(
            Map<String, dynamic>.from(raw),
          );
        }),
      ),
      knownZones: List<ExpeditionKnownZone>.unmodifiable(
        knownZonesRaw.map((raw) {
          if (raw is! Map) {
            throw const FormatException('Invalid known expedition zone.');
          }
          return ExpeditionKnownZone.fromMap(
            Map<String, dynamic>.from(raw),
          );
        }),
      ),
    );
  }
}
