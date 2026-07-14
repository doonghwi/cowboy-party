import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 지난 시즌 랭커 휘장(LoL 티어 엠블럼 스타일, 2026-07-13 사용자 결정).
///
/// 등수 숫자를 적지 않고 **색과 장식 형태**로 격이 드러난다:
/// - 1등 = 챌린저(금+청 날개, 왕관 보석)
/// - 2~3등 = 마스터(보라 크레스트, 뿔 장식)
/// - 4~10등 = 다이아(청 다이아 보석)
/// 좌석 카드에는 ① 테두리 발광(두른 색) ② 카드 하단 중앙 크레스트로 노출.
/// Canvas 전용 — 에셋·이모지 폰트 비의존(웹 안전).
enum RankTier { diamond, master, challenger }

/// 지난 시즌 순위(1~10) → 티어. 그 외는 null(휘장 없음).
RankTier? tierForRank(int rank) {
  if (rank == 1) return RankTier.challenger;
  if (rank == 2 || rank == 3) return RankTier.master;
  if (rank >= 4 && rank <= 10) return RankTier.diamond;
  return null;
}

/// 티어 대표색(카드 발광·크레스트 베이스).
Color tierColor(RankTier t) => switch (t) {
      RankTier.challenger => const Color(0xFFF3C548),
      RankTier.master => const Color(0xFFB05CF0),
      RankTier.diamond => const Color(0xFF57B3F0),
    };

/// 티어 보조색(장식 포인트).
Color tierAccent(RankTier t) => switch (t) {
      RankTier.challenger => const Color(0xFF6ADCF7),
      RankTier.master => const Color(0xFFE8B7FF),
      RankTier.diamond => const Color(0xFFCBE8FF),
    };

class RankEmblem extends StatelessWidget {
  const RankEmblem({super.key, required this.tier, this.size = 24});

  final RankTier tier;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size(size * (tier == RankTier.challenger ? 1.9 : 1.3), size),
        painter: _EmblemPainter(tier),
      ),
    );
  }
}

class _EmblemPainter extends CustomPainter {
  _EmblemPainter(this.tier);
  final RankTier tier;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.height / 2;
    final base = tierColor(tier);
    final accent = tierAccent(tier);
    final dark = HSLColor.fromColor(base).withLightness(0.28).toColor();

    // ── 날개(챌린저 전용): 크레스트 좌우로 뻗는 3갈래 깃 ──
    if (tier == RankTier.challenger) {
      for (final dir in [-1.0, 1.0]) {
        for (var i = 0; i < 3; i++) {
          final a = -0.55 - i * 0.34; // 위쪽으로 펼침
          final len = r * (1.55 - i * 0.28);
          final p0 = c + Offset(dir * r * 0.62, -r * 0.05);
          final p1 = p0 +
              Offset(dir * math.cos(a).abs() * len, math.sin(a) * len);
          final wing = Paint()
            ..color = (i == 1 ? accent : base).withValues(alpha: 0.95)
            ..strokeWidth = r * (0.24 - i * 0.045)
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(p0, p1, wing);
        }
      }
    }

    // ── 마스터: 위로 솟는 뿔 3개 ──
    if (tier == RankTier.master) {
      for (final dx in [-0.55, 0.0, 0.55]) {
        final baseP = c + Offset(dx * r, -r * 0.55);
        final tip = c + Offset(dx * r * 1.25, -r * (dx == 0 ? 1.45 : 1.1));
        canvas.drawLine(
            baseP,
            tip,
            Paint()
              ..color = base
              ..strokeWidth = r * 0.22
              ..strokeCap = StrokeCap.round);
      }
    }

    // ── 공통: 원형 크레스트(금속 링 + 어두운 바탕) ──
    canvas.drawCircle(c, r * 0.92, Paint()..color = dark);
    canvas.drawCircle(
        c,
        r * 0.92,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.22
          ..shader = SweepGradient(
            colors: [base, accent, base, dark, base],
          ).createShader(Rect.fromCircle(center: c, radius: r)));

    // ── 중앙 보석: 티어별 형태 ──
    switch (tier) {
      case RankTier.diamond:
        // ◆ 다이아 컷
        final p = Path()
          ..moveTo(c.dx, c.dy - r * 0.5)
          ..lineTo(c.dx + r * 0.42, c.dy)
          ..lineTo(c.dx, c.dy + r * 0.5)
          ..lineTo(c.dx - r * 0.42, c.dy)
          ..close();
        canvas.drawPath(p, Paint()..color = base);
        canvas.drawPath(
            p,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = accent);
        canvas.drawLine(Offset(c.dx - r * 0.2, c.dy), Offset(c.dx + r * 0.2, c.dy),
            Paint()..color = accent..strokeWidth = 0.8);
      case RankTier.master:
        // 오각 보석
        final p = Path();
        for (var i = 0; i < 5; i++) {
          final a = -math.pi / 2 + i * 2 * math.pi / 5;
          final pt = c + Offset(math.cos(a), math.sin(a)) * r * 0.48;
          i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
        }
        p.close();
        canvas.drawPath(p, Paint()..color = base);
        canvas.drawCircle(c, r * 0.16, Paint()..color = accent);
      case RankTier.challenger:
        // 별 + 상단 소형 왕관 점 3개
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final a = -math.pi / 2 + i * math.pi / 5;
          final rad = i.isEven ? r * 0.5 : r * 0.22;
          final pt = c + Offset(math.cos(a), math.sin(a)) * rad;
          i == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
        }
        star.close();
        canvas.drawPath(star, Paint()..color = base);
        canvas.drawPath(
            star,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.9
              ..color = accent);
    }

    // 하이라이트 점광.
    canvas.drawCircle(c.translate(-r * 0.25, -r * 0.3), r * 0.1,
        Paint()..color = Colors.white.withValues(alpha: 0.85));
  }

  @override
  bool shouldRepaint(covariant _EmblemPainter old) => old.tier != tier;
}
