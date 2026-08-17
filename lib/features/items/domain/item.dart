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

  /// Server-defined categories. An item may belong to more than one category,
  /// for example both `weapon` and `resource`.
  final List<String> type;

  /// Server-defined subtypes such as `head`, `ranged`, `twohanded`, etc.
  /// Multiple subtypes may apply to the same item.
  final List<String> subtype;
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
        'type': List<String>.from(type),
        'subtype': List<String>.from(subtype),
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
    final types = _stringList(data['type'], 'type', id, allowEmpty: false);
    final subtypes = _stringList(data['subtype'], 'subtype', id);
    final value = data['value'];
    final names = _stringMap(data['name'], 'name');
    final descriptions = _stringMap(
      data['description'],
      'description',
      allowEmpty: true,
    );
    final statsRaw = data['stats'];

    if (value is! num) {
      throw FormatException('Item $id value must be numeric.');
    }
    if (statsRaw != null && statsRaw is! Map) {
      throw FormatException('Item $id stats must be an object.');
    }

    return Item(
      id: id,
      type: List<String>.unmodifiable(types),
      subtype: List<String>.unmodifiable(subtypes),
      value: value.toInt(),
      stackable: data['stackable'] as bool? ?? false,
      names: names,
      descriptions: descriptions,
      stats: statsRaw == null
          ? const <String, dynamic>{}
          : Map<String, dynamic>.unmodifiable(
              Map<String, dynamic>.from(statsRaw),
            ),
    );
  }

  static List<String> _stringList(
    Object? raw,
    String field,
    String itemId, {
    bool allowEmpty = true,
  }) {
    // Temporary migration compatibility: documents written with catalog schema
    // v1 stored type/subtype as a single string. New writes always use lists.
    final List<String> values;
    if (raw is String) {
      values = <String>[raw.trim()];
    } else if (raw is List && raw.every((value) => value is String)) {
      values = raw.cast<String>().map((value) => value.trim()).toList();
    } else {
      throw FormatException('Item $itemId $field must be a list of strings.');
    }

    if (values.any((value) => value.isEmpty)) {
      throw FormatException('Item $itemId $field cannot contain empty values.');
    }
    if (!allowEmpty && values.isEmpty) {
      throw FormatException('Item $itemId $field must contain at least one value.');
    }
    if (values.toSet().length != values.length) {
      throw FormatException('Item $itemId $field cannot contain duplicates.');
    }
    return values;
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
