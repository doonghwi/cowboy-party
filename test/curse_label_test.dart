import 'package:cowboy_party/game/party_logic.dart';
import 'package:cowboy_party/widgets/seat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// (D) regression: the curse badge must read "저주 N" (its own labelled row),
// not the old bare "N". Asserts the exact string regardless of glyph font,
// so it pins down what the live build renders.
Widget _host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('cursed seat shows "저주 N" label', (tester) async {
    await tester.pumpWidget(_host(const SeatCard(
      name: '한스',
      ammo: 2,
      alive: true,
      scale: 0,
      char: CharId.commoner,
      curseTurnsLeft: 7,
    )));
    expect(find.text('저주 7'), findsOneWidget);
    expect(find.text('💀'), findsOneWidget);
  });

  testWidgets('no curse → no 저주 label', (tester) async {
    await tester.pumpWidget(_host(const SeatCard(
      name: '한스',
      ammo: 2,
      alive: true,
      scale: 0,
      char: CharId.commoner,
    )));
    expect(find.textContaining('저주'), findsNothing);
  });
}
