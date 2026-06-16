import 'package:cowboy_party/game/party_logic.dart';
import 'package:flutter_test/flutter_test.dart';

// (F) rouletteSelf is exposed on TurnOutcome for display only. Verify it is
// populated and consistent with the existing hit/judgement (no logic change):
//  - it has one entry per seat,
//  - a self-bust seat is always the caster and is hit (took its own bullet),
//  - across seeds both outcomes occur (50:50), proving it tracks the real roll.
void main() {
  test('rouletteSelf is exposed and consistent with the self-hit', () {
    const chars = [CharId.roulette, CharId.none];
    var sawSelf = false;
    var sawOpponent = false;

    for (var i = 0; i < 60; i++) {
      final out = resolvePartyTurn(
        moves: [Move.roulette(1), const Move.idle()],
        ammoBefore: const [1, 1],
        aliveBefore: const [true, true],
        chars: chars,
        state: PartyState.initial(chars),
        seed: 'ROUL$i',
        turn: 0,
      );
      expect(out.rouletteSelf.length, 2);
      expect(out.rouletteFired[0], isTrue);
      if (out.rouletteSelf[0]) {
        sawSelf = true;
        expect(out.hit[0], isTrue, reason: '자기-꽝이면 시전자가 피격되어야 함');
      } else {
        sawOpponent = true;
      }
      // The opponent never self-busts.
      expect(out.rouletteSelf[1], isFalse);
    }

    expect(sawSelf, isTrue, reason: '여러 시드 중 자기-꽝이 한 번은 나와야 함');
    expect(sawOpponent, isTrue, reason: '여러 시드 중 상대 명중도 나와야 함');
  });
}
