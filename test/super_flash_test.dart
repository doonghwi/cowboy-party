import 'package:cowboy_party/widgets/super_flash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SuperBbangyaFlash renders and animates without throwing',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Stack(children: [SuperBbangyaFlash()])),
    ));
    // The four spaced glyphs are present (stroke + fill layers both draw them).
    expect(find.text('슈 퍼 빵 야'), findsWidgets);
    expect(find.byIcon(Icons.bolt), findsOneWidget);
    // Drive the whole one-shot animation; it must complete cleanly and settle.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
