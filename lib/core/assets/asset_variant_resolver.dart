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

  /// Picks a candidate deterministically from a server/application seed.
  ///
  /// The backend never needs to know how many variants exist. A caller can use
  /// a stable per-element [variantKey] (for example a Survivor instance ID) so
  /// different elements do not all resolve to the same candidate for one seed.
  Future<String> pickSeeded(
    String baseAssetPath, {
    required int seed,
    String? variantKey,
  }) async {
    final candidates = await candidatesFor(baseAssetPath);
    final key = '${variantKey ?? ''}|$baseAssetPath';
    final index = seededIndex(
      seed: seed,
      key: key,
      candidateCount: candidates.length,
    );
    return candidates[index];
  }

  /// Produces a stable candidate index across rebuilds, navigation and app
  /// restarts. This deliberately avoids Dart's `String.hashCode`, whose exact
  /// implementation is not part of the persistence contract.
  static int seededIndex({
    required int seed,
    required String key,
    required int candidateCount,
  }) {
    if (candidateCount <= 0) {
      throw ArgumentError.value(
        candidateCount,
        'candidateCount',
        'must be greater than zero',
      );
    }

    return _stableHash('$seed|$key') % candidateCount;
  }

  static int _stableHash(String value) {
    var hash = 17;
    for (final codeUnit in value.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    return hash;
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
