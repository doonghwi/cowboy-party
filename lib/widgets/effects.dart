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
    this.pierce = false,
  });
  final Offset from;
  final Offset to;
  final bool isSuper;
  final ShotResult result;

  /// 스나이퍼 관통 — draws an extra white-hot lance through the beam.
  final bool pierce;
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

/// One muzzle-spray particle (precomputed kinematics, like the smoke puff).
class _Muzzle {
  const _Muzzle(this.dir, this.speed, this.radius, this.mix);
  final Offset dir; // unit direction along the cone
  final double speed; // px/sec
  final double radius;
  final double mix; // 0=white core … 1=beam colour
}

class _ShotsLayerState extends State<ShotsLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)..forward();
  late final List<List<_Muzzle>> _muzzles;

  @override
  void initState() {
    super.initState();
    _muzzles = [
      for (var i = 0; i < widget.shots.length; i++)
        _buildMuzzle(widget.shots[i], i)
    ];
  }

  List<_Muzzle> _buildMuzzle(ShotSpec s, int idx) {
    final dir = s.to - s.from;
    if (dir.distance < 1) return const [];
    final base = math.atan2(dir.dy, dir.dx);
    final rnd = math.Random(idx * 9973 + 7);
    final count = s.isSuper ? 22 : 14;
    return List.generate(count, (i) {
      final spread = (rnd.nextDouble() - 0.5) * (s.isSuper ? 1.5 : 1.1);
      final a = base + spread;
      final speed = (s.isSuper ? 230.0 : 160.0) * (0.4 + rnd.nextDouble());
      final radius = (s.isSuper ? 3.6 : 2.6) * (0.6 + rnd.nextDouble());
      return _Muzzle(
          Offset(math.cos(a), math.sin(a)), speed, radius, rnd.nextDouble());
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ShotsPainter(
          shots: widget.shots,
          muzzles: _muzzles,
          anim: _c,
          durationSec: widget.duration.inMilliseconds / 1000.0,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _ShotsPainter extends CustomPainter {
  _ShotsPainter({
    required this.shots,
    required this.muzzles,
    required this.anim,
    required this.durationSec,
  }) : super(repaint: anim);

  final List<ShotSpec> shots;
  final List<List<_Muzzle>> muzzles;
  final Animation<double> anim;
  final double durationSec;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value.clamp(0.0, 1.0);
    // Normal shots first, super shots on top so they dominate.
    for (final superPass in [false, true]) {
      for (var i = 0; i < shots.length; i++) {
        if (shots[i].isSuper != superPass) continue;
        _paintShot(canvas, shots[i], t, muzzles[i]);
      }
    }
  }

  void _paintShot(Canvas canvas, ShotSpec s, double t, List<_Muzzle> muzzle) {
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
      // Soft glow under the tracer so it reads as hot, not a thin scratch.
      canvas.drawLine(
          start,
          end,
          Paint()
            ..color = color.withValues(alpha: 0.30)
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      final line = Paint()
        ..color = color.withValues(alpha: 0.9)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(start, end, line);
      _arrow(canvas, end, unit, line, 11);
    }

    // 1b) Sniper pierce — a thin white-hot lance straight through the beam.
    if (s.pierce) {
      canvas.drawLine(
          start,
          end,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.9)
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2));
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

    // 3) Muzzle: a particle spray forward along the beam + a bright flash that
    //    fades fast. Particles spray out then decelerate (smoke-quality).
    final ts = t * durationSec;
    for (final m in muzzle) {
      final life = (1 - t).clamp(0.0, 1.0);
      if (life <= 0.02) continue;
      // Decelerating travel: spray out hard, ease to a stop.
      final travel = m.speed * ts * (1 - 0.4 * t);
      final pos = start + m.dir * travel;
      canvas.drawCircle(
        pos,
        m.radius * (1 - t * 0.4),
        Paint()
          ..color = Color.lerp(Colors.white, color, m.mix)!
              .withValues(alpha: life)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
      );
    }
    final fl = (1 - t / 0.25).clamp(0.0, 1.0);
    if (fl > 0.01) {
      canvas.drawCircle(
        start,
        (isSuper ? 17.0 : 12.0) * (0.5 + (1 - fl) * 0.7),
        Paint()
          ..color = color.withValues(alpha: 0.45 * fl)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawCircle(start, (isSuper ? 7.0 : 5.0) * fl + 2,
          Paint()..color = Colors.white.withValues(alpha: 0.85 * fl));
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
        // White flash core + a soft coloured bloom.
        canvas.drawCircle(
          c,
          (s.isSuper ? 26.0 : 17.0) * (0.4 + p),
          Paint()
            ..color = color.withValues(alpha: 0.4 * fade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
        );
        canvas.drawCircle(
          c,
          (s.isSuper ? 22.0 : 14.0) * (0.4 + p),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.7 * fade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        // Two expanding shock rings, staggered.
        for (final delay in [0.0, 0.28]) {
          final rp = ((p - delay) / (1 - delay)).clamp(0.0, 1.0);
          if (rp <= 0) continue;
          canvas.drawCircle(
            c,
            (s.isSuper ? 30.0 : 20.0) * (0.3 + rp),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = (s.isSuper ? 4.0 : 3.0) * (1 - rp)
              ..color = color.withValues(alpha: (1 - rp).clamp(0.0, 1.0)),
          );
        }
        // Radial debris with a little gravity sag.
        final n = s.isSuper ? 16 : 11;
        for (var i = 0; i < n; i++) {
          final a = i * 2 * math.pi / n + (i.isEven ? 0.0 : 0.3);
          final dist = (s.isSuper ? 38.0 : 26.0) * p * (i.isEven ? 1.0 : 0.7);
          final pos = c +
              Offset(math.cos(a), math.sin(a)) * dist +
              const Offset(0, 16) * (p * p);
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

/// HEAL (의사 자힐): a green cross blooms and a few sparkles rise from the seat.
class HealSparkle extends StatefulWidget {
  const HealSparkle({
    super.key,
    required this.center,
    this.seed = 0,
    this.duration = const Duration(milliseconds: 900),
  });

  final Offset center;
  final int seed;
  final Duration duration;

  @override
  State<HealSparkle> createState() => _HealSparkleState();
}

class _HealSparkleState extends State<HealSparkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)..forward();
  late final List<Offset> _dirs;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(widget.seed * 131 + 7);
    _dirs = List.generate(6, (i) {
      final a = (i / 6) * math.pi * 2 + rnd.nextDouble() * 0.5;
      return Offset(math.cos(a), math.sin(a));
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _HealPainter(center: widget.center, dirs: _dirs, anim: _c),
        size: Size.infinite,
      ),
    );
  }
}

class _HealPainter extends CustomPainter {
  _HealPainter({required this.center, required this.dirs, required this.anim})
      : super(repaint: anim);

  final Offset center;
  final List<Offset> dirs;
  final Animation<double> anim;
  static const Color _green = Color(0xFF3FA66A);

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value.clamp(0.0, 1.0);
    final fade = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0);
    // Rising sparkles.
    for (var i = 0; i < dirs.length; i++) {
      final d = dirs[i];
      final pos = center + Offset(d.dx * 16 * t, -18 - 30 * t + d.dy * 6);
      canvas.drawCircle(pos, 2.2 * fade,
          Paint()..color = _green.withValues(alpha: 0.9 * fade));
    }
    // A pulsing green cross above the seat.
    final pop = t < 0.3 ? Curves.easeOutBack.transform(t / 0.3) : 1.0;
    final c = center.translate(0, -26);
    final arm = 8.0 * pop;
    final p = Paint()
      ..color = _green.withValues(alpha: fade)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c.translate(-arm, 0), c.translate(arm, 0), p);
    canvas.drawLine(c.translate(0, -arm), c.translate(0, arm), p);
    canvas.drawCircle(
        c,
        arm + 5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _green.withValues(alpha: 0.5 * fade));
  }

  @override
  bool shouldRepaint(covariant _HealPainter old) => true;
}

/// RESET (리셋터 무효): a cool blue ripple washes out over the seat, signalling
/// the turn's actions were nullified.
class ResetRipple extends StatefulWidget {
  const ResetRipple({
    super.key,
    required this.center,
    required this.radius,
    this.duration = const Duration(milliseconds: 760),
  });

  final Offset center;
  final double radius;
  final Duration duration;

  @override
  State<ResetRipple> createState() => _ResetRippleState();
}

class _ResetRippleState extends State<ResetRipple>
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
        painter: _ResetPainter(
            center: widget.center, radius: widget.radius, anim: _c),
        size: Size.infinite,
      ),
    );
  }
}

class _ResetPainter extends CustomPainter {
  _ResetPainter(
      {required this.center, required this.radius, required this.anim})
      : super(repaint: anim);

  final Offset center;
  final double radius;
  final Animation<double> anim;
  static const Color _blue = Color(0xFF5B7FA6);

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOut.transform(anim.value.clamp(0.0, 1.0));
    final fade = (1 - t).clamp(0.0, 1.0);
    // Soft filled wash that expands and clears.
    canvas.drawCircle(
      center,
      radius * (0.4 + t * 1.0),
      Paint()
        ..color = _blue.withValues(alpha: 0.22 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    // Crisp ripple ring.
    canvas.drawCircle(
      center,
      radius * (0.5 + t * 0.95),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * fade
        ..color = _blue.withValues(alpha: 0.85 * fade),
    );
  }

  @override
  bool shouldRepaint(covariant _ResetPainter old) => true;
}

/// CURSE (부두 저주): a pulsing purple aura with rising motes lingers over a
/// cursed seat for the reveal; [death] adds a sharp burst (저주 만료 사망).
class CurseAura extends StatefulWidget {
  const CurseAura({
    super.key,
    required this.center,
    required this.radius,
    this.death = false,
    this.seed = 0,
    this.duration = const Duration(milliseconds: 1400),
  });

  final Offset center;
  final double radius;
  final bool death;
  final int seed;
  final Duration duration;

  @override
  State<CurseAura> createState() => _CurseAuraState();
}

class _CurseAuraState extends State<CurseAura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)..forward();
  late final List<Offset> _motes;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(widget.seed * 2663 + 5);
    _motes = List.generate(8, (i) {
      final a = rnd.nextDouble() * math.pi * 2;
      final spread = 6 + rnd.nextDouble() * (widget.radius * 0.7);
      return Offset(math.cos(a) * spread, math.sin(a) * spread);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _CursePainter(
            center: widget.center,
            radius: widget.radius,
            motes: _motes,
            death: widget.death,
            anim: _c),
        size: Size.infinite,
      ),
    );
  }
}

class _CursePainter extends CustomPainter {
  _CursePainter({
    required this.center,
    required this.radius,
    required this.motes,
    required this.death,
    required this.anim,
  }) : super(repaint: anim);

  final Offset center;
  final double radius;
  final List<Offset> motes;
  final bool death;
  final Animation<double> anim;
  static const Color _purple = Color(0xFF7E57C2);

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value.clamp(0.0, 1.0);
    final pulse = 0.6 + 0.4 * math.sin(t * 16);
    final fade = t < 0.78 ? 1.0 : (1 - (t - 0.78) / 0.22).clamp(0.0, 1.0);
    // Pulsing aura glow.
    canvas.drawCircle(
      center,
      radius * (0.7 + 0.15 * pulse),
      Paint()
        ..color = _purple.withValues(alpha: 0.34 * fade * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawCircle(
      center,
      radius * 0.85,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _purple.withValues(alpha: 0.8 * fade),
    );
    // Rising motes.
    for (final m in motes) {
      final pos = center + m + Offset(0, -28 * t);
      final a = (math.sin(t * math.pi)).clamp(0.0, 1.0);
      canvas.drawCircle(
        pos,
        2.4 * fade,
        Paint()
          ..color = _purple.withValues(alpha: a * 0.9 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    // Death burst — a sharp expanding ring when the curse claims the seat.
    if (death) {
      final p = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
      canvas.drawCircle(
        center,
        radius * (0.3 + p * 1.1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * (1 - p)
          ..color = _purple.withValues(alpha: (1 - p).clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CursePainter old) => true;
}

/// ROULETTE (러시안룰렛 운명의 방아쇠): a revolver cylinder spins fast, eases to a
/// stop, then the fated chamber clicks with a flash — the 50:50 tension made
/// visible at the shooter's seat. Self-animates.
class RouletteSpin extends StatefulWidget {
  const RouletteSpin({
    super.key,
    required this.center,
    this.radius = 26,
    this.duration = const Duration(milliseconds: 1150),
  });

  final Offset center;
  final double radius;
  final Duration duration;

  @override
  State<RouletteSpin> createState() => _RouletteSpinState();
}

class _RouletteSpinState extends State<RouletteSpin>
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
        painter: _RoulettePainter(
            center: widget.center, radius: widget.radius, anim: _c),
        size: Size.infinite,
      ),
    );
  }
}

class _RoulettePainter extends CustomPainter {
  _RoulettePainter(
      {required this.center, required this.radius, required this.anim})
      : super(repaint: anim);

  final Offset center;
  final double radius;
  final Animation<double> anim;
  static const Color _steel = Color(0xFF3A3A40);

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value.clamp(0.0, 1.0);
    final fade = t < 0.86 ? 1.0 : (1 - (t - 0.86) / 0.14).clamp(0.0, 1.0);
    final spin = Curves.easeOut.transform(t) * math.pi * 8; // ~4 turns, easing
    final r = radius;

    // Tension glow that throbs while spinning.
    canvas.drawCircle(
      center,
      r * 1.35,
      Paint()
        ..color = CD.danger
            .withValues(alpha: 0.28 * fade * (0.5 + 0.5 * math.sin(t * 30)))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    // Steel cylinder body + gold rim.
    canvas.drawCircle(
        center, r, Paint()..color = _steel.withValues(alpha: 0.92 * fade));
    canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = CD.gold.withValues(alpha: fade));
    // Six chambers; the fated one (index 0) flares red after the click.
    final clicked = t > 0.78;
    for (var i = 0; i < 6; i++) {
      final a = spin + i * math.pi / 3;
      final pos = center + Offset(math.cos(a), math.sin(a)) * r * 0.56;
      final fated = i == 0 && clicked;
      canvas.drawCircle(
          pos,
          r * 0.18,
          Paint()
            ..color = (fated ? CD.danger : Colors.black)
                .withValues(alpha: (fated ? 1.0 : 0.55) * fade));
      canvas.drawCircle(
          pos,
          r * 0.18,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = CD.gold.withValues(alpha: 0.7 * fade));
    }
    // Hub.
    canvas.drawCircle(
        center, r * 0.12, Paint()..color = CD.gold.withValues(alpha: fade));
    // Click flash.
    if (clicked) {
      final fl = (1 - (t - 0.78) / 0.22).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        r * (0.6 + (1 - fl) * 1.1),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.65 * fl)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RoulettePainter old) => true;
}

/// ROULETTE SELF-BUST (운명의 방아쇠 자기-꽝): plays AFTER the shared spinning
/// intro when the 50:50 backfires on the caster — a red shock flash, a jagged
/// red starburst with a "꽝!" punch-in and a recoil shake at the caster's seat.
/// Deliberately distinct from the opponent-kill (which has no caster burst).
class RouletteBust extends StatefulWidget {
  const RouletteBust({
    super.key,
    required this.center,
    this.duration = const Duration(milliseconds: 1150),
  });

  final Offset center;
  final Duration duration;

  @override
  State<RouletteBust> createState() => _RouletteBustState();
}

class _RouletteBustState extends State<RouletteBust>
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
        painter: _BustPainter(center: widget.center, anim: _c),
        size: Size.infinite,
      ),
    );
  }
}

class _BustPainter extends CustomPainter {
  _BustPainter({required this.center, required this.anim})
      : super(repaint: anim);

  final Offset center;
  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value.clamp(0.0, 1.0);
    if (t < 0.5) return; // the spinning-cylinder intro plays first
    final p = ((t - 0.5) / 0.5).clamp(0.0, 1.0);
    final pop = p < 0.35 ? Curves.easeOutBack.transform(p / 0.35) : 1.0;
    final fade = p > 0.7 ? (1 - (p - 0.7) / 0.3).clamp(0.0, 1.0) : 1.0;
    final shake = p < 0.4 ? math.sin(p * 50) * (0.4 - p) / 0.4 * 7 : 0.0;
    final c = center.translate(shake, 0);

    // Red shock flash + a white-hot core.
    canvas.drawCircle(
      c,
      48 * (0.4 + p),
      Paint()
        ..color = CD.danger.withValues(alpha: 0.5 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawCircle(c, 26 * (0.4 + p),
        Paint()..color = Colors.white.withValues(alpha: 0.4 * fade * (1 - p)));

    // Jagged red starburst.
    final path = Path();
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final r = (i.isEven ? 34.0 : 15.0) * pop;
      final pt = c + Offset(math.cos(a), math.sin(a)) * r;
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = CD.danger.withValues(alpha: 0.9 * fade));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.8 * fade));

    // "꽝!" punch-in label.
    final tp = TextPainter(
      text: TextSpan(
        text: '꽝!',
        style: TextStyle(
          fontSize: 17 * pop,
          fontWeight: FontWeight.w900,
          color: Colors.white.withValues(alpha: fade),
          shadows: const [Shadow(color: Color(0xFF7A1408), blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c.translate(-tp.width / 2, -tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _BustPainter old) => true;
}

/// CURSE CAST (부두 저주 거는 순간): a wavering purple tether snakes from the
/// caster to the target, then bursts into a ring — the moment the hex lands.
/// (The lingering aura on the cursed seat is [CurseAura].)
class CurseBolt extends StatefulWidget {
  const CurseBolt({
    super.key,
    required this.from,
    required this.to,
    this.duration = const Duration(milliseconds: 950),
  });

  final Offset from;
  final Offset to;
  final Duration duration;

  @override
  State<CurseBolt> createState() => _CurseBoltState();
}

class _CurseBoltState extends State<CurseBolt>
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
        painter: _CurseBoltPainter(from: widget.from, to: widget.to, anim: _c),
        size: Size.infinite,
      ),
    );
  }
}

class _CurseBoltPainter extends CustomPainter {
  _CurseBoltPainter(
      {required this.from, required this.to, required this.anim})
      : super(repaint: anim);

  final Offset from;
  final Offset to;
  final Animation<double> anim;
  static const Color _purple = Color(0xFF7E57C2);

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value.clamp(0.0, 1.0);
    final dir = to - from;
    if (dir.distance < 1) return;

    // Phase 1 (0..0.55): wavering tether travels from caster to target.
    final travel = (t / 0.55).clamp(0.0, 1.0);
    if (travel < 1.0 || t < 0.6) {
      final perp = Offset(-dir.dy, dir.dx) / dir.distance;
      final path = Path()..moveTo(from.dx, from.dy);
      const n = 24;
      for (var i = 1; i <= n; i++) {
        final f = (i / n) * travel;
        final base = from + dir * f;
        final wobble = math.sin(f * 18 + t * 12) * 9 * (1 - f);
        final pt = base + perp * wobble;
        path.lineTo(pt.dx, pt.dy);
      }
      final fade = t < 0.5 ? 1.0 : (1 - (t - 0.5) / 0.3).clamp(0.0, 1.0);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = _purple.withValues(alpha: 0.85 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // Phase 2 (0.45..1): a ring bursts at the target as the hex lands.
    if (t > 0.45) {
      final p = ((t - 0.45) / 0.55).clamp(0.0, 1.0);
      final fade = (1 - p).clamp(0.0, 1.0);
      canvas.drawCircle(
        to,
        28 * (0.3 + p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * fade
          ..color = _purple.withValues(alpha: fade),
      );
      canvas.drawCircle(
        to,
        18 * (0.4 + p),
        Paint()
          ..color = _purple.withValues(alpha: 0.4 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CurseBoltPainter old) => true;
}
