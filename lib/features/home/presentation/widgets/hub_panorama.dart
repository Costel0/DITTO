import 'dart:math' as math;

import 'package:flutter/material.dart';

class HubSceneElement {
  const HubSceneElement({
    required this.position,
    required this.size,
    required this.child,
  });

  final Offset position;
  final Size size;
  final Widget child;
}

class HubBackgroundSegment {
  const HubBackgroundSegment({required this.assetPath});

  final String assetPath;
}

const List<HubBackgroundSegment> initialHubBackgroundSegments = [
  HubBackgroundSegment(assetPath: 'assets/hub/hub_initial_01.png'),
  HubBackgroundSegment(assetPath: 'assets/hub/hub_initial_02.png'),
  HubBackgroundSegment(assetPath: 'assets/hub/hub_initial_03.png'),
  HubBackgroundSegment(assetPath: 'assets/hub/hub_initial_04.png'),
  HubBackgroundSegment(assetPath: 'assets/hub/hub_initial_05.png'),
  HubBackgroundSegment(assetPath: 'assets/hub/hub_initial_06.png'),
];

class HubPanorama extends StatefulWidget {
  const HubPanorama({
    super.key,
    required this.elements,
    this.canvasSize = const Size(1440, 420),
    this.initialFocusX,
    this.backgroundSegments = initialHubBackgroundSegments,
    this.backgroundAssetPath,
    this.backgroundFit = BoxFit.cover,
    this.showCoordinateGrid = true,
  });

  final List<HubSceneElement> elements;
  final Size canvasSize;
  final double? initialFocusX;

  /// Ordered slices that form the scene background from left to right.
  ///
  /// The game state can build a different list at runtime as the hub evolves.
  /// Each PNG is rendered at the canvas height while preserving its intrinsic
  /// aspect ratio, so different source widths are supported without hardcoding
  /// them here. The authored widths should add up to [canvasSize.width].
  final List<HubBackgroundSegment> backgroundSegments;

  /// Kept temporarily so existing callers remain source-compatible while the
  /// hub migrates from one background image to a segmented composition.
  @Deprecated('Use backgroundSegments instead.')
  final String? backgroundAssetPath;

  /// Kept temporarily for source compatibility with the previous API.
  @Deprecated('Segment images preserve their native aspect ratio.')
  final BoxFit backgroundFit;

  final bool showCoordinateGrid;

  @override
  State<HubPanorama> createState() => _HubPanoramaState();
}

class _HubPanoramaState extends State<HubPanorama> {
  final ScrollController _scrollController = ScrollController();
  bool _initialScrollScheduled = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleInitialScroll(double viewportWidth) {
    if (_initialScrollScheduled) return;
    _initialScrollScheduled = true;

    if (viewportWidth >= widget.canvasSize.width) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final focusX = widget.initialFocusX ?? widget.canvasSize.width / 2;
      final target = (focusX - viewportWidth / 2)
          .clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          )
          .toDouble();
      _scrollController.jumpTo(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportWidth = constraints.maxWidth;
          final contentWidth = math.max(viewportWidth, widget.canvasSize.width);
          final canvasOffsetX = math.max(
            0.0,
            (viewportWidth - widget.canvasSize.width) / 2,
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
                height: widget.canvasSize.height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: canvasOffsetX,
                      top: 0,
                      width: widget.canvasSize.width,
                      height: widget.canvasSize.height,
                      child: _HubCanvasBackground(
                        segments: widget.backgroundSegments,
                        canvasHeight: widget.canvasSize.height,
                        showCoordinateGrid: widget.showCoordinateGrid,
                      ),
                    ),
                    for (final element in widget.elements)
                      Positioned(
                        left: canvasOffsetX + element.position.dx,
                        top: element.position.dy,
                        width: element.size.width,
                        height: element.size.height,
                        child: element.child,
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
                      Image.asset(
                        segment.assetPath,
                        height: canvasHeight,
                        fit: BoxFit.fitHeight,
                        alignment: Alignment.center,
                        filterQuality: FilterQuality.high,
                        gaplessPlayback: true,
                        excludeFromSemantics: true,
                        errorBuilder: (context, error, stackTrace) {
                          return SizedBox(height: canvasHeight);
                        },
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
