import 'item.dart';

/// Temporary in-app item definitions used while the Firestore item catalog is
/// being populated. Inventory ownership remains authoritative in BunkerState.
///
/// The IDs are stable and match `assets/items/item_[ID].png`.
const Map<String, Item> itemCatalogById = <String, Item>{
  'scrap_metal': Item(
    id: 'scrap_metal',
    type: ItemType.resource,
    subtype: 'metal',
    value: 4,
    stackable: true,
    stats: <String, dynamic>{'craftingValue': 1},
  ),
  'field_ration': Item(
    id: 'field_ration',
    type: ItemType.food,
    subtype: 'ration',
    value: 12,
    stackable: true,
    stats: <String, dynamic>{'hunger': 25},
  ),
  'makeshift_pistol': Item(
    id: 'makeshift_pistol',
    type: ItemType.weapon,
    subtype: 'ranged',
    value: 45,
    stats: <String, dynamic>{
      'damage': 4,
      'range': 6,
      'twoHanded': false,
    },
  ),
  'work_helmet': Item(
    id: 'work_helmet',
    type: ItemType.equipment,
    subtype: 'head',
    value: 28,
    stats: <String, dynamic>{'armor': 2},
  ),
};

Item? itemById(String id) => itemCatalogById[id];
