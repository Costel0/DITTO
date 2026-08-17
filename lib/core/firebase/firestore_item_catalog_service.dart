import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/items/domain/item.dart';
import '../../features/items/domain/item_catalog_service.dart';

class FirestoreItemCatalogService implements ItemCatalogService {
  FirestoreItemCatalogService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static final FirestoreItemCatalogService instance =
      FirestoreItemCatalogService();

  final FirebaseFirestore _firestore;
  Stream<Map<String, Item>>? _catalogStream;

  @override
  Stream<Map<String, Item>> watchCatalog() {
    return _catalogStream ??= _firestore
        .collection('items')
        .snapshots()
        .map((snapshot) {
          final catalog = <String, Item>{};
          for (final document in snapshot.docs) {
            catalog[document.id] = Item.fromJson(
              document.id,
              document.data(),
            );
          }
          return Map<String, Item>.unmodifiable(catalog);
        })
        .asBroadcastStream();
  }
}
