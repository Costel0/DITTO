import 'package:flutter/material.dart';

class SurvivalBackground extends StatelessWidget {
  const SurvivalBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF171610),
            Color(0xFF242017),
            Color(0xFF0D0D0B),
          ],
          stops: [0, 0.52, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            top: -110,
            left: -90,
            child: _GrimeGlow(
              size: 300,
              color: Color(0x284F3A20),
            ),
          ),
          const Positioned(
            right: -120,
            bottom: -80,
            child: _GrimeGlow(
              size: 360,
              color: Color(0x203F4A31),
            ),
          ),
          const IgnorePointer(
            child: CustomPaint(
              painter: _DistressPainter(),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GrimeGlow extends StatelessWidget {
  const _GrimeGlow({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
        ),
      ),
    );
  }
}

class _DistressPainter extends CustomPainter {
  const _DistressPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scratchPaint = Paint()
      ..color = const Color(0x12E5D5B3)
      ..strokeWidth = 1;
    final darkScratchPaint = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 2;

    final scratches = <List<Offset>>[
      [Offset(size.width * 0.08, size.height * 0.18), Offset(size.width * 0.42, size.height * 0.13)],
      [Offset(size.width * 0.58, size.height * 0.10), Offset(size.width * 0.93, size.height * 0.16)],
      [Offset(size.width * 0.04, size.height * 0.67), Offset(size.width * 0.36, size.height * 0.72)],
      [Offset(size.width * 0.63, size.height * 0.78), Offset(size.width * 0.97, size.height * 0.70)],
      [Offset(size.width * 0.20, size.height * 0.91), Offset(size.width * 0.54, size.height * 0.87)],
    ];

    for (var i = 0; i < scratches.length; i++) {
      final line = scratches[i];
      canvas.drawLine(
        line.first,
        line.last,
        i.isEven ? scratchPaint : darkScratchPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
