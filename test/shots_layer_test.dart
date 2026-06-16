import 'package:cowboy_party/widgets/effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ShotsLayer + the reload/defend effect widgets must render and animate the
// full duration without throwing, for every shot outcome (presentation only).
Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 400, height: 600, child: Stack(children: [child])),
      ),
    );

void main() {
  testWidgets('ShotsLayer renders hit/blocked/missed + super without throwing',
      (tester) async {
    await tester.pumpWidget(_host(ShotsLayer(shots: const [
      ShotSpec(
          from: Offset(60, 540),
          to: Offset(60, 60),
          result: ShotResult.hit),
      ShotSpec(
          from: Offset(60, 540),
          to: Offset(340, 60),
          result: ShotResult.blocked),
      ShotSpec(
          from: Offset(340, 540),
          to: Offset(200, 60),
          result: ShotResult.missed),
      ShotSpec(
          from: Offset(200, 540),
          to: Offset(60, 200),
          isSuper: true,
          result: ShotResult.hit),
    ])));
    expect(find.byType(ShotsLayer), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  });

  testWidgets('ShotsLayer with no shots is harmless', (tester) async {
    await tester.pumpWidget(_host(const ShotsLayer(shots: [])));
    expect(find.byType(ShotsLayer), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('ShieldPulse + ReloadBurst render without throwing',
      (tester) async {
    await tester.pumpWidget(_host(const Stack(children: [
      ShieldPulse(center: Offset(200, 300), radius: 60),
      ReloadBurst(center: Offset(120, 300), count: 3),
      ReloadBurst(center: Offset(280, 300), count: 6),
    ])));
    expect(find.byType(ShieldPulse), findsOneWidget);
    expect(find.byType(ReloadBurst), findsNWidgets(2));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  });
}
