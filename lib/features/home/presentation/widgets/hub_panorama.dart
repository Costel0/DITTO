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

class HubPanorama extends StatefulWidget {
  const HubPanorama({
    super.key,
    required this.elements,
    this.canvasSize = const Size(1440, 420),
    this.initialFocusX,
  });

  final List<HubSceneElement> elements;
  final Size canvasSize;
  final double? initialFocusX;

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
      final target = (focusX - viewportWidth / 2).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
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
                      child: DecoratedBox(
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
                        child: const CustomPaint(
                          painter: _HubCoordinateGridPainter(),
                        ),
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
