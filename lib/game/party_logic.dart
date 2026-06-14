/// Core, UI-independent rules for **Cowboy Party** — the 2-to-6 player
/// generalisation of Cowboy Duel, extended with selectable characters.
///
/// Every turn each living cowboy commits a **single action**:
///   - 장전/방어/빵야/슈퍼빵야 (base) and character-specific actions:
///   - 덫 (사냥꾼), 운명의 방아쇠 (러시안룰렛), 더블 빵야 (쌍권총), 저주 (부두술사),
///     가만히 (idle — 시간초과 시 자동).
///
/// All character randomness uses [seededRoll] so every client replays identical
/// outcomes from the same move history.
library;

import 'characters.dart';

export 'characters.dart'
    show
        CharId,
        CharDef,
        charDef,
        charFromIndex,
        kCharacters,
        kCurseFuse,
        kMysteryPool,
        resolveMystery,
        effectiveChar,
        seededRoll;

/// The kind of an action a cowboy can take in a turn.
/// New values appended at the end (encoding is by explicit int, see [Move]).
enum ActKind { reload, defend, shoot, superShoot, trap, idle, roulette, dualShoot, voodoo }

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
      case ActKind.idle:
        return '가만히';
      case ActKind.roulette:
        return '운명의 방아쇠';
      case ActKind.dualShoot:
        return '더블 빵야';
      case ActKind.voodoo:
        return '저주';
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

/// One cowboy's full commitment for a turn.
class Move {
  final ActKind kind;

  /// Primary target seat (shots / roulette / voodoo), or -1.
  final int target;

  /// Second target seat for 더블 빵야 (쌍권총), or -1.
  final int target2;

  /// 스모커 전용: this turn is smoked (50% evasion), stacked on any base action.
  final bool smoke;

  const Move._(this.kind, this.target, [this.target2 = -1, this.smoke = false]);

  const Move.reload({bool smoke = false}) : this._(ActKind.reload, -1, -1, smoke);
  const Move.defend({bool smoke = false}) : this._(ActKind.defend, -1, -1, smoke);
  const Move.shoot(int target, {bool smoke = false})
      : this._(ActKind.shoot, target, -1, smoke);
  const Move.superShoot(int target, {bool smoke = false})
      : this._(ActKind.superShoot, target, -1, smoke);
  const Move.trap() : this._(ActKind.trap, -1, -1, false);
  const Move.idle() : this._(ActKind.idle, -1, -1, false);
  const Move.roulette(int target) : this._(ActKind.roulette, target, -1, false);
  const Move.dualShoot(int target, int target2)
      : this._(ActKind.dualShoot, target, target2, false);
  const Move.voodoo(int target) : this._(ActKind.voodoo, target, -1, false);

  static const Move empty = Move._(ActKind.reload, -1);

  bool get isShoot => kind == ActKind.shoot || kind == ActKind.superShoot;

  /// Whether the picker must choose a single target seat.
  bool get needsTarget =>
      kind == ActKind.shoot ||
      kind == ActKind.superShoot ||
      kind == ActKind.roulette ||
      kind == ActKind.voodoo;

  /// 더블 빵야 — picker needs two targets.
  bool get needsTwoTargets => kind == ActKind.dualShoot;

  Move withSmoke(bool s) => Move._(kind, target, target2, s);

  /// Compact integer encoding for Firebase. Legacy codes (0..30, +16 smoke bit
  /// for base actions) decode unchanged; new actions use disjoint high ranges.
  int encode() {
    switch (kind) {
      case ActKind.reload:
        return 0 + (smoke ? 16 : 0);
      case ActKind.defend:
        return 1 + (smoke ? 16 : 0);
      case ActKind.shoot:
        return 2 + target + (smoke ? 16 : 0);
      case ActKind.superShoot:
        return 8 + target + (smoke ? 16 : 0);
      case ActKind.trap:
        return 14 + (smoke ? 16 : 0);
      case ActKind.idle:
        return 40;
      case ActKind.roulette:
        return 41 + target; // 41..46
      case ActKind.voodoo:
        return 50 + target; // 50..55
      case ActKind.dualShoot:
        return 100 + target * 8 + target2; // t1*8+t2
    }
  }

  static Move decode(int c) {
    if (c >= 100) {
      final d = c - 100;
      return Move.dualShoot(d ~/ 8, d % 8);
    }
    if (c >= 50 && c <= 55) return Move.voodoo(c - 50);
    if (c >= 41 && c <= 46) return Move.roulette(c - 41);
    if (c == 40) return const Move.idle();
    final smoke = c >= 16;
    final b = smoke ? c - 16 : c;
    if (b <= 0) return Move._(ActKind.reload, -1, -1, smoke);
    if (b == 1) return Move._(ActKind.defend, -1, -1, smoke);
    if (b < 8) return Move._(ActKind.shoot, b - 2, -1, smoke);
    if (b < 14) return Move._(ActKind.superShoot, b - 8, -1, smoke);
    return const Move.trap();
  }

  @override
  bool operator ==(Object other) =>
      other is Move &&
      other.kind == kind &&
      other.target == target &&
      other.target2 == target2 &&
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
  final List<bool> paparazziUsed; // 파파라치 엿보기 사용 여부

  // 부두 저주 (게임당 동시 1개).
  final int curseVictim; // 저주 대상 좌석, -1 없음
  final int curseCaster; // 저주를 건 부두술사 좌석, -1 없음
  final int curseFuse; // 사망까지 남은 턴(0 = 저주 없음)

  const PartyState({
    required this.doctorUsed,
    required this.trapUsed,
    required this.smokeLeft,
    required this.reloads,
    required this.paparazziUsed,
    this.curseVictim = -1,
    this.curseCaster = -1,
    this.curseFuse = 0,
  });

  factory PartyState.initial(List<CharId> chars) => PartyState(
        doctorUsed: List.filled(chars.length, false),
        trapUsed: List.filled(chars.length, false),
        smokeLeft: [
          for (final c in chars) c == CharId.smoker ? 2 : 0
        ],
        reloads: List.filled(chars.length, 0),
        paparazziUsed: List.filled(chars.length, false),
      );
}

/// Starting ammo for a seat given its character (준비자 = 1).
int startAmmoFor(CharId c) => c == CharId.prepper ? 1 : 0;

/// Immutable result of resolving one simultaneous turn for every seat.
class TurnOutcome {
  final List<int> ammoAfter;
  final List<bool> aliveAfter;
  final List<bool> fired; // fired a normal/super bullet this turn
  final List<bool> superFired;
  final List<int> firedTarget; // primary target, -1 if none
  final List<bool> hit; // newly eliminated this turn
  final GameStatus status;
  final int? winner;

  // Character-ability display flags.
  final List<bool> healed; // 의사가 이 턴 치명상을 버팀
  final List<bool> trapSet;
  final List<bool> reflectKill; // 덫 반사로 사망
  final List<bool> evaded; // 연막으로 회피
  final List<bool> pierced; // 스나이퍼 관통
  final List<bool> smoked;
  final List<bool> doubleLoad; // 스피드로더 +2
  final List<bool> rouletteFired; // 운명의 방아쇠 발동
  final List<bool> dualFired; // 더블 빵야 발동
  final List<int> dualTarget2; // 더블 빵야 두 번째 대상, -1
  final List<bool> voodooCast; // 이 턴 저주를 걸었음
  final List<bool> curseKill; // 저주 만료로 사망
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
    this.rouletteFired = const [],
    this.dualFired = const [],
    this.dualTarget2 = const [],
    this.voodooCast = const [],
    this.curseKill = const [],
    this.stateAfter,
    this.specialWin,
  });
}

/// Legacy character-free resolution (kept for old tests/UI paths).
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
  assert(ammoBefore.length == n && aliveBefore.length == n && chars.length == n);

  double roll(int seat, String salt) => seededRoll('$seed|$turn|$seat|$salt');
  bool targetOk(int i, int t) =>
      t >= 0 && t < n && t != i && aliveBefore[t];

  final doctorUsed = List<bool>.from(state.doctorUsed);
  final trapUsed = List<bool>.from(state.trapUsed);
  final smokeLeft = List<int>.from(state.smokeLeft);
  final reloads = List<int>.from(state.reloads);
  final paparazziUsed = List<bool>.from(state.paparazziUsed);

  final fired = List<bool>.filled(n, false);
  final superFired = List<bool>.filled(n, false);
  final firedTarget = List<int>.filled(n, -1);
  final spent = List<int>.filled(n, 0);
  final pierced = List<bool>.filled(n, false);
  final trapSet = List<bool>.filled(n, false);
  final smoked = List<bool>.filled(n, false);
  final doubleLoad = List<bool>.filled(n, false);
  final rouletteFired = List<bool>.filled(n, false);
  final dualFired = List<bool>.filled(n, false);
  final dualTarget2 = List<int>.filled(n, -1);
  final voodooCast = List<bool>.filled(n, false);
  final curseKill = List<bool>.filled(n, false);

  // 0) Modifiers: 덫, 연막.
  for (var i = 0; i < n; i++) {
    if (!aliveBefore[i]) continue;
    final m = moves[i];
    if (m.kind == ActKind.trap && chars[i] == CharId.hunter && !trapUsed[i]) {
      trapSet[i] = true;
      trapUsed[i] = true;
    }
    if (m.smoke && chars[i] == CharId.smoker && smokeLeft[i] > 0) {
      smoked[i] = true;
      smokeLeft[i]--;
    }
  }

  // 1) Shots. Build incoming-shot lists so 쌍권총's two targets are handled.
  final normalAt = List.generate(n, (_) => <List<int>>[]); // [shooter, pierced01]
  final superAt = List.generate(n, (_) => <int>[]); // shooter
  for (var i = 0; i < n; i++) {
    if (!aliveBefore[i] || chars[i] == CharId.pacifist) continue;
    final m = moves[i];
    if (m.kind == ActKind.superShoot &&
        ammoBefore[i] >= kSuperCost &&
        targetOk(i, m.target)) {
      fired[i] = superFired[i] = true;
      firedTarget[i] = m.target;
      spent[i] = kSuperCost;
      superAt[m.target].add(i);
    } else if (m.kind == ActKind.shoot &&
        ammoBefore[i] > 0 &&
        targetOk(i, m.target)) {
      fired[i] = true;
      firedTarget[i] = m.target;
      spent[i] = 1;
      final pierce = chars[i] == CharId.sniper && roll(i, 'pierce') < 0.10;
      pierced[i] = pierce;
      normalAt[m.target].add([i, pierce ? 1 : 0]);
    } else if (m.kind == ActKind.dualShoot &&
        chars[i] == CharId.dualgun &&
        ammoBefore[i] >= 2) {
      final targets = <int>[];
      if (targetOk(i, m.target)) targets.add(m.target);
      if (targetOk(i, m.target2) && m.target2 != m.target) {
        targets.add(m.target2);
      }
      if (targets.isNotEmpty) {
        fired[i] = dualFired[i] = true;
        firedTarget[i] = targets.first;
        dualTarget2[i] = targets.length > 1 ? targets[1] : -1;
        spent[i] = targets.length; // 1발 or 2발
        for (final t in targets) {
          normalAt[t].add([i, 0]);
        }
      }
    }
  }

  // 2) Hits from shots. Defence blocks non-pierced normal shots; 덫 reflects
  // normal shots to the shooter; 연막 dodges each incoming shot at 50%; 슈퍼는
  // 방어·덫 모두 관통.
  final hit = List<bool>.filled(n, false);
  final reflectKill = List<bool>.filled(n, false);
  final evaded = List<bool>.filled(n, false);
  for (var t = 0; t < n; t++) {
    if (!aliveBefore[t]) continue;
    final defending = moves[t].kind == ActKind.defend;
    var lethal = false, dodged = false;
    for (final shot in normalAt[t]) {
      final s = shot[0], pierce = shot[1] == 1;
      if (smoked[t] && roll(t, 'evade$s') < 0.50) {
        dodged = true;
        continue;
      }
      if (trapSet[t]) {
        reflectKill[s] = true;
      } else if (!defending || pierce) {
        lethal = true;
      }
    }
    for (final s in superAt[t]) {
      if (smoked[t] && roll(t, 'evS$s') < 0.50) {
        dodged = true;
        continue;
      }
      lethal = true;
    }
    if (lethal) hit[t] = true;
    if (dodged && !lethal) evaded[t] = true;
  }
  for (var i = 0; i < n; i++) {
    if (reflectKill[i]) hit[i] = true;
  }

  // 3) 운명의 방아쇠 (러시안룰렛): 50:50 나/상대. 상대가 방어하면 반사돼 내가 죽음.
  for (var i = 0; i < n; i++) {
    if (!aliveBefore[i] || chars[i] != CharId.roulette) continue;
    final m = moves[i];
    if (m.kind != ActKind.roulette || !targetOk(i, m.target)) continue;
    rouletteFired[i] = true;
    firedTarget[i] = m.target;
    final intendedTarget = roll(i, 'roulette') < 0.5;
    final victim = (intendedTarget && moves[m.target].kind != ActKind.defend)
        ? m.target
        : i; // 상대 사망, 아니면(자기 차례 or 상대 방어) 내가 사망
    hit[victim] = true;
  }

  // 4) 저주 발동 (이번 턴 만료되는가). caster가 이 턴까지 살아있어야 함.
  if (state.curseFuse > 0) {
    final caster = state.curseCaster;
    final casterAlive =
        caster >= 0 && aliveBefore[caster] && !hit[caster];
    if (casterAlive && state.curseFuse <= 1) {
      final v = state.curseVictim;
      if (v >= 0 && aliveBefore[v]) {
        hit[v] = true;
        curseKill[v] = true;
      }
    }
  }

  // 5) 의사: 게임당 1회 치명상 버팀.
  final healed = List<bool>.filled(n, false);
  for (var i = 0; i < n; i++) {
    if (hit[i] && chars[i] == CharId.doctor && !doctorUsed[i]) {
      hit[i] = false;
      healed[i] = true;
      doctorUsed[i] = true;
    }
  }

  // 6) 탄약·생존.
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
      if (chars[i] == CharId.speedloader && roll(i, 'load') < 0.50) {
        gain = 2;
        doubleLoad[i] = true;
      }
      a += gain;
      reloads[i] += 1;
    }
    if (a > kMaxAmmo) a = kMaxAmmo;
    if (a < 0) a = 0;
    if (healed[i]) a = 0; // 의사 수정: 버틴 즉시 총알 0
    ammoAfter[i] = a;
    if (hit[i]) aliveAfter[i] = false;
  }

  // 7) 저주 상태 갱신: 기존 저주 진행/해제, 새 저주 적용(동시 1개, 늦게 건 게 우선).
  var newVictim = state.curseVictim;
  var newCaster = state.curseCaster;
  var newFuse = state.curseFuse;
  if (newFuse > 0) {
    final casterDead = newCaster < 0 || !aliveAfter[newCaster];
    final victimDead = newVictim < 0 || !aliveAfter[newVictim];
    if (casterDead || victimDead) {
      newFuse = 0;
      newVictim = -1;
      newCaster = -1;
    } else {
      newFuse -= 1; // 매 턴 도화선 감소 (만료 사망은 위 4단계에서 처리됨)
      if (newFuse <= 0) {
        newFuse = 0;
        newVictim = -1;
        newCaster = -1;
      }
    }
  }
  for (var i = 0; i < n; i++) {
    if (chars[i] != CharId.voodoo || !aliveBefore[i] || hit[i]) continue;
    final m = moves[i];
    if (m.kind == ActKind.voodoo &&
        targetOk(i, m.target) &&
        aliveAfter[m.target]) {
      newVictim = m.target;
      newCaster = i;
      newFuse = kCurseFuse;
      voodooCast[i] = true;
    }
  }

  // 파파라치 사용 표시는 게임 화면(엿보기 페이즈)에서 갱신 — 여기선 통과.

  final after = PartyState(
    doctorUsed: doctorUsed,
    trapUsed: trapUsed,
    smokeLeft: smokeLeft,
    reloads: reloads,
    paparazziUsed: paparazziUsed,
    curseVictim: newVictim,
    curseCaster: newCaster,
    curseFuse: newFuse,
  );

  TurnOutcome build(GameStatus status, int? winner, String? special) =>
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
        rouletteFired: rouletteFired,
        dualFired: dualFired,
        dualTarget2: dualTarget2,
        voodooCast: voodooCast,
        curseKill: curseKill,
        stateAfter: after,
        specialWin: special,
      );

  // 8) 승리 판정.
  // 8a) 평화주의자: 장전 6회 + 생존 → 즉시 승리.
  final pacifistWinners = <int>[
    for (var i = 0; i < n; i++)
      if (aliveAfter[i] &&
          chars[i] == CharId.pacifist &&
          reloads[i] >= kPacifistGoal)
        i
  ];
  if (pacifistWinners.length == 1) {
    return build(GameStatus.won, pacifistWinners.first, 'pacifist');
  }

  final survivors = <int>[
    for (var i = 0; i < n; i++)
      if (aliveAfter[i]) i
  ];

  // 8b) 결투가: 둘만 남고 결투가가 정확히 1명 → 즉시 승리.
  if (survivors.length == 2) {
    final duelists = [
      for (final s in survivors)
        if (chars[s] == CharId.duelist) s
    ];
    if (duelists.length == 1) {
      return build(GameStatus.won, duelists.first, 'duelist');
    }
  }

  // 8c) 기본: 최후의 1인 / 전멸.
  if (survivors.length >= 2) return build(GameStatus.ongoing, null, null);
  if (survivors.length == 1) return build(GameStatus.won, survivors.first, null);
  return build(GameStatus.draw, null, null);
}
