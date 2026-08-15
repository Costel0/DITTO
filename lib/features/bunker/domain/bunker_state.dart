import '../../survivors/domain/survivor.dart';

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
    required Map<String, List<String>> busySurvivors,
    required Map<String, int> inventory,
  })  : survivors = List<Survivor>.unmodifiable(survivors),
        idleSurvivors = List<String>.unmodifiable(idleSurvivors),
        busySurvivors = Map<String, List<String>>.unmodifiable(
          busySurvivors.map(
            (occupation, survivorIds) => MapEntry(
              occupation,
              List<String>.unmodifiable(survivorIds),
            ),
          ),
        ),
        inventory = Map<String, int>.unmodifiable(inventory);

  static const int supportedSchemaVersion = 2;

  final int schemaVersion;
  final int revision;
  final DateTime serverUpdatedAt;

  /// Complete authoritative roster.
  final List<Survivor> survivors;

  /// IDs of Survivors currently available for new tasks.
  final List<String> idleSurvivors;

  /// Occupation ID -> Survivor IDs currently assigned to that occupation.
  final Map<String, List<String>> busySurvivors;

  /// Item ID -> quantity owned.
  final Map<String, int> inventory;

  Survivor? survivorById(String id) {
    for (final survivor in survivors) {
      if (survivor.id == id) return survivor;
    }
    return null;
  }

  factory BunkerState.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _requiredInt(json, 'schemaVersion');
    if (schemaVersion != supportedSchemaVersion) {
      throw FormatException(
        'Unsupported bunker state schema version: $schemaVersion',
      );
    }

    final serverUpdatedAtRaw = json['serverUpdatedAt'];
    if (serverUpdatedAtRaw is! String) {
      throw const FormatException('serverUpdatedAt must be an ISO-8601 string.');
    }
    final serverUpdatedAt = DateTime.tryParse(serverUpdatedAtRaw)?.toUtc();
    if (serverUpdatedAt == null) {
      throw const FormatException('serverUpdatedAt is not a valid timestamp.');
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

    final busyRaw = json['busySurvivors'];
    if (busyRaw is! Map) {
      throw const FormatException('busySurvivors must be an object.');
    }
    final busySurvivors = <String, List<String>>{};
    for (final entry in busyRaw.entries) {
      if (entry.key is! String || entry.value is! List) {
        throw const FormatException(
          'busySurvivors must map occupation IDs to lists of Survivor IDs.',
        );
      }
      final ids = (entry.value as List).whereType<String>().toList();
      if (ids.length != (entry.value as List).length) {
        throw const FormatException(
          'busySurvivors lists may contain only Survivor IDs.',
        );
      }
      _validateSurvivorReferences(ids, knownSurvivorIds, entry.key as String);
      busySurvivors[entry.key as String] = ids;
    }

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
      inventory: inventory,
    );
  }

  static List<String> _stringList(Map<String, dynamic> json, String key) {
    final raw = json[key];
    if (raw is! List || raw.any((value) => value is! String)) {
      throw FormatException('$key must be a list of strings.');
    }
    return raw.cast<String>().toList(growable: false);
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
