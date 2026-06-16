import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

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

/// Outcome of a single shot — drives which impact the bullet leaves.
enum ShotResult { hit, blocked, missed }

/// One bullet to animate, in the overlay's coordinate space.
class ShotSpec {
  const ShotSpec({
    required this.from,
    required this.to,
    this.isSuper = false,
    this.result = ShotResult.missed,
  });
  final Offset from;
  final Offset to;
  final bool isSuper;
  final ShotResult result;
}

/// BANG / SUPER BANG tracers. Draws a *persistent* base line + arrow (so
/// who-shot-whom stays readable for the whole reveal) and, layered on top, a
/// one-shot animation: a muzzle flash at the shooter, a bright core racing to
/// the target, and an impact burst that differs by [ShotResult] (a debris/shock
/// hit, a sage deflection arc when blocked, a dust whiff when missed). Super
/// shots get the nova bolt + starburst. Canvas-only, reads no game state.
class ShotsLayer extends StatefulWidget {
  const ShotsLayer({
    super.key,
    required this.shots,
    this.duration = const Duration(milliseconds: 1000),
  });

  final List<ShotSpec> shots;
  final Duration duration;

  @override
  State<ShotsLayer> createState() => _ShotsLayerState();
}

class _ShotsLayerState extends State<ShotsLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ShotsPainter(shots: widget.shots, anim: _c),
        size: Size.infinite,
      ),
    );
  }
}

class _ShotsPainter extends CustomPainter {
  _ShotsPainter({required this.shots, required this.anim}) : super(repaint: anim);

  final List<ShotSpec> shots;
  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value.clamp(0.0, 1.0);
    // Normal shots first, super shots on top so they dominate.
    for (final superPass in [false, true]) {
      for (final s in shots) {
        if (s.isSuper != superPass) continue;
        _paintShot(canvas, s, t);
      }
    }
  }

  void _paintShot(Canvas canvas, ShotSpec s, double t) {
    final dir = s.to - s.from;
    final len = dir.distance;
    if (len < 1) return;
    final unit = dir / len;
    final start = s.from + unit * 52;
    final end = s.to - unit * 52;
    final isSuper = s.isSuper;
    final color = isSuper ? CD.nova : CD.danger;

    // 1) Persistent base line + arrowhead (visible for the whole reveal).
    if (isSuper) {
      _superBase(canvas, start, end, unit);
    } else {
      final line = Paint()
        ..color = color.withValues(alpha: 0.85)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(start, end, line);
      _arrow(canvas, end, unit, line, 11);
    }

    // 2) Travelling bright core (0..0.5) — a lit dash racing to the target.
    final head = Curves.easeOutCubic.transform((t / 0.5).clamp(0.0, 1.0));
    if (head < 1.0) {
      final hp = start + (end - start) * head;
      final tailLen = isSuper ? 60.0 : 40.0;
      final tail = hp - unit * tailLen;
      canvas.drawLine(
        tail,
        hp,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.95)
          ..strokeWidth = isSuper ? 3.5 : 2.2
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }

    // 3) Muzzle flash at the shooter (0..0.3).
    final mz = (1 - t / 0.3).clamp(0.0, 1.0);
    if (mz > 0.01) {
      final r = (isSuper ? 18.0 : 12.0) * (0.4 + (1 - mz) * 0.9);
      canvas.drawCircle(
        start,
        r,
        Paint()
          ..color = color.withValues(alpha: 0.5 * mz)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(start, r * 0.5,
          Paint()..color = Colors.white.withValues(alpha: 0.8 * mz));
    }

    // 4) Impact at the target once the core arrives.
    if (t > 0.45) {
      _impact(canvas, end, unit, s, ((t - 0.45) / 0.55).clamp(0.0, 1.0), color);
    }
  }

  void _impact(
      Canvas canvas, Offset c, Offset unit, ShotSpec s, double p, Color color) {
    final fade = (1 - p).clamp(0.0, 1.0);
    switch (s.result) {
      case ShotResult.hit:
        // White flash core.
        canvas.drawCircle(
          c,
          (s.isSuper ? 22.0 : 14.0) * (0.4 + p),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.7 * fade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        // Expanding shock ring.
        canvas.drawCircle(
          c,
          (s.isSuper ? 30.0 : 20.0) * (0.3 + p),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = (s.isSuper ? 4.0 : 3.0) * fade
            ..color = color.withValues(alpha: fade),
        );
        // Radial debris with a little gravity sag.
        final n = s.isSuper ? 12 : 9;
        for (var i = 0; i < n; i++) {
          final a = i * 2 * math.pi / n;
          final dist = (s.isSuper ? 34.0 : 24.0) * p;
          final pos = c +
              Offset(math.cos(a), math.sin(a)) * dist +
              const Offset(0, 14) * (p * p);
          canvas.drawCircle(pos, (s.isSuper ? 3.0 : 2.4) * fade,
              Paint()..color = color.withValues(alpha: fade));
        }
        if (s.isSuper) _burst(canvas, c, fade);
        break;
      case ShotResult.blocked:
        // Sage deflection arc facing the shooter + bouncing gold sparks.
        final ang = math.atan2(-unit.dy, -unit.dx);
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: s.isSuper ? 22 : 16),
          ang - 0.9,
          1.8,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5 * fade
            ..strokeCap = StrokeCap.round
            ..color = CD.sage.withValues(alpha: fade),
        );
        for (var i = 0; i < 5; i++) {
          final d = Offset(
              math.cos(ang + (i - 2) * 0.32), math.sin(ang + (i - 2) * 0.32));
          canvas.drawCircle(c + d * (18 * p), 2.0 * fade,
              Paint()..color = CD.gold.withValues(alpha: fade));
        }
        break;
      case ShotResult.missed:
        // A grey dust whiff where the bullet whizzes past.
        canvas.drawCircle(
          c,
          (s.isSuper ? 16.0 : 11.0) * (0.4 + p),
          Paint()
            ..color = const Color(0xFFB9B4AC).withValues(alpha: 0.4 * fade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        break;
    }
  }

  void _superBase(Canvas canvas, Offset start, Offset end, Offset unit) {
    canvas.drawLine(
        start,
        end,
        Paint()
          ..color = CD.nova.withValues(alpha: 0.40)
          ..strokeWidth = 13
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawLine(
        start,
        end,
        Paint()
          ..color = CD.nova
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round);
    canvas.drawLine(
        start,
        end,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round);
    _arrow(canvas, end, unit, Paint()..color = CD.nova, 18);
  }

  void _burst(Canvas canvas, Offset c, double fade) {
    canvas.drawCircle(
        c,
        14,
        Paint()
          ..color = CD.nova.withValues(alpha: 0.4 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final r = i.isEven ? 13.0 : 5.5;
      final pt = c + Offset(math.cos(a), math.sin(a)) * r;
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = CD.nova.withValues(alpha: fade));
    canvas.drawCircle(
        c, 3, Paint()..color = Colors.white.withValues(alpha: fade));
  }

  void _arrow(Canvas canvas, Offset tip, Offset unit, Paint paint, double head) {
    final back = tip - unit * head;
    final normal = Offset(-unit.dy, unit.dx);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(back.dx + normal.dx * head * 0.6, back.dy + normal.dy * head * 0.6)
      ..lineTo(back.dx - normal.dx * head * 0.6, back.dy - normal.dy * head * 0.6)
      ..close();
    canvas.drawPath(path, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _ShotsPainter old) => true;
}

/// DEFEND shockwave: one or two sage rings expand and fade outward from the
/// seat, giving the shield a sense of impact under the badge. Self-animates.
class ShieldPulse extends StatefulWidget {
  const ShieldPulse({
    super.key,
    required this.center,
    required this.radius,
    this.color = CD.sage,
    this.duration = const Duration(milliseconds: 620),
  });

  final Offset center;
  final double radius;
  final Color color;
  final Duration duration;

  @override
  State<ShieldPulse> createState() => _ShieldPulseState();
}

class _ShieldPulseState extends State<ShieldPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _PulsePainter(
            center: widget.center,
            radius: widget.radius,
            color: widget.color,
            anim: _c),
        size: Size.infinite,
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({
    required this.center,
    required this.radius,
    required this.color,
    required this.anim,
  }) : super(repaint: anim);

  final Offset center;
  final double radius;
  final Color color;
  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value.clamp(0.0, 1.0);
    // Two staggered rings for a fuller shockwave.
    for (final delay in [0.0, 0.22]) {
      final p = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (p <= 0) continue;
      final fade = (1 - p).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        radius * (0.45 + p * 0.95),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 * fade
          ..color = color.withValues(alpha: 0.75 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PulsePainter old) => true;
}

/// RELOAD spark: a few gold cartridge ticks fly up into the seat with a glint,
/// then fade — the "탄 충전" feel. [count] is larger for a double load.
class ReloadBurst extends StatefulWidget {
  const ReloadBurst({
    super.key,
    required this.center,
    this.count = 3,
    this.color = CD.gold,
    this.duration = const Duration(milliseconds: 560),
  });

  final Offset center;
  final int count;
  final Color color;
  final Duration duration;

  @override
  State<ReloadBurst> createState() => _ReloadBurstState();
}

class _ReloadBurstState extends State<ReloadBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ReloadPainter(
            center: widget.center,
            count: widget.count,
            color: widget.color,
            anim: _c),
        size: Size.infinite,
      ),
    );
  }
}

class _ReloadPainter extends CustomPainter {
  _ReloadPainter({
    required this.center,
    required this.count,
    required this.color,
    required this.anim,
  }) : super(repaint: anim);

  final Offset center;
  final int count;
  final Color color;
  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOut.transform(anim.value.clamp(0.0, 1.0));
    final fade = (1 - t).clamp(0.0, 1.0);
    for (var i = 0; i < count; i++) {
      // Spread the ticks across the seat width, rising from just below it.
      final f = count == 1 ? 0.5 : i / (count - 1);
      final dx = (f - 0.5) * 34;
      final rise = 30 - t * 46; // from +30 (below) up to -16 (into the seat)
      final pos = center + Offset(dx, rise);
      // A short cartridge: a rounded gold rect.
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: pos, width: 5, height: 11),
        const Radius.circular(2.5),
      );
      canvas.drawRRect(
          rect, Paint()..color = color.withValues(alpha: fade));
      // Brass glint at the tip.
      canvas.drawCircle(pos.translate(0, -5), 1.6,
          Paint()..color = Colors.white.withValues(alpha: 0.85 * fade));
    }
  }

  @override
  bool shouldRepaint(covariant _ReloadPainter old) => true;
}
