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

    // 온라인 결정성의 토대: 모든 좌석이 같은 (시드, move 히스토리)를 재생하므로
    // 모든 직업이 낼 수 있는 모든 행동이 Firebase 정수↔Move로 무손실 왕복해야 한다.
    // (기존 테스트는 reload/defend/shoot만 봤음 — 나머지 전부 못박는다.)
    test('모든 행동 종류가 모든 좌석/연막 조합에서 무손실 왕복', () {
      final base = <Move>[
        const Move.reload(),
        const Move.defend(),
        const Move.trap(),
        const Move.idle(),
        const Move.reset(),
      ];
      for (final m in base) {
        expect(Move.decode(m.encode()), m, reason: '$m 왕복 실패');
      }
      // 연막 변형(스모커) — 기본 행동에만 붙는다.
      for (final m in [const Move.reload(), const Move.defend(), const Move.shoot(1)]) {
        final s = m.withSmoke(true);
        expect(Move.decode(s.encode()), s, reason: '연막 $s 왕복 실패');
        expect(Move.decode(s.encode()).smoke, isTrue);
      }
      // 단일 타겟 행동: 모든 좌석.
      for (var t = 0; t < kMaxSeats; t++) {
        for (final m in [
          Move.shoot(t),
          Move.superShoot(t),
          Move.roulette(t),
          Move.voodoo(t),
        ]) {
          expect(Move.decode(m.encode()), m, reason: '$m 왕복 실패');
        }
      }
    });

    test('더블 빵야: 두 대상 모든 쌍 + 외길(두번째 -1)이 무손실 왕복', () {
      for (var a = 0; a < kMaxSeats; a++) {
        for (var b = 0; b < kMaxSeats; b++) {
          final m = Move.dualShoot(a, b);
          expect(Move.decode(m.encode()), m, reason: 'dual($a,$b) 왕복 실패');
        }
        // 두 번째 대상이 없는 경우(2인전 등 외길) — 슬롯 7로 안전하게 왕복.
        final solo = Move.dualShoot(a, -1);
        final back = Move.decode(solo.encode());
        expect(back.kind, ActKind.dualShoot, reason: 'dual($a,-1) 종류 보존');
        expect(back.target, a, reason: 'dual($a,-1) 첫 대상 보존');
        expect(back.target2, -1, reason: 'dual($a,-1) 두번째 대상 -1 보존(슬롯7→ -1)');
      }
    });

    test('인코딩 공간이 행동 간 충돌하지 않는다(모든 코드 유일)', () {
      final codes = <int, Move>{};
      final all = <Move>[
        const Move.reload(),
        const Move.defend(),
        const Move.trap(),
        const Move.idle(),
        const Move.reset(),
        const Move.reload(smoke: true),
        const Move.defend(smoke: true),
        for (var t = 0; t < kMaxSeats; t++) ...[
          Move.shoot(t),
          Move.shoot(t, smoke: true),
          Move.superShoot(t),
          Move.roulette(t),
          Move.voodoo(t),
          for (var u = 0; u < kMaxSeats; u++) Move.dualShoot(t, u),
        ],
      ];
      for (final m in all) {
        final c = m.encode();
        expect(codes.containsKey(c), isFalse,
            reason: '코드 $c 충돌: ${codes[c]} vs $m');
        codes[c] = m;
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
