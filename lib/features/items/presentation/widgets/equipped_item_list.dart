import 'package:flutter/material.dart';

import '../../../../core/localization/l10n.dart';
import '../../domain/item_catalog.dart';
import '../item_display_catalog.dart';
import 'item_artwork.dart';
import 'item_detail_dialog.dart';

class EquippedItemList extends StatelessWidget {
  const EquippedItemList({
    super.key,
    required this.itemIds,
  });

  final List<String> itemIds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.characterEquipmentTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            color: const Color(0xFFE0CFAD),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        if (itemIds.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF171713),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFF4F4638)),
            ),
            child: Text(
              l10n.characterEquipmentEmpty,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF8F8677),
              ),
            ),
          )
        else
          for (var index = 0; index < itemIds.length; index++) ...[
            _EquippedItemRow(itemId: itemIds[index]),
            if (index + 1 < itemIds.length) const SizedBox(height: 7),
          ],
      ],
    );
  }
}

class _EquippedItemRow extends StatelessWidget {
  const _EquippedItemRow({required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = itemById(itemId);

    return Material(
      color: const Color(0xFF171713),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
        side: const BorderSide(color: Color(0xFF4F4638)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ItemDetailDialog.show(
          context,
          itemId: itemId,
          quantity: 1,
          item: item,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: ItemArtwork(
                  itemId: itemId,
                  placeholderIconSize: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemNameForId(context, itemId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFDCCBAA),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item != null && item.subtype.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtype,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF8F8677),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF7C7468),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
