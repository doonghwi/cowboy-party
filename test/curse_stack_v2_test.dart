// 저주 규칙 v2(2026-07-16 사용자 결정, kLogicVersion 2): 시전자별 독립 스택.
// - 서로 다른 부두는 같은 대상에게 각자 저주 가능(각 kCurseFuse턴 독립).
// - 같은 시전자의 재시전은 무효(도화선 리셋 악용 방지 — v1 규칙 계승).
// - 시전자가 죽으면 "그 시전자의 저주만" 해제, 다른 저주는 유지.
import 'package:cowboy_party/game/party_logic.dart';
import 'package:flutter_test/flutter_test.dart';

class _Game {
  final List<CharId> chars;
  static const seed = 'CURSE2';
  List<int> ammo;
  List<bool> alive;
  PartyState state;
  int turn = 0;

  _Game(this.chars)
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
  group('저주 v2 — 시전자별 스택', () {
    test('두 부두가 같은 대상에게 → 저주 2개가 각자 도화선으로 쌓인다', () {
      // 0,1=부두, 2=대상, 3=들러리(전멸 방지).
      final g = _Game(
          [CharId.voodoo, CharId.voodoo, CharId.commoner, CharId.commoner]);
      final out = g.step([
        const Move.voodoo(2),
        const Move.voodoo(2),
        const Move.idle(),
        const Move.idle(),
      ]);
      expect(out.voodooCast[0], isTrue);
      expect(out.voodooCast[1], isTrue, reason: 'v2: 두 번째 부두도 시전 성공');
      final curses = g.state.cursesOn(2);
      expect(curses.length, 2, reason: '같은 대상에 저주 2개 공존');
      expect(curses.map((c) => c.$1).toSet(), {0, 1});
      expect(curses.every((c) => c.$2 == kCurseFuse), isTrue,
          reason: '각자 온전한 도화선 $kCurseFuse턴');
    });

    test('시차 시전 → 도화선이 각자 독립적으로 줄어든다', () {
      final g = _Game(
          [CharId.voodoo, CharId.voodoo, CharId.commoner, CharId.commoner]);
      g.step([
        const Move.voodoo(2),
        const Move.idle(),
        const Move.idle(),
        const Move.idle(),
      ]);
      // 두 턴 뒤 두 번째 부두가 시전.
      g.step([
        const Move.idle(),
        const Move.idle(),
        const Move.idle(),
        const Move.idle(),
      ]);
      g.step([
        const Move.idle(),
        const Move.voodoo(2),
        const Move.idle(),
        const Move.idle(),
      ]);
      final byCaster = {for (final c in g.state.cursesOn(2)) c.$1: c.$2};
      expect(byCaster[0], kCurseFuse - 2, reason: '먼저 건 저주는 2턴 진행');
      expect(byCaster[1], kCurseFuse, reason: '늦게 건 저주는 갓 시작');
    });

    test('같은 시전자 재시전은 무효(도화선 유지), 다른 시전자는 허용', () {
      final g = _Game(
          [CharId.voodoo, CharId.voodoo, CharId.commoner, CharId.commoner]);
      g.step([
        const Move.voodoo(2),
        const Move.idle(),
        const Move.idle(),
        const Move.idle(),
      ]);
      final out = g.step([
        const Move.voodoo(2), // 재시전 → 무효
        const Move.voodoo(2), // 신규 → 유효
        const Move.idle(),
        const Move.idle(),
      ]);
      expect(out.voodooCast[0], isFalse, reason: '같은 시전자 재시전 무효(v1 계승)');
      expect(out.voodooCast[1], isTrue);
      final byCaster = {for (final c in g.state.cursesOn(2)) c.$1: c.$2};
      expect(byCaster[0], lessThan(kCurseFuse), reason: '기존 도화선 리셋 안 됨');
      expect(byCaster[1], kCurseFuse);
    });

    test('시전자 사망 → 그 시전자의 저주만 해제, 다른 저주는 유지', () {
      // 0,1=부두, 2=대상, 3=처형자.
      final g = _Game(
          [CharId.voodoo, CharId.voodoo, CharId.commoner, CharId.commoner]);
      g.step([
        const Move.voodoo(2),
        const Move.voodoo(2),
        const Move.idle(),
        const Move.reload(),
      ]);
      final out = g.step([
        const Move.idle(),
        const Move.idle(),
        const Move.idle(),
        const Move.shoot(0), // 부두0 사살
      ]);
      expect(out.aliveAfter[0], isFalse);
      final byCaster = {for (final c in g.state.cursesOn(2)) c.$1: c.$2};
      expect(byCaster.containsKey(0), isFalse, reason: '죽은 시전자 저주 해제');
      expect(byCaster.containsKey(1), isTrue, reason: '산 시전자 저주 유지');
    });

    test('도화선 만료 시 사망(curseKill) — 스택돼도 가장 이른 것 기준', () {
      final g = _Game(
          [CharId.voodoo, CharId.voodoo, CharId.commoner, CharId.commoner]);
      g.step([
        const Move.voodoo(2),
        const Move.voodoo(2),
        const Move.idle(),
        const Move.idle(),
      ]);
      var died = false;
      for (var t = 0; t < kCurseFuse + 2 && !died; t++) {
        final out = g.step([
          const Move.idle(),
          const Move.idle(),
          g.alive[2] ? const Move.idle() : Move.empty,
          const Move.idle(),
        ]);
        if (out.curseKill[2]) {
          died = true;
          expect(out.aliveAfter[2], isFalse);
        }
      }
      expect(died, isTrue, reason: '저주가 끝내 발동해야 함');
    });
  });
}
