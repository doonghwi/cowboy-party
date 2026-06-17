// DesertBackground 렌더 스모크 — 개선된 배경(태양 글로우·언덕 3층·선인장)이
// dusk/bright 두 팔레트 모두에서 예외 없이 그려지는지 확인(셰이더 rect·NaN 가드).
import 'package:cowboy_party/widgets/desert_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dusk·bright 배경이 자식과 함께 예외 없이 렌더된다', (tester) async {
    for (final bright in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesertBackground(
              bright: bright,
              child: const Center(child: Text('카우보이')),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'bright=$bright 렌더 예외');
      expect(find.byType(DesertBackground), findsOneWidget);
      expect(find.text('카우보이'), findsOneWidget);
    }
  });

  testWidgets('아주 작은 크기에서도 셰이더가 깨지지 않는다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 8,
            height: 8,
            child: DesertBackground(),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
