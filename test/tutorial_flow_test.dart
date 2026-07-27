import 'package:cowboy_party/screens/offline_game_screen.dart';
import 'package:cowboy_party/widgets/action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter_test/flutter_test.dart';

/// 가이드 결투(튜토리얼 A안, 2026-07-15) — 3턴 시나리오가 스크립트대로
/// 굴러가 완주 다이얼로그까지 도달하는지 결정적으로 검증.
/// (봇: 장전→빵야→장전 / 나: 장전→방어→빵야 강제)
void main() {
  Finder inBar(String label) => find.descendant(
      of: find.byType(ActionBar), matching: find.text(label));

  testWidgets('특훈: 장전→방어→빵야 3턴 완주 → 보상 다이얼로그', (t) async {
    await t.pumpWidget(
        const MaterialApp(home: OfflineGameScreen(tutorial: true)));
    await t.pump(); // postFrame _start
    await t.pump(const Duration(milliseconds: 60));

    // 턴0 — 코치가 장전을 지시, 장전만 활성.
    expect(find.textContaining('신참'), findsOneWidget);
    await t.tap(inBar('장전'));
    await t.pump(const Duration(milliseconds: 60));
    await t.tap(inBar('결정!'));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 2400)); // 리빌 → 자동 다음 턴
    await t.pump(const Duration(milliseconds: 120));

    // 턴1 — 봇이 쏘는 턴, 방어만 활성.
    expect(find.textContaining('방어"를 눌러보자'), findsOneWidget);
    await t.tap(inBar('방어'));
    await t.pump(const Duration(milliseconds: 60));
    await t.tap(inBar('결정!'));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 2400));
    await t.pump(const Duration(milliseconds: 120));

    // 턴2 — 빵야(상대 1명이라 자동 조준), 마무리.
    expect(find.textContaining('빈틈'), findsOneWidget);
    await t.tap(inBar('빵야'));
    await t.pump(const Duration(milliseconds: 60));
    await t.tap(inBar('결정!'));
    await t.pump(const Duration(milliseconds: 100));
    // 킬 슬로모(timeDilation)·연출 타이머를 실시간으로 흘려보낸 뒤 확인.
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    timeDilation = 1.0; // 슬로모 잔여 상태 정리(테스트 위생)

    expect(find.textContaining('특훈 완료'), findsOneWidget);
    expect(find.text('결투하러 가기'), findsOneWidget);
  });
}
