// 홍보/보드용 프레임 캡처(일회성 도구) — DRAW! 슬램·승리 셀레브레이션.
// 실행: PROMO_CAPTURE_DIR=<출력폴더> flutter test test/promo_capture_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cowboy_party/widgets/celebration.dart';
import 'package:cowboy_party/widgets/reaction_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _w = 430.0, _h = 860.0;

Future<void> _capture(
    WidgetTester tester, String dir, Widget Function(int frame) build,
    {int frames = 50}) async {
  Directory(dir).createSync(recursive: true);
  await tester.binding.setSurfaceSize(const Size(_w, _h));
  for (var i = 0; i < frames; i++) {
    await tester.pumpWidget(RepaintBoundary(child: build(i)));
    await tester.pump(const Duration(milliseconds: 40)); // 25fps
    final boundary = tester
        .renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
    late final ui.Image img;
    await tester.runAsync(() async {
      img = await boundary.toImage();
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$dir/f_${i.toString().padLeft(2, '0')}.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }
}

void main() {
  final out = Platform.environment['PROMO_CAPTURE_DIR'];

  testWidgets('DRAW! 예열→슬램 프레임', (tester) async {
    if (out == null) return;
    // 0~24프레임(1초) prep, 이후 go — didUpdateWidget 슬램이 발동된다.
    await _capture(tester, '$out/draw', (i) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ReactionPanel(
          stage: i < 25 ? ReactionStage.prep : ReactionStage.go,
          opponents: const ['거스'],
          onTap: () {},
        ),
      );
    }, frames: 55);
  });

  testWidgets('승리 셀레브레이션 프레임', (tester) async {
    if (out == null) return;
    await _capture(tester, '$out/win', (i) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF2E6E5A),
          body: Stack(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 28),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3EBD8),
                    borderRadius: BorderRadius.circular(18),
                    border:
                        Border.all(color: const Color(0xFFE0B34C), width: 3),
                  ),
                  child: const Text('승리! 최후의 1인',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFB5642A))),
                ),
              ),
              const Positioned.fill(
                  child: Celebration(key: ValueKey('cap'))),
            ],
          ),
        ),
      );
    }, frames: 55);
  });
}
