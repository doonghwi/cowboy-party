/// Core, UI-independent rules for **Cowboy Party** — the 2-to-6 player
/// generalisation of Cowboy Duel, extended with 8 selectable characters.
///
/// 2 to 6 cowboys sit in a circle. Every turn each living cowboy commits a
/// **single action**:
///   - 장전 (reload): load one bullet (max [kMaxAmmo]).
///   - 방어 (defend): block **every** shot aimed at you this turn.
///   - 빵야 (shoot):  fire one bullet at any other living cowboy.
///   - 슈퍼빵야 (superShoot): at full ammo, an unstoppable piercing kill.
///   - 덫 (trap, 사냥꾼 전용): reflect every normal shot back at the shooter.
///
/// Characters bend exactly one rule each (see characters.dart). All character
/// randomness uses [seededRoll] so every client replays identical outcomes.
library;

import 'characters.dart';

export 'characters.dart'
    show CharId, CharDef, charDef, charFromIndex, kCharacters, seededRoll;

/// The kind of an action a cowboy can take in a turn.
enum ActKind { reload, defend, shoot, superShoot, trap }

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
      case ActKind.trap:
        return '덫';
    }
  }
}

/// Maximum bullets a cowboy can stockpile.
const int kMaxAmmo = 6;

/// Bullets a 슈퍼빵야 consumes (and the floor at which it becomes available).
const int kSuperCost = 5;

/// Successful reloads a 평화주의자 needs for an instant win.
const int kPacifistGoal = 6;

/// Allowed table sizes.
const int kMinSeats = 2;
const int kMaxSeats = 6;

/// One cowboy's full commitment for a turn: a single action, a target seat for
/// shots, plus the 스모커's optional smoke modifier that rides along any action.
class Move {
  final ActKind kind;

  /// Seat index being shot at, or -1 for non-shots.
  final int target;

  /// 스모커 전용: this turn is smoked (50% evasion), stacked on the action.
  final bool smoke;

  const Move._(this.kind, this.target, [this.smoke = false]);

  const Move.reload({bool smoke = false}) : this._(ActKind.reload, -1, smoke);
  const Move.defend({bool smoke = false}) : this._(ActKind.defend, -1, smoke);
  const Move.shoot(int target, {bool smoke = false})
      : this._(ActKind.shoot, target, smoke);
  const Move.superShoot(int target, {bool smoke = false})
      : this._(ActKind.superShoot, target, smoke);
  const Move.trap() : this._(ActKind.trap, -1, false);

  static const Move empty = Move._(ActKind.reload, -1);

  bool get isShoot => kind == ActKind.shoot || kind == ActKind.superShoot;
  bool get needsTarget => isShoot;

  Move withSmoke(bool s) => Move._(kind, target, s);

  /// Compact integer encoding for Firebase:
  /// 0 = reload, 1 = defend, 2+target = shoot (2..7), 8+target = 슈퍼 (8..13),
  /// 14 = 덫. +16 = 연막 비트(행동과 병행). Old clients' codes decode unchanged.
  int encode() {
    final base = switch (kind) {
      ActKind.reload => 0,
      ActKind.defend => 1,
      ActKind.shoot => 2 + target,
      ActKind.superShoot => 8 + target,
      ActKind.trap => 14,
    };
    return base + (smoke ? 16 : 0);
  }

  static Move decode(int c) {
    final smoke = c >= 16;
    final b = smoke ? c - 16 : c;
    if (b <= 0) return Move._(ActKind.reload, -1, smoke);
    if (b == 1) return Move._(ActKind.defend, -1, smoke);
    if (b < 8) return Move._(ActKind.shoot, b - 2, smoke);
    if (b < 14) return Move._(ActKind.superShoot, b - 8, smoke);
    return const Move.trap();
  }

  @override
  bool operator ==(Object other) =>
      other is Move &&
      other.kind == kind &&
      other.target == target &&
      other.smoke == smoke;

  @override
  int get hashCode => encode();
}

/// The high-level state of the game after a turn resolves.
enum GameStatus { ongoing, won, draw }

/// Per-seat character resources, threaded turn to turn through the replay.
class PartyState {
  final List<bool> doctorUsed;
  final List<bool> trapUsed;
  final List<int> smokeLeft;
  final List<int> reloads; // 평화주의자의 성공한 장전 누적

  const PartyState({
    required this.doctorUsed,
    required this.trapUsed,
    required this.smokeLeft,
    required this.reloads,
  });

  factory PartyState.initial(List<CharId> chars) => PartyState(
        doctorUsed: List.filled(chars.length, false),
        trapUsed: List.filled(chars.length, false),
        smokeLeft: [
          for (final c in chars) c == CharId.smoker ? 2 : 0
        ],
        reloads: List.filled(chars.length, 0),
      );
}

/// Starting ammo for a seat given its character (준비자 = 1).
int startAmmoFor(CharId c) => c == CharId.prepper ? 1 : 0;

/// Immutable result of resolving one simultaneous turn for every seat.
class TurnOutcome {
  final List<int> ammoAfter;
  final List<bool> aliveAfter;
  final List<bool> fired; // fired a live shot this turn (normal or super)
  final List<bool> superFired;
  final List<int> firedTarget; // -1 if none
  final List<bool> hit; // newly eliminated this turn
  final GameStatus status;
  final int? winner;

  // Character-ability display flags (all empty/false when no characters).
  final List<bool> healed; // 의사가 이 턴 치명상을 버팀
  final List<bool> trapSet; // 이 턴 덫을 깔았음
  final List<bool> reflectKill; // 덫 반사로 사망
  final List<bool> evaded; // 연막으로 공격을 전부 회피함
  final List<bool> pierced; // 스나이퍼 관통 발동
  final List<bool> smoked; // 이 턴 연막 사용
  final List<bool> doubleLoad; // 스피드로더 +2 발동
  final PartyState? stateAfter;
  final String? specialWin; // 'duelist' | 'pacifist' | null

  const TurnOutcome({
    required this.ammoAfter,
    required this.aliveAfter,
    required this.fired,
    required this.superFired,
    required this.firedTarget,
    required this.hit,
    required this.status,
    required this.winner,
    this.healed = const [],
    this.trapSet = const [],
    this.reflectKill = const [],
    this.evaded = const [],
    this.pierced = const [],
    this.smoked = const [],
    this.doubleLoad = const [],
    this.stateAfter,
    this.specialWin,
  });
}

/// Legacy character-free resolution (kept for old tests/UI paths): everyone is
/// [CharId.none], so it behaves exactly like the original rules.
TurnOutcome resolveTurn(
  List<Move> moves,
  List<int> ammoBefore,
  List<bool> aliveBefore,
) {
  final n = moves.length;
  final chars = List<CharId>.filled(n, CharId.none);
  return resolvePartyTurn(
    moves: moves,
    ammoBefore: ammoBefore,
    aliveBefore: aliveBefore,
    chars: chars,
    state: PartyState.initial(chars),
    seed: '',
    turn: 0,
  );
}

/// Full resolution of a simultaneous turn with character abilities.
///
/// [seed] is a per-game string (room code + game number) and [turn] the turn
/// index — together they key every probability roll so all clients agree.
TurnOutcome resolvePartyTurn({
  required List<Move> moves,
  required List<int> ammoBefore,
  required List<bool> aliveBefore,
  required List<CharId> chars,
  required PartyState state,
  required String seed,
  required int turn,
}) {
  final n = moves.length;
  assert(ammoBefore.length == n && aliveBefore.length == n);
  assert(chars.length == n);

  double roll(int seat, String salt) => seededRoll('$seed|$turn|$seat|$salt');

  final doctorUsed = List<bool>.from(state.doctorUsed);
  final trapUsed = List<bool>.from(state.trapUsed);
  final smokeLeft = List<int>.from(state.smokeLeft);
  final reloads = List<int>.from(state.reloads);

  final fired = List<bool>.filled(n, false);
  final superFired = List<bool>.filled(n, false);
  final firedTarget = List<int>.filled(n, -1);
  final spent = List<int>.filled(n, 0);
  final pierced = List<bool>.filled(n, false);
  final trapSet = List<bool>.filled(n, false);
  final smoked = List<bool>.filled(n, false);
  final doubleLoad = List<bool>.filled(n, false);

  // 0) Modifiers that precede shots: 덫, 연막.
  for (var i = 0; i < n; i++) {
    if (!aliveBefore[i]) continue;
    final m = moves[i];
    if (m.kind == ActKind.trap &&
        chars[i] == CharId.hunter &&
        !trapUsed[i]) {
      trapSet[i] = true;
      trapUsed[i] = true;
    }
    if (m.smoke && chars[i] == CharId.smoker && smokeLeft[i] > 0) {
      smoked[i] = true;
      smokeLeft[i]--;
    }
  }

  // 1) Which shots actually leave the barrel. 평화주의자 cannot shoot at all.
  for (var i = 0; i < n; i++) {
    if (!aliveBefore[i] || chars[i] == CharId.pacifist) continue;
    final m = moves[i];
    final targetOk =
        m.target >= 0 && m.target < n && m.target != i && aliveBefore[m.target];
    if (m.kind == ActKind.superShoot &&
        ammoBefore[i] >= kSuperCost &&
        targetOk) {
      fired[i] = true;
      superFired[i] = true;
      firedTarget[i] = m.target;
      spent[i] = kSuperCost;
    } else if (m.kind == ActKind.shoot && ammoBefore[i] > 0 && targetOk) {
      fired[i] = true;
      firedTarget[i] = m.target;
      spent[i] = 1;
      // 스나이퍼: 10% 확률로 이 한 발이 방어를 무시한다.
      if (chars[i] == CharId.sniper && roll(i, 'pierce') < 0.10) {
        pierced[i] = true;
      }
    }
  }

  // 2) Hits. Defence blocks normal (non-pierced) shots. 덫 reflects normal
  // shots back at the shooter (the hunter takes no damage from them). 연막은
  // 들어오는 각 발을 50% 확률로 회피(슈퍼 포함 — 막는 게 아니라 피하는 것).
  // 슈퍼빵야 pierces defence *and* traps.
  final hit = List<bool>.filled(n, false);
  final reflectKill = List<bool>.filled(n, false);
  final evaded = List<bool>.filled(n, false);
  for (var t = 0; t < n; t++) {
    if (!aliveBefore[t]) continue;
    final defending = moves[t].kind == ActKind.defend;
    var lethal = false;
    var dodgedSomething = false;
    for (var i = 0; i < n; i++) {
      if (!fired[i] || firedTarget[i] != t) continue;
      // 연막 회피 (발사자별 독립 50%).
      if (smoked[t] && roll(t, 'evade$i') < 0.50) {
        dodgedSomething = true;
        continue;
      }
      if (superFired[i]) {
        lethal = true; // 슈퍼는 방어·덫 모두 관통
      } else if (trapSet[t]) {
        reflectKill[i] = true; // 일반탄 반사 — 쏜 자가 쓰러진다
      } else if (!defending || pierced[i]) {
        lethal = true;
      }
    }
    if (lethal) hit[t] = true;
    if (dodgedSomething && !lethal) evaded[t] = true;
  }
  // 반사 사망 적용 (자기 덫 위에서 죽지는 않는다 — 반사는 쏜 사람에게만).
  for (var i = 0; i < n; i++) {
    if (reflectKill[i]) hit[i] = true;
  }

  // 3) 의사: 게임당 1회, 치명상을 무효로 한다.
  final healed = List<bool>.filled(n, false);
  for (var i = 0; i < n; i++) {
    if (hit[i] && chars[i] == CharId.doctor && !doctorUsed[i]) {
      hit[i] = false;
      healed[i] = true;
      doctorUsed[i] = true;
    }
  }

  // 4) Ammo & reload effects.
  final ammoAfter = List<int>.filled(n, 0);
  final aliveAfter = List<bool>.from(aliveBefore);
  for (var i = 0; i < n; i++) {
    if (!aliveBefore[i]) {
      ammoAfter[i] = ammoBefore[i];
      continue;
    }
    var a = ammoBefore[i] - spent[i];
    if (moves[i].kind == ActKind.reload) {
      var gain = 1;
      // 스피드로더: 50% 확률로 2발.
      if (chars[i] == CharId.speedloader && roll(i, 'load') < 0.50) {
        gain = 2;
        doubleLoad[i] = true;
      }
      a += gain;
      reloads[i] += 1;
    }
    if (a > kMaxAmmo) a = kMaxAmmo;
    if (a < 0) a = 0;
    ammoAfter[i] = a;
    if (hit[i]) aliveAfter[i] = false;
  }

  final after = PartyState(
    doctorUsed: doctorUsed,
    trapUsed: trapUsed,
    smokeLeft: smokeLeft,
    reloads: reloads,
  );

  // 5) Win conditions, in priority order.
  // 5a) 평화주의자: 장전 6회를 채우고 이 턴을 살아남으면 즉시 승리.
  final pacifistWinners = <int>[
    for (var i = 0; i < n; i++)
      if (aliveAfter[i] &&
          chars[i] == CharId.pacifist &&
          reloads[i] >= kPacifistGoal)
        i
  ];
  if (pacifistWinners.length == 1) {
    return _outcome(
      ammoAfter, aliveAfter, fired, superFired, firedTarget, hit,
      GameStatus.won, pacifistWinners.first,
      healed, trapSet, reflectKill, evaded, pierced, smoked, doubleLoad,
      after, 'pacifist',
    );
  }

  final survivors = <int>[
    for (var i = 0; i < n; i++)
      if (aliveAfter[i]) i
  ];

  // 5b) 결투가: 살아남은 둘 중 결투가가 정확히 1명이면 그 즉시 승리.
  if (survivors.length == 2) {
    final duelists = [
      for (final s in survivors)
        if (chars[s] == CharId.duelist) s
    ];
    if (duelists.length == 1) {
      return _outcome(
        ammoAfter, aliveAfter, fired, superFired, firedTarget, hit,
        GameStatus.won, duelists.first,
        healed, trapSet, reflectKill, evaded, pierced, smoked, doubleLoad,
        after, 'duelist',
      );
    }
  }

  // 5c) 기본: 최후의 1인 / 전멸.
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

  return _outcome(
    ammoAfter, aliveAfter, fired, superFired, firedTarget, hit,
    status, winner,
    healed, trapSet, reflectKill, evaded, pierced, smoked, doubleLoad,
    after, null,
  );
}

TurnOutcome _outcome(
  List<int> ammoAfter,
  List<bool> aliveAfter,
  List<bool> fired,
  List<bool> superFired,
  List<int> firedTarget,
  List<bool> hit,
  GameStatus status,
  int? winner,
  List<bool> healed,
  List<bool> trapSet,
  List<bool> reflectKill,
  List<bool> evaded,
  List<bool> pierced,
  List<bool> smoked,
  List<bool> doubleLoad,
  PartyState after,
  String? specialWin,
) =>
    TurnOutcome(
      ammoAfter: ammoAfter,
      aliveAfter: aliveAfter,
      fired: fired,
      superFired: superFired,
      firedTarget: firedTarget,
      hit: hit,
      status: status,
      winner: winner,
      healed: healed,
      trapSet: trapSet,
      reflectKill: reflectKill,
      evaded: evaded,
      pierced: pierced,
      smoked: smoked,
      doubleLoad: doubleLoad,
      stateAfter: after,
      specialWin: specialWin,
    );
