/// Core, UI-independent rules for **Cowboy Party** — the 2-to-6 player
/// generalisation of Cowboy Duel.
///
/// 2 to 6 cowboys sit in a circle. Every turn each living cowboy commits a
/// **single action**:
///   - 장전 (reload): load one bullet (max [kMaxAmmo]).
///   - 방어 (defend): block **every** shot aimed at you this turn, no matter how
///     many cowboys fire at you.
///   - 빵야 (shoot):  fire one bullet at **any** other living cowboy you pick.
///
/// Rules:
///   * Shooting needs at least one bullet and consumes exactly one. A bullet can
///     only come from ammo loaded on a **previous** turn, so on turn 1 (everyone
///     at 0 ammo) no shot is possible.
///   * Every cowboy reveals simultaneously, then the turn resolves.
///   * One undefended hit eliminates a cowboy outright. Several can fall on the
///     same turn. The last cowboy standing wins; if everyone left dies together
///     it's a draw.
///
/// Seats are fixed for the whole game: an eliminated cowboy's seat just stays
/// empty so the circle never re-shuffles.
library;

/// The kind of an action a cowboy can take in a turn.
///
/// [superShoot] only unlocks at full ammo: once you can no longer reload, the
/// reload slot becomes a 슈퍼빵야 — it costs [kSuperCost] bullets and is an
/// unstoppable kill that even pierces a defender. It's the counter to an
/// endless-defend stalemate.
enum ActKind { reload, defend, shoot, superShoot }

extension ActKindLabel on ActKind {
  String get ko {
    switch (this) {
      case ActKind.reload:
        return '장전';
      case ActKind.defend:
        return '방어';
      case ActKind.shoot:
        return '빵야';
      case ActKind.superShoot:
        return '슈퍼빵야';
    }
  }
}

/// Maximum bullets a cowboy can stockpile.
const int kMaxAmmo = 6;

/// Bullets a 슈퍼빵야 consumes (and the floor at which it becomes available).
const int kSuperCost = 5;

/// Allowed table sizes.
const int kMinSeats = 2;
const int kMaxSeats = 6;

/// One cowboy's full commitment for a turn: a single action, plus a target seat
/// when (and only when) the action is [ActKind.shoot].
class Move {
  final ActKind kind;

  /// Seat index being shot at, or -1 for reload/defend.
  final int target;

  const Move._(this.kind, this.target);

  const Move.reload() : this._(ActKind.reload, -1);
  const Move.defend() : this._(ActKind.defend, -1);
  const Move.shoot(int target) : this._(ActKind.shoot, target);
  const Move.superShoot(int target) : this._(ActKind.superShoot, target);

  static const Move empty = Move._(ActKind.reload, -1);

  bool get isShoot => kind == ActKind.shoot || kind == ActKind.superShoot;
  bool get needsTarget => isShoot;

  /// Compact integer encoding for Firebase: 0 = reload, 1 = defend,
  /// 2 + target = shoot (2..7), 8 + target = 슈퍼빵야 (8..13).
  int encode() {
    switch (kind) {
      case ActKind.reload:
        return 0;
      case ActKind.defend:
        return 1;
      case ActKind.shoot:
        return 2 + target;
      case ActKind.superShoot:
        return 8 + target;
    }
  }

  static Move decode(int c) {
    if (c <= 0) return const Move.reload();
    if (c == 1) return const Move.defend();
    if (c < 8) return Move.shoot(c - 2);
    return Move.superShoot(c - 8);
  }

  @override
  bool operator ==(Object other) =>
      other is Move && other.kind == kind && other.target == target;

  @override
  int get hashCode => encode();
}

/// The high-level state of the game after a turn resolves.
enum GameStatus { ongoing, won, draw }

/// Immutable result of resolving one simultaneous turn for every seat.
class TurnOutcome {
  final List<int> ammoAfter; // length == seats
  final List<bool> aliveAfter; // length == seats
  final List<bool> fired; // seat fired a live shot this turn (normal or super)
  final List<bool> superFired; // the shot was a 슈퍼빵야
  final List<int> firedTarget; // seat it fired at (-1 if none)
  final List<bool> hit; // seat took a clean hit (newly eliminated)
  final GameStatus status;

  /// Winning seat when [status] == [GameStatus.won], else null.
  final int? winner;

  const TurnOutcome({
    required this.ammoAfter,
    required this.aliveAfter,
    required this.fired,
    required this.superFired,
    required this.firedTarget,
    required this.hit,
    required this.status,
    required this.winner,
  });
}

/// Pure resolution of a single simultaneous turn for an arbitrary number of
/// seats. [moves], [ammoBefore] and [aliveBefore] all share the same length.
/// Moves for dead seats are ignored. A shot only leaves the barrel if the
/// shooter had ammo *before* this turn and the chosen target is a living seat;
/// reloads chosen this turn arm the next turn, never this one.
TurnOutcome resolveTurn(
  List<Move> moves,
  List<int> ammoBefore,
  List<bool> aliveBefore,
) {
  final n = moves.length;
  assert(ammoBefore.length == n && aliveBefore.length == n);

  final fired = List<bool>.filled(n, false);
  final superFired = List<bool>.filled(n, false);
  final firedTarget = List<int>.filled(n, -1);
  final spent = List<int>.filled(n, 0);

  // Decide which shots actually fire. A 슈퍼빵야 needs [kSuperCost] bullets and
  // pierces defence; a normal 빵야 needs one and can be defended.
  for (var i = 0; i < n; i++) {
    if (!aliveBefore[i]) continue;
    final m = moves[i];
    final targetOk =
        m.target >= 0 && m.target < n && m.target != i && aliveBefore[m.target];
    if (m.kind == ActKind.superShoot && ammoBefore[i] >= kSuperCost && targetOk) {
      fired[i] = true;
      superFired[i] = true;
      firedTarget[i] = m.target;
      spent[i] = kSuperCost;
    } else if (m.kind == ActKind.shoot && ammoBefore[i] > 0 && targetOk) {
      fired[i] = true;
      firedTarget[i] = m.target;
      spent[i] = 1;
    }
  }

  // Work out hits. Defence blocks every *normal* incoming shot but is useless
  // against a 슈퍼빵야, which always kills its target.
  final hit = List<bool>.filled(n, false);
  for (var t = 0; t < n; t++) {
    if (!aliveBefore[t]) continue;
    final defending = moves[t].kind == ActKind.defend;
    var superHit = false;
    var normalIncoming = 0;
    for (var i = 0; i < n; i++) {
      if (!fired[i] || firedTarget[i] != t) continue;
      if (superFired[i]) {
        superHit = true;
      } else {
        normalIncoming++;
      }
    }
    if (superHit || (normalIncoming > 0 && !defending)) hit[t] = true;
  }

  final ammoAfter = List<int>.filled(n, 0);
  final aliveAfter = List<bool>.from(aliveBefore);
  for (var i = 0; i < n; i++) {
    if (!aliveBefore[i]) {
      ammoAfter[i] = ammoBefore[i];
      continue;
    }
    var a = ammoBefore[i] - spent[i];
    if (moves[i].kind == ActKind.reload) a += 1;
    if (a > kMaxAmmo) a = kMaxAmmo;
    if (a < 0) a = 0;
    ammoAfter[i] = a;
    if (hit[i]) aliveAfter[i] = false;
  }

  final survivors = <int>[
    for (var i = 0; i < n; i++)
      if (aliveAfter[i]) i
  ];
  final GameStatus status;
  int? winner;
  if (survivors.length >= 2) {
    status = GameStatus.ongoing;
  } else if (survivors.length == 1) {
    status = GameStatus.won;
    winner = survivors.first;
  } else {
    status = GameStatus.draw;
  }

  return TurnOutcome(
    ammoAfter: ammoAfter,
    aliveAfter: aliveAfter,
    fired: fired,
    superFired: superFired,
    firedTarget: firedTarget,
    hit: hit,
    status: status,
    winner: winner,
  );
}
