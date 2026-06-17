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

  test('스나이퍼: 20% 관통이 시드에 따라 발동하면 방어를 뚫는다 (B1)', () {
    // 발동하는 시드를 찾는다 (결정적이므로 테스트도 안정적).
    String? hitSeed;
    String? missSeed;
    for (var i = 0; i < 200; i++) {
      final r = seededRoll('S$i|0|0|pierce');
      if (r < 0.20) hitSeed ??= 'S$i';
      if (r >= 0.20) missSeed ??= 'S$i';
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

  test('결투가 너프(B2): 둘만 남아도 평소엔 즉시 승리하지 않는다', () {
    // 3인 → 한 명이 사살되어 2인이 되는 턴. 더 이상 결투가 자동승 없음.
    final out = run(
      moves: [Move.shoot(2), const Move.reload(), const Move.reload()],
      ammo: [1, 0, 0],
      alive: [true, true, true],
      chars: [CharId.none, CharId.duelist, CharId.none],
    );
    expect(out.hit[2], isTrue);
    expect(out.status, GameStatus.ongoing, reason: '결투가는 평소 효과 없음');
    expect(out.specialWin, isNull);
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
    expect(first.ammoAfter[1], 0,
        reason: 'B7: 버텨낸 직후 총알 0 (장전했어도)');

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
      paparazziUsed: s0.paparazziUsed,
      resetterUsed: s0.resetterUsed,
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
      paparazziUsed: [false, false],
      resetterUsed: [false, false],
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

  // ---- 신규 캐릭터 ----

  test('인코딩 라운드트립: 신규 액션', () {
    final samples = [
      const Move.idle(),
      Move.roulette(3),
      Move.dualShoot(1, 4),
      Move.voodoo(2),
      const Move.reset(),
    ];
    for (final m in samples) {
      expect(Move.decode(m.encode()), m, reason: 'code=${m.encode()}');
    }
    // 신규 코드가 레거시 범위와 겹치지 않는다.
    expect(const Move.idle().encode(), 40);
    expect(Move.decode(40), const Move.idle());
    expect(const Move.reset().encode(), 47);
    expect(Move.decode(47), const Move.reset());
  });

  String seedFor(String salt, int seat, bool wantUnderHalf) {
    for (var i = 0; i < 500; i++) {
      final r = seededRoll('S$i|0|$seat|$salt');
      if ((r < 0.5) == wantUnderHalf) return 'S$i';
    }
    throw StateError('seed 못 찾음');
  }

  test('운명의 방아쇠: roll<0.5면 상대에게 총알 — 일반탄처럼 날아간다', () {
    final hitTargetSeed = seedFor('roulette', 0, true); // 상대 지목(총알이 상대로)
    final out = run(
      moves: [Move.roulette(1), const Move.reload()],
      ammo: [0, 0],
      alive: [true, true],
      chars: [CharId.roulette, CharId.none],
      seed: hitTargetSeed,
    );
    expect(out.rouletteFired[0], isTrue);
    expect(out.hit[1], isTrue, reason: '상대 사망');
    expect(out.hit[0], isFalse);
    expect(out.ammoAfter[0], 0, reason: '총알 소모 없음');
  });

  test('운명의 방아쇠: 상대를 향했어도 상대가 방어하면 막힌다(아무도 안 죽음)', () {
    final hitTargetSeed = seedFor('roulette', 0, true);
    final out = run(
      moves: [Move.roulette(1), const Move.defend()],
      ammo: [0, 0],
      alive: [true, true],
      chars: [CharId.roulette, CharId.none],
      seed: hitTargetSeed,
    );
    expect(out.hit[1], isFalse, reason: '방어로 막힘');
    expect(out.hit[0], isFalse, reason: '내가 죽지 않음 — 일반탄 판정');
  });

  test('운명의 방아쇠: 상대를 향했는데 상대가 덫이면 반사돼 내가 죽음', () {
    final hitTargetSeed = seedFor('roulette', 0, true);
    final out = run(
      moves: [Move.roulette(1), const Move.trap()],
      ammo: [0, 0],
      alive: [true, true],
      chars: [CharId.roulette, CharId.hunter],
      seed: hitTargetSeed,
    );
    expect(out.hit[1], isFalse, reason: '사냥꾼은 덫으로 무사');
    expect(out.hit[0], isTrue, reason: '덫 반사로 내가 죽음');
  });

  test('운명의 방아쇠: roll>=0.5면 자해 — 내가 죽음', () {
    final selfSeed = seedFor('roulette', 0, false);
    final out = run(
      moves: [Move.roulette(1), const Move.reload()],
      ammo: [0, 0],
      alive: [true, true],
      chars: [CharId.roulette, CharId.none],
      seed: selfSeed,
    );
    expect(out.hit[0], isTrue);
    expect(out.hit[1], isFalse);
  });

  test('운명의 방아쇠 + 연막(C1): 상대가 연막으로 회피하면 아무도 안 죽는다', () {
    // roulette roll<0.5(상대 지목) & evade0 roll<0.5(상대 연막 회피) 둘 다 만족.
    String? seed;
    for (var i = 0; i < 2000; i++) {
      final s = 'R$i';
      if (seededRoll('$s|0|0|roulette') < 0.5 &&
          seededRoll('$s|0|1|evade0') < 0.5) {
        seed = s;
        break;
      }
    }
    expect(seed, isNotNull, reason: '조건 만족 시드 존재');
    final out = run(
      moves: [Move.roulette(1), const Move.reload(smoke: true)],
      ammo: [0, 0],
      alive: [true, true],
      chars: [CharId.roulette, CharId.smoker],
      seed: seed!,
    );
    expect(out.rouletteFired[0], isTrue);
    expect(out.hit[1], isFalse, reason: '연막으로 회피');
    expect(out.hit[0], isFalse);
    expect(out.evaded[1], isTrue);
  });

  test('리셋터 무효(B6): 그 턴 상대의 빵야가 총알만 소모되고 안 맞는다', () {
    // p0=리셋터(무효), p1=일반(빵야 p0), p2=일반(장전).
    final out = run(
      moves: [const Move.reset(), Move.shoot(0), const Move.reload()],
      ammo: [0, 1, 0],
      alive: [true, true, true],
      chars: [CharId.resetter, CharId.none, CharId.none],
    );
    expect(out.resetActive[0], isTrue);
    expect(out.hit[0], isFalse, reason: '빵야 무효 — 리셋터 생존');
    expect(out.ammoAfter[1], 0, reason: '총알은 소모됨');
    expect(out.ammoAfter[2], 0, reason: '장전도 무효 — 총알 안 늘어남');
    expect(out.stateAfter!.resetterUsed[0], isTrue);
    expect(out.status, GameStatus.ongoing);
  });

  test('리셋터 무효(B6): 게임당 1회 — 두 번째 무효는 발동 안 함', () {
    final used = PartyState(
      doctorUsed: [false, false],
      trapUsed: [false, false],
      smokeLeft: [0, 0],
      reloads: [0, 0],
      paparazziUsed: [false, false],
      resetterUsed: [true, false],
    );
    final out = run(
      moves: [const Move.reset(), Move.shoot(0)],
      ammo: [0, 1],
      alive: [true, true],
      chars: [CharId.resetter, CharId.none],
      state: used,
    );
    expect(out.resetActive[0], isFalse, reason: '이미 사용함');
    expect(out.hit[0], isTrue, reason: '무효 발동 안 돼 빵야 적중');
  });

  test('쌍권총 더블 빵야: 총알 2발로 두 명 동시 처치', () {
    final out = run(
      moves: [Move.dualShoot(1, 2), const Move.reload(), const Move.reload()],
      ammo: [2, 0, 0],
      alive: [true, true, true],
      chars: [CharId.dualgun, CharId.none, CharId.none],
    );
    expect(out.dualFired[0], isTrue);
    expect(out.hit[1], isTrue);
    expect(out.hit[2], isTrue);
    expect(out.ammoAfter[0], 0, reason: '2발 소모');
    expect(out.status, GameStatus.won);
    expect(out.winner, 0);
  });

  test('쌍권총: 한 명이 방어하면 그 한 명만 산다', () {
    final out = run(
      moves: [Move.dualShoot(1, 2), const Move.defend(), const Move.reload()],
      ammo: [2, 0, 0],
      alive: [true, true, true],
      chars: [CharId.dualgun, CharId.none, CharId.none],
    );
    expect(out.hit[1], isFalse, reason: '방어 성공');
    expect(out.hit[2], isTrue);
  });

  test('의사 수정: 치명타를 버티면 그 즉시 총알 0', () {
    final out = run(
      moves: [Move.shoot(1), const Move.reload()],
      ammo: [1, 3],
      alive: [true, true],
      chars: [CharId.none, CharId.doctor],
    );
    expect(out.hit[1], isFalse);
    expect(out.healed[1], isTrue);
    expect(out.ammoAfter[1], 0, reason: '버틴 즉시 총알 0 (장전했어도 0)');
  });

  test('idle(가만히): 아무 일도 없음', () {
    final out = run(
      moves: [const Move.idle(), const Move.reload()],
      ammo: [2, 0],
      alive: [true, true],
      chars: [CharId.none, CharId.none],
    );
    expect(out.ammoAfter[0], 2, reason: '장전 안 함');
    expect(out.hit[0], isFalse);
    expect(out.status, GameStatus.ongoing);
  });

  test('부두 저주: 10턴 뒤 대상 사망, 부두술사 죽으면 해제', () {
    final chars = [CharId.voodoo, CharId.none, CharId.none];
    // turn 0: 부두(0)가 1을 저주.
    var state = PartyState.initial(chars);
    var ammo = [0, 0, 0];
    var alive = [true, true, true];
    var out = run(
      moves: [Move.voodoo(1), const Move.reload(), const Move.reload()],
      ammo: ammo, alive: alive, chars: chars, state: state, turn: 0,
    );
    expect(out.voodooCast[0], isTrue);
    expect(out.stateAfter!.curseFuse[1], kCurseFuse);
    state = out.stateAfter!;
    ammo = out.ammoAfter;
    alive = out.aliveAfter;

    // turn 1..10: 모두 장전. turn 10에서 대상 사망해야 함.
    var diedTurn = -1;
    for (var t = 1; t <= kCurseFuse; t++) {
      out = run(
        moves: [const Move.reload(), const Move.reload(), const Move.reload()],
        ammo: ammo, alive: alive, chars: chars, state: state, turn: t,
      );
      if (out.curseKill[1]) diedTurn = t;
      state = out.stateAfter!;
      ammo = out.ammoAfter;
      alive = out.aliveAfter;
    }
    expect(diedTurn, kCurseFuse, reason: '건 턴(0)으로부터 10턴 뒤 사망');
    expect(alive[1], isFalse);
  });

  test('부두 저주: 부두술사가 죽으면 저주가 풀린다', () {
    final chars = [CharId.voodoo, CharId.none, CharId.none];
    var state = PartyState.initial(chars);
    // 0이 1을 저주.
    var out = run(
      moves: [Move.voodoo(1), const Move.reload(), const Move.reload()],
      ammo: [0, 0, 0], alive: [true, true, true], chars: chars,
      state: state, turn: 0,
    );
    state = out.stateAfter!;
    expect(state.curseFuse[1], kCurseFuse);
    // 2가 부두술사(0)를 사살 → 저주 해제.
    out = run(
      moves: [const Move.reload(), const Move.reload(), Move.shoot(0)],
      ammo: [0, 0, 1], alive: out.aliveAfter, chars: chars,
      state: state, turn: 1,
    );
    expect(out.hit[0], isTrue, reason: '부두술사 사망');
    expect(out.stateAfter!.curseFuse[1], 0, reason: '저주 해제');
  });

  test('부두 저주: 부두술사 둘이 서로 다른 대상을 동시에 저주(좌석별 독립)', () {
    final chars = [CharId.voodoo, CharId.voodoo, CharId.none, CharId.none];
    final state = PartyState.initial(chars);
    // 0이 2를, 1이 3을 동시에 저주.
    final out = run(
      moves: [Move.voodoo(2), Move.voodoo(3), const Move.reload(),
        const Move.reload()],
      ammo: [0, 0, 0, 0],
      alive: [true, true, true, true],
      chars: chars,
      state: state,
      turn: 0,
    );
    expect(out.voodooCast[0], isTrue);
    expect(out.voodooCast[1], isTrue);
    // 두 대상 모두 각각 저주가 걸린다(예전엔 하나만 잡혔음).
    expect(out.stateAfter!.curseFuse[2], kCurseFuse);
    expect(out.stateAfter!.curseFuse[3], kCurseFuse);
    expect(out.stateAfter!.curseCaster[2], 0);
    expect(out.stateAfter!.curseCaster[3], 1);
    // 저주 안 받은 좌석은 0.
    expect(out.stateAfter!.curseFuse[0], 0);
    expect(out.stateAfter!.curseFuse[1], 0);
  });

  test('mystery: 시드로 결정적으로 한 직업이 되고 풀 안에 든다', () {
    final a = resolveMystery('GAME1', 0);
    final b = resolveMystery('GAME1', 0);
    expect(a, b, reason: '결정적');
    expect(kMysteryPool.contains(a), isTrue);
    expect(a, isNot(CharId.mystery));
    expect(a, isNot(CharId.none));
  });

  test('???(mystery) 공개 분류: 시작공개 ∪ 턴트리거 == 전체 변신 직업, 서로소', () {
    final pool = kMysteryPool.toSet();
    final union = {
      ...kMysteryStartRevealChars,
      ...kMysteryTurnTriggerChars,
    };
    // 모든 ??? 변신 직업은 시작공개 또는 턴트리거 중 정확히 하나로 공개돼야 한다.
    expect(union, equals(pool),
        reason: '공개 경로가 없는 직업이 있으면 영영 ???로 남는다(원래 버그)');
    expect(
        kMysteryStartRevealChars.intersection(kMysteryTurnTriggerChars),
        isEmpty,
        reason: '두 집합은 서로소(한 직업이 두 경로에 걸치면 안 됨)');
    // mystery 자신·none은 분류 대상이 아니다.
    expect(union.contains(CharId.mystery), isFalse);
    expect(union.contains(CharId.none), isFalse);
  });

  test('시작 공개 직업은 턴 중 능동 신호가 없는 직업뿐이다', () {
    for (final c in kMysteryStartRevealChars) {
      expect(mysteryRevealsAtStart(c), isTrue, reason: '$c 는 시작 공개');
    }
    // 능력 발동 신호가 있는 직업은 시작 공개가 아니다(턴 트리거).
    for (final c in kMysteryTurnTriggerChars) {
      expect(mysteryRevealsAtStart(c), isFalse, reason: '$c 는 턴 트리거');
    }
  });

  test('평화주의자·결투가는 시작 공개가 아니라 능력 발동(승리) 시 공개된다', () {
    // 사용자 제보 #1: 둘은 능력이 게임 종반에 비로소 발동하므로 그 전엔 숨겨야 한다.
    expect(kMysteryStartRevealChars.contains(CharId.pacifist), isFalse,
        reason: '평화주의자는 6장전 승리 순간에만 공개');
    expect(kMysteryStartRevealChars.contains(CharId.duelist), isFalse,
        reason: '결투가는 결투 자동승 순간에만 공개');
    expect(kMysteryTurnTriggerChars.contains(CharId.pacifist), isTrue);
    expect(kMysteryTurnTriggerChars.contains(CharId.duelist), isTrue);
    expect(mysteryRevealsAtStart(CharId.pacifist), isFalse);
    expect(mysteryRevealsAtStart(CharId.duelist), isFalse);
    // 신호가 전혀 없는 직업만 시작 공개로 남는다.
    expect(kMysteryStartRevealChars,
        equals({CharId.commoner, CharId.prepper, CharId.shadow}));
  });
}
