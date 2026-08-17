import 'package:flutter/material.dart';

import '../item_display_catalog.dart';
import 'item_artwork.dart';

class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.itemId,
    required this.quantity,
    required this.onTap,
  });

  final String itemId;
  final int quantity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: const Color(0xFF171713),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: const BorderSide(color: Color(0xFF504738)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Positioned.fill(
                top: 38,
                bottom: 28,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: ItemArtwork(itemId: itemId),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 38,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  color: const Color(0xFF29241C),
                  child: Text(
                    itemNameForId(context, itemId),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFFE0CFAD),
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 7,
                child: Text(
                  'x$quantity',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: const Color(0xFFC9B78F),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
