// 룰엔진 엣지케이스 속성 테스트 (BUGS.md P2 후속).
//
// 퍼즈 하니스(fuzz_party_logic_test)가 대량 무작위로 못 좁히는 **특정 상호작용**을
// 결정적으로 못 박는다: 결투가 동점 처리, 쌍권총 더블 타깃(동일/사망/자기), ???
// 전 직업 공개 도달, 동시 다중 저주, 리셋(무효) 상호작용.
import 'package:cowboy_party/game/party_logic.dart';
import 'package:flutter_test/flutter_test.dart';

TurnOutcome run({
  required List<Move> moves,
  required List<int> ammo,
  required List<bool> alive,
  required List<CharId> chars,
  PartyState? state,
  String seed = 'EDGE',
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
  // ---- 결투가 동점 처리(B2) ----
  group('결투가 showdown 자동승 판정', () {
    test('참가자 중 결투가 정확히 1명 → 그 좌석 자동승', () {
      final chars = [CharId.duelist, CharId.none, CharId.sniper];
      expect(duelistShowdownWinner(chars, [0, 1, 2]), 0);
      expect(duelistShowdownWinner(chars, [1, 2, 0]), 0);
    });
    test('결투가 0명 → null(반응속도 결투로)', () {
      final chars = [CharId.none, CharId.sniper];
      expect(duelistShowdownWinner(chars, [0, 1]), isNull);
    });
    test('결투가 2명 이상 → null(자동승 무효, 결투끼리는 반응속도)', () {
      final chars = [CharId.duelist, CharId.duelist, CharId.none];
      expect(duelistShowdownWinner(chars, [0, 1, 2]), isNull);
    });
    test('결투가가 참가자 목록 밖이면 카운트 안 됨', () {
      final chars = [CharId.duelist, CharId.none];
      expect(duelistShowdownWinner(chars, [1]), isNull); // 0은 참가 안 함
    });
    test('범위 밖 좌석 인덱스는 무시(안전)', () {
      final chars = [CharId.duelist];
      expect(duelistShowdownWinner(chars, [0, 5, -1]), 0);
    });
  });

  // ---- 쌍권총 더블 빵야 타깃 엣지 ----
  group('쌍권총 더블 타깃', () {
    test('두 타깃이 같으면 1발만 소모하고 그 1명만 맞는다', () {
      final out = run(
        moves: [Move.dualShoot(1, 1), const Move.reload(), const Move.reload()],
        ammo: [2, 0, 0],
        alive: [true, true, true],
        chars: [CharId.dualgun, CharId.none, CharId.none],
      );
      expect(out.dualFired[0], isTrue);
      expect(out.hit[1], isTrue);
      expect(out.hit[2], isFalse);
      expect(out.ammoAfter[0], 1, reason: '중복 타깃은 1발만 소모');
      expect(out.dualTarget2[0], -1, reason: '두 번째 타깃 없음');
    });

    test('두 번째 타깃이 자기 자신이면 무시 — 첫 타깃만', () {
      final out = run(
        moves: [Move.dualShoot(1, 0), const Move.reload(), const Move.reload()],
        ammo: [2, 0, 0],
        alive: [true, true, true],
        chars: [CharId.dualgun, CharId.none, CharId.none],
      );
      expect(out.hit[1], isTrue);
      expect(out.hit[0], isFalse, reason: '자기 자신은 타깃 불가');
      expect(out.ammoAfter[0], 1);
    });

    test('두 번째 타깃이 이미 죽은 좌석이면 무시 — 첫 타깃만', () {
      final out = run(
        moves: [Move.dualShoot(1, 2), const Move.reload(), Move.empty],
        ammo: [2, 0, 0],
        alive: [true, true, false], // 2는 이미 사망
        chars: [CharId.dualgun, CharId.none, CharId.none],
      );
      expect(out.hit[1], isTrue);
      expect(out.ammoAfter[0], 1, reason: '죽은 타깃은 발사 안 됨 → 1발');
    });

    test('두 타깃 모두 무효(자기·죽은자)면 발사 자체가 없다', () {
      final out = run(
        moves: [Move.dualShoot(0, 2), Move.empty, Move.empty],
        ammo: [2, 0, 0],
        alive: [true, false, false],
        chars: [CharId.dualgun, CharId.none, CharId.none],
      );
      expect(out.dualFired[0], isFalse);
      expect(out.ammoAfter[0], 2, reason: '유효 타깃 0 → 소모 없음');
    });
  });

  // ---- ??? 전 직업 공개 도달 ----
  test('??? 턴-트리거 전 직업: 능력 발동 시 대응 리빌 플래그가 실제로 켜진다', () {
    // online_service의 리빌 루프가 키로 쓰는 플래그가 각 직업에서 도달 가능함을 보장.
    // (시작-공개 직업은 mysteryRevealsAtStart로 별도 보장됨.)
    bool fires(CharId job, bool Function(TurnOutcome) flag,
        {required List<Move> moves,
        required List<int> ammo,
        required List<bool> alive,
        required List<CharId> chars,
        String seed = 'EDGE',
        PartyState? state}) {
      final out = run(
          moves: moves,
          ammo: ammo,
          alive: alive,
          chars: chars,
          seed: seed,
          state: state);
      return flag(out);
    }

    // sniper: 관통 시드를 찾아 pierced 발동.
    String pierceSeed = 'X';
    for (var i = 0; i < 500; i++) {
      if (seededRoll('P$i|0|0|pierce') < 0.20) {
        pierceSeed = 'P$i';
        break;
      }
    }
    expect(
        fires(CharId.sniper, (o) => o.pierced[0],
            moves: [Move.shoot(1), const Move.defend()],
            ammo: [1, 0],
            alive: [true, true],
            chars: [CharId.sniper, CharId.none],
            seed: pierceSeed),
        isTrue);

    // speedloader: 더블장전 시드.
    String loadSeed = 'X';
    for (var i = 0; i < 500; i++) {
      if (seededRoll('L$i|0|0|load') < 0.50) {
        loadSeed = 'L$i';
        break;
      }
    }
    expect(
        fires(CharId.speedloader, (o) => o.doubleLoad[0],
            moves: [const Move.reload(), const Move.reload()],
            ammo: [0, 0],
            alive: [true, true],
            chars: [CharId.speedloader, CharId.none],
            seed: loadSeed),
        isTrue);

    // doctor: 치명상 버팀 → healed.
    expect(
        fires(CharId.doctor, (o) => o.healed[0],
            moves: [const Move.reload(), Move.shoot(0)],
            ammo: [0, 1],
            alive: [true, true],
            chars: [CharId.doctor, CharId.none]),
        isTrue);

    // hunter: 덫 → trapSet.
    expect(
        fires(CharId.hunter, (o) => o.trapSet[0],
            moves: [const Move.trap(), const Move.reload()],
            ammo: [0, 0],
            alive: [true, true],
            chars: [CharId.hunter, CharId.none]),
        isTrue);

    // smoker: 연막 → smoked.
    expect(
        fires(CharId.smoker, (o) => o.smoked[0],
            moves: [const Move.reload(smoke: true), const Move.reload()],
            ammo: [0, 0],
            alive: [true, true],
            chars: [CharId.smoker, CharId.none]),
        isTrue);

    // roulette: 운명의 방아쇠 → rouletteFired.
    expect(
        fires(CharId.roulette, (o) => o.rouletteFired[0],
            moves: [Move.roulette(1), const Move.reload()],
            ammo: [0, 0],
            alive: [true, true],
            chars: [CharId.roulette, CharId.none]),
        isTrue);

    // dualgun: 더블 빵야 → dualFired.
    expect(
        fires(CharId.dualgun, (o) => o.dualFired[0],
            moves: [Move.dualShoot(1, 2), const Move.reload(), const Move.reload()],
            ammo: [2, 0, 0],
            alive: [true, true, true],
            chars: [CharId.dualgun, CharId.none, CharId.none]),
        isTrue);

    // voodoo: 저주 → voodooCast.
    expect(
        fires(CharId.voodoo, (o) => o.voodooCast[0],
            moves: [Move.voodoo(1), const Move.reload()],
            ammo: [0, 0],
            alive: [true, true],
            chars: [CharId.voodoo, CharId.none]),
        isTrue);

    // resetter: 무효 → resetActive.
    expect(
        fires(CharId.resetter, (o) => o.resetActive[0],
            moves: [const Move.reset(), const Move.reload()],
            ammo: [0, 0],
            alive: [true, true],
            chars: [CharId.resetter, CharId.none]),
        isTrue);

    // paparazzi는 엿보기(peekUsed)가 별도 페이즈라 엔진 플래그가 없다 → 분류로만 보장.
    expect(kMysteryTurnTriggerChars.contains(CharId.paparazzi), isTrue);
  });

  // ---- 동시 다중 저주 ----
  group('동시 다중 저주', () {
    test('부두술사 3명이 서로 다른 대상을 동시에 저주 — 좌석별 독립', () {
      final chars = [
        CharId.voodoo,
        CharId.voodoo,
        CharId.voodoo,
        CharId.none,
        CharId.none,
        CharId.none,
      ];
      final out = run(
        moves: [
          Move.voodoo(3),
          Move.voodoo(4),
          Move.voodoo(5),
          const Move.reload(),
          const Move.reload(),
          const Move.reload(),
        ],
        ammo: List.filled(6, 0),
        alive: List.filled(6, true),
        chars: chars,
      );
      final st = out.stateAfter!;
      expect(st.curseFuse[3], kCurseFuse);
      expect(st.curseFuse[4], kCurseFuse);
      expect(st.curseFuse[5], kCurseFuse);
      expect(st.curseCaster[3], 0);
      expect(st.curseCaster[4], 1);
      expect(st.curseCaster[5], 2);
      expect(st.curseFuse[0], 0);
    });

    test('두 부두술사가 같은 대상을 저주하면 한 저주만 남는다(마지막 시전자)', () {
      final chars = [CharId.voodoo, CharId.voodoo, CharId.none];
      final out = run(
        moves: [Move.voodoo(2), Move.voodoo(2), const Move.reload()],
        ammo: [0, 0, 0],
        alive: [true, true, true],
        chars: chars,
      );
      final st = out.stateAfter!;
      expect(st.curseFuse[2], kCurseFuse);
      // 좌석은 하나의 도화선/시전자만 가진다(중첩되지 않음).
      expect(st.curseCaster[2], anyOf(0, 1));
    });
  });

  // ---- 리셋(무효) 상호작용 ----
  group('리셋 무효 상호작용', () {
    test('무효 턴은 만료 직전 저주를 막고 도화선을 보존한다', () {
      // 저주가 이번 턴 만료(fuse=1)되도록 세팅. 0=부두, 1=대상, 2=리셋터.
      final base = PartyState.initial(
          [CharId.voodoo, CharId.none, CharId.resetter]);
      final primed = PartyState(
        doctorUsed: base.doctorUsed,
        trapUsed: base.trapUsed,
        smokeLeft: base.smokeLeft,
        reloads: base.reloads,
        paparazziUsed: base.paparazziUsed,
        resetterUsed: base.resetterUsed,
        curseFuse: [0, 1, 0], // 좌석1 이번 턴 만료 예정
        curseCaster: [-1, 0, -1],
      );
      final out = run(
        moves: [const Move.reload(), const Move.reload(), const Move.reset()],
        ammo: [0, 0, 0],
        alive: [true, true, true],
        chars: [CharId.voodoo, CharId.none, CharId.resetter],
        state: primed,
      );
      expect(out.resetActive[2], isTrue);
      expect(out.curseKill[1], isFalse, reason: '무효가 만료 사망을 막음');
      expect(out.aliveAfter[1], isTrue);
      expect(out.stateAfter!.curseFuse[1], 1, reason: '도화선 보존(감소 안 함)');
      expect(out.stateAfter!.curseCaster[1], 0);
    });

    test('무효 턴은 덫 반사 사망을 막는다', () {
      // 0=일반(빵야 1), 1=사냥꾼(덫), 2=리셋터(무효).
      final out = run(
        moves: [Move.shoot(1), const Move.trap(), const Move.reset()],
        ammo: [1, 0, 0],
        alive: [true, true, true],
        chars: [CharId.none, CharId.hunter, CharId.resetter],
      );
      expect(out.resetActive[2], isTrue);
      expect(out.hit[0], isFalse, reason: '반사 사망 무효');
      expect(out.hit[1], isFalse);
      expect(out.ammoAfter[0], 0, reason: '총알은 소모(결과만 무효)');
    });

    test('무효 턴은 새 저주 적용을 막는다(총알·특수자원은 소모 규칙과 별개)', () {
      final out = run(
        moves: [Move.voodoo(1), const Move.reload(), const Move.reset()],
        ammo: [0, 0, 0],
        alive: [true, true, true],
        chars: [CharId.voodoo, CharId.none, CharId.resetter],
      );
      expect(out.resetActive[2], isTrue);
      expect(out.voodooCast[0], isFalse, reason: '무효 턴 저주 미적용');
      expect(out.stateAfter!.curseFuse[1], 0);
    });
  });
}
