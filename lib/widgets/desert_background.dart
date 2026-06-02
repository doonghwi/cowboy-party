import 'package:flutter/material.dart';

import '../theme.dart';

/// A hand-painted spaghetti-western backdrop: gradient dusk sky, a low sun,
/// layered dunes and a couple of saguaro cactus silhouettes.
///
/// [bright] swaps in a lighter palette so foreground game cards stay readable.
class DesertBackground extends StatelessWidget {
  final bool bright;
  final Widget? child;
  const DesertBackground({super.key, this.bright = false, this.child});

  @override
  Widget build(BuildContext context) {
    final sky = bright
        ? const [Color(0xFFFBEFD2), Color(0xFFF3D79B), CD.sand]
        : const [CD.skyTop, CD.skyMid, CD.skyLow];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: sky,
        ),
      ),
      child: CustomPaint(
        painter: _DesertPainter(bright: bright),
        child: child,
      ),
    );
  }
}

class _DesertPainter extends CustomPainter {
  final bool bright;
  _DesertPainter({required this.bright});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sun — a soft disc with a halo, sitting on the horizon.
    final sunCenter = Offset(w * 0.5, h * 0.34);
    final sunColor = bright ? const Color(0xFFFFE3A6) : const Color(0xFFFFD27A);
    canvas.drawCircle(
      sunCenter,
      h * 0.16,
      Paint()..color = sunColor.withValues(alpha: 0.35),
    );
    canvas.drawCircle(
      sunCenter,
      h * 0.10,
      Paint()..color = sunColor.withValues(alpha: bright ? 0.55 : 0.9),
    );

    // Stars (only at dusk).
    if (!bright) {
      final star = Paint()..color = Colors.white.withValues(alpha: 0.7);
      const pts = [
        Offset(0.12, 0.10),
        Offset(0.82, 0.08),
        Offset(0.68, 0.16),
        Offset(0.25, 0.06),
        Offset(0.9, 0.2),
      ];
      for (final p in pts) {
        canvas.drawCircle(Offset(p.dx * w, p.dy * h), 1.6, star);
      }
    }

    // Far dune.
    final far = Paint()
      ..color = bright ? const Color(0xFFE0B873) : CD.duneFar;
    final farPath = Path()
      ..moveTo(0, h * 0.66)
      ..quadraticBezierTo(w * 0.3, h * 0.58, w * 0.6, h * 0.66)
      ..quadraticBezierTo(w * 0.85, h * 0.72, w, h * 0.63)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(farPath, far);

    // Near dune.
    final near = Paint()
      ..color = bright ? const Color(0xFFCBA161) : CD.duneNear;
    final nearPath = Path()
      ..moveTo(0, h * 0.80)
      ..quadraticBezierTo(w * 0.4, h * 0.72, w * 0.7, h * 0.82)
      ..quadraticBezierTo(w * 0.88, h * 0.87, w, h * 0.80)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(nearPath, near);

    // Cactus silhouettes on the near dune.
    final cactus = Paint()
      ..color = bright ? const Color(0xFF8A6B33) : const Color(0xFF2E1C0C);
    _cactus(canvas, cactus, Offset(w * 0.16, h * 0.86), h * 0.11);
    _cactus(canvas, cactus, Offset(w * 0.84, h * 0.90), h * 0.08);
  }

  void _cactus(Canvas canvas, Paint paint, Offset base, double height) {
    final stem = height * 0.28;
    final r = Radius.circular(stem);
    // Trunk.
    canvas.drawRRect(
      RRect.fromLTRBR(base.dx - stem / 2, base.dy - height, base.dx + stem / 2,
          base.dy, r),
      paint,
    );
    // Left arm.
    canvas.drawRRect(
      RRect.fromLTRBR(base.dx - stem * 1.6, base.dy - height * 0.62,
          base.dx - stem * 1.0, base.dy - height * 0.28, r),
      paint,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(base.dx - stem * 1.6, base.dy - height * 0.62,
          base.dx - stem * 0.5, base.dy - height * 0.38, r),
      paint,
    );
    // Right arm.
    canvas.drawRRect(
      RRect.fromLTRBR(base.dx + stem * 1.0, base.dy - height * 0.72,
          base.dx + stem * 1.6, base.dy - height * 0.40, r),
      paint,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(base.dx + stem * 0.5, base.dy - height * 0.72,
          base.dx + stem * 1.6, base.dy - height * 0.52, r),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DesertPainter old) => old.bright != bright;
}
