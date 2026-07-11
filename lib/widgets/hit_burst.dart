import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// 명중 파티클(타격감 1단계) — 불꽃 스파크 + 파편 + 잔류 연기.
///
/// effects.dart와 같은 원칙: 표시 전용, 게임 상태 미참조, Canvas 한 장,
/// RepaintBoundary 아래에서 자체 애니메이션 후 소멸. 기존 ShotsLayer의
/// 임팩트(흰 섬광+링)를 대체하지 않고 **위에 얹는** 증량 레이어다.
class HitBurst extends StatefulWidget {
  const HitBurst({
    super.key,
    required this.center,
    this.isSuper = false,
    this.seed = 0,
    this.duration = const Duration(milliseconds: 750),
    this.delay = Duration.zero,
  });

  /// 오버레이 좌표계에서의 임팩트 지점.
  final Offset center;

  /// 슈퍼빵야 — 스파크·파편 증량 + 금색 혼합.
  final bool isSuper;

  /// 좌석별 변주(결정적) — 같은 프레임의 두 임팩트가 똑같아 보이지 않게.
  final int seed;
  final Duration duration;

  /// 탄환 코어 도착(ShotsLayer 기준 ~450ms)에 맞추기 위한 시작 지연.
  final Duration delay;

  @override
  State<HitBurst> createState() => _HitBurstState();
}

class _Spark {
  const _Spark(this.dir, this.speed, this.len, this.gold);
  final Offset dir; // 단위 방향
  final double speed; // px/s
  final double len; // 꼬리 길이 배율
  final bool gold; // 금색/주황 혼합
}

class _Debris {
  const _Debris(this.dir, this.speed, this.r);
  final Offset dir;
  final double speed;
  final double r;
}

class _Smoke {
  const _Smoke(this.start, this.vx, this.vy, this.r);
  final Offset start;
  final double vx, vy, r;
}

class _HitBurstState extends State<HitBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final List<_Spark> _sparks;
  late final List<_Debris> _debris;
  late final List<_Smoke> _smoke;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
    final rnd = math.Random(widget.seed * 7919 + 13);
    final ns = widget.isSuper ? 24 : 16;
    _sparks = List.generate(ns, (i) {
      final a = rnd.nextDouble() * math.pi * 2;
      return _Spark(
        Offset(math.cos(a), math.sin(a)),
        180 + rnd.nextDouble() * 240,
        0.6 + rnd.nextDouble() * 0.9,
        rnd.nextBool(),
      );
    });
    final nd = widget.isSuper ? 12 : 8;
    _debris = List.generate(nd, (i) {
      final a = rnd.nextDouble() * math.pi * 2;
      return _Debris(Offset(math.cos(a), math.sin(a)),
          70 + rnd.nextDouble() * 150, 2.2 + rnd.nextDouble() * 2.2);
    });
    _smoke = List.generate(4, (i) {
      final a = rnd.nextDouble() * math.pi * 2;
      return _Smoke(
        Offset(math.cos(a) * 6, math.sin(a) * 5),
        (rnd.nextDouble() - 0.5) * 26,
        -18 - rnd.nextDouble() * 22,
        10 + rnd.nextDouble() * 9,
      );
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _HitBurstPainter(
          center: widget.center,
          sparks: _sparks,
          debris: _debris,
          smoke: _smoke,
          isSuper: widget.isSuper,
          anim: _c,
          durationSec: widget.duration.inMilliseconds / 1000.0,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _HitBurstPainter extends CustomPainter {
  _HitBurstPainter({
    required this.center,
    required this.sparks,
    required this.debris,
    required this.smoke,
    required this.isSuper,
    required this.anim,
    required this.durationSec,
  }) : super(repaint: anim);

  final Offset center;
  final List<_Spark> sparks;
  final List<_Debris> debris;
  final List<_Smoke> smoke;
  final bool isSuper;
  final Animation<double> anim;
  final double durationSec;

  static const Color _orange = Color(0xFFFF8A3D);
  static const Color _smokeCol = Color(0xFFB9B4AC);

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value.clamp(0.0, 1.0);
    final ts = t * durationSec;

    // 1) 불꽃 스파크 — 감속하며 뻗는 가는 선 + 중력 처짐. 초반 0.45에 집중.
    final sparkFade = (1 - t / 0.62).clamp(0.0, 1.0);
    if (sparkFade > 0.02) {
      for (final s in sparks) {
        // 감속 이동(스모크와 같은 방식) + 중력.
        final travel = s.speed * ts * (1 - 0.55 * t);
        final head = center + s.dir * travel + Offset(0, 60 * ts * ts);
        final tail = center +
            s.dir * (travel * (1 - 0.22 * s.len)) +
            Offset(0, 60 * ts * ts * 0.8);
        final col = s.gold ? CD.gold : _orange;
        canvas.drawLine(
          tail,
          head,
          Paint()
            ..color = col.withValues(alpha: sparkFade)
            ..strokeWidth = 2.8 * sparkFade + 0.9
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
        );
      }
    }

    // 2) 파편 — 붉은 조각이 튀어 중력으로 떨어진다.
    final debrisFade = (1 - t).clamp(0.0, 1.0);
    for (final d in debris) {
      final travel = d.speed * ts * (1 - 0.4 * t);
      final pos = center + d.dir * travel + Offset(0, 130 * ts * ts);
      canvas.drawCircle(
          pos,
          d.r * debrisFade,
          Paint()
            ..color = (isSuper ? CD.nova : CD.danger)
                .withValues(alpha: debrisFade));
    }

    // 3) 잔류 연기 — 뒤늦게(0.2~) 피어올라 끝까지 은은하게 남는다.
    final sp = ((t - 0.18) / 0.82).clamp(0.0, 1.0);
    if (sp > 0) {
      final sts = sp * durationSec;
      for (final m in smoke) {
        final pos = center +
            m.start +
            Offset(m.vx, m.vy) * sts +
            const Offset(0, 6) * (0.5 * sts * sts);
        final alpha = (math.sin(sp * math.pi) * 0.42).clamp(0.0, 1.0);
        if (alpha <= 0.01) continue;
        canvas.drawCircle(
          pos,
          m.r * (0.6 + sp * 0.9),
          Paint()
            ..color = _smokeCol.withValues(alpha: alpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );
      }
    }

    // 4) 초기 섬광 보강 — 아주 짧은 주황 글로우(기존 흰 섬광 아래 온기).
    final fl = (1 - t / 0.18).clamp(0.0, 1.0);
    if (fl > 0.01) {
      canvas.drawCircle(
        center,
        (isSuper ? 36.0 : 27.0) * (1 - fl * 0.5),
        Paint()
          ..color = _orange.withValues(alpha: 0.5 * fl)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.drawCircle(center, 10 * fl + 2,
          Paint()..color = Colors.white.withValues(alpha: 0.9 * fl));
    }
  }

  @override
  bool shouldRepaint(covariant _HitBurstPainter old) => true;
}
