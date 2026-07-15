// 치장 라운드4 디자인 시안 캡처(일회성 도구) — R4_CAPTURE_DIR 지정 시.
// 사용자 규칙(2026-07-15): 디자인 작업은 코드 적용 전에 시안을 만들어 선택받는다.
// 1) 명중 이펙트 스타일 4안  2) 처치 연출 3안  3) 황금 별·치장 상점 UI 2안
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
  final root =
      Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter';
  final iconsPath =
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  if (File(iconsPath).existsSync()) {
    final icons = FontLoader('MaterialIcons')..addFont(bd(iconsPath));
    await icons.load();
  }
}

/// 명중 이펙트 스타일 스케치 — 실제로는 0.2~0.4초 파티클 애니메이션.
class _HitSketch extends CustomPainter {
  _HitSketch(this.kind); // dyna | cards | bolt | star
  final String kind;

  @override
  void paint(Canvas c, Size s) {
    c.clipRRect(RRect.fromRectAndRadius(
        Offset.zero & s, const Radius.circular(12)));
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF221B14));
    // 맞는 좌석 카드 암시.
    final card = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(s.width / 2, s.height * .72),
            width: s.width * .5,
            height: s.height * .42),
        const Radius.circular(8));
    c.drawRRect(card, Paint()..color = const Color(0xFF3A2F24));
    c.drawCircle(Offset(s.width / 2, s.height * .64), 10,
        Paint()..color = const Color(0xFF5A4A38));
    final ctr = Offset(s.width / 2, s.height * .5);
    switch (kind) {
      case 'dyna':
        for (var i = 0; i < 10; i++) {
          final a = i * math.pi / 5;
          c.drawLine(
              ctr + Offset(math.cos(a), math.sin(a)) * 10,
              ctr + Offset(math.cos(a), math.sin(a)) * (i.isEven ? 30.0 : 21.0),
              Paint()
                ..color = i.isEven
                    ? const Color(0xFFFFB13D)
                    : const Color(0xFFFF5E3A)
                ..strokeWidth = i.isEven ? 3.2 : 2.2
                ..strokeCap = StrokeCap.round);
        }
        for (final d in [const Offset(-26, -8), const Offset(24, -16)]) {
          c.drawCircle(ctr + d, 6,
              Paint()..color = const Color(0x66FF8A50));
        }
        c.drawCircle(ctr, 9, Paint()..color = const Color(0xFFFFE08A));
      case 'cards':
        final suits = [const Color(0xFFD8392B), Colors.black87];
        for (var i = 0; i < 5; i++) {
          final a = -math.pi / 2 + (i - 2) * 0.5;
          final p = ctr + Offset(math.cos(a), math.sin(a)) * (20 + i * 3.0);
          c.save();
          c.translate(p.dx, p.dy);
          c.rotate(a + math.pi / 2 + (i.isEven ? .2 : -.25));
          c.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromCenter(center: Offset.zero, width: 13, height: 18),
                  const Radius.circular(2)),
              Paint()..color = const Color(0xFFF2E8D0));
          c.drawCircle(Offset.zero, 2.4, Paint()..color = suits[i % 2]);
          c.restore();
        }
        c.drawCircle(ctr, 6, Paint()..color = Colors.white);
      case 'bolt':
        final glow = Paint()
          ..color = const Color(0x557FD7FF)
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round;
        final core = Paint()
          ..color = const Color(0xFFDFF4FF)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        final pts = [
          Offset(ctr.dx + 6, 8),
          Offset(ctr.dx - 6, s.height * .3),
          Offset(ctr.dx + 5, s.height * .38),
          Offset(ctr.dx - 4, s.height * .5),
        ];
        for (final p in [glow, core]) {
          for (var i = 0; i < pts.length - 1; i++) {
            c.drawLine(pts[i], pts[i + 1], p);
          }
        }
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3;
          c.drawLine(
              ctr + Offset(math.cos(a), math.sin(a)) * 8,
              ctr + Offset(math.cos(a), math.sin(a)) * 16,
              core..strokeWidth = 2);
        }
      case 'star':
        void star4(Offset o, double r, Color col) {
          final p = Path();
          for (var i = 0; i < 8; i++) {
            final a = i * math.pi / 4 - math.pi / 2;
            final rr = i.isEven ? r : r * .38;
            final pt = o + Offset(math.cos(a), math.sin(a)) * rr;
            i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
          }
          p.close();
          c.drawPath(p, Paint()..color = col);
        }

        c.drawCircle(ctr, 16, Paint()..color = const Color(0x33F2C14E));
        star4(ctr, 15, const Color(0xFFF2C14E));
        star4(ctr + const Offset(-22, -12), 6, const Color(0xFFFFE08A));
        star4(ctr + const Offset(20, -18), 5, const Color(0xFFFFE08A));
        star4(ctr + const Offset(16, 10), 4, const Color(0xFFF2C14E));
    }
  }

  @override
  bool shouldRepaint(covariant _HitSketch old) => old.kind != kind;
}

/// 처치 연출 스케치 — 킬 슬로모 순간 위에 얹는 마무리 도장.
class _KillSketch extends CustomPainter {
  _KillSketch(this.kind); // stamp | crows | hat
  final String kind;

  @override
  void paint(Canvas c, Size s) {
    c.clipRRect(RRect.fromRectAndRadius(
        Offset.zero & s, const Radius.circular(12)));
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF1B222B));
    switch (kind) {
      case 'stamp':
        final card = Rect.fromCenter(
            center: Offset(s.width / 2, s.height * .52),
            width: s.width * .5,
            height: s.height * .6);
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
                    fontSize: 10,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1)),
            textDirection: TextDirection.ltr)
          ..layout();
        tp.paint(c, Offset(card.center.dx - tp.width / 2, card.top + 6));
        c.drawCircle(Offset(card.center.dx, card.center.dy + 2), 8,
            Paint()..color = const Color(0xFF5A4630));
        c.restore();
        c.save();
        c.translate(s.width / 2, s.height * .56);
        c.rotate(-0.35);
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset.zero, width: 68, height: 24),
                const Radius.circular(6)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.4
              ..color = const Color(0xFFD8392B));
        final tp2 = TextPainter(
            text: const TextSpan(
                text: '회수 완료',
                style: TextStyle(
                    color: Color(0xFFD8392B),
                    fontSize: 11,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w900)),
            textDirection: TextDirection.ltr)
          ..layout();
        tp2.paint(c, Offset(-tp2.width / 2, -tp2.height / 2));
        c.restore();
      case 'crows':
        // 달과 실루엣 까마귀 떼가 날아오른다.
        c.drawCircle(Offset(s.width * .75, s.height * .25), 13,
            Paint()..color = const Color(0xFFE8DFC8));
        final wing = Paint()
          ..color = Colors.black
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        final pos = [
          [.3, .62, 9.0], [.45, .45, 11.0], [.58, .3, 8.0],
          [.68, .5, 6.0], [.38, .3, 6.0],
        ];
        for (final p in pos) {
          final o = Offset(s.width * p[0], s.height * p[1]);
          final r = p[2];
          final path = Path()
            ..moveTo(o.dx - r, o.dy)
            ..quadraticBezierTo(o.dx - r / 2, o.dy - r * .9, o.dx, o.dy)
            ..quadraticBezierTo(o.dx + r / 2, o.dy - r * .9, o.dx + r, o.dy);
          c.drawPath(path, wing);
        }
        // 떨어진 깃털.
        c.save();
        c.translate(s.width * .5, s.height * .8);
        c.rotate(.5);
        c.drawOval(Rect.fromCenter(center: Offset.zero, width: 4, height: 14),
            Paint()..color = Colors.black87);
        c.restore();
      case 'hat':
        // 모자가 벗겨져 떠오르고 링 후광.
        final o = Offset(s.width / 2, s.height * .5);
        c.drawOval(
            Rect.fromCenter(
                center: o.translate(0, -26), width: 34, height: 9),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = const Color(0xFFF2C14E));
        final hat = Paint()..color = const Color(0xFF6B4A2E);
        c.drawOval(Rect.fromCenter(center: o, width: 44, height: 12), hat);
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: o.translate(0, -7), width: 22, height: 16),
                const Radius.circular(5)),
            hat);
        c.drawRect(
            Rect.fromCenter(center: o.translate(0, -1), width: 24, height: 3.4),
            Paint()..color = const Color(0xFFC9992F));
        for (final d in [const Offset(-26, 10), const Offset(26, 4)]) {
          c.drawLine(o + d, o + d + const Offset(0, -8),
              Paint()
                ..color = Colors.white70
                ..strokeWidth = 1.6
                ..strokeCap = StrokeCap.round);
        }
    }
  }

  @override
  bool shouldRepaint(covariant _KillSketch old) => old.kind != kind;
}

void main() {
  final out = Platform.environment['R4_CAPTURE_DIR'];

  setUpAll(() async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    await _loadFonts();
  });

  Widget frame({required Widget child, required String title}) => MaterialApp(
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
                  Text(title, style: posterTitle(17, color: Colors.white)),
                  const SizedBox(height: 12),
                  child,
                ],
              ),
            ),
          ),
        ),
      );

  Widget opt(String label, Widget body, String cap, {double w = 176}) =>
      Column(
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
          body,
          const SizedBox(height: 8),
          SizedBox(
            width: w,
            child: Text(cap,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 10.5,
                    height: 1.35)),
          ),
        ],
      );

  Future<void> shoot(WidgetTester tester, String file) async {
    await tester.pump(const Duration(milliseconds: 300));
    final boundary = tester
        .renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
    await tester.runAsync(() async {
      final img = await boundary.toImage(pixelRatio: 2);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$file').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('명중 이펙트 4안', (tester) async {
    if (out == null) return;
    await tester.binding.setSurfaceSize(const Size(880, 330));
    Widget sk(String k) => SizedBox(
        width: 168, height: 128, child: CustomPaint(painter: _HitSketch(k)));
    await tester.pumpWidget(frame(
      title: '명중 이펙트 — 내 빵야가 맞는 순간의 연출 (그림은 느낌 스케치, 실제는 0.3초 파티클)',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(child: Center(child: opt('A안 · 다이너마이트', sk('dyna'),
              '주황·빨강 폭발 + 불똥 — 기본 스파크의 화끈한 상위호환'))),
          Expanded(child: Center(child: opt('B안 · 카드 폭죽', sk('cards'),
              '트럼프 카드가 튀어오름 — 도박장 무드, 경쾌함'))),
          Expanded(child: Center(child: opt('C안 · 번개', sk('bolt'),
              '하늘에서 번개 내리꽂기 — 파랑 섬광, 임팩트 최대'))),
          Expanded(child: Center(child: opt('D안 · 황금 성광', sk('star'),
              '금빛 별 반짝 — 화려하지만 우아함, 황금 별 재화와 톤 통일'))),
        ],
      ),
    ));
    await shoot(tester, 'hit_fx_options.png');
  });

  testWidgets('처치 연출 3안', (tester) async {
    if (out == null) return;
    await tester.binding.setSurfaceSize(const Size(760, 340));
    Widget sk(String k) => SizedBox(
        width: 180, height: 140, child: CustomPaint(painter: _KillSketch(k)));
    await tester.pumpWidget(frame(
      title: '처치 연출 — 킬 슬로모 순간의 마무리 도장 (그림은 느낌 스케치)',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(child: Center(child: opt('A안 · 현상금 회수', sk('stamp'),
              'WANTED 전단에 빨간 도장 쾅 — 서부 현상금 사냥꾼 무드'))),
          Expanded(child: Center(child: opt('B안 · 까마귀 떼', sk('crows'),
              '검은 까마귀들이 날아오름 — 시적이고 서늘한 연출'))),
          Expanded(child: Center(child: opt('C안 · 모자 헌정', sk('hat'),
              '모자가 벗겨져 금빛 후광으로 — 유머러스한 추모, 기존 사망 모자와 연결'))),
        ],
      ),
    ));
    await shoot(tester, 'kill_fx_options.png');
  });

  testWidgets('황금 별·치장 상점 UI 2안', (tester) async {
    if (out == null) return;
    await tester.binding.setSurfaceSize(const Size(760, 540));

    Widget chip(IconData ic, String t, Color c) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: c, borderRadius: BorderRadius.circular(9)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ic, size: 11, color: const Color(0xFFFFE08A)),
            const SizedBox(width: 3),
            Text(t,
                style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
          ]),
        );

    Widget cosmeticCard(IconData ic, String name, String price) => Container(
          width: 74,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF2E4E40),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            Icon(ic, size: 20, color: const Color(0xFFF2C14E)),
            const SizedBox(height: 3),
            Text(name,
                style: const TextStyle(
                    fontSize: 9.5,
                    color: Colors.white,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star_rounded,
                  size: 11, color: Color(0xFFF2C14E)),
              Text(price,
                  style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFFF2C14E),
                      fontWeight: FontWeight.w900)),
            ]),
          ]),
        );

    Widget phoneA() => Container(
          width: 250,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1C3428),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black26, width: 3),
          ),
          child: Column(children: [
            Row(children: [
              const Text('상점',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
              const Spacer(),
              chip(Icons.monetization_on_rounded, '4,200', const Color(0xFF8A6A2F)),
              const SizedBox(width: 4),
              chip(Icons.star_rounded, '12', const Color(0xFFB8860B)),
            ]),
            const SizedBox(height: 8),
            // 세그먼트: 캐릭터 | 치장
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(11)),
              child: Row(children: [
                Expanded(
                    child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        alignment: Alignment.center,
                        child: const Text('캐릭터',
                            style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)))),
                Expanded(
                    child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: const Color(0xFFD9A441),
                            borderRadius: BorderRadius.circular(9)),
                        child: const Text('치장',
                            style: TextStyle(
                                color: Colors.black87,
                                fontSize: 11,
                                fontWeight: FontWeight.w900)))),
              ]),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              cosmeticCard(Icons.local_fire_department_rounded, '다이너마이트', '8'),
              cosmeticCard(Icons.style_rounded, '카드 폭죽', '8'),
              cosmeticCard(Icons.receipt_long_rounded, '현상금 회수', '12'),
              cosmeticCard(Icons.flight_takeoff_rounded, '까마귀 떼', '12'),
              cosmeticCard(Icons.military_tech_rounded, '모자 헌정', '12'),
              cosmeticCard(Icons.landscape_rounded, '(예정) 결투장', '20'),
            ]),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: const Color(0xFF2E6E5A),
                  borderRadius: BorderRadius.circular(10)),
              child: const Text('미리보기 재생 ▶ · 장착',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
        );

    Widget phoneB() => Container(
          width: 250,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1C3428),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black26, width: 3),
          ),
          child: Column(children: [
            Row(children: [
              const Text('상점',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
              const Spacer(),
              chip(Icons.monetization_on_rounded, '4,200', const Color(0xFF8A6A2F)),
              const SizedBox(width: 4),
              chip(Icons.star_rounded, '12', const Color(0xFFB8860B)),
            ]),
            const SizedBox(height: 8),
            // 기존 캐릭터 캐러셀 축소 표현.
            Container(
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: const Color(0xFF2E4E40),
                  borderRadius: BorderRadius.circular(12)),
              child: const Text('캐릭터 캐러셀 (지금 그대로)\n◀ 일러스트 ▶',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 8),
            Row(children: const [
              Text('★ 치장',
                  style: TextStyle(
                      color: Color(0xFFF2C14E),
                      fontSize: 12,
                      fontWeight: FontWeight.w900)),
              Spacer(),
              Text('전체 보기 ›',
                  style: TextStyle(color: Colors.white54, fontSize: 10)),
            ]),
            const SizedBox(height: 6),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  cosmeticCard(Icons.local_fire_department_rounded, '다이너마이트', '8'),
                  cosmeticCard(Icons.style_rounded, '카드 폭죽', '8'),
                  cosmeticCard(Icons.receipt_long_rounded, '현상금', '12'),
                ]),
          ]),
        );

    await tester.pumpWidget(frame(
      title: '황금 별 잔액 표시 + 치장 상점 위치 — 어느 구조로 갈까요?',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
              child: Center(
                  child: opt(
                      'A안 · 상점 세그먼트 분리',
                      phoneA(),
                      '상점 상단에 캐릭터|치장 전환. 치장 전용 화면이라 탐색·미리보기가 넉넉함 (추천)',
                      w: 240))),
          Expanded(
              child: Center(
                  child: opt(
                      'B안 · 캐러셀 아래 섹션',
                      phoneB(),
                      '지금 상점 화면 아래에 치장 줄 추가. 화면 전환은 없지만 스크롤이 길어짐',
                      w: 240))),
        ],
      ),
    ));
    await shoot(tester, 'currency_shop_options.png');
  });
}
