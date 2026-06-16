import 'package:cowboy_party/widgets/effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Per-character ability effect widgets must render and animate to completion
// without throwing (presentation only).
Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 400, height: 600, child: Stack(children: [child])),
      ),
    );

void main() {
  testWidgets('HealSparkle / ResetRipple / CurseAura render without throwing',
      (tester) async {
    await tester.pumpWidget(_host(const Stack(children: [
      HealSparkle(center: Offset(100, 200), seed: 1),
      ResetRipple(center: Offset(250, 200), radius: 56),
      CurseAura(center: Offset(180, 400), radius: 54, seed: 2),
      CurseAura(center: Offset(320, 400), radius: 54, death: true, seed: 3),
    ])));
    expect(find.byType(HealSparkle), findsOneWidget);
    expect(find.byType(ResetRipple), findsOneWidget);
    expect(find.byType(CurseAura), findsNWidgets(2));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  });

  testWidgets('ShotSpec.pierce lance renders without throwing', (tester) async {
    await tester.pumpWidget(_host(ShotsLayer(shots: const [
      ShotSpec(
          from: Offset(80, 520),
          to: Offset(80, 80),
          result: ShotResult.hit,
          pierce: true),
    ])));
    expect(find.byType(ShotsLayer), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
  });
}
