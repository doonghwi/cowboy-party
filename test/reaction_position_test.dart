import 'package:cowboy_party/widgets/circular_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a top-seat emoji reaction stays on-screen (2 players)',
      (tester) async {
    const seats = [
      TableSeat(name: '나', ammo: 0, alive: true, isMe: true),
      TableSeat(name: '상대', ammo: 0, alive: true),
    ];
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 600,
            child: CircularTable(
              seats: seats,
              mySeat: 0,
              center: SizedBox.shrink(),
              reactions: {1: 'cowboy'}, // the opponent (top seat) reacts
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400)); // let it pop in

    final box = tester.getRect(find.byType(SizedBox).first);
    final rect = tester.getRect(find.byKey(const ValueKey('rx-1-cowboy')));
    // The bubble must sit fully inside the table area — the bug put the top
    // seat's bubble above the top edge (negative), off-screen.
    expect(rect.top, greaterThanOrEqualTo(box.top - 0.5));
    expect(rect.bottom, lessThanOrEqualTo(box.bottom + 0.5));

    // The Twemoji PNG isn't bundled in the test environment; ignore that load
    // error so it doesn't fail the position assertion above.
    tester.takeException();
  });
}
