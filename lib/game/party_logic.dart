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

// 순수 규칙 코어만 import — Flutter 의존이 없어 헤드리스(봇 러너)에서도 돈다.
// UI 심볼(CharDef·kCharacters·charDef)이 필요한 화면은 characters.dart 를 직접
// import 한다.
import 'char_core.dart';

export 'char_core.dart'
    show
        CharId,
        charFromIndex,
        kCurseFuse,
        kMysteryPool,
        kMysteryStartRevealChars,
        kMysteryTurnTriggerChars,
        mysteryRevealsAtStart,
        resolveMystery,
        effectiveChar,
        seededRoll;

/// The kind of an action a cowboy can take in a turn.
/// New values appended at the end (encoding is by explicit int, see [Move]).
enum ActKind { reload, defend, shoot, superShoot, trap, idle, roulette, dualShoot, voodoo, reset }

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
      case ActKind.reset:
        return '무효';
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

/// 턴당 제한 시간(초). 만료 시 아무 행동 없이(idle) 턴이 넘어간다.
const int kTurnSeconds = 20;

/// 시간초과(가만히)일 때 보여줄 멘트. 결정적으로 고르도록 seed/turn/seat 사용.
const List<String> kIdleFlavors = [
  '석양을 보고 있었다',
  '멍때리고 있었다',
  '커피를 홀짝이고 있었다',
  '딴생각에 빠져 있었다',
  '말에게 한눈 팔았다',
  '모자를 고쳐 쓰고 있었다',
];

String idleFlavor(String seed, int turn, int seat) {
  final r = seededRoll('$seed|$turn|$seat|idle');
  return kIdleFlavors[(r * kIdleFlavors.length).floor().clamp(0, kIdleFlavors.length - 1)];
}

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
  const Move.reset() : this._(ActKind.reset, -1, -1, false);

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
      case ActKind.reset:
        return 47;
      case ActKind.voodoo:
        return 50 + target; // 50..55
      case ActKind.dualShoot:
        // t1*8+t2. 좌석은 0..5뿐이라 슬롯 6·7은 미사용 — 두 번째 대상이
        // 없을 때(-1: 외길 등)는 슬롯 7로 실어 보낸다. 기존 유효 코드(t2 0..5)는
        // 그대로라 버전 스큐 없음. decode가 7을 -1로 되돌린다.
        return 100 + target * 8 + (target2 >= 0 ? target2 : 7);
    }
  }

  static Move decode(int c) {
    if (c >= 100) {
      final d = c - 100;
      final t2 = d % 8;
      return Move.dualShoot(d ~/ 8, t2 == 7 ? -1 : t2);
    }
    if (c >= 50 && c <= 55) return Move.voodoo(c - 50);
    if (c == 47) return const Move.reset();
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
  final List<bool> resetterUsed; // 리셋터 '무효' 사용 여부

  // 부두 저주 — **대상 좌석별로 독립**(동시에 여러 명을 저주할 수 있다).
  // 부두술사가 여럿이어도 각자 따로 저주를 건다. 좌석 s가 저주받지 않았으면
  // curseFuse[s] == 0, curseCaster[s] == -1.
  final List<int> curseFuse; // 좌석별 사망까지 남은 턴(0 = 저주 없음)
  final List<int> curseCaster; // 좌석별 저주를 건 부두술사 좌석(-1 없음)

  const PartyState({
    required this.doctorUsed,
    required this.trapUsed,
    required this.smokeLeft,
    required this.reloads,
    required this.paparazziUsed,
    required this.resetterUsed,
    this.curseFuse = const [],
    this.curseCaster = const [],
  });

  factory PartyState.initial(List<CharId> chars) => PartyState(
        doctorUsed: List.filled(chars.length, false),
        trapUsed: List.filled(chars.length, false),
        smokeLeft: [
          for (final c in chars) c == CharId.smoker ? 2 : 0
        ],
        reloads: List.filled(chars.length, 0),
        paparazziUsed: List.filled(chars.length, false),
        resetterUsed: List.filled(chars.length, false),
        curseFuse: List.filled(chars.length, 0),
        curseCaster: List.filled(chars.length, -1),
      );
}

/// Starting ammo for a seat given its character (준비자 = 1).
int startAmmoFor(CharId c) => c == CharId.prepper ? 1 : 0;

/// 반응속도 결투(showdown) 결투가 자동승 판정(B2). 동시 사망한 [participants] 중
/// 결투가가 **정확히 1명**이면 그 좌석이 반응속도 없이 즉시 승리(그 좌석 반환).
/// 결투가가 0명이거나 2명 이상이면 자동승 없음(null) → 반응속도 결투로 진행.
/// (온라인 computeView·오프라인 _beginShowdown이 공유하는 순수함수 — 한 곳에서 결정.)
int? duelistShowdownWinner(List<CharId> chars, List<int> participants) {
  int? only;
  for (final s in participants) {
    if (s >= 0 && s < chars.length && chars[s] == CharId.duelist) {
      if (only != null) return null; // 둘 이상 → 자동승 무효
      only = s;
    }
  }
  return only;
}

/// 유한 사용 능력의 **남은 횟수** 라벨 (모든 플레이어에게 표시, #11).
/// 좌석 배지에 직업 아이콘과 함께 "남은 N"으로 보인다. 0이면 다 쓴 것.
/// 해당 캐릭터가 횟수 제한 능력이 없으면 null.
String? abilityUsesLabel(CharId c, PartyState st, int seat) {
  if (seat < 0 || seat >= st.smokeLeft.length) return null;
  switch (c) {
    case CharId.smoker:
      return '${st.smokeLeft[seat]}'; // 연막 남은 횟수(2→0)
    case CharId.hunter:
      return st.trapUsed[seat] ? '0' : '1'; // 덫
    case CharId.resetter:
      return st.resetterUsed[seat] ? '0' : '1'; // 무효
    case CharId.doctor:
      return st.doctorUsed[seat] ? '0' : '1'; // 자힐
    case CharId.paparazzi:
      return st.paparazziUsed[seat] ? '0' : '1'; // 엿보기
    default:
      return null;
  }
}

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
  final List<bool> rouletteSelf; // 운명의 방아쇠가 자신에게 빗나가 자해(표시용 파생)
  final List<bool> dualFired; // 더블 빵야 발동
  final List<int> dualTarget2; // 더블 빵야 두 번째 대상, -1
  final List<bool> voodooCast; // 이 턴 저주를 걸었음
  final List<bool> curseKill; // 저주 만료로 사망
  final List<bool> resetActive; // 리셋터가 이 턴 '무효'를 발동
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
    this.rouletteSelf = const [],
    this.dualFired = const [],
    this.dualTarget2 = const [],
    this.voodooCast = const [],
    this.curseKill = const [],
    this.resetActive = const [],
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
  final resetterUsed = List<bool>.from(state.resetterUsed);
  // 좌석별 저주 상태(길이 보정 — 옛 PartyState/빈 리스트도 안전하게).
  final curseFuse =
      List<int>.generate(n, (i) => i < state.curseFuse.length ? state.curseFuse[i] : 0);
  final curseCaster = List<int>.generate(
      n, (i) => i < state.curseCaster.length ? state.curseCaster[i] : -1);

  // 리셋터 '무효': 살아있는 리셋터가 미사용 상태로 무효를 내면 이번 턴은
  // 모든 전투 결과(피격/장전/저주발동 등)가 없던 일이 된다. 단 총알·특수자원은 소모.
  final resetActive = List<bool>.filled(n, false);
  var turnVoided = false;
  for (var i = 0; i < n; i++) {
    if (!aliveBefore[i]) continue;
    if (moves[i].kind == ActKind.reset &&
        chars[i] == CharId.resetter &&
        !resetterUsed[i]) {
      resetActive[i] = true;
      resetterUsed[i] = true;
      turnVoided = true;
    }
  }

  final fired = List<bool>.filled(n, false);
  final superFired = List<bool>.filled(n, false);
  final firedTarget = List<int>.filled(n, -1);
  final spent = List<int>.filled(n, 0);
  final pierced = List<bool>.filled(n, false);
  final trapSet = List<bool>.filled(n, false);
  final smoked = List<bool>.filled(n, false);
  final doubleLoad = List<bool>.filled(n, false);
  final rouletteFired = List<bool>.filled(n, false);
  final rouletteSelf = List<bool>.filled(n, false); // 운빵이 자신을 겨눔(자해)
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
      final pierce = chars[i] == CharId.sniper && roll(i, 'pierce') < 0.20;
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
    } else if (m.kind == ActKind.roulette &&
        chars[i] == CharId.roulette &&
        targetOk(i, m.target)) {
      // 운명의 방아쇠: 50:50으로 상대 또는 나에게 총알을 날린다.
      // 상대를 향하면 **일반 총알 판정**(방어로 막힘·덫으로 반사·연막 회피).
      // 나를 향하면 자해(자기 총이라 못 막음).
      rouletteFired[i] = true;
      firedTarget[i] = m.target;
      if (roll(i, 'roulette') < 0.5) {
        normalAt[m.target].add([i, 0]); // 상대에게 일반 총알
      } else {
        rouletteSelf[i] = true; // 나에게 — step 2 뒤 자해
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

  // 3) 운명의 방아쇠 자해(50%): 자기 총이라 방어로 못 막는다.
  for (var i = 0; i < n; i++) {
    if (rouletteSelf[i]) hit[i] = true;
  }

  // 4) 저주 발동 (이번 턴 만료되는가) — 좌석별로 독립 판정. 건 부두술사가
  //    이 턴까지 살아있어야 함.
  for (var v = 0; v < n; v++) {
    if (curseFuse[v] <= 0 || !aliveBefore[v]) continue;
    final caster = curseCaster[v];
    final casterAlive = caster >= 0 && aliveBefore[caster] && !hit[caster];
    if (casterAlive && curseFuse[v] <= 1) {
      hit[v] = true;
      curseKill[v] = true;
    }
  }

  // 4b) 리셋터 '무효': 이번 턴 모든 치명 결과를 없던 일로. (총알·특수자원은 이미 소모됨.)
  //     사인(死因) 표시 플래그도 모두 끈다 — 안 그러면 무효로 살아남은 좌석에
  //     '꽝!'(룰렛 자해)·반사·저주 사망 연출이 잘못 뜬다.
  if (turnVoided) {
    for (var i = 0; i < n; i++) {
      hit[i] = false;
      reflectKill[i] = false;
      curseKill[i] = false;
      evaded[i] = false;
      rouletteSelf[i] = false;
    }
  }

  // 5) 의사: 게임당 1회 치명상 버팀. 살아남았으므로 사인(死因) 표시 플래그도 모두
  //    지운다 — 안 그러면 의사가 저주 만료·덫 반사를 버틴 턴에 '저주 사망!'/'반사
  //    사망' 연출과 사망 배너가 산 의사에게 잘못 뜬다.
  final healed = List<bool>.filled(n, false);
  for (var i = 0; i < n; i++) {
    if (hit[i] && chars[i] == CharId.doctor && !doctorUsed[i]) {
      hit[i] = false;
      curseKill[i] = false;
      reflectKill[i] = false;
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
    if (moves[i].kind == ActKind.reload && !turnVoided) {
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

  // 7) 저주 상태 갱신(좌석별): 기존 저주 진행/해제 후 새 저주 적용.
  //    무효 턴이면 저주 상태도 그대로 보존(없던 일).
  if (!turnVoided) {
    // 7a) 기존 저주 진행/해제 — 대상이나 시전자가 죽었으면 해제.
    for (var v = 0; v < n; v++) {
      if (curseFuse[v] <= 0) continue;
      final caster = curseCaster[v];
      final casterDead = caster < 0 || !aliveAfter[caster];
      if (casterDead || !aliveAfter[v]) {
        curseFuse[v] = 0;
        curseCaster[v] = -1;
      } else {
        curseFuse[v] -= 1; // 도화선 감소 (만료 사망은 위 4단계에서 처리됨)
        if (curseFuse[v] <= 0) {
          curseFuse[v] = 0;
          curseCaster[v] = -1;
        }
      }
    }
    // 7b) 새 저주 적용 — 살아있는 부두술사 각자 자기 대상에게(동시에 여러 명 가능).
    // 이미 저주 중인 대상에 재시전하면 **무효**(도화선 유지) — 재시전으로 도화선을
    // 10으로 되돌려 죽음을 무한히 미루는 것을 막는다(제보 #2). 같은 턴에 두 부두가
    // 같은 (비저주) 대상을 노리면 먼저 처리된 좌석의 저주만 걸린다.
    for (var i = 0; i < n; i++) {
      if (chars[i] != CharId.voodoo || !aliveBefore[i] || hit[i]) continue;
      final m = moves[i];
      if (m.kind == ActKind.voodoo &&
          targetOk(i, m.target) &&
          aliveAfter[m.target] &&
          curseFuse[m.target] <= 0) {
        curseFuse[m.target] = kCurseFuse;
        curseCaster[m.target] = i;
        voodooCast[i] = true;
      }
    }
  }

  // 파파라치 사용 표시는 게임 화면(엿보기 페이즈)에서 갱신 — 여기선 통과.

  final after = PartyState(
    doctorUsed: doctorUsed,
    trapUsed: trapUsed,
    smokeLeft: smokeLeft,
    reloads: reloads,
    paparazziUsed: paparazziUsed,
    resetterUsed: resetterUsed,
    curseFuse: curseFuse,
    curseCaster: curseCaster,
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
        rouletteSelf: rouletteSelf,
        dualFired: dualFired,
        dualTarget2: dualTarget2,
        voodooCast: voodooCast,
        curseKill: curseKill,
        resetActive: resetActive,
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

  // 8b) 결투가 너프(B2): 평소엔 효과 없음. '반응속도 결투(showdown)'에 가면
  // 반드시 승리 — 그 판정은 online_service.computeView / 오프라인 showdown에서 처리.

  // 8c) 기본: 최후의 1인 / 전멸.
  if (survivors.length >= 2) return build(GameStatus.ongoing, null, null);
  if (survivors.length == 1) return build(GameStatus.won, survivors.first, null);
  return build(GameStatus.draw, null, null);
}
