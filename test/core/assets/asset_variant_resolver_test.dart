import 'package:ditto/core/assets/asset_variant_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AssetVariantResolver.candidatesFromAssetList', () {
    test('returns the original asset and all matching variants', () {
      final candidates = AssetVariantResolver.candidatesFromAssetList(
        'assets/characters/survivor_01_idle.png',
        const <String>[
          'assets/characters/survivor_01_idle_variant_2.png',
          'assets/characters/survivor_02_idle_variant_1.png',
          'assets/characters/survivor_01_idle.png',
          'assets/characters/survivor_01_idle_variant_1.png',
          'assets/characters/survivor_01_portrait_variant_1.png',
        ],
      );

      expect(
        candidates,
        const <String>[
          'assets/characters/survivor_01_idle.png',
          'assets/characters/survivor_01_idle_variant_1.png',
          'assets/characters/survivor_01_idle_variant_2.png',
        ],
      );
    });

    test('falls back to the requested base path when nothing matches', () {
      final candidates = AssetVariantResolver.candidatesFromAssetList(
        'assets/characters/survivor_03_idle.png',
        const <String>[
          'assets/characters/survivor_01_idle.png',
          'assets/characters/survivor_02_idle.png',
        ],
      );

      expect(
        candidates,
        const <String>['assets/characters/survivor_03_idle.png'],
      );
    });
  });
}
