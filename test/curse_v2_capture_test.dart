// 저주 v2 시각 검증 캡처(일회성) — CURSE_CAPTURE_DIR 지정 시.
// 부두 2명이 같은 대상을 저주한 장면: 색 구분 배지 2개 + 부두 아이콘 색 일치.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cowboy_party/game/characters.dart';
import 'package:cowboy_party/theme.dart';
import 'package:cowboy_party/widgets/circular_table.dart';
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
}

void main() {
  final out = Platform.environment['CURSE_CAPTURE_DIR'];

  setUpAll(() async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    // 폰트 로딩은 FakeAsync 밖(setUpAll)에서 — testWidgets 안에서 하면 IO가
    // 영영 안 끝나 테스트가 타임아웃된다(이번에 밟은 함정).
    await _loadFonts();
  });

  testWidgets('부두 2명 저주 스택 — 색 구분 배지', (tester) async {
    if (out == null) return;
    await tester.binding.setSurfaceSize(const Size(420, 560));

    final seats = [
      TableSeat(
        name: '부두A',
        ammo: 1,
        alive: true,
        isMe: true,
        joined: true,
        submitted: false,
        char: CharId.voodoo,
        abilityUses: '1',
      ),
      TableSeat(
        name: '부두B',
        ammo: 0,
        alive: true,
        joined: true,
        submitted: false,
        char: CharId.voodoo,
        abilityUses: '1',
      ),
      TableSeat(
        name: '이중저주',
        ammo: 2,
        alive: true,
        joined: true,
        submitted: false,
        char: CharId.commoner,
        curses: const [(0, 7), (1, 3)],
      ),
      TableSeat(
        name: '단일저주',
        ammo: 0,
        alive: true,
        joined: true,
        submitted: false,
        char: CharId.commoner,
        curses: const [(1, 9)],
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildCowboyTheme(),
      home: Material(
        type: MaterialType.transparency,
        child: RepaintBoundary(
          key: const Key('shot'),
          child: Container(
            color: const Color(0xFF2E4E40),
            padding: const EdgeInsets.all(8),
            child: CircularTable(
                seats: seats, mySeat: 0, center: const SizedBox()),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    final boundary = tester
        .renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
    await tester.runAsync(() async {
      final img = await boundary.toImage(pixelRatio: 2);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/curse_stack.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
