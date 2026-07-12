import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// 타격감 3단계 위젯 묶음 — 전부 표시 전용(게임 상태 미참조), Canvas 위주.
/// 데미지 숫자 팝 · 탄흔 영속 · 사망 모자 굴러감 · idle 숨쉬기.

/// 피격 좌석 위로 "-1"이 떠오르며 사라지는 숫자 팝.
class DamagePop extends StatefulWidget {
  const DamagePop({
    super.key,
    required this.center,
    this.text = '-1',
    this.color = CD.danger,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 900),
  });

  final Offset center;
  final String text;
  final Color color;
  final Duration delay;
  final Duration duration;

  @override
  State<DamagePop> createState() => _DamagePopState();
}

class _DamagePopState extends State<DamagePop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _c.forward();
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
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          if (t == 0) return const SizedBox.shrink();
          final pop = t < 0.25 ? Curves.easeOutBack.transform(t / 0.25) : 1.0;
          final fade = t > 0.6 ? (1 - (t - 0.6) / 0.4).clamp(0.0, 1.0) : 1.0;
          return CustomPaint(
            size: Size.infinite,
            painter: _TextPainterOnce(
              text: widget.text,
              color: widget.color.withValues(alpha: fade),
              at: widget.center.translate(0, -46 - 34 * t),
              scale: pop,
            ),
          );
        },
      ),
    );
  }
}

class _TextPainterOnce extends CustomPainter {
  _TextPainterOnce(
      {required this.text,
      required this.color,
      required this.at,
      required this.scale});
  final String text;
  final Color color;
  final Offset at;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 22 * scale,
          fontWeight: FontWeight.w900,
          color: color,
          shadows: const [Shadow(color: Colors.black45, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at.translate(-tp.width / 2, -tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _TextPainterOnce old) =>
      old.at != at || old.scale != scale || old.color != color;
}

/// 게임 동안 테이블에 쌓이는 탄흔(영속, 상한 [kMaxBulletHoles]).
/// 목록은 화면이 들고 있고(표시 전용 상태) 여긴 그리기만 한다.
const int kMaxBulletHoles = 50;

class BulletHolesLayer extends StatelessWidget {
  const BulletHolesLayer({super.key, required this.holes});

  /// (위치, 시드) — 시드로 크기·모양 변주를 결정적으로.
  final List<(Offset, int)> holes;

  @override
  Widget build(BuildContext context) {
    if (holes.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
          painter: _HolesPainter(holes: List.of(holes)), size: Size.infinite),
    );
  }
}

class _HolesPainter extends CustomPainter {
  _HolesPainter({required this.holes});
  final List<(Offset, int)> holes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (pos, seed) in holes) {
      final rnd = math.Random(seed);
      final r = 2.6 + rnd.nextDouble() * 1.8;
      // 그을린 테두리 + 어두운 구멍.
      canvas.drawCircle(
          pos,
          r + 1.6,
          Paint()
            ..color = const Color(0xFF2B1D12).withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      canvas.drawCircle(
          pos, r, Paint()..color = const Color(0xFF17100A).withValues(alpha: 0.8));
      canvas.drawCircle(pos.translate(-r * 0.3, -r * 0.3), r * 0.35,
          Paint()..color = Colors.white.withValues(alpha: 0.12));
    }
  }

  @override
  bool shouldRepaint(covariant _HolesPainter old) =>
      old.holes.length != holes.length;
}

/// 사망 연출 — 카우보이 모자가 튕겨 굴러떨어진다.
class DeathHatRoll extends StatefulWidget {
  const DeathHatRoll({
    super.key,
    required this.center,
    this.seed = 0,
    this.delay = const Duration(milliseconds: 430),
    this.duration = const Duration(milliseconds: 1400),
  });

  final Offset center;
  final int seed;
  final Duration delay;
  final Duration duration;

  @override
  State<DeathHatRoll> createState() => _DeathHatRollState();
}

class _DeathHatRollState extends State<DeathHatRoll>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rnd = math.Random(widget.seed * 31 + 5);
    final dir = rnd.nextBool() ? 1.0 : -1.0;
    final vx = (34 + rnd.nextDouble() * 26) * dir;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          if (t == 0) return const SizedBox.shrink();
          final fade = t > 0.75 ? (1 - (t - 0.75) / 0.25).clamp(0.0, 1.0) : 1.0;
          // 포물선: 위로 살짝 떴다가 아래로 굴러떨어진다.
          final pos = widget.center.translate(
              vx * t * 2.2, -36 * math.sin(math.pi * math.min(t * 1.3, 1)) + 68 * t * t);
          return CustomPaint(
            size: Size.infinite,
            painter: _HatPainter(
                at: pos, angle: t * 5.2 * dir, alpha: fade),
          );
        },
      ),
    );
  }
}

class _HatPainter extends CustomPainter {
  _HatPainter({required this.at, required this.angle, required this.alpha});
  final Offset at;
  final double angle;
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    if (alpha <= 0.01) return;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    final brown = const Color(0xFF6B4A2F).withValues(alpha: alpha);
    final dark = const Color(0xFF4E3520).withValues(alpha: alpha);
    // 챙(넓은 타원) + 크라운(둥근 사다리꼴) — 단순 실루엣.
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 30, height: 10),
        Paint()..color = brown);
    final crown = Path()
      ..moveTo(-9, -1)
      ..quadraticBezierTo(-8, -12, 0, -12)
      ..quadraticBezierTo(8, -12, 9, -1)
      ..close();
    canvas.drawPath(crown, Paint()..color = dark);
    canvas.drawRect(
        Rect.fromCenter(center: const Offset(0, -2.5), width: 18, height: 2.6),
        Paint()..color = CD.gold.withValues(alpha: alpha * 0.9));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HatPainter old) =>
      old.at != at || old.angle != angle || old.alpha != alpha;
}

/// idle 숨쉬기 — 살아있는 좌석이 아주 미세하게 오르내린다(좌석별 위상차).
class Breathing extends StatefulWidget {
  const Breathing({super.key, required this.phase, required this.child});

  /// 좌석별 위상(0~1) — 전원이 같은 박자로 움직이지 않게.
  final double phase;
  final Widget child;

  @override
  State<Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<Breathing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(
            0, math.sin((_c.value + widget.phase) * 2 * math.pi) * 1.3),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// 버튼 공통 눌림(타격감 2단계 잔여): 눌리는 동안 0.95로 수축 + 탭음은 호출부.
class TapScale extends StatefulWidget {
  const TapScale({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: widget.child,
      ),
    );
  }
}
