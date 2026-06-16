import 'package:cowboy_party/widgets/circular_table.dart';
import 'package:cowboy_party/widgets/effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Regression for the smoke-effect bug: the puff must appear whenever a seat
// RAISED smoke this turn (smoked=true), even if it was never shot (evaded=false).
List<TableSeat> _seats({required bool smoked, required bool evaded}) => [
      TableSeat(name: '나', ammo: 1, alive: true, isMe: true,
          smoked: smoked, evadedFx: evaded),
      const TableSeat(name: '봇', ammo: 1, alive: true),
    ];

Widget _table(List<TableSeat> seats) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 600,
          child: CircularTable(
            seats: seats, mySeat: 0, reveal: true, center: const SizedBox(),
          ),
        ),
      ),
    );

void main() {
  testWidgets('smoke raised but not shot → puff still shows', (tester) async {
    await tester.pumpWidget(_table(_seats(smoked: true, evaded: false)));
    expect(find.byType(SmokePuff), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('no smoke raised → no puff', (tester) async {
    await tester.pumpWidget(_table(_seats(smoked: false, evaded: false)));
    expect(find.byType(SmokePuff), findsNothing);
    await tester.pumpAndSettle();
  });
}
