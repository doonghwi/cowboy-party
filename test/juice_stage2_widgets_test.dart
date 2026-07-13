// 타격감 2단계 위젯 스모크 — DRAW! 슬램·승리 콘페티가 예외 없이 재생되는지.
import 'package:cowboy_party/widgets/celebration.dart';
import 'package:cowboy_party/widgets/reaction_panel.dart';
import 'package:cowboy_party/widgets/seat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ReactionPanel: prep 펄스 → go 슬램 전환이 예외 없이 렌더', (tester) async {
    var stage = ReactionStage.prep;
    late StateSetter setStage;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, set) {
        setStage = set;
        return ReactionPanel(stage: stage, opponents: const ['조이'], onTap: () {});
      }),
    ));
    expect(find.text('준비…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500)); // 펄스 진행
    setStage(() => stage = ReactionStage.go);
    await tester.pump();
    expect(find.text('DRAW!'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100)); // 슬램+플래시 중
    await tester.pump(const Duration(milliseconds: 400)); // 슬램 종료
    setStage(() => stage = ReactionStage.falseStart);
    await tester.pump();
    expect(find.textContaining('부정출발'), findsOneWidget);
  });

  testWidgets('SeatCard: 방장 칩이 텍스트로 렌더(웹 이모지 폰트 비의존)', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 110,
            child: SeatCard(name: '나', ammo: 1, alive: true, isHost: true),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('방장'), findsOneWidget);
  });

  testWidgets('Celebration: 콘페티가 끝까지 재생되고 소멸 가능', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Stack(children: [Positioned.fill(child: Celebration())])));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 1000)); // 완료
    await tester.pumpWidget(const MaterialApp(home: SizedBox())); // dispose OK
  });
}
