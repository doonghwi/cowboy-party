// 적대적/퇴행(degenerate) 시나리오 — 무작위 퍼즈가 잘 안 닿는 극단적 대국을
// 손으로 구성해 룰엔진이 멈추거나 거짓 승리/크래시를 내지 않는지 못박는다.
//   · 전원 영원히 가만히      → 끝나지 않음(ongoing), 자원 불변
//   · 전원 영원히 방어         → 스테일메이트, 사망/승리 없음
//   · 마지막 2인 상호 사살     → 무승부(draw)
//   · 긴 저주 체인            → 퓨즈 10→0 단조감소, 만료턴에 사망, 시전자 사망 시 해제
//   · ??? vs ???             → 각자 결정적 실제 직업으로 동작, 거짓 reveal 없음
//   · 최대 장전 평화주의자     → 6장전+생존 즉시 승리, 동시 2명 도달은 승자 없음(ongoing)
import 'package:cowboy_party/game/party_logic.dart';
import 'package:flutter_test/flutter_test.dart';

/// 상태를 턴마다 이어가며 대국을 굴리는 작은 드라이버
/// (엔진 resolvePartyTurn은 입력을 변형하지 않으므로 매 턴 결과로 갱신).
class _Game {
  final List<CharId> chars;
  final String seed;
  List<int> ammo;
  List<bool> alive;
  PartyState state;
  int turn = 0;

  _Game(this.chars, {this.seed = 'ADV'})
      : ammo = [for (final c in chars) startAmmoFor(c)],
        alive = List<bool>.filled(chars.length, true),
        state = PartyState.initial(chars);

  TurnOutcome step(List<Move> moves) {
    final out = resolvePartyTurn(
      moves: moves,
      ammoBefore: ammo,
      aliveBefore: alive,
      chars: chars,
      state: state,
      seed: seed,
      turn: turn,
    );
    ammo = out.ammoAfter;
    alive = out.aliveAfter;
    state = out.stateAfter!;
    turn++;
    return out;
  }
}

void main() {
  group('퇴행 시나리오 — 멈추지 않고 거짓 승리도 없다', () {
    test('전원 영원히 가만히: 50턴이 지나도 ongoing, 자원 불변·사망 없음', () {
      for (final n in [2, 3, 6]) {
        final g = _Game([for (var i = 0; i < n; i++) CharId.commoner]);
        final ammo0 = List<int>.from(g.ammo);
        for (var t = 0; t < 50; t++) {
          final out = g.step([for (var i = 0; i < n; i++) const Move.idle()]);
          expect(out.status, GameStatus.ongoing, reason: 'n=$n t=$t 가만히인데 종료됨');
          expect(out.hit.any((h) => h), isFalse, reason: 'n=$n 가만히인데 사망');
        }
        expect(g.ammo, ammo0, reason: 'n=$n 가만히인데 총알 변함');
        expect(g.alive.every((a) => a), isTrue);
      }
    });

    test('전원 영원히 방어: 스테일메이트 — 사망/승리 없이 계속 ongoing', () {
      final g = _Game([for (var i = 0; i < 4; i++) CharId.commoner]);
      for (var t = 0; t < 40; t++) {
        final out = g.step([for (var i = 0; i < 4; i++) const Move.defend()]);
        expect(out.status, GameStatus.ongoing, reason: '방어 스테일메이트 t=$t');
        expect(out.hit.any((h) => h), isFalse);
      }
      expect(g.alive.every((a) => a), isTrue);
    });

    test('마지막 2인 상호 사살 → 무승부(draw)', () {
      final g = _Game([CharId.commoner, CharId.commoner]);
      // 양쪽 다 장전.
      g.step([const Move.reload(), const Move.reload()]);
      expect(g.ammo[0], 1);
      expect(g.ammo[1], 1);
      // 서로를 동시에 쏜다 → 둘 다 사망 → draw.
      final out = g.step([const Move.shoot(1), const Move.shoot(0)]);
      expect(out.aliveAfter, [false, false]);
      expect(out.status, GameStatus.draw, reason: '동시 전멸은 무승부');
      expect(out.winner, isNull);
    });
  });

  group('긴 저주 체인', () {
    test('저주 퓨즈 10→0 단조 감소, 0이 되는 턴에만 사망', () {
      // 부두술사(0)가 일반인(1)을 저주. 그 후 둘 다 가만히.
      final g = _Game([CharId.voodoo, CharId.commoner]);
      final first = g.step([const Move.voodoo(1), const Move.idle()]);
      expect(first.voodooCast[0], isTrue, reason: '저주 시전 표시');
      expect(first.stateAfter!.curseFuse[1], kCurseFuse,
          reason: '저주 직후 퓨즈 = $kCurseFuse');
      expect(first.stateAfter!.curseCaster[1], 0);

      var prev = kCurseFuse;
      var deathTurn = -1;
      for (var t = 0; t < kCurseFuse + 2 && g.alive[1]; t++) {
        final out = g.step([const Move.idle(), const Move.idle()]);
        final fuse = out.stateAfter!.curseFuse[1];
        if (g.alive[1]) {
          // 아직 살아있다면 퓨즈는 정확히 1씩 줄어든다.
          expect(fuse, prev - 1, reason: '퓨즈 단조감소 t=$t (이전 $prev)');
          prev = fuse;
        }
        if (out.curseKill[1]) {
          deathTurn = t;
          expect(out.aliveAfter[1], isFalse);
        }
      }
      expect(deathTurn, greaterThanOrEqualTo(0), reason: '저주가 끝내 발동해야 함');
    });

    test('시전자가 먼저 죽으면 저주가 풀린다(피해자 생존)', () {
      // 0=부두, 1=피해자, 2=처형자. 0이 1을 저주.
      final g = _Game([CharId.voodoo, CharId.commoner, CharId.commoner]);
      g.step([const Move.voodoo(1), const Move.idle(), const Move.reload()]);
      expect(g.state.curseFuse[1], kCurseFuse);
      // 2가 장전돼 있으니 0(시전자)을 쏴 죽인다.
      final out = g.step([const Move.idle(), const Move.idle(), const Move.shoot(0)]);
      expect(out.aliveAfter[0], isFalse, reason: '시전자 사망');
      expect(out.stateAfter!.curseFuse[1], 0, reason: '시전자 사망 → 저주 해제');
      expect(out.stateAfter!.curseCaster[1], -1);
      // 이후 한참 가만히 둬도 피해자는 안 죽는다.
      for (var t = 0; t < kCurseFuse + 2; t++) {
        final o = g.step([Move.empty, const Move.idle(), const Move.idle()]);
        expect(o.curseKill[1], isFalse, reason: '해제됐으니 저주사 없음 t=$t');
      }
      expect(g.alive[1], isTrue);
    });
  });

  group('??? vs ??? (정체 미공개 둘이 맞붙어도 결정적)', () {
    test('두 ???가 같은 시드에서 각자 고정된 실제 직업으로 동작', () {
      const seed = 'MYSTERYDUEL';
      final e0 = effectiveChar(CharId.mystery, seed, 0);
      final e1 = effectiveChar(CharId.mystery, seed, 1);
      // 결정적: 다시 풀어도 동일.
      expect(effectiveChar(CharId.mystery, seed, 0), e0);
      expect(effectiveChar(CharId.mystery, seed, 1), e1);
      // 실제 직업은 ???가 아니다.
      expect(e0, isNot(CharId.mystery));
      expect(e1, isNot(CharId.mystery));
      // 엔진엔 실제 직업이 들어간다(룰은 effectiveChar 기준).
      final g = _Game([e0, e1], seed: seed);
      final out = g.step([const Move.reload(), const Move.reload()]);
      expect(out.status, GameStatus.ongoing);
      // 같은 입력 재생 → 동일 결과(결정성).
      final g2 = _Game([e0, e1], seed: seed);
      final out2 = g2.step([const Move.reload(), const Move.reload()]);
      expect(out2.ammoAfter, out.ammoAfter);
    });
  });

  group('최대 장전 평화주의자', () {
    test('6회 장전 + 생존 → 즉시 평화주의자 승리', () {
      final g = _Game([CharId.pacifist, CharId.commoner]);
      TurnOutcome? out;
      for (var t = 0; t < kPacifistGoal; t++) {
        out = g.step([const Move.reload(), const Move.defend()]);
      }
      expect(out!.specialWin, 'pacifist');
      expect(out.status, GameStatus.won);
      expect(out.winner, 0);
      expect(g.state.reloads[0], greaterThanOrEqualTo(kPacifistGoal));
    });

    test('두 평화주의자가 같은 턴에 목표 도달 → 단독 승자 없음(ongoing)', () {
      // length==1 가드: 동시 도달은 즉시 승리로 처리하지 않는다(둘 다 생존).
      final g = _Game([CharId.pacifist, CharId.pacifist]);
      TurnOutcome? out;
      for (var t = 0; t < kPacifistGoal; t++) {
        out = g.step([const Move.reload(), const Move.reload()]);
      }
      expect(g.state.reloads[0], greaterThanOrEqualTo(kPacifistGoal));
      expect(g.state.reloads[1], greaterThanOrEqualTo(kPacifistGoal));
      expect(out!.specialWin, isNull, reason: '동시 도달은 특수승 없음');
      expect(out.status, GameStatus.ongoing, reason: '둘 다 생존 → 계속');
    });

    test('평화주의자는 빵야할 수 없어 6장전 경로만 승리한다', () {
      // 평화주의자가 쏘려 해도(설사 총알이 있어도) 발사되지 않는다(line 430 가드).
      final g = _Game([CharId.pacifist, CharId.commoner]);
      // 평화주의자에게 억지로 총알을 줄 수 없으니 장전 후 빵야 시도.
      g.step([const Move.reload(), const Move.defend()]);
      final out = g.step([const Move.shoot(1), const Move.defend()]);
      expect(out.fired[0], isFalse, reason: '평화주의자는 발사 불가');
      expect(out.hit.any((h) => h), isFalse);
    });
  });

  group('의사 자힐과 승패 판정', () {
    test('상호 사살에서 의사가 자힐로 버티면 무승부가 아니라 단독 승리', () {
      final g = _Game([CharId.doctor, CharId.commoner]);
      g.step([const Move.reload(), const Move.reload()]); // 둘 다 1발
      final out = g.step([const Move.shoot(1), const Move.shoot(0)]);
      expect(out.healed[0], isTrue, reason: '의사가 치명상 버팀');
      expect(out.curseKill[0], isFalse);
      expect(out.reflectKill[0], isFalse);
      expect(out.aliveAfter, [true, false]);
      expect(out.status, GameStatus.won, reason: '의사 생존 → 무승부 아님');
      expect(out.winner, 0);
    });

    test('두 의사가 서로 사살하면 둘 다 자힐로 버텨 게임이 계속된다', () {
      final g = _Game([CharId.doctor, CharId.doctor]);
      g.step([const Move.reload(), const Move.reload()]);
      final out = g.step([const Move.shoot(1), const Move.shoot(0)]);
      expect(out.healed[0], isTrue);
      expect(out.healed[1], isTrue);
      expect(out.aliveAfter, [true, true], reason: '둘 다 자힐 생존');
      expect(out.status, GameStatus.ongoing, reason: '거짓 무승부/승리 없음');
      // 자힐은 게임당 1회 — 다음 상호 사살은 진짜 무승부.
      g.step([const Move.reload(), const Move.reload()]);
      final out2 = g.step([const Move.shoot(1), const Move.shoot(0)]);
      expect(out2.aliveAfter, [false, false], reason: '자힐 소진 → 둘 다 사망');
      expect(out2.status, GameStatus.draw);
    });
  });
}
