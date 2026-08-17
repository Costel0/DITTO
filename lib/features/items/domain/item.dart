enum ItemType {
  weapon,
  equipment,
  resource,
  food,
}

extension ItemTypeFirestoreValue on ItemType {
  String get firestoreValue => name;

  static ItemType fromFirestore(Object? raw) {
    if (raw is! String) {
      throw const FormatException('Item type must be a string.');
    }

    for (final type in ItemType.values) {
      if (type.name == raw) return type;
    }

    throw FormatException('Unsupported item type: $raw');
  }
}

class Item {
  const Item({
    required this.id,
    required this.type,
    required this.subtype,
    required this.value,
    this.description = '',
    this.stackable = false,
    this.stats = const <String, dynamic>{},
  });

  final String id;
  final ItemType type;

  /// Flexible subtype such as `head`, `ranged`, `twohanded`, `medical`, etc.
  /// Keeping it as a string lets each [ItemType] grow its own subtype taxonomy
  /// without forcing unrelated categories into one enum.
  final String subtype;

  final int value;
  final String description;
  final bool stackable;

  /// Item-specific gameplay payload. Examples: damage, armor, hunger restored,
  /// crafting tags, status effects, durability or any future item-only data.
  final Map<String, dynamic> stats;

  String get assetPath => 'assets/items/item_$id.png';

  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'type': type.firestoreValue,
        'subtype': subtype,
        'value': value,
        'description': description,
        'stackable': stackable,
        'stats': Map<String, dynamic>.from(stats),
      };

  factory Item.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final valueRaw = data['value'];
    if (valueRaw is! num) {
      throw const FormatException('Item value must be numeric.');
    }

    final statsRaw = data['stats'];
    if (statsRaw != null && statsRaw is! Map) {
      throw const FormatException('Item stats must be an object.');
    }

    return Item(
      id: id,
      type: ItemTypeFirestoreValue.fromFirestore(data['type']),
      subtype: data['subtype'] as String? ?? '',
      value: valueRaw.toInt(),
      description: data['description'] as String? ?? '',
      stackable: data['stackable'] as bool? ?? false,
      stats: statsRaw == null
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(statsRaw),
    );
  }
}
