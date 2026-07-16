// 휘장 인게임 소실 버그 프로브(일회성) — EMBLEM_PROBE_DIR 지정 시 캡처.
// 대기방 모드 vs 게임 모드 파라미터로 CircularTable을 렌더해 휘장 유무를 비교.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cowboy_party/game/characters.dart';
import 'package:cowboy_party/theme.dart';
import 'package:cowboy_party/widgets/circular_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final out = Platform.environment['EMBLEM_PROBE_DIR'];

  testWidgets('대기방 vs 게임 모드 휘장 렌더 비교', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    await tester.binding.setSurfaceSize(const Size(420, 900));

    List<TableSeat> seats({required bool waiting}) => [
          for (var s = 0; s < 4; s++)
            TableSeat(
              name: s == 1 ? '랭커' : 'p$s',
              level: waiting ? (s == 1 ? 21 : 3) : -1,
              rank: s == 1 ? 1 : 0,
              ammo: waiting ? 0 : 2,
              alive: true,
              isMe: s == 0,
              joined: true,
              submitted: false,
              char: s == 1 ? CharId.sniper : CharId.commoner,
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
            child: Column(children: [
              const Text('대기방 모드', style: TextStyle(color: Colors.white)),
              Expanded(
                  child: CircularTable(
                      seats: seats(waiting: true), mySeat: 0, center: const SizedBox())),
              const Text('게임 모드', style: TextStyle(color: Colors.white)),
              Expanded(
                  child: CircularTable(
                      seats: seats(waiting: false), mySeat: 0, center: const SizedBox())),
            ]),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 600));
    final boundary = tester
        .renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
    await tester.runAsync(() async {
      final img = await boundary.toImage(pixelRatio: 2);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/emblem_probe.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
