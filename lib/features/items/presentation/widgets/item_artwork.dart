import 'package:flutter/material.dart';

class ItemArtwork extends StatelessWidget {
  const ItemArtwork({
    super.key,
    required this.itemId,
    this.fit = BoxFit.contain,
    this.placeholderIconSize = 42,
  });

  final String itemId;
  final BoxFit fit;
  final double placeholderIconSize;

  String get _assetPath => 'assets/items/item_$itemId.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _assetPath,
      fit: fit,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Icon(
            Icons.inventory_2_outlined,
            size: placeholderIconSize,
            color: const Color(0xFF786F61),
          ),
        );
      },
    );
  }
}
