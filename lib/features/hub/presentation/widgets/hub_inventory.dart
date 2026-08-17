import 'package:flutter/material.dart';

import '../../../../core/firebase/firestore_item_catalog_service.dart';
import '../../../../core/localization/l10n.dart';
import '../../../items/domain/item.dart';
import '../../../items/presentation/widgets/item_detail_dialog.dart';
import '../../../items/presentation/widgets/item_tile.dart';

class HubInventory extends StatelessWidget {
  const HubInventory({
    super.key,
    required this.inventory,
    this.loadError,
  });

  final Map<String, int>? inventory;
  final Object? loadError;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final inventory = this.inventory;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xE611110E),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.hubInventoryTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: const Color(0xFFE6D8BD),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildBody(context, inventory)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Map<String, int>? inventory) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    if (inventory == null) {
      if (loadError != null) {
        return Align(
          alignment: Alignment.topCenter,
          child: Text(
            l10n.hubInventoryLoadError,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFB08C75),
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    final ownedEntries = inventory.entries
        .where((entry) => entry.value > 0)
        .toList(growable: false);
    if (ownedEntries.isEmpty) {
      return Align(
        alignment: Alignment.topCenter,
        child: Text(
          l10n.hubInventoryEmpty,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF8F8677),
          ),
        ),
      );
    }

    return StreamBuilder<Map<String, Item>>(
      stream: FirestoreItemCatalogService.instance.watchCatalog(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final catalog = snapshot.data ?? const <String, Item>{};
        final languageCode = Localizations.localeOf(context).languageCode;
        final entries = List<MapEntry<String, int>>.from(ownedEntries)
          ..sort((a, b) {
            final aName = catalog[a.key]?.nameForLanguage(languageCode) ?? a.key;
            final bName = catalog[b.key]?.nameForLanguage(languageCode) ?? b.key;
            return aName.compareTo(bName);
          });

        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 150,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final item = catalog[entry.key];
            return ItemTile(
              itemId: entry.key,
              item: item,
              quantity: entry.value,
              onTap: () => ItemDetailDialog.show(
                context,
                itemId: entry.key,
                quantity: entry.value,
                item: item,
              ),
            );
          },
        );
      },
    );
  }
}
