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

    test('이미 저주된 대상 재시전은 무효 — 도화선이 리셋되지 않는다 (제보 #2)', () {
      // 0=부두, 1=대상. 0이 1을 저주 → 도화선 10. 이후 가만히 두며 줄다가
      // 다시 저주를 걸어도 도화선이 10으로 되돌아가면 안 된다(죽음 무한연기 방지).
      final chars = [CharId.voodoo, CharId.none];
      var st = PartyState.initial(chars);
      // t0: 저주 시전 → 10.
      var out = run(
        moves: [Move.voodoo(1), const Move.idle()],
        ammo: [0, 0],
        alive: [true, true],
        chars: chars,
        state: st,
        turn: 0,
      );
      st = out.stateAfter!;
      expect(st.curseFuse[1], kCurseFuse);

      // t1·t2: 가만히 → 매 턴 1씩 감소.
      for (var t = 1; t <= 2; t++) {
        out = run(
          moves: [const Move.idle(), const Move.idle()],
          ammo: out.ammoAfter,
          alive: out.aliveAfter,
          chars: chars,
          state: st,
          turn: t,
        );
        st = out.stateAfter!;
      }
      expect(st.curseFuse[1], kCurseFuse - 2, reason: '2턴 지나 8이어야');

      // t3: 같은 대상에 재시전 → 무효. 7a 감소(8→7)는 적용되지만 10으로 리셋 안 됨.
      out = run(
        moves: [Move.voodoo(1), const Move.idle()],
        ammo: out.ammoAfter,
        alive: out.aliveAfter,
        chars: chars,
        state: st,
        turn: 3,
      );
      st = out.stateAfter!;
      expect(st.curseFuse[1], kCurseFuse - 3,
          reason: '재시전 무효 → 정상 감소만(7). 10으로 리셋되면 버그');
      expect(out.voodooCast[0], isFalse,
          reason: '이미 저주 중이라 새 저주 표시 안 함');
      expect(st.curseCaster[1], 0, reason: '원래 시전자 유지');
    });

    test('시전자 사망으로 해제된 같은 턴에 다른 부두가 재시전하면 새 저주가 걸린다', () {
      // 0=부두A, 1=대상, 2=부두B, 3=사수. A가 1을 저주 → 같은 턴 A가 죽으면
      // 7a에서 해제(fuse 0)되고, 7b에서 B의 재시전이 (이제 비저주라) 걸려야 한다.
      final chars = [
        CharId.voodoo,
        CharId.none,
        CharId.voodoo,
        CharId.none,
      ];
      var st = PartyState.initial(chars);
      // t0: A 저주 시전, 사수 장전.
      var out = run(
        moves: [Move.voodoo(1), const Move.idle(), const Move.idle(), const Move.reload()],
        ammo: [0, 0, 0, 0],
        alive: [true, true, true, true],
        chars: chars,
        state: st,
        turn: 0,
      );
      st = out.stateAfter!;
      expect(st.curseFuse[1], kCurseFuse);
      expect(st.curseCaster[1], 0);

      // t1: 사수가 A(0)를 사살 + 동시에 B(2)가 같은 대상(1)에 재시전.
      out = run(
        moves: [const Move.idle(), const Move.idle(), Move.voodoo(1), Move.shoot(0)],
        ammo: out.ammoAfter,
        alive: out.aliveAfter,
        chars: chars,
        state: st,
        turn: 1,
      );
      st = out.stateAfter!;
      expect(out.aliveAfter[0], isFalse, reason: 'A 사망');
      expect(st.curseFuse[1], kCurseFuse,
          reason: 'A 저주 해제된 빈 자리에 B가 새로 저주(10)');
      expect(st.curseCaster[1], 2, reason: '새 시전자는 B(2)');
      expect(out.voodooCast[2], isTrue, reason: 'B의 새 저주는 표시됨');
    });

    test('의사가 저주 만료를 자힐로 버틴 같은 턴, 부두 재시전은 새 저주로 걸린다', () {
      // 0=의사(저주 fuse 1), 1=부두. 저주가 이번 턴 만료→의사 자힐로 생존→저주
      // 해제(0). 같은 턴 부두가 재시전하면 (이제 비저주라) 새 저주가 걸려야 한다.
      // 만료턴(fuse==1) 해제는 정당한 재시전 — 활성 저주를 리셋하는 버그와 다르다.
      final chars = [CharId.doctor, CharId.voodoo];
      final base = PartyState.initial(chars);
      final primed = PartyState(
        doctorUsed: base.doctorUsed, // 자힐 미사용
        trapUsed: base.trapUsed,
        smokeLeft: base.smokeLeft,
        reloads: base.reloads,
        paparazziUsed: base.paparazziUsed,
        resetterUsed: base.resetterUsed,
        curseFuse: [1, 0], // 의사 이번 턴 만료 예정
        curseCaster: [1, -1],
      );
      final out = run(
        moves: [const Move.idle(), Move.voodoo(0)],
        ammo: [0, 0],
        alive: [true, true],
        chars: chars,
        state: primed,
      );
      expect(out.healed[0], isTrue, reason: '의사가 저주 만료 사망을 자힐로 버팀');
      expect(out.curseKill[0], isFalse);
      expect(out.aliveAfter[0], isTrue);
      expect(out.stateAfter!.curseFuse[0], kCurseFuse,
          reason: '만료·해제된 자리에 새 저주(10)');
      expect(out.stateAfter!.curseCaster[0], 1);
      expect(out.voodooCast[1], isTrue);
    });

    test('의사가 덫 반사를 자힐로 버티면 반사사망 표시가 남지 않는다', () {
      // 0=의사(빵야), 1=사냥꾼(덫). 덫 놓은 사냥꾼을 쏘면 반사로 죽을 뻔하나 자힐로
      // 생존 — reflectKill이 산 의사에게 남으면 '반사 사망' 연출이 잘못 뜬다.
      final out = run(
        moves: [Move.shoot(1), const Move.trap()],
        ammo: [1, 0],
        alive: [true, true],
        chars: [CharId.doctor, CharId.hunter],
      );
      expect(out.healed[0], isTrue, reason: '의사가 반사 사망을 자힐로 버팀');
      expect(out.reflectKill[0], isFalse, reason: '살아남았으니 반사사망 표시 없음');
      expect(out.aliveAfter[0], isTrue);
    });
  });

  // ---- 리셋(무효) 상호작용 ----
  group('리셋 무효 상호작용', () {
    test('무효 턴은 룰렛 자기-꽝(자해)의 사망·표시를 모두 지운다', () {
      // 0=룰렛, 1=대상, 2=리셋터. 룰렛이 자신에게 빗나가는(자해) 턴을 결정적으로
      // 찾은 뒤, 같은 턴 리셋터가 무효를 내면 자해 사망도 '꽝!' 표시도 없어야 한다.
      final chars = [CharId.roulette, CharId.none, CharId.resetter];
      int? selfTurn;
      for (var t = 0; t < 300; t++) {
        final ctrl = run(
          moves: [Move.roulette(1), const Move.idle(), const Move.idle()],
          ammo: [0, 0, 0],
          alive: [true, true, true],
          chars: chars,
          turn: t,
        );
        if (ctrl.rouletteSelf[0]) {
          selfTurn = t;
          break;
        }
      }
      expect(selfTurn, isNotNull, reason: '룰렛 자해 턴을 찾아야 함');
      final out = run(
        moves: [Move.roulette(1), const Move.idle(), const Move.reset()],
        ammo: [0, 0, 0],
        alive: [true, true, true],
        chars: chars,
        turn: selfTurn!,
      );
      expect(out.resetActive[2], isTrue);
      expect(out.aliveAfter[0], isTrue, reason: '무효로 자해 사망 취소');
      expect(out.rouletteSelf[0], isFalse,
          reason: '무효 턴엔 꽝 표시도 없어야(거짓 RouletteBust 방지)');
    });

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

  // ---- 저주 도화선 만료 타이밍 엣지 ----
  group('저주 도화선 만료 타이밍', () {
    // 0=부두(시전자), 1=대상, 2=일반(시전자를 쏠 수 있음).
    PartyState primed(int fuse) {
      final base = PartyState.initial(
          [CharId.voodoo, CharId.none, CharId.none]);
      return PartyState(
        doctorUsed: base.doctorUsed,
        trapUsed: base.trapUsed,
        smokeLeft: base.smokeLeft,
        reloads: base.reloads,
        paparazziUsed: base.paparazziUsed,
        resetterUsed: base.resetterUsed,
        curseFuse: [0, fuse, 0],
        curseCaster: [-1, 0, -1],
      );
    }

    test('도화선 1 + 시전자·대상 생존 → 이번 턴 대상 사망', () {
      final out = run(
        moves: [const Move.reload(), const Move.reload(), const Move.reload()],
        ammo: [0, 0, 0],
        alive: [true, true, true],
        chars: [CharId.voodoo, CharId.none, CharId.none],
        state: primed(1),
      );
      expect(out.curseKill[1], isTrue);
      expect(out.aliveAfter[1], isFalse);
    });

    test('만료 턴에 시전자가 사망하면 대상은 살아남는다(저주 해제)', () {
      // 도화선 1인데 같은 턴 시전자(0)가 2의 빵야에 죽음 → 저주 미발동.
      final out = run(
        moves: [const Move.reload(), const Move.reload(), Move.shoot(0)],
        ammo: [0, 0, 1],
        alive: [true, true, true],
        chars: [CharId.voodoo, CharId.none, CharId.none],
        state: primed(1),
      );
      expect(out.hit[0], isTrue, reason: '시전자 사망');
      expect(out.curseKill[1], isFalse, reason: '시전자 죽으면 저주 미발동');
      expect(out.aliveAfter[1], isTrue);
      expect(out.stateAfter!.curseFuse[1], 0, reason: '저주 해제');
      expect(out.stateAfter!.curseCaster[1], -1);
    });

    test('대상이 만료 전에 다른 사인으로 죽으면 저주 상태가 해제된다', () {
      // 도화선 5(아직 멀었음)인데 대상(1)이 2의 빵야에 죽음.
      final out = run(
        moves: [const Move.reload(), const Move.reload(), Move.shoot(1)],
        ammo: [0, 0, 1],
        alive: [true, true, true],
        chars: [CharId.voodoo, CharId.none, CharId.none],
        state: primed(5),
      );
      expect(out.hit[1], isTrue);
      expect(out.curseKill[1], isFalse, reason: '만료가 아니라 일반 사망');
      expect(out.stateAfter!.curseFuse[1], 0, reason: '죽은 대상 저주 해제');
      expect(out.stateAfter!.curseCaster[1], -1);
    });

    test('도화선은 만료 전까지 매 턴 정확히 1씩만 감소한다', () {
      var state = primed(3);
      // 턴마다 모두 장전. 3→2→1→(만료 사망).
      var alive = [true, true, true];
      var ammo = [0, 0, 0];
      final fuses = <int>[];
      var killTurn = -1;
      for (var t = 0; t < 4; t++) {
        final out = run(
          moves: [const Move.reload(), const Move.reload(), const Move.reload()],
          ammo: ammo,
          alive: alive,
          chars: [CharId.voodoo, CharId.none, CharId.none],
          state: state,
          turn: t,
        );
        if (out.curseKill[1]) killTurn = t;
        fuses.add(out.stateAfter!.curseFuse[1]);
        state = out.stateAfter!;
        alive = out.aliveAfter;
        ammo = out.ammoAfter;
      }
      // fuse 진행: 2,1,0(사망),0 — 단조 감소 + 만료 정확히 3번째 턴.
      expect(fuses[0], 2);
      expect(fuses[1], 1);
      expect(killTurn, 2, reason: 'fuse 3 → 정확히 3턴 뒤 사망');
    });

    test('시전자가 만료 1턴 전에 죽으면 다음 턴 대상은 안 죽는다', () {
      // 도화선 2. 이번 턴 시전자 사망 → 해제. 다음 턴엔 저주 없음.
      var out = run(
        moves: [const Move.reload(), const Move.reload(), Move.shoot(0)],
        ammo: [0, 0, 1],
        alive: [true, true, true],
        chars: [CharId.voodoo, CharId.none, CharId.none],
        state: primed(2),
      );
      expect(out.hit[0], isTrue);
      expect(out.stateAfter!.curseFuse[1], 0, reason: '시전자 죽어 즉시 해제');
      // 다음 턴: 대상 생존 유지.
      out = run(
        moves: [Move.empty, const Move.reload(), const Move.reload()],
        ammo: out.ammoAfter,
        alive: out.aliveAfter,
        chars: [CharId.voodoo, CharId.none, CharId.none],
        state: out.stateAfter!,
        turn: 1,
      );
      expect(out.curseKill[1], isFalse);
      expect(out.aliveAfter[1], isTrue);
    });
  });

  // ---- 파파라치 엿보기 페이즈는 엔진 판정과 무관(메타데이터) ----
  group('파파라치 엿보기', () {
    test('파파라치가 일반 행동을 하면 일반인과 동일하게 판정된다', () {
      // 엿보기(peek)는 online_service의 별도 페이즈라 resolvePartyTurn에 안 들어온다.
      // 따라서 파파라치 좌석의 일반 행동은 일반인과 결과가 같아야 한다.
      TurnOutcome forChar(CharId c) => run(
            moves: [Move.shoot(1), const Move.defend(), const Move.reload()],
            ammo: [1, 0, 0],
            alive: [true, true, true],
            chars: [c, CharId.none, CharId.none],
            seed: 'PAPA',
          );
      final papa = forChar(CharId.paparazzi);
      final commoner = forChar(CharId.commoner);
      expect(papa.hit, commoner.hit);
      expect(papa.ammoAfter, commoner.ammoAfter);
      expect(papa.aliveAfter, commoner.aliveAfter);
      expect(papa.status, commoner.status);
    });

    test('파파라치는 시작 탄약·연막 자원이 없다(일반과 동일)', () {
      expect(startAmmoFor(CharId.paparazzi), 0);
      final st = PartyState.initial([CharId.paparazzi, CharId.none]);
      expect(st.smokeLeft[0], 0);
      expect(st.paparazziUsed[0], isFalse);
    });
  });
}
