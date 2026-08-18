import 'package:flutter/material.dart';

import '../assets/asset_variant_resolver.dart';

/// Displays one random bundled variant of [baseAssetPath].
///
/// Variants are discovered using [AssetVariantResolver] and follow the
/// `_variant_[x]` naming convention. The selected path remains stable for the
/// lifetime of this widget state, so regular Flutter rebuilds do not reshuffle
/// the image.
class RandomAssetVariantImage extends StatefulWidget {
  const RandomAssetVariantImage({
    super.key,
    required this.baseAssetPath,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.medium,
    this.gaplessPlayback = false,
    this.excludeFromSemantics = false,
    this.errorBuilder,
    this.resolver,
  });

  final String baseAssetPath;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final FilterQuality filterQuality;
  final bool gaplessPlayback;
  final bool excludeFromSemantics;
  final ImageErrorWidgetBuilder? errorBuilder;

  /// Optional override mainly useful for tests or special asset bundles.
  final AssetVariantResolver? resolver;

  @override
  State<RandomAssetVariantImage> createState() =>
      _RandomAssetVariantImageState();
}

class _RandomAssetVariantImageState extends State<RandomAssetVariantImage> {
  String? _selectedAssetPath;
  int _selectionGeneration = 0;

  @override
  void initState() {
    super.initState();
    _selectVariant();
  }

  @override
  void didUpdateWidget(covariant RandomAssetVariantImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.baseAssetPath != widget.baseAssetPath ||
        oldWidget.resolver != widget.resolver) {
      _selectedAssetPath = null;
      _selectVariant();
    }
  }

  Future<void> _selectVariant() async {
    final generation = ++_selectionGeneration;
    final requestedBasePath = widget.baseAssetPath;
    final resolver = widget.resolver ?? assetVariantResolver;
    final selectedPath = await resolver.pickRandom(requestedBasePath);

    if (!mounted ||
        generation != _selectionGeneration ||
        requestedBasePath != widget.baseAssetPath) {
      return;
    }

    setState(() {
      _selectedAssetPath = selectedPath;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedAssetPath = _selectedAssetPath;
    if (selectedAssetPath == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
      );
    }

    return Image.asset(
      selectedAssetPath,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
      filterQuality: widget.filterQuality,
      gaplessPlayback: widget.gaplessPlayback,
      excludeFromSemantics: widget.excludeFromSemantics,
      errorBuilder: widget.errorBuilder,
    );
  }
}
