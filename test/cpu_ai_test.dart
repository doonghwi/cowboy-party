// CPU 봇 AI(오프라인 '컴퓨터와 대결') 속성 테스트.
//
// CpuAi.chooseMove는 158줄 분기인데 그동안 테스트가 0이었다. 봇이 **불법 수**를
// 내면(자기/죽은 좌석 조준, 총알 없이 빵야, 더블빵야 한쪽 -1 등) 룰엔진이 오작동할
// 수 있다. 여기서 모든 분기가 항상 유효한 Move를 내는지 시드 고정으로 못박는다.
import 'dart:math';

import 'package:cowboy_party/game/cpu_ai.dart';
import 'package:cowboy_party/game/party_logic.dart';
import 'package:flutter_test/flutter_test.dart';

final _pool = CharId.values.where((c) => c != CharId.mystery).toList();

/// 이 좌석/상태에서 [m]이 룰엔진이 받아들일 수 있는 유효한 수인가.
String? invalidReason(
    Move m, int seat, List<int> ammo, List<bool> alive, CharId myChar) {
  final n = ammo.length;
  bool livingRival(int t) => t >= 0 && t < n && t != seat && alive[t];
  switch (m.kind) {
    case ActKind.reload:
    case ActKind.defend:
    case ActKind.idle:
      return null;
    case ActKind.trap:
      return myChar == CharId.hunter ? null : '덫은 사냥꾼만';
    case ActKind.reset:
      return myChar == CharId.resetter ? null : '무효는 리셋터만';
    case ActKind.shoot:
      if (ammo[seat] <= 0) return '총알 없이 빵야';
      return livingRival(m.target) ? null : '빵야 대상 무효 ${m.target}';
    case ActKind.superShoot:
      if (ammo[seat] < kSuperCost) return '슈퍼 총알 부족';
      return livingRival(m.target) ? null : '슈퍼 대상 무효';
    case ActKind.dualShoot:
      if (myChar != CharId.dualgun) return '더블은 쌍권총만';
      if (ammo[seat] < 2) return '더블 총알 부족';
      if (!livingRival(m.target) || !livingRival(m.target2)) {
        return '더블 대상 무효 ${m.target}/${m.target2}';
      }
      if (m.target == m.target2) return '더블 두 대상 동일';
      return null;
    case ActKind.roulette:
      if (myChar != CharId.roulette) return '룰렛은 러시안룰렛만';
      return livingRival(m.target) ? null : '룰렛 대상 무효';
    case ActKind.voodoo:
      if (myChar != CharId.voodoo) return '저주는 부두만';
      return livingRival(m.target) ? null : '저주 대상 무효';
  }
}

void main() {
  test('봇은 어떤 랜덤 상태에서도 유효한 수만 낸다(2000케이스)', () {
    final problems = <String>[];
    final rng = Random(7);
    outer:
    for (var g = 0; g < 2000; g++) {
      final n = 2 + rng.nextInt(5); // 2..6
      final chars = [for (var s = 0; s < n; s++) _pool[rng.nextInt(_pool.length)]];
      final alive = [for (var s = 0; s < n; s++) rng.nextBool() || s == 0];
      // 살아있는 좌석이 최소 2는 되게(봇 결정이 의미 있으려면).
      if (alive.where((a) => a).length < 2) {
        alive[0] = true;
        alive[1 % n] = true;
      }
      final ammo = [for (var s = 0; s < n; s++) rng.nextInt(kMaxAmmo + 1)];
      var state = PartyState.initial(chars);
      // 자원 상태도 약간 흔든다(저주·자원 소진 분기 커버).
      if (rng.nextBool()) {
        final cf = List<int>.from(state.curseFuse);
        for (var s = 0; s < n; s++) {
          if (rng.nextDouble() < 0.3) cf[s] = 1 + rng.nextInt(kCurseFuse);
        }
        state = PartyState(
          doctorUsed: state.doctorUsed,
          trapUsed: [for (var s = 0; s < n; s++) rng.nextBool()],
          smokeLeft: [for (var s = 0; s < n; s++) rng.nextInt(3)],
          reloads: state.reloads,
          paparazziUsed: state.paparazziUsed,
          resetterUsed: [for (var s = 0; s < n; s++) rng.nextBool()],
          curseFuse: cf,
          curseCaster: [for (var s = 0; s < n; s++) cf[s] > 0 ? 0 : -1],
        );
      }
      for (var seat = 0; seat < n; seat++) {
        if (!alive[seat]) continue;
        final ai = CpuAi(g * 31 + seat); // 시드 고정 재현성
        final m = ai.chooseMove(
          seat: seat,
          ammo: ammo,
          alive: alive,
          chars: chars,
          state: state,
        );
        final bad = invalidReason(m, seat, ammo, alive, chars[seat]);
        if (bad != null) {
          problems.add('g$g seat$seat ${chars[seat]} ammo=$ammo: $bad ($m)');
          continue outer;
        }
      }
    }
    expect(problems, isEmpty,
        reason: '봇이 불법 수를 냄:\n${problems.take(15).join("\n")}');
  });

  test('평화주의자 봇은 절대 공격하지 않는다(장전/방어만)', () {
    for (var i = 0; i < 300; i++) {
      final ai = CpuAi(i);
      final m = ai.chooseMove(
        seat: 0,
        ammo: [6, 6], // 총알이 가득해도
        alive: [true, true],
        chars: [CharId.pacifist, CharId.commoner],
        state: PartyState.initial([CharId.pacifist, CharId.commoner]),
      );
      expect(m.kind == ActKind.reload || m.kind == ActKind.defend, isTrue,
          reason: '평화주의자가 공격 수를 냄: $m');
    }
  });

  test('빈 총(0발)이면 빵야/슈퍼/더블을 내지 않는다', () {
    for (var i = 0; i < 300; i++) {
      final ai = CpuAi(i);
      final m = ai.chooseMove(
        seat: 0,
        ammo: [0, 3],
        alive: [true, true],
        chars: [CharId.commoner, CharId.commoner],
        state: PartyState.initial([CharId.commoner, CharId.commoner]),
      );
      expect(m.isShoot, isFalse, reason: '빈 총인데 빵야: $m');
      expect(m.kind, isNot(ActKind.dualShoot));
    }
  });

  test('봇끼리 풀 게임이 엔진과 모순 없이 끝까지 굴러간다', () {
    for (var g = 0; g < 40; g++) {
      final rng = Random(g + 100);
      final n = 2 + rng.nextInt(5);
      final chars = [for (var s = 0; s < n; s++) _pool[rng.nextInt(_pool.length)]];
      var ammo = [for (final c in chars) startAmmoFor(c)];
      var alive = List<bool>.filled(n, true);
      var state = PartyState.initial(chars);
      final ai = CpuAi(g);
      final seed = 'AIGAME$g';
      for (var t = 0; t < 200; t++) {
        final moves = [
          for (var s = 0; s < n; s++)
            alive[s]
                ? ai.chooseMove(
                    seat: s,
                    ammo: ammo,
                    alive: alive,
                    chars: chars,
                    state: state)
                : Move.empty
        ];
        final out = resolvePartyTurn(
          moves: moves,
          ammoBefore: ammo,
          aliveBefore: alive,
          chars: chars,
          state: state,
          seed: seed,
          turn: t,
        );
        // 죽은 자가 살아나지 않고, 총알 범위가 유지된다(엔진 기본 불변식).
        for (var s = 0; s < n; s++) {
          expect(out.aliveAfter[s] && !alive[s], isFalse,
              reason: 'g$g t$t 좌석 $s 부활');
          expect(out.ammoAfter[s] >= 0 && out.ammoAfter[s] <= kMaxAmmo, isTrue,
              reason: 'g$g t$t 좌석 $s 총알 범위 ${out.ammoAfter[s]}');
        }
        ammo = out.ammoAfter;
        alive = out.aliveAfter;
        state = out.stateAfter!;
        if (out.status != GameStatus.ongoing) break;
      }
    }
  });
}
