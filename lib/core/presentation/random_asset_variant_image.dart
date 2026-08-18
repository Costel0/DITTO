import 'package:flutter/material.dart';

import '../assets/asset_variant_resolver.dart';

/// Displays one bundled variant of [baseAssetPath].
///
/// Variants are discovered using [AssetVariantResolver] and follow the
/// `_variant_[x]` naming convention. Without [selectionSeed] the widget keeps
/// the previous random behaviour. With a seed, the same seed + [variantKey]
/// always resolves to the same asset, even after navigation or an app restart.
class RandomAssetVariantImage extends StatefulWidget {
  const RandomAssetVariantImage({
    super.key,
    required this.baseAssetPath,
    this.selectionSeed,
    this.variantKey,
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

  /// When present, variant selection is deterministic instead of ephemeral.
  final int? selectionSeed;

  /// Stable identity used to give different elements independent selections.
  /// If omitted, [baseAssetPath] is enough to distinguish different assets.
  final String? variantKey;

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
        oldWidget.selectionSeed != widget.selectionSeed ||
        oldWidget.variantKey != widget.variantKey ||
        oldWidget.resolver != widget.resolver) {
      _selectVariant();
    }
  }

  Future<void> _selectVariant() async {
    final generation = ++_selectionGeneration;
    final requestedBasePath = widget.baseAssetPath;
    final requestedSeed = widget.selectionSeed;
    final requestedVariantKey = widget.variantKey;
    final resolver = widget.resolver ?? assetVariantResolver;

    final selectedPath = requestedSeed == null
        ? await resolver.pickRandom(requestedBasePath)
        : await resolver.pickSeeded(
            requestedBasePath,
            seed: requestedSeed,
            variantKey: requestedVariantKey,
          );

    if (!mounted ||
        generation != _selectionGeneration ||
        requestedBasePath != widget.baseAssetPath ||
        requestedSeed != widget.selectionSeed ||
        requestedVariantKey != widget.variantKey) {
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
