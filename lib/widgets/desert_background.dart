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
      // 배경은 늘 부모(=화면)를 가득 채운다 — 내용이 짧아도 아래가 끊기지 않게.
      constraints: const BoxConstraints.expand(),
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

    // Sun — soft radial glow + crisp core, sitting just above the horizon.
    final sunCenter = Offset(w * 0.5, h * 0.345);
    final core = bright ? const Color(0xFFFFEBB8) : const Color(0xFFFFD27A);
    final glow = bright ? const Color(0xFFFFE0A0) : const Color(0xFFFF9E5E);
    final glowR = h * 0.22;
    canvas.drawCircle(
      sunCenter,
      glowR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            core.withValues(alpha: bright ? 0.55 : 0.85),
            glow.withValues(alpha: 0.28),
            glow.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: sunCenter, radius: glowR)),
    );
    // Crisp disc with a faint top-lit gradient.
    final discR = h * 0.092;
    canvas.drawCircle(
      sunCenter,
      discR,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (bright ? const Color(0xFFFFF3D6) : const Color(0xFFFFE6A8)),
            core,
          ],
        ).createShader(Rect.fromCircle(center: sunCenter, radius: discR)),
    );
    // Two thin horizon light streaks across the sun (spaghetti-western look).
    if (!bright) {
      final streak = Paint()..color = CD.skyLow.withValues(alpha: 0.45);
      for (final dy in const [-0.018, 0.02]) {
        canvas.drawRect(
          Rect.fromLTWH(sunCenter.dx - discR * 1.25,
              sunCenter.dy + h * dy, discR * 2.5, h * 0.012),
          streak,
        );
      }
    }

    // Stars + a distant bird pair (only at dusk).
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
      _bird(canvas, Offset(w * 0.30, h * 0.20), w * 0.028);
      _bird(canvas, Offset(w * 0.37, h * 0.235), w * 0.022);
    }

    // Far dune.
    final far = Paint()..color = bright ? const Color(0xFFE0B873) : CD.duneFar;
    final farPath = Path()
      ..moveTo(0, h * 0.66)
      ..quadraticBezierTo(w * 0.3, h * 0.58, w * 0.6, h * 0.66)
      ..quadraticBezierTo(w * 0.85, h * 0.72, w, h * 0.63)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(farPath, far);

    // Mid dune (new depth layer) with a thin sun-lit rim.
    // duneMid: a tone between duneFar(0xFFB9712E) and duneNear(0xFF7A3E18).
    final mid = Paint()
      ..color = bright ? const Color(0xFFD6AC6A) : const Color(0xFF995824);
    final midPath = Path()
      ..moveTo(0, h * 0.73)
      ..quadraticBezierTo(w * 0.22, h * 0.67, w * 0.5, h * 0.73)
      ..quadraticBezierTo(w * 0.78, h * 0.79, w, h * 0.71)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(midPath, mid);

    // Near dune.
    final near = Paint()..color = bright ? const Color(0xFFCBA161) : CD.duneNear;
    final nearPath = Path()
      ..moveTo(0, h * 0.80)
      ..quadraticBezierTo(w * 0.4, h * 0.72, w * 0.7, h * 0.82)
      ..quadraticBezierTo(w * 0.88, h * 0.87, w, h * 0.80)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(nearPath, near);
    // Warm rim highlight along the near-dune crest (light from the sun).
    canvas.drawPath(
      nearPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = (bright ? Colors.white : const Color(0xFFFFC98A))
            .withValues(alpha: 0.18),
    );

    // Cactus silhouettes on the near dune — a tall pair + a small one for depth.
    final cactus = Paint()
      ..color = bright ? const Color(0xFF6E5226) : const Color(0xFF241405);
    _cactus(canvas, cactus, Offset(w * 0.16, h * 0.865), h * 0.115);
    _cactus(canvas, cactus, Offset(w * 0.85, h * 0.905), h * 0.085);
    _cactus(canvas, cactus, Offset(w * 0.70, h * 0.86), h * 0.05);
  }

  /// A simple two-stroke flying bird ("M" gull shape) far in the sky.
  void _bird(Canvas canvas, Offset c, double s) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF3A2A18).withValues(alpha: 0.55);
    final path = Path()
      ..moveTo(c.dx - s, c.dy)
      ..quadraticBezierTo(c.dx - s * 0.4, c.dy - s * 0.55, c.dx, c.dy)
      ..quadraticBezierTo(c.dx + s * 0.4, c.dy - s * 0.55, c.dx + s, c.dy);
    canvas.drawPath(path, p);
  }

  /// An organic saguaro: rounded trunk, arms that elbow upward, faint ribs,
  /// and a soft ground shadow. Drawn as one filled path so joints stay smooth.
  void _cactus(Canvas canvas, Paint paint, Offset base, double height) {
    final stem = height * 0.26;
    final cap = stem * 0.5;

    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(base.dx, base.dy + stem * 0.18),
          width: stem * 4.2,
          height: stem * 0.9),
      Paint()..color = const Color(0xFF000000).withValues(alpha: 0.12),
    );

    // One rounded "capsule" segment between two points.
    void limb(Offset a, Offset b, double width) {
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = paint.color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    final top = Offset(base.dx, base.dy - height);
    // Trunk.
    limb(Offset(base.dx, base.dy), top, stem);

    // Left arm: out then up, with a rounded elbow.
    final lElbow = Offset(base.dx - stem * 1.4, base.dy - height * 0.5);
    limb(Offset(base.dx, base.dy - height * 0.5), lElbow, cap);
    limb(lElbow, Offset(lElbow.dx, base.dy - height * 0.78), cap);

    // Right arm (higher, shorter).
    final rElbow = Offset(base.dx + stem * 1.3, base.dy - height * 0.62);
    limb(Offset(base.dx, base.dy - height * 0.62), rElbow, cap);
    limb(rElbow, Offset(rElbow.dx, base.dy - height * 0.86), cap);

    // Faint vertical ribs on the trunk for a hand-drawn feel.
    final rib = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.10)
      ..strokeWidth = 1;
    for (final dx in const [-0.22, 0.0, 0.22]) {
      canvas.drawLine(
        Offset(base.dx + stem * dx, base.dy - stem * 0.4),
        Offset(base.dx + stem * dx, base.dy - height + cap),
        rib,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DesertPainter old) => old.bright != bright;
}
