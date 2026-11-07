// 사망 원인 표시용 엔진 산출(pierceVictim/superVictim) — 2026-11-06 제보(방어 뚫림) 대응.
import 'package:cowboy_party/game/party_logic.dart';
import 'package:flutter_test/flutter_test.dart';

TurnOutcome run({
  required List<Move> moves,
  required List<int> ammo,
  required List<bool> alive,
  required List<CharId> chars,
  String seed = 'TEST',
}) =>
    resolvePartyTurn(
      moves: moves,
      ammoBefore: ammo,
      aliveBefore: alive,
      chars: chars,
      state: PartyState.initial(chars),
      seed: seed,
      turn: 0,
    );

void main() {
  test('스나이퍼 관통으로 방어가 뚫리면 피격자에 pierceVictim', () {
    String? hitSeed;
    for (var i = 0; i < 300; i++) {
      if (seededRoll('S$i|0|0|pierce') < 0.20) {
        hitSeed = 'S$i';
        break;
      }
    }
    final out = run(
      moves: [Move.shoot(1), const Move.defend()],
      ammo: [1, 0],
      alive: [true, true],
      chars: [CharId.sniper, CharId.none],
      seed: hitSeed!,
    );
    expect(out.hit[1], isTrue);
    expect(out.pierceVictim[1], isTrue);
    expect(out.pierceVictim[0], isFalse);
    expect(out.superVictim[1], isFalse);
  });

  test('방어 안 한 상대를 스나이퍼가 맞히면 pierceVictim 아님(그냥 피격)', () {
    final out = run(
      moves: [Move.shoot(1), const Move.reload()],
      ammo: [1, 0],
      alive: [true, true],
      chars: [CharId.sniper, CharId.none],
    );
    expect(out.hit[1], isTrue);
    expect(out.pierceVictim[1], isFalse);
  });

  test('슈퍼빵야 피격자에 superVictim (방어해도)', () {
    final out = run(
      moves: [Move.superShoot(1), const Move.defend()],
      ammo: [5, 0],
      alive: [true, true],
      chars: [CharId.none, CharId.none],
    );
    expect(out.hit[1], isTrue);
    expect(out.superVictim[1], isTrue);
    expect(out.pierceVictim[1], isFalse);
  });

  test('일반 빵야가 방어에 막히면 둘 다 false', () {
    final out = run(
      moves: [Move.shoot(1), const Move.defend()],
      ammo: [1, 0],
      alive: [true, true],
      chars: [CharId.none, CharId.none],
    );
    expect(out.hit[1], isFalse);
    expect(out.pierceVictim[1], isFalse);
    expect(out.superVictim[1], isFalse);
  });
}
