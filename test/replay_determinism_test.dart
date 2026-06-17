// 온라인 결정성 / 리플레이 안전성 속성 테스트.
//
// 온라인은 **모든 클라이언트가 같은 (방시드, 턴별 행동 히스토리)를 각자 독립으로
// 재계산**해 화면을 만든다. 따라서 룰엔진은:
//   ① 같은 입력이면 항상 같은 출력(순수·재현 가능),
//   ② 입력 리스트를 변형하지 않음(히스토리 재사용 안전),
//   ③ 전체 게임을 처음부터 다시 재생해도 동일한 상태 궤적,
//   ④ ??? 변신(effectiveChar/resolveMystery)도 시드로 결정적(클라 간 동일)
// 을 만족해야 한다. 하나라도 깨지면 클라이언트마다 다른 결과가 보인다.
import 'dart:math';

import 'package:cowboy_party/game/party_logic.dart';
import 'package:flutter_test/flutter_test.dart';

final List<CharId> _pool = CharId.values;

Move _move(Random rng, int n) {
  final t = rng.nextInt(n);
  final t2 = rng.nextInt(n);
  final smoke = rng.nextBool();
  switch (rng.nextInt(11)) {
    case 0:
      return Move.reload(smoke: smoke);
    case 1:
      return Move.defend(smoke: smoke);
    case 2:
      return Move.shoot(t, smoke: smoke);
    case 3:
      return Move.superShoot(t, smoke: smoke);
    case 4:
      return const Move.trap();
    case 5:
      return const Move.idle();
    case 6:
      return Move.roulette(t);
    case 7:
      return Move.dualShoot(t, t2);
    case 8:
      return Move.voodoo(t);
    case 9:
      return const Move.reset();
    default:
      return const Move.reload();
  }
}

/// TurnOutcome 전체를 문자열로 직렬화 — 한 글자라도 다르면 결정성 위반.
String _sig(TurnOutcome o) {
  final s = o.stateAfter!;
  return [
    'ammo=${o.ammoAfter}',
    'alive=${o.aliveAfter}',
    'fired=${o.fired}',
    'super=${o.superFired}',
    'ft=${o.firedTarget}',
    'hit=${o.hit}',
    'status=${o.status}',
    'winner=${o.winner}',
    'healed=${o.healed}',
    'trapSet=${o.trapSet}',
    'reflect=${o.reflectKill}',
    'evaded=${o.evaded}',
    'pierced=${o.pierced}',
    'smoked=${o.smoked}',
    'dbl=${o.doubleLoad}',
    'roul=${o.rouletteFired}',
    'roulSelf=${o.rouletteSelf}',
    'dual=${o.dualFired}',
    'dt2=${o.dualTarget2}',
    'voodoo=${o.voodooCast}',
    'curseKill=${o.curseKill}',
    'reset=${o.resetActive}',
    'special=${o.specialWin}',
    'st.doctor=${s.doctorUsed}',
    'st.trap=${s.trapUsed}',
    'st.smoke=${s.smokeLeft}',
    'st.reloads=${s.reloads}',
    'st.papa=${s.paparazziUsed}',
    'st.reset=${s.resetterUsed}',
    'st.fuse=${s.curseFuse}',
    'st.caster=${s.curseCaster}',
  ].join('|');
}

/// 결정적 게임 1판을 끝까지 돌리며 매 턴 시그니처를 모은다(클라이언트 1대 분량).
List<String> _playTrajectory(int g, {int maxTurns = 100}) {
  final rng = Random(g + 1);
  final n = 2 + rng.nextInt(kMaxSeats - kMinSeats + 1);
  final seed = 'NET$g';
  final chars = [
    for (var s = 0; s < n; s++)
        effectiveChar(_pool[rng.nextInt(_pool.length)], seed, s)
  ];
  var state = PartyState.initial(chars);
  var ammo = [for (final c in chars) startAmmoFor(c)];
  var alive = List<bool>.filled(n, true);
  final trajectory = <String>[];
  for (var t = 0; t < maxTurns; t++) {
    final moves = [
      for (var s = 0; s < n; s++) alive[s] ? _move(rng, n) : Move.empty
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
    trajectory.add(_sig(out));
    state = out.stateAfter!;
    ammo = out.ammoAfter;
    alive = out.aliveAfter;
    if (out.status != GameStatus.ongoing) break;
  }
  return trajectory;
}

void main() {
  test('① 같은 입력 → 같은 출력(턴 재계산 재현성)', () {
    for (var g = 0; g < 800; g++) {
      final rng = Random(g + 7);
      final n = 2 + rng.nextInt(kMaxSeats - kMinSeats + 1);
      final seed = 'REP$g';
      final chars = [
        for (var s = 0; s < n; s++)
            effectiveChar(_pool[rng.nextInt(_pool.length)], seed, s)
      ];
      final state = PartyState.initial(chars);
      final ammo = [for (final c in chars) startAmmoFor(c)];
      final alive = List<bool>.filled(n, true);
      final moves = [for (var s = 0; s < n; s++) _move(rng, n)];
      // 두 "클라이언트"가 동일 입력(독립 복사본)으로 각자 계산.
      final a = resolvePartyTurn(
        moves: List.of(moves),
        ammoBefore: List.of(ammo),
        aliveBefore: List.of(alive),
        chars: List.of(chars),
        state: state,
        seed: seed,
        turn: 0,
      );
      final b = resolvePartyTurn(
        moves: List.of(moves),
        ammoBefore: List.of(ammo),
        aliveBefore: List.of(alive),
        chars: List.of(chars),
        state: state,
        seed: seed,
        turn: 0,
      );
      expect(_sig(a), _sig(b), reason: 'game $g: 두 계산 불일치(비결정성)');
    }
  });

  test('② resolvePartyTurn은 입력 리스트를 변형하지 않는다(히스토리 재사용 안전)', () {
    for (var g = 0; g < 800; g++) {
      final rng = Random(g + 11);
      final n = 2 + rng.nextInt(kMaxSeats - kMinSeats + 1);
      final seed = 'IMM$g';
      final chars = [
        for (var s = 0; s < n; s++)
            effectiveChar(_pool[rng.nextInt(_pool.length)], seed, s)
      ];
      final state = PartyState(
        doctorUsed: List.filled(n, false),
        trapUsed: List.filled(n, false),
        smokeLeft: [for (final c in chars) c == CharId.smoker ? 2 : 0],
        reloads: List.filled(n, 0),
        paparazziUsed: List.filled(n, false),
        resetterUsed: List.filled(n, false),
        curseFuse: List.filled(n, 0),
        curseCaster: List.filled(n, -1),
      );
      final ammo = [for (var s = 0; s < n; s++) rng.nextInt(kMaxAmmo + 1)];
      final alive = [for (var s = 0; s < n; s++) rng.nextBool() || s == 0];
      final moves = [for (var s = 0; s < n; s++) _move(rng, n)];
      // 입력 스냅샷.
      final ammoCopy = List.of(ammo);
      final aliveCopy = List.of(alive);
      final movesCopy = List.of(moves);
      final fuseCopy = List.of(state.curseFuse);
      final smokeCopy = List.of(state.smokeLeft);

      resolvePartyTurn(
        moves: moves,
        ammoBefore: ammo,
        aliveBefore: alive,
        chars: chars,
        state: state,
        seed: seed,
        turn: 3,
      );

      expect(ammo, ammoCopy, reason: 'game $g: ammoBefore가 변형됨');
      expect(alive, aliveCopy, reason: 'game $g: aliveBefore가 변형됨');
      expect(moves, movesCopy, reason: 'game $g: moves가 변형됨');
      expect(state.curseFuse, fuseCopy, reason: 'game $g: state.curseFuse 변형됨');
      expect(state.smokeLeft, smokeCopy, reason: 'game $g: state.smokeLeft 변형됨');
    }
  });

  test('③ 전체 게임을 다시 재생해도 상태 궤적이 동일하다(리플레이 안전)', () {
    for (var g = 0; g < 600; g++) {
      // 같은 시드 g로 두 번 독립 재생(서로 다른 클라이언트가 같은 히스토리를
      // 처음부터 재계산하는 상황) → 궤적이 글자 단위로 같아야 한다.
      final first = _playTrajectory(g);
      final second = _playTrajectory(g);
      expect(second, equals(first), reason: 'game $g: 재생 궤적 불일치');
    }
  });

  test('④ ??? 변신은 시드로 결정적 — 클라이언트 간 동일 라인업', () {
    for (var seat = 0; seat < kMaxSeats; seat++) {
      for (var game = 0; game < 50; game++) {
        final seed = 'ROOM-abc#$game';
        final a = effectiveChar(CharId.mystery, seed, seat);
        final b = effectiveChar(CharId.mystery, seed, seat);
        expect(a, b, reason: 'seed=$seed seat=$seat: mystery 변신 불일치');
        expect(a, isNot(CharId.mystery));
        expect(kMysteryPool.contains(a), isTrue);
      }
    }
    // 같은 게임에서 좌석이 다르면 (대부분) 서로 다른 직업이 나올 수 있고,
    // 게임이 다르면 같은 좌석도 직업이 바뀐다 — 결정성은 (seed,seat) 쌍에 묶임.
    expect(effectiveChar(CharId.mystery, 'ROOM-abc#0', 0),
        effectiveChar(CharId.mystery, 'ROOM-abc#0', 0));
  });
}
