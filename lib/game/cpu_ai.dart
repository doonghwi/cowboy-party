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
  Move chooseMove({
    required int seat,
    required List<int> ammo,
    required List<bool> alive,
  }) {
    final n = ammo.length;
    final myAmmo = ammo[seat];

    final rivals = <int>[
      for (var i = 0; i < n; i++)
        if (i != seat && alive[i]) i
    ];
    if (rivals.isEmpty) return const Move.reload();

    // Living rivals that could shoot me this turn.
    final threats = [for (final r in rivals) if (ammo[r] > 0) r];

    // Full magazine → the reload slot is a 슈퍼빵야. Mostly use it (it pierces
    // defence), preferring the most armed rival; sometimes hold for a normal play.
    if (myAmmo >= kMaxAmmo && _r.nextDouble() < 0.8) {
      final pool = threats.isNotEmpty ? threats : rivals;
      return Move.superShoot(_pickTarget(pool, ammo));
    }

    // Empty gun → can't shoot. Mostly reload, but raise a shield under heavy
    // threat so it isn't a sitting duck.
    if (myAmmo == 0) {
      if (threats.length >= 2 && _r.nextDouble() < 0.45) {
        return const Move.defend();
      }
      if (threats.isNotEmpty && _r.nextDouble() < 0.25) {
        return const Move.defend();
      }
      return const Move.reload();
    }

    // Occasionally turtle when menaced, even while armed.
    if (threats.isNotEmpty) {
      final guardChance = threats.length >= 2 ? 0.35 : 0.20;
      if (_r.nextDouble() < guardChance) return const Move.defend();
    }

    // Sometimes top up the magazine instead of firing.
    if (_r.nextDouble() < 0.18) return const Move.reload();

    // Otherwise shoot: prefer an armed rival (neutralise a threat); else pick
    // any living rival.
    final pool = threats.isNotEmpty ? threats : rivals;
    return Move.shoot(_pickTarget(pool, ammo));
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
