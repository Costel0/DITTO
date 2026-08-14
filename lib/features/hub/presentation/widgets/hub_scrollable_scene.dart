import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/hub_background_configuration.dart';
import '../../domain/hub_scene_configuration.dart';

class HubSceneCharacter {
  const HubSceneCharacter({
    required this.assetPath,
    required this.fallbackIcon,
  });

  final String assetPath;
  final IconData fallbackIcon;
}

class HubScrollableScene extends StatefulWidget {
  const HubScrollableScene({
    super.key,
    required this.characters,
    this.configuration = defaultHubSceneConfiguration,
  });

  /// Only occupied slots need to be supplied. Slots absent from this map stay
  /// empty but retain their configured position for future companions.
  final Map<HubCharacterSlot, HubSceneCharacter> characters;
  final HubSceneConfiguration configuration;

  @override
  State<HubScrollableScene> createState() => _HubScrollableSceneState();
}

class _HubScrollableSceneState extends State<HubScrollableScene> {
  final ScrollController _scrollController = ScrollController();
  bool _initialScrollScheduled = false;

  HubSceneConfiguration get configuration => widget.configuration;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleInitialScroll(double viewportWidth) {
    if (_initialScrollScheduled) return;
    _initialScrollScheduled = true;

    if (viewportWidth >= configuration.canvasSize.width) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final target = (configuration.initialFocusX - viewportWidth / 2)
          .clamp(0.0, _scrollController.position.maxScrollExtent)
          .toDouble();
      _scrollController.jumpTo(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final backgroundSegments =
        resolveHubBackgroundSegments(configuration.backgroundState);

    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportWidth = constraints.maxWidth;
          final contentWidth = math.max(
            viewportWidth,
            configuration.canvasSize.width,
          );
          final canvasOffsetX = math.max(
            0.0,
            (viewportWidth - configuration.canvasSize.width) / 2,
          );

          _scheduleInitialScroll(viewportWidth);

          return Scrollbar(
            controller: _scrollController,
            notificationPredicate: (notification) => notification.depth == 0,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                width: contentWidth,
                height: configuration.canvasSize.height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: canvasOffsetX,
                      top: 0,
                      width: configuration.canvasSize.width,
                      height: configuration.canvasSize.height,
                      child: _HubCanvasBackground(
                        segments: backgroundSegments,
                        canvasHeight: configuration.canvasSize.height,
                        showCoordinateGrid: configuration.showCoordinateGrid,
                      ),
                    ),
                    for (final entry in widget.characters.entries)
                      _positionedCharacter(
                        canvasOffsetX: canvasOffsetX,
                        slot: entry.key,
                        character: entry.value,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _positionedCharacter({
    required double canvasOffsetX,
    required HubCharacterSlot slot,
    required HubSceneCharacter character,
  }) {
    final placement = configuration.placementFor(slot);

    return Positioned(
      left: canvasOffsetX + placement.position.dx,
      top: placement.position.dy,
      width: placement.size.width,
      height: placement.size.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: 18,
            right: 18,
            bottom: 0,
            height: 30,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _HubCharacterGroundShadowPainter(),
              ),
            ),
          ),
          Positioned.fill(
            child: _HubCharacterSprite(
              assetPath: character.assetPath,
              fallbackIcon: character.fallbackIcon,
              brightness: configuration.characterBrightness,
            ),
          ),
        ],
      ),
    );
  }
}

class _HubCharacterGroundShadowPainter extends CustomPainter {
  const _HubCharacterGroundShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x24000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final shadow = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.34,
      size.width * 0.84,
      size.height * 0.46,
    );
    canvas.drawOval(shadow, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HubCharacterSprite extends StatelessWidget {
  const _HubCharacterSprite({
    required this.assetPath,
    required this.fallbackIcon,
    required this.brightness,
  });

  final String assetPath;
  final IconData fallbackIcon;
  final double brightness;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix(<double>[
          brightness, 0, 0, 0, 0,
          0, brightness, 0, 0, 0,
          0, 0, brightness, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(
                fallbackIcon,
                size: 150,
                color: const Color(0xFF9C8D70),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HubCanvasBackground extends StatelessWidget {
  const _HubCanvasBackground({
    required this.segments,
    required this.canvasHeight,
    required this.showCoordinateGrid,
  });

  final List<HubBackgroundSegment> segments;
  final double canvasHeight;
  final bool showCoordinateGrid;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF28251D),
            Color(0xFF191813),
            Color(0xFF11110E),
          ],
        ),
        border: Border.symmetric(
          horizontal: BorderSide(
            color: const Color(0xFF5A4D38).withValues(alpha: 0.8),
          ),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (segments.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                height: canvasHeight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final segment in segments)
                      _HubBackgroundSegmentImage(
                        segment: segment,
                        canvasHeight: canvasHeight,
                      ),
                  ],
                ),
              ),
            ),
          if (showCoordinateGrid)
            const IgnorePointer(
              child: CustomPaint(
                painter: _HubCoordinateGridPainter(),
              ),
            ),
        ],
      ),
    );
  }
}

class _HubBackgroundSegmentImage extends StatelessWidget {
  const _HubBackgroundSegmentImage({
    required this.segment,
    required this.canvasHeight,
  });

  final HubBackgroundSegment segment;
  final double canvasHeight;

  Widget _image(String assetPath, {required Widget Function() onError}) {
    return Image.asset(
      assetPath,
      width: segment.width,
      height: canvasHeight,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) => onError(),
    );
  }

  Widget _emptySlot() {
    return SizedBox(
      width: segment.width,
      height: canvasHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _image(
      segment.assetPath,
      onError: () {
        if (segment.assetPath == segment.defaultAssetPath) {
          return _emptySlot();
        }

        return _image(
          segment.defaultAssetPath,
          onError: _emptySlot,
        );
      },
    );
  }
}

class _HubCoordinateGridPainter extends CustomPainter {
  const _HubCoordinateGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final minorPaint = Paint()
      ..color = const Color(0x12D5C39D)
      ..strokeWidth = 1;
    final majorPaint = Paint()
      ..color = const Color(0x1FD5C39D)
      ..strokeWidth = 1;

    const spacing = 120.0;

    for (double x = 0; x <= size.width; x += spacing) {
      final paint = x % (spacing * 4) == 0 ? majorPaint : minorPaint;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += spacing) {
      final paint = y % (spacing * 2) == 0 ? majorPaint : minorPaint;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final horizonPaint = Paint()
      ..color = const Color(0x2475634A)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(0, size.height * 0.82),
      Offset(size.width, size.height * 0.82),
      horizonPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
