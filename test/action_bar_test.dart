import 'package:cowboy_party/game/party_logic.dart';
import 'package:cowboy_party/widgets/action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 신규 캐릭터의 액션바가 예외 없이 렌더되고 전용 행동 버튼이 보이는지 검증.
/// (에뮬레이터 탭이 Flutter 캔버스를 못 잡는 문제와 무관한 결정적 검증.)
Widget _bar(CharId char, {int ammo = 3, int smokeLeft = 0}) => MaterialApp(
      home: Scaffold(
        body: ActionBar(
          myAmmo: ammo,
          selected: null,
          selectedTarget: -1,
          targetName: null,
          onSelect: (_) {},
          onConfirm: () {},
          myChar: char,
          trapAvailable: char == CharId.hunter,
          smokeLeft: smokeLeft,
          showPeek: char == CharId.paparazzi,
          peekEnabled: true,
          onPeek: () {},
        ),
      ),
    );

void main() {
  testWidgets('러시안룰렛: 운명의 방아쇠 버튼 표시', (t) async {
    await t.pumpWidget(_bar(CharId.roulette));
    expect(find.text('운명의 방아쇠'), findsOneWidget);
  });

  testWidgets('쌍권총: 더블 빵야 버튼 표시', (t) async {
    await t.pumpWidget(_bar(CharId.dualgun));
    expect(find.text('더블 빵야'), findsOneWidget);
  });

  testWidgets('부두술사: 저주 버튼 표시', (t) async {
    await t.pumpWidget(_bar(CharId.voodoo));
    expect(find.text('저주'), findsOneWidget);
  });

  testWidgets('파파라치: 엿보기 버튼 표시', (t) async {
    await t.pumpWidget(_bar(CharId.paparazzi));
    expect(find.textContaining('엿보기'), findsWidgets);
  });

  testWidgets('스모커: 연막 토글 표시', (t) async {
    await t.pumpWidget(_bar(CharId.smoker, smokeLeft: 2));
    expect(find.textContaining('연막'), findsWidgets);
  });

  testWidgets('사냥꾼: 덫 버튼 표시', (t) async {
    await t.pumpWidget(_bar(CharId.hunter));
    expect(find.text('덫'), findsOneWidget);
  });

  testWidgets('기본(none): 장전/방어/빵야 표시', (t) async {
    await t.pumpWidget(_bar(CharId.none));
    expect(find.text('장전'), findsOneWidget);
    expect(find.text('방어'), findsOneWidget);
    expect(find.text('빵야'), findsOneWidget);
  });

  testWidgets('평화주의자: 빵야 비활성(사용 불가 표기)', (t) async {
    await t.pumpWidget(_bar(CharId.pacifist));
    expect(find.text('사용 불가'), findsOneWidget);
  });
}
