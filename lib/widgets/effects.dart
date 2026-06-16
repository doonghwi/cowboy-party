import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Presentation-only effect layers for the table. These read NO game state —
/// they are driven entirely by the reveal flags the table already computes and
/// render purely additive visuals on top. Ported in spirit from
/// cowboy_redesign/lib/effects (Canvas-only reproduction — no flame/shader
/// dependencies, so the live launch build stays unchanged in size and risk).

/// SMOKE (스모커 연막): a soft grey particle cloud that billows up and out from
/// a seat, growing then fading — the dodge/concealment puff that the live game
/// previously had no table visual for. Self-animates once over [duration].
class SmokePuff extends StatefulWidget {
  const SmokePuff({
    super.key,
    required this.center,
    this.seed = 0,
    this.duration = const Duration(milliseconds: 1100),
  });

  /// Seat centre in the overlay's coordinate space.
  final Offset center;

  /// Deterministic per-seat variation so puffs don't look identical.
  final int seed;
  final Duration duration;

  @override
  State<SmokePuff> createState() => _SmokePuffState();
}

class _SmokePuffState extends State<SmokePuff>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Puff> _puffs;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
    final rnd = math.Random(widget.seed * 5381 + 11);
    _puffs = List.generate(18, (i) {
      final a = rnd.nextDouble() * math.pi * 2;
      final spread = 10 + rnd.nextDouble() * 20;
      return _Puff(
        start: Offset(math.cos(a) * spread, math.sin(a) * spread * 0.6),
        // Drift gently outward and slowly upward (a settling screen, not a jet).
        vx: math.cos(a) * (10 + rnd.nextDouble() * 16),
        vy: -16 - rnd.nextDouble() * 26,
        baseR: 16 + rnd.nextDouble() * 18,
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _SmokePainter(
          center: widget.center,
          puffs: _puffs,
          anim: _ctrl,
          durationSec: widget.duration.inMilliseconds / 1000.0,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _Puff {
  const _Puff({
    required this.start,
    required this.vx,
    required this.vy,
    required this.baseR,
  });
  final Offset start;
  final double vx;
  final double vy;
  final double baseR;
}

class _SmokePainter extends CustomPainter {
  _SmokePainter({
    required this.center,
    required this.puffs,
    required this.anim,
    required this.durationSec,
  }) : super(repaint: anim);

  final Offset center;
  final List<_Puff> puffs;
  final Animation<double> anim;
  final double durationSec;

  static const Color _smoke = Color(0xFFB9B4AC);

  @override
  void paint(Canvas canvas, Size size) {
    final p = anim.value.clamp(0.0, 1.0);
    final ts = p * durationSec; // seconds elapsed, for kinematics
    for (final puff in puffs) {
      // pos = start + v*t + 0.5*a*t²  (a = gravity-ish downward 8px/s²)
      final pos = center +
          puff.start +
          Offset(puff.vx, puff.vy) * ts +
          const Offset(0, 8) * (0.5 * ts * ts);
      // Puff grows then fades; soft blurred grey.
      final grow = 0.55 + p * 0.85;
      final alpha = (math.sin(p * math.pi) * 0.58).clamp(0.0, 1.0);
      if (alpha <= 0.01) continue;
      canvas.drawCircle(
        pos,
        puff.baseR * grow,
        Paint()
          ..color = _smoke.withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SmokePainter old) => true;
}
