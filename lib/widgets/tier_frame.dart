import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'rank_emblem.dart';

/// 지난 시즌 랭커 카드 장식 프레임(2026-07-15 사용자 선택: B안 변형).
///
/// LoL 시즌 승리 테두리처럼 **카드 네모 틀을 벗어나** 모서리 장식이 밖으로
/// 뻗는 화려한 프레임 — 티어색 그라데이션 테두리 + 네 모서리 플러리시 +
/// 상단 중앙 크레스트 + 은은한 숨쉬는 발광. Canvas 전용(에셋 비의존), 표시 전용.
class TierFramed extends StatelessWidget {
  const TierFramed({super.key, required this.tier, required this.child});

  final RankTier tier;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        // 장식은 카드 밖 여백까지 그린다 — 부모 Stack들이 Clip.none이라 안 잘림.
        Positioned(
          left: -12,
          top: -14,
          right: -12,
          bottom: -12,
          child: IgnorePointer(
            child: TweenAnimationBuilder<double>(
              // 숨쉬는 발광(2.4초 왕복) — 로비 전용 장식이라 가벼운 반복만.
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(seconds: 2),
              curve: Curves.easeInOut,
              builder: (context, t, _) => CustomPaint(
                painter: _TierFramePainter(tier, 0.75 + 0.25 * t),
              ),
            ),
          ),
        ),
        // 상단 중앙 크레스트 — 프레임 위에 얹힌 메달.
        Positioned(
          top: -13,
          left: 0,
          right: 0,
          child: Center(child: RankEmblem(tier: tier, size: 20)),
        ),
      ],
    );
  }
}

class _TierFramePainter extends CustomPainter {
  _TierFramePainter(this.tier, this.glow);

  final RankTier tier;
  final double glow; // 0.75~1.0 숨쉬기

  @override
  void paint(Canvas canvas, Size size) {
    final base = tierColor(tier);
    final accent = tierAccent(tier);
    // 오버레이는 카드보다 12/14 크게 깔려 있다 — 카드 실제 테두리 좌표.
    final card = Rect.fromLTRB(12, 14, size.width - 12, size.height - 12);
    final rrect = RRect.fromRectAndRadius(card.inflate(2), const Radius.circular(16));

    // ── 발광(숨쉬기) ──
    canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = base.withValues(alpha: 0.35 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));

    // ── 이중 그라데이션 테두리(금속 느낌) ──
    final borderShader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [base, accent, base, accent, base],
    ).createShader(card.inflate(6));
    canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..shader = borderShader);
    canvas.drawRRect(
        RRect.fromRectAndRadius(card.inflate(5), const Radius.circular(19)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = accent.withValues(alpha: 0.75));

    // ── 네 모서리 플러리시: 밖으로 뻗는 3갈래 장식 획 + 보석 점 ──
    void flourish(Offset corner, double dirX, double dirY) {
      for (var i = 0; i < 3; i++) {
        final len = 13.0 - i * 3.5;
        final spread = 0.32 + i * 0.42; // 갈래 각도
        final a = math.atan2(dirY, dirX);
        for (final s in [-1.0, 1.0]) {
          final ang = a + s * spread * 0.5;
          final p1 = corner + Offset(math.cos(ang), math.sin(ang)) * (4.0 + i * 2);
          final p2 = corner + Offset(math.cos(ang), math.sin(ang)) * (4.0 + i * 2 + len);
          canvas.drawLine(
              p1,
              p2,
              Paint()
                ..color = (i == 1 ? accent : base).withValues(alpha: 0.95)
                ..strokeWidth = 2.4 - i * 0.6
                ..strokeCap = StrokeCap.round);
        }
      }
      // 모서리 보석.
      canvas.drawCircle(corner, 3.2, Paint()..color = base);
      canvas.drawCircle(corner, 3.2,
          Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = accent);
      canvas.drawCircle(corner.translate(-0.8, -0.8), 1.0,
          Paint()..color = Colors.white.withValues(alpha: 0.9));
    }

    flourish(Offset(card.left - 1, card.top - 1), -1, -1);
    flourish(Offset(card.right + 1, card.top - 1), 1, -1);
    flourish(Offset(card.left - 1, card.bottom + 1), -1, 1);
    flourish(Offset(card.right + 1, card.bottom + 1), 1, 1);

    // ── 좌우 변 중앙 포인트 젬(작은 다이아) ──
    for (final c in [
      Offset(card.left - 2, card.center.dy),
      Offset(card.right + 2, card.center.dy),
    ]) {
      final p = Path()
        ..moveTo(c.dx, c.dy - 5)
        ..lineTo(c.dx + 3.4, c.dy)
        ..lineTo(c.dx, c.dy + 5)
        ..lineTo(c.dx - 3.4, c.dy)
        ..close();
      canvas.drawPath(p, Paint()..color = base);
      canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9
            ..color = accent);
    }

    // ── 하단 중앙 리본 꼬리(살짝 아래로 뻗는 V) ──
    final bc = Offset(card.center.dx, card.bottom + 1);
    final ribbon = Path()
      ..moveTo(bc.dx - 9, bc.dy)
      ..lineTo(bc.dx, bc.dy + 7)
      ..lineTo(bc.dx + 9, bc.dy)
      ..close();
    canvas.drawPath(ribbon, Paint()..color = base);
    canvas.drawPath(
        ribbon,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = accent);
  }

  @override
  bool shouldRepaint(covariant _TierFramePainter old) =>
      old.tier != tier || old.glow != glow;
}
