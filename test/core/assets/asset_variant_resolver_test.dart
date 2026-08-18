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

  group('AssetVariantResolver.seededIndex', () {
    const key =
        'survivor-a|assets/characters/survivor_01_idle.png';

    test('is stable for the same seed and element key', () {
      final first = AssetVariantResolver.seededIndex(
        seed: 12,
        key: key,
        candidateCount: 4,
      );
      final second = AssetVariantResolver.seededIndex(
        seed: 12,
        key: key,
        candidateCount: 4,
      );

      expect(second, first);
      expect(first, inInclusiveRange(0, 3));
    });

    test('uses the bunker seed when resolving the candidate index', () {
      expect(
        AssetVariantResolver.seededIndex(
          seed: 1,
          key: key,
          candidateCount: 4,
        ),
        3,
      );
      expect(
        AssetVariantResolver.seededIndex(
          seed: 2,
          key: key,
          candidateCount: 4,
        ),
        0,
      );
    });

    test('rejects an empty candidate list', () {
      expect(
        () => AssetVariantResolver.seededIndex(
          seed: 1,
          key: key,
          candidateCount: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
