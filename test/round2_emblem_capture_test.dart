// 휘장 화려함 라운드2 시안 캡처(일회성 도구) — R2_CAPTURE_DIR 지정 시.
// A=현재 반영본(TierFramed), B/C는 테스트 전용 오버레이로 "더 화려한" 방향 목업.
// 선택되면 그 수위로 tier_frame.dart를 실제 구현한다.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cowboy_party/game/characters.dart';
import 'package:cowboy_party/theme.dart';
import 'package:cowboy_party/widgets/rank_emblem.dart';
import 'package:cowboy_party/widgets/seat_card.dart';
import 'package:cowboy_party/widgets/tier_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFonts() async {
  Future<ByteData> bd(String p) async {
    final bytes = await File(p).readAsBytes();
    return ByteData.view(bytes.buffer);
  }

  final pret = FontLoader('Pretendard')
    ..addFont(bd('assets/fonts/GothicA1-Regular.ttf'))
    ..addFont(bd('assets/fonts/GothicA1-Bold.ttf'))
    ..addFont(bd('assets/fonts/GothicA1-Black.ttf'));
  await pret.load();
  final bhs = FontLoader('BlackHanSans')
    ..addFont(bd('assets/fonts/BlackHanSans-Regular.ttf'));
  await bhs.load();
  final root = Platform.environment['FLUTTER_ROOT'] ??
      '/opt/homebrew/share/flutter';
  final iconsPath =
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  if (File(iconsPath).existsSync()) {
    final icons = FontLoader('MaterialIcons')..addFont(bd(iconsPath));
    await icons.load();
  }
}

/// B/C안 목업용 추가 장식 — 실제 구현이 아니라 "이 정도 수위" 미리보기.
class _ExtraOrnament extends CustomPainter {
  _ExtraOrnament(this.tier, {required this.level}); // level 1=B, 2=C
  final RankTier tier;
  final int level;

  @override
  void paint(Canvas canvas, Size size) {
    final base = tierColor(tier);
    final accent = tierAccent(tier);
    final card = Rect.fromLTRB(12, 14, size.width - 12, size.height - 12);

    // ── B: 좌우 큰 날개(5갈래) + 이중 외곽 프레임 + 반짝 별 ──
    for (final dir in [-1.0, 1.0]) {
      final anchor = Offset(
          dir > 0 ? card.right + 2 : card.left - 2, card.top + card.height * 0.32);
      for (var i = 0; i < 5; i++) {
        final a = -0.15 - i * 0.28;
        final len = 26.0 - i * 3.5;
        final p1 = anchor + Offset(dir * 2, i * 4.0);
        final p2 = p1 + Offset(dir * math.cos(a).abs() * len, math.sin(a) * len);
        canvas.drawLine(
            p1,
            p2,
            Paint()
              ..color = (i.isEven ? base : accent)
              ..strokeWidth = 3.0 - i * 0.35
              ..strokeCap = StrokeCap.round);
      }
    }
    canvas.drawRRect(
        RRect.fromRectAndRadius(card.inflate(8), const Radius.circular(22)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = base.withValues(alpha: 0.8));
    void spark(Offset c, double r) {
      for (final a in [0.0, math.pi / 2]) {
        canvas.drawLine(
            c + Offset(math.cos(a), math.sin(a)) * r,
            c - Offset(math.cos(a), math.sin(a)) * r,
            Paint()
              ..color = Colors.white
              ..strokeWidth = 1.6
              ..strokeCap = StrokeCap.round);
      }
      canvas.drawCircle(c, r * 0.22, Paint()..color = accent);
    }

    spark(Offset(card.left + 10, card.top - 8), 5);
    spark(Offset(card.right - 6, card.bottom + 4), 6);
    if (level < 2) return;

    // ── C: 상단 방사 광선 아치 + 대형 왕관 보석 + 젬 스트립 ──
    final topC = Offset(card.center.dx, card.top - 4);
    for (var i = -4; i <= 4; i++) {
      final a = -math.pi / 2 + i * 0.16;
      final p1 = topC + Offset(math.cos(a), math.sin(a)) * 14;
      final p2 = topC + Offset(math.cos(a), math.sin(a)) * (30 - i.abs() * 2.5);
      canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = (i.isEven ? base : accent).withValues(alpha: 0.9)
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round);
    }
    // 하단 젬 스트립(3개).
    for (final dx in [-22.0, 0.0, 22.0]) {
      final c = Offset(card.center.dx + dx, card.bottom + 6);
      final p = Path()
        ..moveTo(c.dx, c.dy - 4)
        ..lineTo(c.dx + 3.4, c.dy)
        ..lineTo(c.dx, c.dy + 4)
        ..lineTo(c.dx - 3.4, c.dy)
        ..close();
      canvas.drawPath(p, Paint()..color = dx == 0 ? accent : base);
    }
    spark(Offset(card.center.dx - 34, card.top - 16), 5);
    spark(Offset(card.center.dx + 30, card.top - 20), 4);
  }

  @override
  bool shouldRepaint(covariant _ExtraOrnament old) =>
      old.tier != tier || old.level != level;
}

void main() {
  final out = Platform.environment['R2_CAPTURE_DIR'];

  setUpAll(() async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    await _loadFonts();
  });

  testWidgets('휘장 화려함 3수위(A 현재/B 강화/C 최대)', (tester) async {
    if (out == null) return;
    await tester.binding.setSurfaceSize(const Size(760, 380));

    Widget framed(int level) {
      final card = SizedBox(
        width: 150,
        child: SeatCard(
            name: '지난시즌 1등',
            ammo: 0,
            alive: true,
            level: 21,
            rankTier: RankTier.challenger,
            char: CharId.sniper),
      );
      if (level == 0) return card;
      return Stack(clipBehavior: Clip.none, children: [
        card,
        Positioned(
          left: -20,
          top: -22,
          right: -20,
          bottom: -18,
          child: IgnorePointer(
            child: CustomPaint(
                painter:
                    _ExtraOrnament(RankTier.challenger, level: level)),
          ),
        ),
      ]);
    }

    Widget opt(String label, String cap, int level) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
            ),
            const SizedBox(height: 26),
            framed(level),
            const SizedBox(height: 22),
            SizedBox(
              width: 200,
              child: Text(cap,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 10.5,
                      height: 1.35)),
            ),
          ],
        );

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildCowboyTheme(),
      home: Material(
        type: MaterialType.transparency,
        child: RepaintBoundary(
          key: const Key('shot'),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [CD.skyTop, CD.duneNear],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('휘장 화려함 — 어느 수위로 할까요? (챌린저 예시)',
                    style: posterTitle(18, color: Colors.white)),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                        child: Center(
                            child: opt('A안 · 지금 반영본',
                                '그라데이션 테두리+모서리 장식+상단 크레스트+숨쉬는 발광', 0))),
                    Expanded(
                        child: Center(
                            child: opt('B안 · 더 화려하게',
                                'A + 좌우 큰 날개(5갈래)·이중 프레임·반짝임 — 반짝은 은은히 움직임',
                                1))),
                    Expanded(
                        child: Center(
                            child: opt('C안 · 최대치',
                                'B + 상단 방사 광선 아치·하단 젬 스트립 — 로비의 주인공급 존재감',
                                2))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    final boundary = tester
        .renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
    await tester.runAsync(() async {
      final img = await boundary.toImage(pixelRatio: 2);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/emblem_flair_levels.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
