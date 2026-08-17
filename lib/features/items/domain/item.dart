class Item {
  const Item({
    required this.id,
    required this.type,
    required this.subtype,
    required this.value,
    required this.names,
    required this.descriptions,
    this.stackable = false,
    this.stats = const <String, dynamic>{},
  });

  /// Stable identifier used by inventories, equipment and local artwork.
  final String id;

  /// Server-defined category. Current values are weapon, equipment, resource
  /// and food. It remains a string so adding future categories does not make an
  /// older client unable to deserialize the catalog.
  final String type;

  /// Server-defined subtype such as head, ranged, twohanded, medical, etc.
  final String subtype;
  final int value;
  final bool stackable;

  /// Language code -> localized display text. The backend owns these values.
  final Map<String, String> names;
  final Map<String, String> descriptions;

  /// Item-specific gameplay payload. Examples include damage, armor, hunger,
  /// durability, crafting tags or status effects.
  final Map<String, dynamic> stats;

  /// Artwork is the only item definition intentionally kept in the app bundle.
  String get assetPath => 'assets/items/item_$id.png';

  String nameForLanguage(String languageCode) =>
      _localizedValue(names, languageCode, fallback: id);

  String descriptionForLanguage(String languageCode) =>
      _localizedValue(descriptions, languageCode);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'subtype': subtype,
        'value': value,
        'stackable': stackable,
        'name': Map<String, String>.from(names),
        'description': Map<String, String>.from(descriptions),
        'stats': Map<String, dynamic>.from(stats),
      };

  factory Item.fromJson(
    String id,
    Map<String, dynamic> data,
  ) {
    final type = data['type'];
    final subtype = data['subtype'];
    final value = data['value'];
    final names = _stringMap(data['name'], 'name');
    final descriptions = _stringMap(
      data['description'],
      'description',
      allowEmpty: true,
    );
    final statsRaw = data['stats'];

    if (type is! String || type.trim().isEmpty) {
      throw FormatException('Item $id type must be a non-empty string.');
    }
    if (subtype is! String) {
      throw FormatException('Item $id subtype must be a string.');
    }
    if (value is! num) {
      throw FormatException('Item $id value must be numeric.');
    }
    if (statsRaw != null && statsRaw is! Map) {
      throw FormatException('Item $id stats must be an object.');
    }

    return Item(
      id: id,
      type: type,
      subtype: subtype,
      value: value.toInt(),
      stackable: data['stackable'] as bool? ?? false,
      names: names,
      descriptions: descriptions,
      stats: statsRaw == null
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(statsRaw),
    );
  }

  static Map<String, String> _stringMap(
    Object? raw,
    String field, {
    bool allowEmpty = false,
  }) {
    if (raw is! Map) {
      throw FormatException('Item $field must be an object of localized text.');
    }

    final result = <String, String>{};
    for (final entry in raw.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw FormatException('Item $field entries must be strings.');
      }
      result[entry.key as String] = entry.value as String;
    }

    if (!allowEmpty && result.isEmpty) {
      throw FormatException('Item $field must contain at least one language.');
    }
    return Map<String, String>.unmodifiable(result);
  }

  static String _localizedValue(
    Map<String, String> values,
    String languageCode, {
    String fallback = '',
  }) {
    final requested = values[languageCode];
    if (requested != null && requested.isNotEmpty) return requested;

    final english = values['en'];
    if (english != null && english.isNotEmpty) return english;

    for (final value in values.values) {
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }
}
