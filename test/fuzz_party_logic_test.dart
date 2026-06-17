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

/// 균일 무작위 행동. 빵야가 잦아 게임이 빨리 끝난다(공격형 커버리지).
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

/// 소극적(passive) 행동 — 장전·방어·저주·덫 위주, 빵야 거의 안 함. 게임이
/// 오래가서 저주 10턴 만료·평화주의자 6장전 승리 같은 **장기 불변식**을 깊게 친다.
Move _passiveMove(Random rng, int n) {
  final tgt = rng.nextInt(n);
  switch (rng.nextInt(10)) {
    case 0:
    case 1:
    case 2:
    case 3:
      return Move.reload(smoke: rng.nextBool());
    case 4:
    case 5:
      return Move.defend(smoke: rng.nextBool());
    case 6:
      return Move.voodoo(tgt);
    case 7:
      return const Move.trap();
    case 8:
      return const Move.reset();
    default:
      return Move.shoot(tgt); // 가끔만 빵야 — 누군가는 떨어져야 끝남
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
    // 8b) 사인(死因) 표시 플래그는 실제 사망일 때만 — 살아남은 좌석에 켜져 있으면
    //     '저주 사망!'/'반사 사망' 연출·배너가 잘못 뜬다(의사 자힐 누락 버그).
    if (out.curseKill[s] && out.aliveAfter[s]) {
      v.add('seat $s curseKill set but alive (거짓 저주사망)');
    }
    if (out.reflectKill[s] && out.aliveAfter[s]) {
      v.add('seat $s reflectKill set but alive (거짓 반사사망)');
    }

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

    // 3b) 능력 귀속: 각 능력 플래그는 해당 직업에서만 발동해야 한다(오귀속 방지).
    void attrib(bool flag, CharId owner, String name) {
      if (flag && chars[s] != owner) {
        v.add('$name set on seat $s of ${chars[s]} (only $owner)');
      }
    }

    attrib(out.pierced[s], CharId.sniper, 'pierced');
    attrib(out.doubleLoad[s], CharId.speedloader, 'doubleLoad');
    attrib(out.healed[s], CharId.doctor, 'healed');
    attrib(out.trapSet[s], CharId.hunter, 'trapSet');
    attrib(out.smoked[s], CharId.smoker, 'smoked');
    attrib(out.rouletteFired[s], CharId.roulette, 'rouletteFired');
    attrib(out.dualFired[s], CharId.dualgun, 'dualFired');
    attrib(out.voodooCast[s], CharId.voodoo, 'voodooCast');
    attrib(out.resetActive[s], CharId.resetter, 'resetActive');

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
    // 5b) 재시전 리셋 금지(제보 #2, newlyCast로 가려지지 않는 강한 가드):
    //     도화선이 **2 이상**(이번 턴 만료되지 않음)이고 시전자가 생존 중이면,
    //     그 저주는 7a에서 감소만 되고(여전히 >0) 7b의 재시전 가드가 막으므로
    //     도화선은 반드시 정확히 1 줄어야 한다. 그대로거나 늘면(=재시전 리셋) 버그.
    //     fuse==1은 이번 턴 만료·해제(의사 자힐로 생존 시 0으로 풀려 재시전 가능)라
    //     정당한 증가가 있을 수 있어 제외. 시전자 사망으로 해제 후 새 저주도
    //     oldCasterAlive=false로 자연 제외된다.
    final ccBefore = curseCasterBefore(s);
    final oldCasterAlive =
        ccBefore >= 0 && ccBefore < n && out.aliveAfter[ccBefore];
    if (!voided && curseFuseBefore(s) > 1 && oldCasterAlive) {
      if (cf >= curseFuseBefore(s)) {
        v.add('curseFuse[$s] 시전자 생존·만료전인데 감소 안 함 '
            '${curseFuseBefore(s)}->$cf (재시전 리셋 의심)');
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
    const games = 6000;
    const maxTurns = 120;
    const passiveFrom = 4000; // 이 이후 게임은 소극적 행동(장기 불변식 커버)
    final problems = <String>[];
    // 장기 이벤트가 실제로 발생했는지 커버리지 카운터(0이면 테스트가 헛돈 것).
    var sawCurseKill = 0, sawPacifistWin = 0, sawReflectKill = 0;

    outer:
    for (var g = 0; g < games; g++) {
      final rng = Random(g + 1);
      final passive = g >= passiveFrom;
      final n = 2 + rng.nextInt(kMaxSeats - kMinSeats + 1); // 2..6
      final chars = [for (var s = 0; s < n; s++) _charPool[rng.nextInt(_charPool.length)]];
      var state = PartyState.initial(chars);
      var ammo = [for (final c in chars) startAmmoFor(c)];
      var alive = List<bool>.filled(n, true);
      final seed = 'FUZZ$g';

      for (var t = 0; t < maxTurns; t++) {
        final moves = [
          for (var s = 0; s < n; s++)
            alive[s]
                ? (passive ? _passiveMove(rng, n) : _randomMove(rng, n))
                : Move.empty
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
        if (out.curseKill.any((x) => x)) sawCurseKill++;
        if (out.reflectKill.any((x) => x)) sawReflectKill++;
        if (out.specialWin == 'pacifist') sawPacifistWin++;
        state = out.stateAfter!;
        ammo = out.ammoAfter;
        alive = out.aliveAfter;
        if (out.status != GameStatus.ongoing) break;
      }
    }

    expect(problems, isEmpty,
        reason: '불변식 위반 ${problems.length}건:\n${problems.take(20).join("\n")}');
    // 커버리지 가드: 장기 이벤트가 한 번도 안 났으면 퍼즈가 표면만 친 것.
    expect(sawCurseKill, greaterThan(0), reason: '저주 만료 사망이 한 번도 발생 안 함');
    expect(sawReflectKill, greaterThan(0), reason: '덫 반사 사망이 한 번도 발생 안 함');
    expect(sawPacifistWin, greaterThan(0), reason: '평화주의자 승리가 한 번도 발생 안 함');
  });
}
