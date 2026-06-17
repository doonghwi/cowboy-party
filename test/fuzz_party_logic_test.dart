// 룰엔진 퍼즈/속성 테스트 (BUGS.md P2).
//
// 시드 고정 무작위 게임을 대량(N회) 돌리며 [resolvePartyTurn]의 불변식을 검사한다.
// 결정적(math.Random 고정 시드)이라 실패하면 game/turn 인덱스로 그대로 재현된다.
// 불변식 위반이 나오면 BUGS.md에 새 항목으로 등록하고 엔진을 고친 뒤 이 테스트가
// 다시 통과해야 한다.
import 'dart:math';

import 'package:cowboy_party/game/party_logic.dart';
import 'package:flutter_test/flutter_test.dart';

/// 모든 직업 + 무직(none) 풀. ???(mystery)는 effectiveChar로 실제 직업이 되므로
/// 엔진엔 절대 들어오지 않지만(=일반인처럼 동작) 견고성 차원에서 포함한다.
final List<CharId> _charPool = CharId.values;

Move _randomMove(Random rng, int n) {
  final tgt = rng.nextInt(n);
  final tgt2 = rng.nextInt(n);
  final smoke = rng.nextBool();
  switch (rng.nextInt(11)) {
    case 0:
      return Move.reload(smoke: smoke);
    case 1:
      return Move.defend(smoke: smoke);
    case 2:
      return Move.shoot(tgt, smoke: smoke);
    case 3:
      return Move.superShoot(tgt, smoke: smoke);
    case 4:
      return const Move.trap();
    case 5:
      return const Move.idle();
    case 6:
      return Move.roulette(tgt);
    case 7:
      return Move.dualShoot(tgt, tgt2);
    case 8:
      return Move.voodoo(tgt);
    case 9:
      return const Move.reset();
    default:
      return const Move.reload();
  }
}

/// 한 턴 결과의 불변식을 모두 검사하고 위반 메시지 목록을 돌려준다(빈 = 정상).
List<String> _checkInvariants({
  required PartyState before,
  required List<bool> aliveBefore,
  required List<int> ammoBefore,
  required List<CharId> chars,
  required TurnOutcome out,
}) {
  final v = <String>[];
  final n = chars.length;
  final after = out.stateAfter!;
  final voided = out.resetActive.any((x) => x);

  int curseFuseBefore(int s) =>
      s < before.curseFuse.length ? before.curseFuse[s] : 0;
  int curseCasterBefore(int s) =>
      s < before.curseCaster.length ? before.curseCaster[s] : -1;

  for (var s = 0; s < n; s++) {
    // 1) 총알 0..max.
    if (out.ammoAfter[s] < 0 || out.ammoAfter[s] > kMaxAmmo) {
      v.add('ammo[$s]=${out.ammoAfter[s]} out of [0,$kMaxAmmo]');
    }
    // 2) 부활 금지: 살아있는 결과면 시작도 살아있었어야.
    if (out.aliveAfter[s] && !aliveBefore[s]) {
      v.add('seat $s resurrected (dead before, alive after)');
    }
    // 8) 피격은 사망으로 이어진다(의사 힐은 hit를 끈다); 죽은 자는 못 맞는다.
    if (out.hit[s] && out.aliveAfter[s]) v.add('seat $s hit but still alive');
    if (out.hit[s] && !aliveBefore[s]) v.add('seat $s hit while dead-before');

    // 3) 죽은 자는 어떤 행동/능력도 발동하지 않고 총알도 그대로.
    if (!aliveBefore[s]) {
      if (out.ammoAfter[s] != ammoBefore[s]) {
        v.add('dead seat $s ammo changed ${ammoBefore[s]}->${out.ammoAfter[s]}');
      }
      final flags = {
        'fired': out.fired[s],
        'healed': out.healed[s],
        'trapSet': out.trapSet[s],
        'smoked': out.smoked[s],
        'evaded': out.evaded[s],
        'pierced': out.pierced[s],
        'doubleLoad': out.doubleLoad[s],
        'rouletteFired': out.rouletteFired[s],
        'dualFired': out.dualFired[s],
        'voodooCast': out.voodooCast[s],
        'curseKill': out.curseKill[s],
        'resetActive': out.resetActive[s],
      };
      flags.forEach((k, set) {
        if (set) v.add('dead seat $s flag $k set');
      });
    }

    // 4) 1회성 자원 단조성(false→true), 연막 단조 감소, 장전 누적 비감소.
    if (before.doctorUsed[s] && !after.doctorUsed[s]) {
      v.add('doctorUsed[$s] reverted true->false');
    }
    if (before.trapUsed[s] && !after.trapUsed[s]) {
      v.add('trapUsed[$s] reverted true->false');
    }
    if (before.resetterUsed[s] && !after.resetterUsed[s]) {
      v.add('resetterUsed[$s] reverted true->false');
    }
    if (after.smokeLeft[s] > before.smokeLeft[s]) {
      v.add('smokeLeft[$s] increased ${before.smokeLeft[s]}->${after.smokeLeft[s]}');
    }
    if (after.smokeLeft[s] < 0 || after.smokeLeft[s] > 2) {
      v.add('smokeLeft[$s]=${after.smokeLeft[s]} out of [0,2]');
    }
    if (after.reloads[s] < before.reloads[s]) {
      v.add('reloads[$s] decreased ${before.reloads[s]}->${after.reloads[s]}');
    }

    // 5) 저주: 도화선 0..fuse, 도화선>0 ⟺ 시전자 좌석 유효 & 그 시전자 생존.
    final cf = after.curseFuse[s], cc = after.curseCaster[s];
    if (cf < 0 || cf > kCurseFuse) {
      v.add('curseFuse[$s]=$cf out of [0,$kCurseFuse]');
    }
    if ((cf > 0) != (cc >= 0)) {
      v.add('curse fuse/caster inconsistent at $s (fuse=$cf caster=$cc)');
    }
    if (cf > 0 && cc >= 0 && cc < n && !out.aliveAfter[cc]) {
      v.add('curse on $s but caster $cc is dead (should release)');
    }
    if (cf > 0) {
      final newlyCast = out.voodooCast.asMap().entries.any(
          (e) => e.value && cc == e.key); // 이번 턴 cc가 s를 새로 저주했나(근사)
      // 새 저주가 아니고 무효 턴도 아니면 도화선은 단조 감소해야 한다.
      if (!newlyCast && !voided && curseFuseBefore(s) > 0) {
        if (cf > curseFuseBefore(s)) {
          v.add('curseFuse[$s] increased ${curseFuseBefore(s)}->$cf (non-cast)');
        }
      }
    }
  }

  // 6) 무효(reset) 턴: 아무도 죽지 않고 저주 상태가 보존된다.
  if (voided) {
    for (var s = 0; s < n; s++) {
      if (out.aliveAfter[s] != aliveBefore[s]) {
        v.add('voided turn changed alive[$s]');
      }
      if (after.curseFuse[s] != curseFuseBefore(s)) {
        v.add('voided turn changed curseFuse[$s]');
      }
      if (after.curseCaster[s] != curseCasterBefore(s)) {
        v.add('voided turn changed curseCaster[$s]');
      }
    }
  }

  // 7) 상태값 일관성.
  final survivors = [for (var s = 0; s < n; s++) if (out.aliveAfter[s]) s];
  switch (out.status) {
    case GameStatus.won:
      if (out.winner == null) {
        v.add('won but winner null');
      } else if (!out.aliveAfter[out.winner!]) {
        v.add('winner ${out.winner} not alive');
      }
      break;
    case GameStatus.draw:
      if (survivors.isNotEmpty) v.add('draw but survivors=$survivors');
      break;
    case GameStatus.ongoing:
      if (survivors.length < 2) {
        v.add('ongoing but survivors=$survivors (<2)');
      }
      break;
  }
  return v;
}

void main() {
  test('퍼즈: 무작위 라인업·행동시퀀스 대량 시뮬에서 룰엔진 불변식 위반 0', () {
    const games = 4000;
    const maxTurns = 80;
    final problems = <String>[];

    outer:
    for (var g = 0; g < games; g++) {
      final rng = Random(g + 1);
      final n = 2 + rng.nextInt(kMaxSeats - kMinSeats + 1); // 2..6
      final chars = [for (var s = 0; s < n; s++) _charPool[rng.nextInt(_charPool.length)]];
      var state = PartyState.initial(chars);
      var ammo = [for (final c in chars) startAmmoFor(c)];
      var alive = List<bool>.filled(n, true);
      final seed = 'FUZZ$g';

      for (var t = 0; t < maxTurns; t++) {
        final moves = [
          for (var s = 0; s < n; s++)
            alive[s] ? _randomMove(rng, n) : Move.empty
        ];
        final before = state;
        final aliveBefore = List<bool>.from(alive);
        final ammoBefore = List<int>.from(ammo);
        final out = resolvePartyTurn(
          moves: moves,
          ammoBefore: ammo,
          aliveBefore: alive,
          chars: chars,
          state: state,
          seed: seed,
          turn: t,
        );
        final viol = _checkInvariants(
          before: before,
          aliveBefore: aliveBefore,
          ammoBefore: ammoBefore,
          chars: chars,
          out: out,
        );
        if (viol.isNotEmpty) {
          problems.add('game $g turn $t chars=$chars: ${viol.join("; ")}');
          continue outer; // 이 게임은 더 돌리지 않고 다음으로
        }
        state = out.stateAfter!;
        ammo = out.ammoAfter;
        alive = out.aliveAfter;
        if (out.status != GameStatus.ongoing) break;
      }
    }

    expect(problems, isEmpty,
        reason: '불변식 위반 ${problems.length}건:\n${problems.take(20).join("\n")}');
  });
}
