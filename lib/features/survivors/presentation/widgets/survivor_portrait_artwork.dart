import 'package:flutter/material.dart';

const String defaultSurvivorPortraitBackgroundAssetPath =
    'assets/characters/survivor_portrait_background_default.png';

class SurvivorPortraitArtwork extends StatelessWidget {
  const SurvivorPortraitArtwork({
    super.key,
    required this.imageAssetPath,
    this.fallbackImageAssetPath,
    this.backgroundAssetPath = defaultSurvivorPortraitBackgroundAssetPath,
    this.placeholderIcon = Icons.person_rounded,
  });

  final String imageAssetPath;
  final String? fallbackImageAssetPath;
  final String? backgroundAssetPath;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (backgroundAssetPath != null)
            _FadedPortraitBackground(assetPath: backgroundAssetPath!),
          _buildPortrait(),
        ],
      ),
    );
  }

  Widget _buildPortrait() {
    Widget placeholder() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: FittedBox(
          fit: BoxFit.contain,
          child: Icon(
            placeholderIcon,
            color: const Color(0xFFB7A47E),
          ),
        ),
      );
    }

    Widget assetImage(String assetPath, {required Widget Function() onError}) {
      return Image.asset(
        assetPath,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => onError(),
      );
    }

    return Center(
      child: FractionallySizedBox(
        heightFactor: 0.94,
        child: AspectRatio(
          aspectRatio: 2 / 3,
          child: assetImage(
            imageAssetPath,
            onError: () {
              final fallback = fallbackImageAssetPath;
              if (fallback == null || fallback == imageAssetPath) {
                return placeholder();
              }
              return assetImage(fallback, onError: placeholder);
            },
          ),
        ),
      ),
    );
  }
}

class _FadedPortraitBackground extends StatelessWidget {
  const _FadedPortraitBackground({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final background = Image.asset(
      assetPath,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: [0, 0.14, 0.86, 1],
      ).createShader(bounds),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0, 0.10, 0.90, 1],
        ).createShader(bounds),
        child: background,
      ),
    );
  }
}
