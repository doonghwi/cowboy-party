// 치장(코스메틱) 라운드3 컨셉 캡처(일회성 도구) — R3_CAPTURE_DIR 지정 시.
// TFT식 범용 장착 치장 4카테고리(결투장/명중/처치/셀레브레이션)의 "느낌" 목업.
// 실제 구현이 아니라 카테고리 이해를 돕는 컨셉 스케치다.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cowboy_party/theme.dart';
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
}

/// 카테고리별 컨셉 스케치.
class _ConceptSketch extends CustomPainter {
  _ConceptSketch(this.kind); // arena | hit | kill | win
  final String kind;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(12));
    canvas.clipRRect(r);
    switch (kind) {
      case 'arena':
        _arena(canvas, size);
      case 'hit':
        _hit(canvas, size);
      case 'kill':
        _kill(canvas, size);
      case 'win':
        _win(canvas, size);
    }
  }

  void _arena(Canvas c, Size s) {
    // 밤의 축제 팔레트 미니 결투장 — 하늘·모래 색이 통째로 바뀌는 느낌.
    c.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(0, s.height), [
            const Color(0xFF241B4A),
            const Color(0xFF4A2B5E),
            const Color(0xFF7A4A3A),
          ], [
            0,
            .55,
            1
          ]));
    // 달과 별.
    c.drawCircle(Offset(s.width * .78, s.height * .2), 11,
        Paint()..color = const Color(0xFFF4E9C8));
    final rnd = [0.12, 0.3, 0.5, 0.62, 0.88, 0.42];
    for (var i = 0; i < rnd.length; i++) {
      c.drawCircle(Offset(s.width * rnd[i], s.height * (0.08 + (i % 3) * 0.1)),
          1.4, Paint()..color = Colors.white70);
    }
    // 모래 언덕.
    final dune = Path()
      ..moveTo(0, s.height * .72)
      ..quadraticBezierTo(
          s.width * .35, s.height * .58, s.width * .62, s.height * .74)
      ..quadraticBezierTo(
          s.width * .82, s.height * .85, s.width, s.height * .76)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    c.drawPath(dune, Paint()..color = const Color(0xFF3A2438));
    // 축제 전구 줄.
    final line = Path()
      ..moveTo(0, s.height * .34)
      ..quadraticBezierTo(
          s.width * .5, s.height * .5, s.width, s.height * .3);
    c.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white38);
    for (var i = 1; i <= 6; i++) {
      final t = i / 7.0;
      final x = s.width * t;
      final y = s.height * (.34 + math.sin(t * math.pi) * .13);
      c.drawCircle(Offset(x, y + 3), 2.6,
          Paint()..color = i.isEven ? const Color(0xFFFFC85C) : const Color(0xFFFF7B9C));
    }
  }

  void _hit(Canvas c, Size s) {
    // 다이너마이트 붐 — 명중 순간 파티클이 통째로 교체되는 느낌.
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF241C14));
    final ctr = Offset(s.width * .5, s.height * .52);
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5;
      final p1 = ctr + Offset(math.cos(a), math.sin(a)) * 12;
      final p2 = ctr + Offset(math.cos(a), math.sin(a)) * (i.isEven ? 34.0 : 24.0);
      c.drawLine(
          p1,
          p2,
          Paint()
            ..color = i.isEven ? const Color(0xFFFFB13D) : const Color(0xFFFF5E3A)
            ..strokeWidth = i.isEven ? 3 : 2
            ..strokeCap = StrokeCap.round);
    }
    c.drawCircle(ctr, 10, Paint()..color = const Color(0xFFFFE08A));
    c.drawCircle(ctr, 5, Paint()..color = Colors.white);
    // 튀는 불똥.
    for (final d in [const Offset(-30, -26), const Offset(34, -18), const Offset(26, 26)]) {
      c.drawCircle(ctr + d, 2.2, Paint()..color = const Color(0xFFFFB13D));
    }
  }

  void _kill(Canvas c, Size s) {
    // 현상금 회수 — 처치 순간 WANTED 도장 쾅.
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF1B222B));
    final card = Rect.fromCenter(
        center: Offset(s.width / 2, s.height * .52),
        width: s.width * .52,
        height: s.height * .62);
    c.save();
    c.translate(card.center.dx, card.center.dy);
    c.rotate(-0.06);
    c.translate(-card.center.dx, -card.center.dy);
    c.drawRRect(RRect.fromRectAndRadius(card, const Radius.circular(4)),
        Paint()..color = const Color(0xFFE8D9B0));
    final tp = TextPainter(
        text: const TextSpan(
            text: 'WANTED',
            style: TextStyle(
                color: Color(0xFF5A4630),
                fontSize: 11,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w900,
                letterSpacing: 1)),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(c, Offset(card.center.dx - tp.width / 2, card.top + 7));
    // 실루엣.
    c.drawCircle(Offset(card.center.dx, card.center.dy + 2), 9,
        Paint()..color = const Color(0xFF5A4630));
    c.restore();
    // 빨간 회수 도장.
    final stamp = Offset(s.width * .5, s.height * .56);
    c.save();
    c.translate(stamp.dx, stamp.dy);
    c.rotate(-0.35);
    final sp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = const Color(0xFFD8392B);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 74, height: 26),
            const Radius.circular(6)),
        sp);
    final tp2 = TextPainter(
        text: const TextSpan(
            text: '회수 완료',
            style: TextStyle(
                color: Color(0xFFD8392B),
                fontSize: 12,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr)
      ..layout();
    tp2.paint(c, Offset(-tp2.width / 2, -tp2.height / 2));
    c.restore();
  }

  void _win(Canvas c, Size s) {
    // 금화 비 셀레브레이션.
    c.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(0, s.height),
              [const Color(0xFF2E4E40), const Color(0xFF1C3428)]));
    final gold = Paint()..color = const Color(0xFFF2C14E);
    final dark = Paint()..color = const Color(0xFFC9992F);
    final pos = [
      [.15, .18], [.32, .38], [.5, .14], [.66, .32], [.84, .2],
      [.22, .6], [.44, .52], [.62, .62], [.8, .5], [.9, .68],
    ];
    for (var i = 0; i < pos.length; i++) {
      final o = Offset(s.width * pos[i][0], s.height * pos[i][1]);
      c.drawOval(
          Rect.fromCenter(center: o, width: 9, height: i.isEven ? 9 : 5),
          i % 3 == 0 ? dark : gold);
    }
    // 트로피.
    final base = Offset(s.width / 2, s.height * .8);
    c.drawRect(
        Rect.fromCenter(center: base, width: 26, height: 6), gold);
    c.drawRect(
        Rect.fromCenter(
            center: base.translate(0, -8), width: 8, height: 12), dark);
    final cup = Path()
      ..moveTo(base.dx - 13, base.dy - 30)
      ..quadraticBezierTo(base.dx - 11, base.dy - 12, base.dx, base.dy - 12)
      ..quadraticBezierTo(base.dx + 11, base.dy - 12, base.dx + 13, base.dy - 30)
      ..close();
    c.drawPath(cup, gold);
  }

  @override
  bool shouldRepaint(covariant _ConceptSketch old) => old.kind != kind;
}

void main() {
  final out = Platform.environment['R3_CAPTURE_DIR'];

  setUpAll(() async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    await _loadFonts();
  });

  testWidgets('치장 카테고리 4종 컨셉 목업', (tester) async {
    if (out == null) return;
    await tester.binding.setSurfaceSize(const Size(880, 350));

    Widget panel(String kind, String label, String cap) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
            const SizedBox(height: 10),
            SizedBox(
              width: 186,
              height: 150,
              child: CustomPaint(painter: _ConceptSketch(kind)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 190,
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('치장 카테고리 컨셉 (전원 공용 장착 · TFT식) — 예시는 느낌 스케치입니다',
                    style: posterTitle(17, color: Colors.white)),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    panel('arena', '결투장 스킨',
                        '게임 배경·모래·하늘이 통째로 교체\n예) 밤의 축제 · 석양 협곡 · 설원'),
                    panel('hit', '명중 이펙트',
                        '내 빵야가 맞는 순간의 폭발 연출 교체\n예) 다이너마이트 · 카드 폭죽 · 번개'),
                    panel('kill', '처치 연출',
                        '킬 슬로모 순간 나만의 마무리 도장\n예) 현상금 회수 · 까마귀 떼 · 모자 헌정'),
                    panel('win', '승리 셀레브레이션',
                        '승리 화면 연출 교체\n예) 금화 비 · 불꽃놀이 · 컨페티 폭풍'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    final boundary = tester
        .renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
    await tester.runAsync(() async {
      final img = await boundary.toImage(pixelRatio: 2);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/cosmetic_categories.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
