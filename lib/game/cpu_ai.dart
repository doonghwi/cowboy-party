import 'dart:math';

import 'party_logic.dart';

/// A light, slightly randomised opponent for the offline "컴퓨터와 대결" mode,
/// generalised from the Cowboy Duel heuristic to any number of seats.
///
/// The bot can see everyone's ammo (it's a casual single-player aid, not a
/// ranked AI). It builds up when empty, picks off armed rivals when loaded, and
/// occasionally turtles so it never feels fully predictable.
class CpuAi {
  final Random _r;
  CpuAi([int? seed]) : _r = seed == null ? Random() : Random(seed);

  /// Choose a complete [Move] for [seat] given the whole table's state.
  /// [chars]/[state]를 주면 캐릭터 능력(덫·연막·평화주의자)을 살려서 둔다.
  Move chooseMove({
    required int seat,
    required List<int> ammo,
    required List<bool> alive,
    List<CharId>? chars,
    PartyState? state,
  }) {
    final n = ammo.length;
    final myAmmo = ammo[seat];
    final myChar = (chars != null && seat < chars.length)
        ? chars[seat]
        : CharId.none;

    final rivals = <int>[
      for (var i = 0; i < n; i++)
        if (i != seat && alive[i]) i
    ];
    if (rivals.isEmpty) return const Move.reload();

    // Living rivals that could shoot me this turn.
    final threats = [for (final r in rivals) if (ammo[r] > 0) r];

    // 평화주의자 봇: 쏠 수 없다 — 장전으로 6회 승리를 노리고, 위협이 크면 방어.
    if (myChar == CharId.pacifist) {
      if (threats.length >= 2 && _r.nextDouble() < 0.55) {
        return const Move.defend();
      }
      if (threats.isNotEmpty && _r.nextDouble() < 0.3) {
        return const Move.defend();
      }
      return const Move.reload();
    }

    // 사냥꾼 봇: 위협받을 때 가끔 덫 (게임당 1회).
    if (myChar == CharId.hunter &&
        state != null &&
        !state.trapUsed[seat] &&
        threats.isNotEmpty &&
        _r.nextDouble() < 0.30) {
      return const Move.trap();
    }

    // 리셋터 봇: 위협이 클 때(무장 라이벌 2명+) 가끔 '무효'로 판을 지운다(게임당 1회).
    if (myChar == CharId.resetter &&
        state != null &&
        !state.resetterUsed[seat] &&
        threats.length >= 2 &&
        _r.nextDouble() < 0.35) {
      return const Move.reset();
    }

    // 스모커 봇: 위협받으면 가끔 연막을 행동에 얹는다.
    Move smoke(Move m) {
      if (myChar == CharId.smoker &&
          state != null &&
          state.smokeLeft[seat] > 0 &&
          threats.isNotEmpty &&
          _r.nextDouble() < 0.45) {
        return m.withSmoke(true);
      }
      return m;
    }

    // 부두술사 봇: 활성 저주가 없고 라이벌이 있으면 가끔 저주를 건다.
    if (myChar == CharId.voodoo &&
        state != null &&
        state.curseFuse == 0 &&
        rivals.isNotEmpty &&
        _r.nextDouble() < 0.35) {
      return Move.voodoo(_pickTarget(threats.isNotEmpty ? threats : rivals, ammo));
    }

    // 쌍권총 봇: 총알 2발+ 라이벌 2명+ 이면 가끔 두 명을 동시에 노린다.
    if (myChar == CharId.dualgun &&
        myAmmo >= 2 &&
        rivals.length >= 2 &&
        _r.nextDouble() < 0.5) {
      final pool = threats.length >= 2 ? threats : rivals;
      final t1 = _pickTarget(pool, ammo);
      final rest = [for (final r in rivals) if (r != t1) r];
      return Move.dualShoot(t1, _pickTarget(rest, ammo));
    }

    // 러시안룰렛 봇: 총알이 없을 때 도박으로, 평소엔 가끔 운명의 방아쇠.
    if (myChar == CharId.roulette && rivals.isNotEmpty) {
      final p = myAmmo == 0 ? 0.45 : 0.18;
      if (_r.nextDouble() < p) {
        return Move.roulette(
            _pickTarget(threats.isNotEmpty ? threats : rivals, ammo));
      }
    }

    // Full magazine → the reload slot is a 슈퍼빵야. Mostly use it (it pierces
    // defence), preferring the most armed rival; sometimes hold for a normal play.
    if (myAmmo >= kMaxAmmo && _r.nextDouble() < 0.8) {
      final pool = threats.isNotEmpty ? threats : rivals;
      return smoke(Move.superShoot(_pickTarget(pool, ammo)));
    }

    // Empty gun → can't shoot. Mostly reload, but raise a shield under heavy
    // threat so it isn't a sitting duck.
    if (myAmmo == 0) {
      if (threats.length >= 2 && _r.nextDouble() < 0.45) {
        return smoke(const Move.defend());
      }
      if (threats.isNotEmpty && _r.nextDouble() < 0.25) {
        return smoke(const Move.defend());
      }
      return smoke(const Move.reload());
    }

    // Occasionally turtle when menaced, even while armed.
    if (threats.isNotEmpty) {
      final guardChance = threats.length >= 2 ? 0.35 : 0.20;
      if (_r.nextDouble() < guardChance) return smoke(const Move.defend());
    }

    // Sometimes top up the magazine instead of firing.
    if (_r.nextDouble() < 0.18) return smoke(const Move.reload());

    // Otherwise shoot: prefer an armed rival (neutralise a threat); else pick
    // any living rival.
    final pool = threats.isNotEmpty ? threats : rivals;
    return smoke(Move.shoot(_pickTarget(pool, ammo)));
  }

  int _pickTarget(List<int> pool, List<int> ammo) {
    // 60% of the time go for the rival with the most bullets, else random.
    if (_r.nextDouble() < 0.6) {
      var best = pool.first;
      for (final p in pool) {
        if (ammo[p] > ammo[best]) best = p;
      }
      return best;
    }
    return pool[_r.nextInt(pool.length)];
  }
}
