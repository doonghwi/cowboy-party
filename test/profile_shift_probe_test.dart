// 빠른시작 소인원 방(n=4, 슬롯 110px)에서 휘장(TierFramed) 카드가 왼쪽으로
// 쏠리던 버그 회귀 테스트(2026-07-18 제보). TierFramed Stack이 제약을 loose로
// 풀면 92px 카드가 topStart로 붙는다 — StackFit.passthrough로 고정.
// PROFILE_PROBE_DIR 지정 시 캡처 PNG도 저장.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cowboy_party/game/characters.dart';
import 'package:cowboy_party/theme.dart';
import 'package:cowboy_party/widgets/circular_table.dart';
import 'package:cowboy_party/widgets/seat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final out = Platform.environment['PROFILE_PROBE_DIR'];

  // 빠른시작 소인원 방 재현: n=4 → CircularTable cardW=110 vs SeatCard mini 92.
  List<TableSeat> seats({required bool waiting}) => [
        for (var s = 0; s < 4; s++)
          TableSeat(
            name: s == 0 ? '둥휘둥휘' : '봇$s',
            level: waiting ? (s == 0 ? 34 : 12) : -1,
            rank: s == 0 ? 1 : 0,
            ammo: waiting ? 0 : 3,
            alive: true,
            isMe: s == 0,
            isHostSeat: s == 0,
            joined: true,
            submitted: false,
            char: CharId.values[(s % (CharId.values.length - 1)) + 1],
          ),
      ];

  Future<void> probe(WidgetTester tester, {required bool waiting}) async {
    await tester.binding.setSurfaceSize(const Size(420, 700));
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildCowboyTheme(),
      home: Material(
        type: MaterialType.transparency,
        child: RepaintBoundary(
          key: const Key('shot'),
          child: Container(
            color: const Color(0xFF2E4E40),
            child: CircularTable(
                seats: seats(waiting: waiting),
                mySeat: 0,
                center: const SizedBox()),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 600));

    // 내 카드(AnimatedContainer)와 내부 요소들의 수평 중심 비교.
    final myCard = find.ancestor(
        of: find.textContaining('둥휘'), matching: find.byType(SeatCard));
    final cardRect = tester.getRect(myCard);
    final nameRect = tester.getRect(find.textContaining('둥휘'));
    final tableRect = tester.getRect(find.byType(CircularTable));
    debugPrint('[probe ${waiting ? "waiting" : "game"}] '
        'table cx=${tableRect.center.dx.toStringAsFixed(1)} '
        'card cx=${cardRect.center.dx.toStringAsFixed(1)} '
        'card rect=${cardRect.left.toStringAsFixed(1)}..${cardRect.right.toStringAsFixed(1)} '
        'name cx=${nameRect.center.dx.toStringAsFixed(1)}');
    // 카드 내부 다른 자식들 중심도 확인.
    final colFinder = find.descendant(
        of: myCard, matching: find.byType(Column));
    final col = tester.renderObject<RenderFlex>(colFinder.first);
    var child = col.firstChild;
    var i = 0;
    while (child != null) {
      final box = child;
      final topLeft = box.localToGlobal(Offset.zero);
      debugPrint('  child#$i ${box.runtimeType} '
          'x=${topLeft.dx.toStringAsFixed(1)} w=${box.size.width.toStringAsFixed(1)} '
          'cx=${(topLeft.dx + box.size.width / 2).toStringAsFixed(1)}');
      child = col.childAfter(box);
      i++;
    }

    if (out != null) {
      Directory(out).createSync(recursive: true);
      final boundary = tester
          .renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
      await tester.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: 2);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/profile_${waiting ? "waiting" : "game"}.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    // 핵심 회귀: 내 좌석 슬롯 중심 == 카드 내용(이름) 중심 == 테이블 중심.
    expect((cardRect.center.dx - tableRect.center.dx).abs(), lessThan(0.5),
        reason: '내 좌석 슬롯이 테이블 중앙에 있어야 한다');
    expect((nameRect.center.dx - cardRect.center.dx).abs(), lessThan(0.5),
        reason: '휘장 카드 내용이 슬롯 중앙에 있어야 한다(왼쪽 쏠림 회귀)');
  }

  testWidgets('빠른시작 인게임 — 내 카드 중심 측정', (tester) async {
    await probe(tester, waiting: false);
  });

  testWidgets('대기실 — 내 카드 중심 측정', (tester) async {
    await probe(tester, waiting: true);
  });
}
