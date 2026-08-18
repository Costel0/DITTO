import 'dart:math';

import 'package:flutter/services.dart';

/// Resolves optional asset variants that follow the naming convention:
///
/// `asset.png`
/// `asset_variant_1.png`
/// `asset_variant_2.png`
/// ...
///
/// The original asset is treated as one more candidate when it exists.
class AssetVariantResolver {
  AssetVariantResolver({
    AssetBundle? bundle,
    Random? random,
  })  : _bundle = bundle ?? rootBundle,
        _random = random ?? Random();

  final AssetBundle _bundle;
  final Random _random;

  Future<AssetManifest>? _manifestFuture;

  Future<AssetManifest> _loadManifest() {
    return _manifestFuture ??=
        AssetManifest.loadFromAssetBundle(_bundle);
  }

  /// Returns the base asset plus every bundled `_variant_[x]` asset that
  /// belongs to it. If the manifest cannot be read or no candidate is found,
  /// the base path is returned so the caller can keep its normal fallback.
  Future<List<String>> candidatesFor(String baseAssetPath) async {
    try {
      final manifest = await _loadManifest();
      return candidatesFromAssetList(
        baseAssetPath,
        manifest.listAssets(),
      );
    } catch (_) {
      return <String>[baseAssetPath];
    }
  }

  /// Picks one candidate at random. The choice is intentionally not cached:
  /// callers decide how long a random selection should remain stable.
  Future<String> pickRandom(String baseAssetPath) async {
    final candidates = await candidatesFor(baseAssetPath);
    return candidates[_random.nextInt(candidates.length)];
  }

  /// Pure helper kept public so variant matching can be reused and unit tested
  /// without loading Flutter's runtime asset manifest.
  static List<String> candidatesFromAssetList(
    String baseAssetPath,
    Iterable<String> bundledAssets,
  ) {
    final extensionSeparator = baseAssetPath.lastIndexOf('.');
    final lastDirectorySeparator = baseAssetPath.lastIndexOf('/');
    final hasExtension = extensionSeparator > lastDirectorySeparator;

    final stem = hasExtension
        ? baseAssetPath.substring(0, extensionSeparator)
        : baseAssetPath;
    final extension = hasExtension
        ? baseAssetPath.substring(extensionSeparator)
        : '';

    final variantPattern = RegExp(
      '^${RegExp.escape(stem)}_variant_[^/]+${RegExp.escape(extension)}\$',
    );

    final candidates = bundledAssets
        .where(
          (assetPath) =>
              assetPath == baseAssetPath || variantPattern.hasMatch(assetPath),
        )
        .toList(growable: false);

    if (candidates.isEmpty) {
      return <String>[baseAssetPath];
    }

    final sortedCandidates = List<String>.from(candidates)
      ..sort((left, right) {
        if (left == baseAssetPath) return -1;
        if (right == baseAssetPath) return 1;
        return left.compareTo(right);
      });

    return sortedCandidates;
  }
}

final AssetVariantResolver assetVariantResolver = AssetVariantResolver();
