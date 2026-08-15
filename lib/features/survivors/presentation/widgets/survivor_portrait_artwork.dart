import 'package:flutter/material.dart';

const String defaultSurvivorPortraitBackgroundAssetPath =
    'assets/characters/survivor_portrait_background_default.png';

class SurvivorPortraitArtwork extends StatefulWidget {
  const SurvivorPortraitArtwork({
    super.key,
    required this.imageAssetPath,
    this.fallbackImageAssetPath,
    this.backgroundAssetPath = defaultSurvivorPortraitBackgroundAssetPath,
    this.placeholderIcon = Icons.person_rounded,
    this.portraitBottomInset = 20,
  });

  final String imageAssetPath;
  final String? fallbackImageAssetPath;
  final String? backgroundAssetPath;
  final IconData placeholderIcon;
  final double portraitBottomInset;

  @override
  State<SurvivorPortraitArtwork> createState() =>
      _SurvivorPortraitArtworkState();
}

class _SurvivorPortraitArtworkState extends State<SurvivorPortraitArtwork> {
  static const double _fallbackBackgroundAspectRatio = 0.62;

  ImageStream? _backgroundImageStream;
  ImageStreamListener? _backgroundImageListener;
  double? _backgroundAspectRatio;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveBackgroundAspectRatio();
  }

  @override
  void didUpdateWidget(covariant SurvivorPortraitArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backgroundAssetPath != widget.backgroundAssetPath) {
      _resolveBackgroundAspectRatio();
    }
  }

  @override
  void dispose() {
    _removeBackgroundImageListener();
    super.dispose();
  }

  void _resolveBackgroundAspectRatio() {
    _removeBackgroundImageListener();
    _backgroundAspectRatio = null;

    final assetPath = widget.backgroundAssetPath;
    if (assetPath == null) return;

    final stream = AssetImage(assetPath).resolve(
      createLocalImageConfiguration(context),
    );
    final listener = ImageStreamListener(
      (imageInfo, _) {
        final image = imageInfo.image;
        final aspectRatio = image.width / image.height;
        if (!mounted || _backgroundAspectRatio == aspectRatio) return;
        setState(() => _backgroundAspectRatio = aspectRatio);
      },
      onError: (_, _) {},
    );

    _backgroundImageStream = stream;
    _backgroundImageListener = listener;
    stream.addListener(listener);
  }

  void _removeBackgroundImageListener() {
    final stream = _backgroundImageStream;
    final listener = _backgroundImageListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _backgroundImageStream = null;
    _backgroundImageListener = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 320.0;
        final availableHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : 320.0;
        final aspectRatio =
            _backgroundAspectRatio ?? _fallbackBackgroundAspectRatio;
        final fittedSize = applyBoxFit(
          BoxFit.contain,
          Size(aspectRatio, 1),
          Size(availableWidth, availableHeight),
        ).destination;

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: fittedSize.width,
            height: fittedSize.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.backgroundAssetPath != null)
                  _FadedPortraitBackground(
                    assetPath: widget.backgroundAssetPath!,
                  ),
                Padding(
                  padding: EdgeInsets.only(
                    bottom: widget.portraitBottomInset,
                  ),
                  child: _buildPortrait(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPortrait() {
    Widget placeholder() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: FittedBox(
          fit: BoxFit.contain,
          child: Icon(
            widget.placeholderIcon,
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

    return Align(
      alignment: Alignment.bottomCenter,
      child: assetImage(
        widget.imageAssetPath,
        onError: () {
          final fallback = widget.fallbackImageAssetPath;
          if (fallback == null || fallback == widget.imageAssetPath) {
            return placeholder();
          }
          return assetImage(fallback, onError: placeholder);
        },
      ),
    );
  }
}

class _FadedPortraitBackground extends StatelessWidget {
  const _FadedPortraitBackground({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final background = Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF222019)),
        Image.asset(
          assetPath,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ],
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
        stops: [0, 0.26, 0.74, 1],
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
          stops: [0, 0.18, 0.76, 1],
        ).createShader(bounds),
        child: background,
      ),
    );
  }
}
