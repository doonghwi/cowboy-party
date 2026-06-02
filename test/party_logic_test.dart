import 'package:cowboy_party/game/party_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Move encode/decode', () {
    test('round-trips reload, defend and shoots at every seat', () {
      expect(Move.decode(const Move.reload().encode()), const Move.reload());
      expect(Move.decode(const Move.defend().encode()), const Move.defend());
      for (var t = 0; t < kMaxSeats; t++) {
        final m = Move.shoot(t);
        expect(Move.decode(m.encode()), m);
        expect(Move.decode(m.encode()).target, t);
      }
    });
  });

  group('resolveTurn', () {
    test('turn 1: nobody has ammo so no shot lands', () {
      final out = resolveTurn(
        [const Move.shoot(1), const Move.shoot(0), const Move.reload()],
        [0, 0, 0],
        [true, true, true],
      );
      expect(out.fired.any((f) => f), isFalse);
      expect(out.hit.any((h) => h), isFalse);
      expect(out.status, GameStatus.ongoing);
    });

    test('an undefended shot eliminates the target and spends a bullet', () {
      final out = resolveTurn(
        [const Move.shoot(1), const Move.reload(), const Move.reload()],
        [1, 0, 0],
        [true, true, true],
      );
      expect(out.fired[0], isTrue);
      expect(out.firedTarget[0], 1);
      expect(out.hit[1], isTrue);
      expect(out.aliveAfter[1], isFalse);
      expect(out.ammoAfter[0], 0); // spent the bullet
      expect(out.status, GameStatus.ongoing);
    });

    test('defend blocks every incoming shot, no matter how many', () {
      // Seats 0,1,2 all fire at seat 3, which defends. 3 survives.
      final out = resolveTurn(
        [
          const Move.shoot(3),
          const Move.shoot(3),
          const Move.shoot(3),
          const Move.defend(),
        ],
        [1, 1, 1, 0],
        [true, true, true, true],
      );
      expect(out.hit[3], isFalse);
      expect(out.aliveAfter[3], isTrue);
      // The shooters still spent their bullets.
      expect(out.ammoAfter[0], 0);
      expect(out.ammoAfter[1], 0);
      expect(out.ammoAfter[2], 0);
    });

    test('multiple cowboys can fall on the same turn', () {
      final out = resolveTurn(
        [const Move.shoot(1), const Move.shoot(0), const Move.reload()],
        [1, 1, 0],
        [true, true, true],
      );
      expect(out.hit[0], isTrue);
      expect(out.hit[1], isTrue);
      expect(out.aliveAfter[0], isFalse);
      expect(out.aliveAfter[1], isFalse);
      expect(out.status, GameStatus.won);
      expect(out.winner, 2);
    });

    test('last cowboy standing wins', () {
      final out = resolveTurn(
        [const Move.shoot(1), const Move.reload()],
        [1, 0],
        [true, true],
      );
      expect(out.status, GameStatus.won);
      expect(out.winner, 0);
    });

    test('everyone left dying together is a draw', () {
      final out = resolveTurn(
        [const Move.shoot(1), const Move.shoot(0)],
        [1, 1],
        [true, true],
      );
      expect(out.status, GameStatus.draw);
      expect(out.winner, isNull);
    });

    test('cannot shoot a dead seat; that bullet is kept', () {
      final out = resolveTurn(
        [const Move.shoot(1), Move.empty, const Move.reload()],
        [1, 0, 0],
        [true, false, true],
      );
      expect(out.fired[0], isFalse);
      expect(out.ammoAfter[0], 1); // bullet not spent on a dead target
      expect(out.status, GameStatus.ongoing);
    });

    test('reload this turn arms next turn, not this one; caps at kMaxAmmo', () {
      final out = resolveTurn(
        [const Move.reload(), const Move.reload()],
        [kMaxAmmo, 3],
        [true, true],
      );
      expect(out.ammoAfter[0], kMaxAmmo); // capped
      expect(out.ammoAfter[1], 4);
    });

    test('two shooters at one undefended target: still eliminated once', () {
      final out = resolveTurn(
        [const Move.shoot(2), const Move.shoot(2), const Move.reload()],
        [1, 1, 0],
        [true, true, true],
      );
      expect(out.hit[2], isTrue);
      expect(out.aliveAfter[2], isFalse);
    });
  });
}
