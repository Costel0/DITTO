import 'package:flutter/material.dart';

import '../../../../core/localization/l10n.dart';
import '../../domain/item.dart';
import '../item_display_catalog.dart';
import 'item_artwork.dart';

class ItemDetailDialog extends StatelessWidget {
  const ItemDetailDialog({
    super.key,
    required this.itemId,
    required this.quantity,
    this.item,
  });

  final String itemId;
  final int quantity;
  final Item? item;

  static Future<void> show(
    BuildContext context, {
    required String itemId,
    required int quantity,
    Item? item,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ItemDetailDialog(
        itemId: itemId,
        quantity: quantity,
        item: item,
      ),
    );
  }

  String _typeLabel(BuildContext context, ItemType type) {
    final l10n = context.l10n;
    switch (type) {
      case ItemType.weapon:
        return l10n.itemTypeWeapon;
      case ItemType.equipment:
        return l10n.itemTypeEquipment;
      case ItemType.resource:
        return l10n.itemTypeResource;
      case ItemType.food:
        return l10n.itemTypeFood;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final catalogDescription = itemDescriptionForId(context, itemId);
    final resolvedDescription = catalogDescription.isNotEmpty
        ? catalogDescription
        : item?.description ?? '';

    return Dialog(
      backgroundColor: const Color(0xFF171713),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: const BorderSide(color: Color(0xFF5A4E3B)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      itemNameForId(context, itemId),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: const Color(0xFFE7D9BE),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 210,
                  height: 210,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF11110E),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF4C4437)),
                  ),
                  child: ItemArtwork(
                    itemId: itemId,
                    placeholderIconSize: 70,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (resolvedDescription.isNotEmpty) ...[
                Text(
                  resolvedDescription,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFAAA18F),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
              ],
              _DetailRow(
                label: l10n.itemDetailQuantity,
                value: quantity.toString(),
              ),
              if (item != null) ...[
                _DetailRow(
                  label: l10n.itemDetailType,
                  value: _typeLabel(context, item!.type),
                ),
                _DetailRow(
                  label: l10n.itemDetailSubtype,
                  value: item!.subtype.isEmpty ? '-' : item!.subtype,
                ),
                _DetailRow(
                  label: l10n.itemDetailValue,
                  value: item!.value.toString(),
                ),
                if (item!.stats.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.itemDetailStats,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: const Color(0xFFD3C29E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final entry in item!.stats.entries)
                    _DetailRow(
                      label: entry.key,
                      value: entry.value.toString(),
                    ),
                ],
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  l10n.itemDetailUnknown,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF827A6D),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF8F8677),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFFD8C9AB),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
