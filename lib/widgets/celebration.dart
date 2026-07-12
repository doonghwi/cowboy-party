import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// 승리 셀레브레이션(타격감 2단계) — 금색 콘페티 낙하 + 헤비 햅틱.
///
/// 표시 전용(게임 상태 미참조), Canvas 한 장. 결과 카드 위에 얹어 마운트
/// 순간 1회 재생하고 사라진다. 스킨 무대(B2)의 "승리 무대" 기반이 된다.
class Celebration extends StatefulWidget {
  const Celebration({
    super.key,
    this.duration = const Duration(milliseconds: 2200),
  });

  final Duration duration;

  @override
  State<Celebration> createState() => _CelebrationState();
}

class _Confetti {
  const _Confetti(this.x, this.delay, this.fall, this.drift, this.size,
      this.spin, this.color);
  final double x; // 0~1 가로 위치
  final double delay; // 0~0.35 시작 지연(진행 비율)
  final double fall; // 낙하 속도 배율
  final double drift; // 좌우 흔들림 진폭
  final double size;
  final double spin; // 회전 속도
  final Color color;
}

class _CelebrationState extends State<Celebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)..forward();
  late final List<_Confetti> _bits;

  static const _colors = [
    CD.gold,
    Color(0xFFF2D06B),
    Color(0xFFFFF3C4),
    CD.rust,
    Color(0xFFE9E2D0),
  ];

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    final rnd = math.Random(77);
    _bits = List.generate(44, (i) {
      return _Confetti(
        rnd.nextDouble(),
        rnd.nextDouble() * 0.35,
        0.75 + rnd.nextDouble() * 0.8,
        10 + rnd.nextDouble() * 26,
        5 + rnd.nextDouble() * 6,
        (rnd.nextDouble() - 0.5) * 10,
        _colors[i % _colors.length],
      );
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
        painter: _ConfettiPainter(bits: _bits, anim: _c),
        size: Size.infinite,
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.bits, required this.anim})
      : super(repaint: anim);

  final List<_Confetti> bits;
  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value.clamp(0.0, 1.0);
    for (final b in bits) {
      final p = ((t - b.delay) / (1 - b.delay)).clamp(0.0, 1.0);
      if (p <= 0) continue;
      final fade = p > 0.82 ? (1 - (p - 0.82) / 0.18).clamp(0.0, 1.0) : 1.0;
      // 위(-10%)에서 아래(110%)로, 가속 낙하 + 사인 드리프트.
      final y = size.height * (-0.1 + 1.2 * Curves.easeIn.transform(p) * b.fall);
      if (y > size.height + 20) continue;
      final x = size.width * b.x + math.sin(p * 6 + b.x * 9) * b.drift;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p * b.spin);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: b.size, height: b.size * 0.62),
            const Radius.circular(1.5)),
        Paint()..color = b.color.withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}
