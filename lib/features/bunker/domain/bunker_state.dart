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
    required Map<String, int> resources,
  })  : survivors = List<Survivor>.unmodifiable(survivors),
        resources = Map<String, int>.unmodifiable(resources);

  static const int supportedSchemaVersion = 1;

  final int schemaVersion;
  final int revision;
  final DateTime serverUpdatedAt;
  final List<Survivor> survivors;
  final Map<String, int> resources;

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

    final resourcesRaw = json['resources'];
    if (resourcesRaw is! Map) {
      throw const FormatException('resources must be an object.');
    }
    final resources = <String, int>{};
    for (final entry in resourcesRaw.entries) {
      if (entry.key is! String || entry.value is! num) {
        throw const FormatException(
          'Resource keys must be strings and values must be numbers.',
        );
      }
      resources[entry.key as String] = (entry.value as num).toInt();
    }

    return BunkerState._(
      schemaVersion: schemaVersion,
      revision: _requiredInt(json, 'revision'),
      serverUpdatedAt: serverUpdatedAt,
      survivors: survivors,
      resources: resources,
    );
  }

  static int _requiredInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num) {
      throw FormatException('$key must be a number.');
    }
    return value.toInt();
  }
}
