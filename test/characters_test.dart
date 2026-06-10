import 'package:cowboy_party/game/party_logic.dart';
import 'package:flutter_test/flutter_test.dart';

TurnOutcome run({
  required List<Move> moves,
  required List<int> ammo,
  required List<bool> alive,
  required List<CharId> chars,
  PartyState? state,
  String seed = 'TEST',
  int turn = 0,
}) =>
    resolvePartyTurn(
      moves: moves,
      ammoBefore: ammo,
      aliveBefore: alive,
      chars: chars,
      state: state ?? PartyState.initial(chars),
      seed: seed,
      turn: turn,
    );

void main() {
  test('인코딩 라운드트립: 덫·연막 비트 포함', () {
    final samples = [
      const Move.reload(),
      const Move.defend(),
      Move.shoot(3),
      Move.superShoot(5),
      const Move.trap(),
      const Move.reload(smoke: true),
      const Move.defend(smoke: true),
      Move.shoot(0, smoke: true),
    ];
    for (final m in samples) {
      expect(Move.decode(m.encode()), m, reason: 'code=${m.encode()}');
    }
    // 구버전 코드는 동일하게 해석된다.
    expect(Move.decode(0), const Move.reload());
    expect(Move.decode(1), const Move.defend());
    expect(Move.decode(4), Move.shoot(2));
    expect(Move.decode(9), Move.superShoot(1));
  });

  test('시드 롤은 결정적이고 분포가 극단적이지 않다', () {
    expect(seededRoll('a|1|2|x'), seededRoll('a|1|2|x'));
    var under = 0;
    for (var i = 0; i < 1000; i++) {
      if (seededRoll('k$i') < 0.5) under++;
    }
    expect(under, inInclusiveRange(380, 620));
  });

  test('준비자: 시작 총알 1', () {
    expect(startAmmoFor(CharId.prepper), 1);
    expect(startAmmoFor(CharId.sniper), 0);
  });

  test('스나이퍼: 10% 관통이 시드에 따라 발동하면 방어를 뚫는다', () {
    // 발동하는 시드를 찾는다 (결정적이므로 테스트도 안정적).
    String? hitSeed;
    String? missSeed;
    for (var i = 0; i < 200; i++) {
      final r = seededRoll('S$i|0|0|pierce');
      if (r < 0.10) hitSeed ??= 'S$i';
      if (r >= 0.10) missSeed ??= 'S$i';
      if (hitSeed != null && missSeed != null) break;
    }
    expect(hitSeed, isNotNull);
    expect(missSeed, isNotNull);

    TurnOutcome shootDefender(String seed) => run(
          moves: [Move.shoot(1), const Move.defend()],
          ammo: [1, 0],
          alive: [true, true],
          chars: [CharId.sniper, CharId.none],
          seed: seed,
        );

    final pierce = shootDefender(hitSeed!);
    expect(pierce.hit[1], isTrue, reason: '관통이면 방어 무시');
    expect(pierce.pierced[0], isTrue);

    final blocked = shootDefender(missSeed!);
    expect(blocked.hit[1], isFalse, reason: '관통 실패면 방어가 막음');
  });

  test('스피드로더: 50% 더블 장전 발동 시 +2', () {
    String? dblSeed;
    for (var i = 0; i < 100; i++) {
      if (seededRoll('L$i|0|0|load') < 0.50) {
        dblSeed = 'L$i';
        break;
      }
    }
    final out = run(
      moves: [const Move.reload(), const Move.reload()],
      ammo: [0, 0],
      alive: [true, true],
      chars: [CharId.speedloader, CharId.none],
      seed: dblSeed!,
    );
    expect(out.ammoAfter[0], 2);
    expect(out.doubleLoad[0], isTrue);
    expect(out.ammoAfter[1], 1);
  });

  test('결투가: 둘만 남으면 즉시 승리', () {
    // 3인 → 한 명이 사살되어 2인이 되는 턴, 결투가가 즉시 승리.
    final out = run(
      moves: [Move.shoot(2), const Move.reload(), const Move.reload()],
      ammo: [1, 0, 0],
      alive: [true, true, true],
      chars: [CharId.none, CharId.duelist, CharId.none],
    );
    expect(out.hit[2], isTrue);
    expect(out.status, GameStatus.won);
    expect(out.winner, 1);
    expect(out.specialWin, 'duelist');
  });

  test('결투가 둘이면 효과 무효', () {
    final out = run(
      moves: [Move.shoot(2), const Move.reload(), const Move.reload()],
      ammo: [1, 0, 0],
      alive: [true, true, true],
      chars: [CharId.duelist, CharId.duelist, CharId.none],
    );
    expect(out.status, GameStatus.ongoing);
  });

  test('의사: 게임당 1회 치명상 무효, 두 번째는 사망', () {
    final chars = [CharId.none, CharId.doctor];
    final first = run(
      moves: [Move.shoot(1), const Move.reload()],
      ammo: [2, 0],
      alive: [true, true],
      chars: chars,
    );
    expect(first.hit[1], isFalse);
    expect(first.healed[1], isTrue);
    expect(first.stateAfter!.doctorUsed[1], isTrue);

    final second = run(
      moves: [Move.shoot(1), const Move.reload()],
      ammo: [1, 0],
      alive: [true, true],
      chars: chars,
      state: first.stateAfter,
      turn: 1,
    );
    expect(second.hit[1], isTrue);
    expect(second.status, GameStatus.won);
  });

  test('사냥꾼: 덫이 일반탄을 반사해 쏜 자가 죽는다 (1회용)', () {
    final out = run(
      moves: [Move.shoot(1), const Move.trap()],
      ammo: [1, 0],
      alive: [true, true],
      chars: [CharId.none, CharId.hunter],
    );
    expect(out.hit[1], isFalse, reason: '사냥꾼은 무사');
    expect(out.hit[0], isTrue, reason: '반사로 사수가 죽음');
    expect(out.reflectKill[0], isTrue);
    expect(out.stateAfter!.trapUsed[1], isTrue);
    expect(out.status, GameStatus.won);
    expect(out.winner, 1);
  });

  test('사냥꾼: 덫은 슈퍼빵야를 막지 못한다', () {
    final out = run(
      moves: [Move.superShoot(1), const Move.trap()],
      ammo: [5, 0],
      alive: [true, true],
      chars: [CharId.none, CharId.hunter],
    );
    expect(out.hit[1], isTrue);
    expect(out.hit[0], isFalse);
  });

  test('덫은 게임당 1회 — 두 번째 시도는 무효(장전도 안 됨)', () {
    final s0 = PartyState.initial([CharId.none, CharId.hunter]);
    final used = PartyState(
      doctorUsed: s0.doctorUsed,
      trapUsed: [false, true],
      smokeLeft: s0.smokeLeft,
      reloads: s0.reloads,
    );
    final out = run(
      moves: [Move.shoot(1), const Move.trap()],
      ammo: [1, 0],
      alive: [true, true],
      chars: [CharId.none, CharId.hunter],
      state: used,
    );
    expect(out.hit[1], isTrue, reason: '덫이 안 깔리므로 그냥 맞는다');
  });

  test('스모커: 연막 회피 발동 시 생존, 차감은 정확히 1회', () {
    String? dodgeSeed;
    for (var i = 0; i < 200; i++) {
      if (seededRoll('M$i|0|1|evade0') < 0.50) {
        dodgeSeed = 'M$i';
        break;
      }
    }
    final out = run(
      moves: [Move.shoot(1), const Move.reload(smoke: true)],
      ammo: [1, 0],
      alive: [true, true],
      chars: [CharId.none, CharId.smoker],
      seed: dodgeSeed!,
    );
    expect(out.hit[1], isFalse);
    expect(out.evaded[1], isTrue);
    expect(out.stateAfter!.smokeLeft[1], 1);
    expect(out.ammoAfter[1], 1, reason: '연막은 행동(장전)과 병행');
  });

  test('스모커가 아니면 연막 비트는 무시된다', () {
    final out = run(
      moves: [Move.shoot(1), const Move.reload(smoke: true)],
      ammo: [1, 0],
      alive: [true, true],
      chars: [CharId.none, CharId.none],
    );
    expect(out.hit[1], isTrue);
  });

  test('평화주의자: 빵야가 불발된다', () {
    final out = run(
      moves: [Move.shoot(1), const Move.reload()],
      ammo: [3, 0],
      alive: [true, true],
      chars: [CharId.pacifist, CharId.none],
    );
    expect(out.fired[0], isFalse);
    expect(out.hit[1], isFalse);
  });

  test('평화주의자: 장전 6회 달성 + 생존 시 즉시 승리', () {
    var state = PartyState.initial([CharId.pacifist, CharId.none]);
    var ammo = [0, 0];
    var alive = [true, true];
    TurnOutcome? out;
    for (var t = 0; t < 6; t++) {
      out = run(
        moves: [const Move.reload(), const Move.defend()],
        ammo: ammo,
        alive: alive,
        chars: [CharId.pacifist, CharId.none],
        state: state,
        turn: t,
      );
      state = out.stateAfter!;
      ammo = out.ammoAfter;
      alive = out.aliveAfter;
    }
    expect(out!.status, GameStatus.won);
    expect(out.winner, 0);
    expect(out.specialWin, 'pacifist');
  });

  test('평화주의자: 6번째 장전 턴에 사망하면 승리 무효', () {
    final state = PartyState(
      doctorUsed: [false, false],
      trapUsed: [false, false],
      smokeLeft: [0, 0],
      reloads: [5, 0],
    );
    final out = run(
      moves: [const Move.reload(), Move.shoot(0)],
      ammo: [5, 1],
      alive: [true, true],
      chars: [CharId.pacifist, CharId.none],
      state: state,
    );
    expect(out.hit[0], isTrue);
    expect(out.status, GameStatus.won);
    expect(out.winner, 1, reason: '쏜 쪽이 최후의 1인');
  });

  test('캐릭터 없음 = 기존 규칙과 동일 (legacy resolveTurn 경유)', () {
    final out = resolveTurn(
      [Move.shoot(1), const Move.defend()],
      [1, 0],
      [true, true],
    );
    expect(out.hit[1], isFalse);
    expect(out.status, GameStatus.ongoing);
  });
}
