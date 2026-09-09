import '../../survivors/domain/survivor.dart';

DateTime? _dateAtSecondPrecision(Object? raw) {
  final parsed = raw is String ? DateTime.tryParse(raw)?.toUtc() : null;
  if (parsed == null) return null;
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
  );
}

String _legacyLocationForActivity(String activity) {
  switch (activity) {
    case 'sleeping':
      return 'beds';
    default:
      return 'unknown';
  }
}

String? _optionalNonEmptyString(Object? raw) {
  if (raw is! String) return null;
  final normalized = raw.trim();
  return normalized.isEmpty ? null : normalized;
}

int? _optionalPositiveInt(Object? raw) {
  if (raw == null) return null;
  if (raw is! num ||
      !raw.isFinite ||
      raw != raw.toInt() ||
      raw.toInt() < 1) {
    throw const FormatException('Expected a positive integer.');
  }
  return raw.toInt();
}

class BunkerCoordinates {
  const BunkerCoordinates({
    required this.x,
    required this.y,
    required this.z,
  });

  static const BunkerCoordinates temporaryDefault =
      BunkerCoordinates(x: 0, y: 0, z: 0);

  final int x;
  final int y;
  final int z;

  factory BunkerCoordinates.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException(
        'bunkerCoordinates must be an object.',
      );
    }
    final map = Map<String, dynamic>.from(raw);

    int readAxis(String axis) {
      final value = map[axis];
      if (value is! num ||
          !value.isFinite ||
          value != value.toInt() ||
          value < 0 ||
          value > 999) {
        throw FormatException(
          'bunkerCoordinates.$axis must be an integer from 0 to 999.',
        );
      }
      return value.toInt();
    }

    return BunkerCoordinates(
      x: readAxis('x'),
      y: readAxis('y'),
      z: readAxis('z'),
    );
  }

  String get displayValue => '$x, $y, $z';

  @override
  bool operator ==(Object other) =>
      other is BunkerCoordinates &&
      other.x == x &&
      other.y == y &&
      other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);
}

class BusySurvivor {
  const BusySurvivor({
    required this.survivorId,
    required this.activity,
    required this.location,
    required this.startedAt,
    required this.endsAt,
    this.taskId,
    this.executionId,
    this.expeditionType,
    this.taskExecutionCount,
  });

  final String survivorId;
  final String activity;
  final String location;
  final DateTime startedAt;
  final DateTime endsAt;

  /// Server task ID. Sleeping and legacy occupations may not have one.
  final String? taskId;

  /// Shared by every Survivor assigned to the same task execution.
  final String? executionId;

  /// Expedition presentation/type discriminator. Null for jobs, sleeping, and
  /// legacy expedition entries created before this field existed.
  final String? expeditionType;

  /// Number of base executions grouped into this job occupation. Normal tasks
  /// and legacy data use 1.
  final int? taskExecutionCount;

  factory BusySurvivor.fromJson(
    Map<String, dynamic> json, {
    DateTime? legacyFallbackDate,
    bool allowLegacyLocation = false,
  }) {
    final survivorId = json['survivorId'];
    final activity = json['activity'];

    if (survivorId is! String || survivorId.trim().isEmpty) {
      throw const FormatException(
        'Busy Survivor survivorId must be a non-empty string.',
      );
    }
    if (activity is! String || activity.trim().isEmpty) {
      throw const FormatException(
        'Busy Survivor activity must be a non-empty string.',
      );
    }

    final normalizedActivity = activity.trim();
    final locationRaw = json['location'];
    final String location;
    if (locationRaw is String && locationRaw.trim().isNotEmpty) {
      location = locationRaw.trim();
    } else if (allowLegacyLocation) {
      location = _legacyLocationForActivity(normalizedActivity);
    } else {
      throw const FormatException(
        'Busy Survivor location must be a non-empty string.',
      );
    }

    final fallback = legacyFallbackDate == null
        ? null
        : DateTime.utc(
            legacyFallbackDate.year,
            legacyFallbackDate.month,
            legacyFallbackDate.day,
            legacyFallbackDate.hour,
            legacyFallbackDate.minute,
            legacyFallbackDate.second,
          );
    final startedAt = _dateAtSecondPrecision(json['startedAt']) ?? fallback;
    final endsAt = _dateAtSecondPrecision(json['endsAt']) ?? fallback;

    if (startedAt == null || endsAt == null) {
      throw const FormatException(
        'Busy Survivor startedAt and endsAt must be ISO-8601 timestamps.',
      );
    }
    if (endsAt.isBefore(startedAt)) {
      throw const FormatException(
        'Busy Survivor endsAt cannot be before startedAt.',
      );
    }

    return BusySurvivor(
      survivorId: survivorId.trim(),
      activity: normalizedActivity,
      location: location,
      startedAt: startedAt,
      endsAt: endsAt,
      taskId: _optionalNonEmptyString(json['taskId']),
      executionId: _optionalNonEmptyString(json['executionId']),
      expeditionType: _optionalNonEmptyString(json['expeditionType']),
      taskExecutionCount: _optionalPositiveInt(json['taskExecutionCount']),
    );
  }
}

class ActiveBackgroundTask {
  const ActiveBackgroundTask({
    required this.executionId,
    required this.taskId,
    required this.activity,
    required this.location,
    required this.startedBySurvivorId,
    required this.startedAt,
    required this.endsAt,
  });

  final String executionId;
  final String taskId;
  final String activity;
  final String location;
  final String startedBySurvivorId;
  final DateTime startedAt;
  final DateTime endsAt;

  factory ActiveBackgroundTask.fromJson(Map<String, dynamic> json) {
    final executionId = _optionalNonEmptyString(json['executionId']);
    final taskId = _optionalNonEmptyString(json['taskId']);
    final activity = _optionalNonEmptyString(json['activity']);
    final location = _optionalNonEmptyString(json['location']);
    final startedBySurvivorId =
        _optionalNonEmptyString(json['startedBySurvivorId']);
    final startedAt = _dateAtSecondPrecision(json['startedAt']);
    final endsAt = _dateAtSecondPrecision(json['endsAt']);

    if (executionId == null ||
        taskId == null ||
        activity == null ||
        location == null ||
        startedBySurvivorId == null ||
        startedAt == null ||
        endsAt == null) {
      throw const FormatException(
        'Active background tasks must contain IDs, location and timestamps.',
      );
    }
    if (endsAt.isBefore(startedAt)) {
      throw const FormatException(
        'Active background task endsAt cannot be before startedAt.',
      );
    }

    return ActiveBackgroundTask(
      executionId: executionId,
      taskId: taskId,
      activity: activity,
      location: location,
      startedBySurvivorId: startedBySurvivorId,
      startedAt: startedAt,
      endsAt: endsAt,
    );
  }
}

/// Immutable snapshot of the player's bunker state as provided by the server.
///
/// The app intentionally exposes no mutation or serialization API for this
/// model. Client code should replace the whole snapshot when a newer revision
/// is fetched from the backend.
class BunkerState {
  BunkerState._({
    required this.schemaVersion,
    required this.revision,
    required this.serverUpdatedAt,
    required List<Survivor> survivors,
    required List<String> idleSurvivors,
    required List<BusySurvivor> busySurvivors,
    required List<ActiveBackgroundTask> activeBackgroundTasks,
    required List<String> completedTaskIds,
    required Map<String, int> inventory,
    required this.bunkerCoordinates,
  })  : survivors = List<Survivor>.unmodifiable(survivors),
        idleSurvivors = List<String>.unmodifiable(idleSurvivors),
        busySurvivors = List<BusySurvivor>.unmodifiable(busySurvivors),
        activeBackgroundTasks =
            List<ActiveBackgroundTask>.unmodifiable(activeBackgroundTasks),
        completedTaskIds = List<String>.unmodifiable(completedTaskIds),
        inventory = Map<String, int>.unmodifiable(inventory);

  static const int supportedSchemaVersion = 9;
  static const int backgroundTasksSchemaVersion = 9;
  static const int bunkerCoordinatesSchemaVersion = 7;
  static const int completedTasksSchemaVersion = 6;
  static const int locationSchemaVersion = 5;
  static const int timestampSchemaVersion = 4;
  static const int legacySchemaVersion = 2;

  final int schemaVersion;
  final int revision;
  final DateTime serverUpdatedAt;

  /// Complete authoritative roster.
  final List<Survivor> survivors;

  /// IDs of Survivors currently available for new tasks.
  final List<String> idleSurvivors;

  /// Survivors currently occupied, what they are doing, where, and for which
  /// exact time window.
  final List<BusySurvivor> busySurvivors;

  /// Time-based jobs that continue independently after an available Survivor
  /// starts them. The starter remains idle and can do other work immediately.
  final List<ActiveBackgroundTask> activeBackgroundTasks;

  /// IDs of storable tasks that have been completed at least once.
  final List<String> completedTaskIds;

  /// Item ID -> quantity owned.
  final Map<String, int> inventory;

  /// Server-authoritative position of this player's bunker.
  ///
  /// Until coordinate assignment exists, older states use the temporary
  /// 0,0,0 fallback. Schema v7+ must explicitly carry this field.
  final BunkerCoordinates bunkerCoordinates;

  Survivor? survivorById(String id) {
    for (final survivor in survivors) {
      if (survivor.id == id) return survivor;
    }
    return null;
  }

  BusySurvivor? busySurvivorById(String id) {
    for (final busySurvivor in busySurvivors) {
      if (busySurvivor.survivorId == id) return busySurvivor;
    }
    return null;
  }

  factory BunkerState.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _requiredInt(json, 'schemaVersion');
    if (schemaVersion < legacySchemaVersion ||
        schemaVersion > supportedSchemaVersion) {
      throw FormatException(
        'Unsupported bunker state schema version: $schemaVersion',
      );
    }

    final serverUpdatedAt = _dateAtSecondPrecision(json['serverUpdatedAt']);
    if (serverUpdatedAt == null) {
      throw const FormatException(
        'serverUpdatedAt must be a valid ISO-8601 timestamp.',
      );
    }

    final survivorsRaw = json['survivors'];
    if (survivorsRaw is! List) {
      throw const FormatException('survivors must be a list.');
    }
    final survivors = survivorsRaw.map((rawSurvivor) {
      if (rawSurvivor is! Map) {
        throw const FormatException('Each survivor must be an object.');
      }
      return Survivor.fromMap(Map<String, dynamic>.from(rawSurvivor));
    }).toList(growable: false);

    final survivorIds = survivors.map((survivor) => survivor.id).toList();
    if (survivorIds.any((id) => id.isEmpty) ||
        survivorIds.toSet().length != survivorIds.length) {
      throw const FormatException(
        'Every bunker Survivor must have a unique non-empty id.',
      );
    }
    final knownSurvivorIds = survivorIds.toSet();

    final idleSurvivors = _stringList(json, 'idleSurvivors');
    _validateSurvivorReferences(
      idleSurvivors,
      knownSurvivorIds,
      'idleSurvivors',
    );

    final busySurvivors = _parseBusySurvivors(
      json['busySurvivors'],
      knownSurvivorIds,
      schemaVersion: schemaVersion,
      serverUpdatedAt: serverUpdatedAt,
    );
    final busyIds = busySurvivors
        .map((busySurvivor) => busySurvivor.survivorId)
        .toList(growable: false);
    if (busyIds.toSet().length != busyIds.length) {
      throw const FormatException(
        'busySurvivors cannot contain the same Survivor more than once.',
      );
    }
    if (idleSurvivors.any(busyIds.toSet().contains)) {
      throw const FormatException(
        'A Survivor cannot be both idle and busy in the same bunker state.',
      );
    }

    final activeBackgroundTasks =
        schemaVersion >= backgroundTasksSchemaVersion
        ? _parseActiveBackgroundTasks(
            json['activeBackgroundTasks'],
            knownSurvivorIds,
          )
        : const <ActiveBackgroundTask>[];

    final completedTaskIds = schemaVersion >= completedTasksSchemaVersion
        ? _uniqueNonEmptyStringList(json, 'completedTaskIds')
        : const <String>[];

    final bunkerCoordinates = schemaVersion >= bunkerCoordinatesSchemaVersion
        ? BunkerCoordinates.fromJson(json['bunkerCoordinates'])
        : BunkerCoordinates.temporaryDefault;

    final inventoryRaw = json['inventory'];
    if (inventoryRaw is! Map) {
      throw const FormatException('inventory must be an object.');
    }
    final inventory = <String, int>{};
    for (final entry in inventoryRaw.entries) {
      if (entry.key is! String || entry.value is! num) {
        throw const FormatException(
          'Inventory keys must be strings and values must be numbers.',
        );
      }
      final quantity = (entry.value as num).toInt();
      if (quantity < 0) {
        throw const FormatException('Inventory quantities cannot be negative.');
      }
      inventory[entry.key as String] = quantity;
    }

    return BunkerState._(
      schemaVersion: schemaVersion,
      revision: _requiredInt(json, 'revision'),
      serverUpdatedAt: serverUpdatedAt,
      survivors: survivors,
      idleSurvivors: idleSurvivors,
      busySurvivors: busySurvivors,
      activeBackgroundTasks: activeBackgroundTasks,
      completedTaskIds: completedTaskIds,
      inventory: inventory,
      bunkerCoordinates: bunkerCoordinates,
    );
  }

  static List<ActiveBackgroundTask> _parseActiveBackgroundTasks(
    Object? raw,
    Set<String> knownSurvivorIds,
  ) {
    if (raw is! List) {
      throw const FormatException(
        'activeBackgroundTasks must be a list.',
      );
    }

    final result = <ActiveBackgroundTask>[];
    final executionIds = <String>{};
    for (final rawTask in raw) {
      if (rawTask is! Map) {
        throw const FormatException(
          'Each activeBackgroundTasks entry must be an object.',
        );
      }
      final task = ActiveBackgroundTask.fromJson(
        Map<String, dynamic>.from(rawTask),
      );
      if (!knownSurvivorIds.contains(task.startedBySurvivorId)) {
        throw const FormatException(
          'activeBackgroundTasks references an unknown Survivor ID.',
        );
      }
      if (!executionIds.add(task.executionId)) {
        throw const FormatException(
          'activeBackgroundTasks contains duplicate execution IDs.',
        );
      }
      result.add(task);
    }
    return result;
  }

  static List<BusySurvivor> _parseBusySurvivors(
    Object? raw,
    Set<String> knownSurvivorIds, {
    required int schemaVersion,
    required DateTime serverUpdatedAt,
  }) {
    final legacyFallbackDate = schemaVersion < timestampSchemaVersion
        ? serverUpdatedAt
        : null;
    final allowLegacyLocation = schemaVersion < locationSchemaVersion;

    if (raw is List) {
      final result = <BusySurvivor>[];
      for (final rawBusySurvivor in raw) {
        if (rawBusySurvivor is! Map) {
          throw const FormatException(
            'Each busySurvivors entry must be an object.',
          );
        }
        final busySurvivor = BusySurvivor.fromJson(
          Map<String, dynamic>.from(rawBusySurvivor),
          legacyFallbackDate: legacyFallbackDate,
          allowLegacyLocation: allowLegacyLocation,
        );
        _validateSurvivorReferences(
          <String>[busySurvivor.survivorId],
          knownSurvivorIds,
          'busySurvivors',
        );
        result.add(busySurvivor);
      }
      return result;
    }

    // Compatibility with schema v2, where busySurvivors was stored as
    // activity -> list of Survivor IDs and had no activity timestamps/location.
    if (raw is Map && schemaVersion == legacySchemaVersion) {
      final result = <BusySurvivor>[];
      for (final entry in raw.entries) {
        if (entry.key is! String ||
            (entry.key as String).trim().isEmpty ||
            entry.value is! List) {
          throw const FormatException(
            'Legacy busySurvivors must map activities to Survivor ID lists.',
          );
        }
        final ids = (entry.value as List).whereType<String>().toList();
        if (ids.length != (entry.value as List).length) {
          throw const FormatException(
            'Legacy busySurvivors lists may contain only Survivor IDs.',
          );
        }
        _validateSurvivorReferences(
          ids,
          knownSurvivorIds,
          'busySurvivors',
        );
        final activity = (entry.key as String).trim();
        for (final id in ids) {
          result.add(
            BusySurvivor(
              survivorId: id,
              activity: activity,
              location: _legacyLocationForActivity(activity),
              startedAt: serverUpdatedAt,
              endsAt: serverUpdatedAt,
            ),
          );
        }
      }
      return result;
    }

    throw const FormatException(
      'busySurvivors must be a list of Survivor/activity/location/time entries.',
    );
  }

  static List<String> _stringList(Map<String, dynamic> json, String key) {
    final raw = json[key];
    if (raw is! List || raw.any((value) => value is! String)) {
      throw FormatException('$key must be a list of strings.');
    }
    return raw.cast<String>().toList(growable: false);
  }

  static List<String> _uniqueNonEmptyStringList(
    Map<String, dynamic> json,
    String key,
  ) {
    final values = _stringList(json, key).map((value) => value.trim()).toList();
    if (values.any((value) => value.isEmpty)) {
      throw FormatException('$key cannot contain empty strings.');
    }
    if (values.toSet().length != values.length) {
      throw FormatException('$key cannot contain duplicates.');
    }
    return values;
  }

  static void _validateSurvivorReferences(
    List<String> ids,
    Set<String> knownIds,
    String field,
  ) {
    if (ids.toSet().length != ids.length) {
      throw FormatException('$field contains duplicate Survivor IDs.');
    }
    if (ids.any((id) => !knownIds.contains(id))) {
      throw FormatException('$field references an unknown Survivor ID.');
    }
  }

  static int _requiredInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num) {
      throw FormatException('$key must be a number.');
    }
    return value.toInt();
  }
}
