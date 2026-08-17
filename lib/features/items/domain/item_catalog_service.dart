import 'item.dart';

abstract class ItemCatalogService {
  /// Watches the shared server-authored item catalog.
  ///
  /// Ownership is intentionally not part of this model. User inventories only
  /// reference item IDs and quantities; definitions come from this catalog.
  Stream<Map<String, Item>> watchCatalog();
}
