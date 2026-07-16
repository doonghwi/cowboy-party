// 캐릭터 선택 "전체 보기" 시안 캡처(일회성 도구) — R4_CAPTURE_DIR 지정 시.
// 제보(2026-07-16): 페이저는 예쁘지만 15명 탐색이 느림 — 한눈 보기 옵션 후보 3안.
import 'dart:io';
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

const _names = [
  '일반인', '스나이퍼', '의사', '쌍권총', '결투가', '사냥꾼',
  '평화주의', '준비자', '부두술사', '그림자', '스모커', '리셋터',
];

void main() {
  final out = Platform.environment['R4_CAPTURE_DIR'];

  setUpAll(() async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    await _loadFonts();
  });

  Widget face(double r, {bool sel = false}) => Container(
        width: r * 2,
        height: r * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFE8D9B0),
          border: Border.all(
              color: sel ? CD.gold : Colors.black26, width: sel ? 3 : 1.5),
        ),
        child: Icon(Icons.person, size: r, color: const Color(0xFF8A6A2F)),
      );

  Widget phone(Widget child) => Container(
        width: 236,
        height: 320,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1C3428),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black26, width: 3),
        ),
        child: child,
      );

  Widget gridCell(int i, {double r = 17, bool sel = false}) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          face(r, sel: sel),
          const SizedBox(height: 2),
          Text(_names[i % _names.length],
              style: TextStyle(
                  fontSize: 8.5,
                  color: sel ? const Color(0xFFF2C14E) : Colors.white70,
                  fontWeight: FontWeight.w800)),
        ],
      );

  // A안: 페이저 상단 [넘겨보기|전체 보기] 세그먼트 — 전체 보기 상태.
  Widget optionA() => phone(Column(children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
              color: Colors.black26, borderRadius: BorderRadius.circular(11)),
          child: Row(children: [
            Expanded(
                child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    alignment: Alignment.center,
                    child: const Text('넘겨보기',
                        style: TextStyle(
                            color: Colors.white60,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800)))),
            Expanded(
                child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: const Color(0xFFD9A441),
                        borderRadius: BorderRadius.circular(9)),
                    child: const Text('전체 보기',
                        style: TextStyle(
                            color: Colors.black87,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900)))),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.count(
            crossAxisCount: 4,
            mainAxisSpacing: 6,
            crossAxisSpacing: 4,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < 12; i++) gridCell(i, sel: i == 1),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: const Color(0xFF2E6E5A),
              borderRadius: BorderRadius.circular(10)),
          child: const Text('스나이퍼 장착',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800)),
        ),
      ]));

  // B안: 페이저 유지 + 하단 썸네일 스트립(탭=점프).
  Widget optionB() => phone(Column(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
                color: const Color(0xFF2E4E40),
                borderRadius: BorderRadius.circular(12)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                face(34, sel: true),
                const SizedBox(height: 6),
                const Text('스나이퍼',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13)),
                const Text('◀ 지금 페이저 그대로 ▶',
                    style: TextStyle(color: Colors.white54, fontSize: 9.5)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                Column(mainAxisSize: MainAxisSize.min, children: [
                  face(13, sel: i == 1),
                ]),
            ],
          ),
        ),
        const Text('밑줄 썸네일을 탭하면 그 캐릭터로 바로 점프',
            style: TextStyle(color: Colors.white54, fontSize: 8.5)),
      ]));

  // C안: 그리드가 기본 + 탭하면 하단에 상세(대사·능력·장착) 패널.
  Widget optionC() => phone(Column(children: [
        Expanded(
          flex: 3,
          child: GridView.count(
            crossAxisCount: 4,
            mainAxisSpacing: 5,
            crossAxisSpacing: 4,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < 8; i++) gridCell(i, r: 15, sel: i == 1),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: const Color(0xFF2E4E40),
              borderRadius: BorderRadius.circular(10)),
          child: Column(children: const [
            Text('"방패 뒤에 숨어도 소용없지."',
                style: TextStyle(
                    color: Color(0xFFF2C14E),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800)),
            SizedBox(height: 3),
            Text('빵야가 20% 확률로 방어를 관통',
                style: TextStyle(color: Colors.white70, fontSize: 9)),
          ]),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: const Color(0xFF2E6E5A),
              borderRadius: BorderRadius.circular(10)),
          child: const Text('장착',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800)),
        ),
      ]));

  testWidgets('캐릭터 선택 전체 보기 3안', (tester) async {
    if (out == null) return;
    await tester.binding.setSurfaceSize(const Size(880, 470));

    Widget opt(String label, Widget body, String cap) => Column(
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
              width: 240,
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
                Text('캐릭터 선택 — 한눈에 보고 빨리 고르기 (얼굴은 자리표시, 실제론 일러스트)',
                    style: posterTitle(16, color: Colors.white)),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                        child: Center(
                            child: opt('A안 · 전체 보기 전환(추천)', optionA(),
                                '페이저 위 세그먼트로 넘겨보기↔전체 그리드 전환 — 둘 다 유지, 급할 땐 그리드'))),
                    Expanded(
                        child: Center(
                            child: opt('B안 · 하단 썸네일 스트립', optionB(),
                                '페이저는 그대로, 아래 얼굴 줄을 탭하면 바로 점프 — 화면 전환 없음'))),
                    Expanded(
                        child: Center(
                            child: opt('C안 · 그리드 기본', optionC(),
                                '그리드가 기본, 탭하면 아래에 대사·능력 요약+장착 — 가장 빠른 선택'))),
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
      File('$out/char_picker_options.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
