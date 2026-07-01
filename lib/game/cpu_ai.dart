import 'dart:math';

import 'party_logic.dart';

/// 봇 한 명의 성격·실력 프로필. 게임 시작 때 좌석별로 한 번 뽑아 그 게임 내내
/// 유지한다 → 봇마다 다르되(약~강 섞임) 각자는 일관되게 행동한다.
class _BotProfile {
  final double skill; // 0.15~1.0: 낮으면 헛수(어수룩한 판단)가 잦다
  final double aggression; // 쏘기 성향(높을수록 장전/방어 대신 공격)
  final double caution; // 위협받을 때 방어 성향
  final double focus; // 표적 집착(높으면 최다무장, 낮으면 분산)
  final double grudge; // 직전 턴 나를 쏜 상대에 반격하는 성향
  const _BotProfile(
      this.skill, this.aggression, this.caution, this.focus, this.grudge);
}

/// 오프라인 "컴퓨터와 대결"용 상대 AI.
///
/// 봇마다 성격·실력이 달라(약~강 섞임) 사람처럼 보이도록, 그리고 표적이 한
/// 명(=사람)에게 몰리지 않도록 설계했다. 능력(덫·연막·평화주의자·저주 등)은
/// 살려서 둔다. 오프라인 전용이라 재현 결정성이 필요 없어 [Random]을 쓴다.
class CpuAi {
  final Random _r;
  CpuAi([int? seed]) : _r = seed == null ? Random() : Random(seed);

  final Map<int, _BotProfile> _profiles = {};

  /// 새 게임 시작 시 호출 — 봇별 성격/실력을 새로 뽑는다.
  void beginGame() => _profiles.clear();

  /// 특정 좌석의 성격을 강제 지정(온라인 봇 러너의 '공격/수비' 같은 성향 봇용).
  /// 지정 안 한 항목은 기존(랜덤) 값을 유지. beginGame 뒤에 호출한다.
  void setProfile(int seat,
      {double? skill,
      double? aggression,
      double? caution,
      double? focus,
      double? grudge}) {
    final b = _profileFor(seat);
    _profiles[seat] = _BotProfile(
      (skill ?? b.skill).clamp(0.0, 1.0),
      (aggression ?? b.aggression).clamp(0.0, 1.0),
      (caution ?? b.caution).clamp(0.0, 1.0),
      (focus ?? b.focus).clamp(0.0, 1.0),
      (grudge ?? b.grudge).clamp(0.0, 1.0),
    );
  }

  _BotProfile _profileFor(int seat) => _profiles.putIfAbsent(seat, () {
        double v(double lo, double hi) => lo + _r.nextDouble() * (hi - lo);
        return _BotProfile(
          v(0.15, 1.0), // skill: 약~강 고르게
          v(0.25, 0.9), // aggression
          v(0.10, 0.75), // caution
          v(0.10, 0.45), // focus: 낮게 — '최다무장 몰빵' 억제(대개 랜덤 분산)
          v(0.00, 0.45), // grudge: 반격도 완화(한 명에게 몰리지 않게)
        );
      });

  /// 좌석 [seat]의 이번 턴 [Move]. [lastMoves]는 직전 턴 전원의 수(반격용, null 가능).
  Move chooseMove({
    required int seat,
    required List<int> ammo,
    required List<bool> alive,
    List<CharId>? chars,
    PartyState? state,
    List<Move?>? lastMoves,
  }) {
    final p = _profileFor(seat);
    final n = ammo.length;
    final myAmmo = ammo[seat];
    final myChar =
        (chars != null && seat < chars.length) ? chars[seat] : CharId.none;

    final rivals = <int>[
      for (var i = 0; i < n; i++)
        if (i != seat && alive[i]) i
    ];
    if (rivals.isEmpty) return const Move.reload();

    // 나를 이번 턴 쏠 수 있는(무장한) 라이벌.
    final threats = [for (final r in rivals) if (ammo[r] > 0) r];

    int pick(List<int> pool) => _pickTarget(seat, pool, ammo, p, lastMoves);

    // 평화주의자 봇: 쏠 수 없다 — 장전으로 승리를 노리고, 위협 크면 방어.
    if (myChar == CharId.pacifist) {
      if (threats.length >= 2 && _r.nextDouble() < 0.40 + p.caution * 0.3) {
        return const Move.defend();
      }
      if (threats.isNotEmpty && _r.nextDouble() < 0.15 + p.caution * 0.3) {
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

    // 리셋터 봇: 위협이 클 때 가끔 '무효' (게임당 1회).
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

    // 부두술사 봇: 아직 저주에 안 걸린 라이벌이 있으면 가끔 저주.
    if (myChar == CharId.voodoo && state != null && rivals.isNotEmpty) {
      bool uncursed(int s) =>
          s >= state.curseFuse.length || state.curseFuse[s] <= 0;
      final freshThreats = [for (final s in threats) if (uncursed(s)) s];
      final freshRivals = [for (final s in rivals) if (uncursed(s)) s];
      final pool = freshThreats.isNotEmpty ? freshThreats : freshRivals;
      if (pool.isNotEmpty && _r.nextDouble() < 0.35) {
        return Move.voodoo(pick(pool));
      }
    }

    // 쌍권총 봇: 총알 2발+ 라이벌 2명+ 이면 가끔 두 명을 동시에 노린다.
    if (myChar == CharId.dualgun &&
        myAmmo >= 2 &&
        rivals.length >= 2 &&
        _r.nextDouble() < 0.5) {
      final pool = threats.length >= 2 ? threats : rivals;
      final t1 = pick(pool);
      final rest = [for (final r in rivals) if (r != t1) r];
      return Move.dualShoot(t1, pick(rest));
    }

    // 러시안룰렛 봇: 총알 없을 때 도박, 평소엔 가끔.
    if (myChar == CharId.roulette && rivals.isNotEmpty) {
      final pr = myAmmo == 0 ? 0.45 : 0.18;
      if (_r.nextDouble() < pr) {
        return Move.roulette(pick(threats.isNotEmpty ? threats : rivals));
      }
    }

    // 풀 탄창 → 슈퍼빵야(방어 관통). 공격적일수록 자주 쓴다.
    if (myAmmo >= kMaxAmmo &&
        _r.nextDouble() < 0.55 + p.aggression * 0.35) {
      return smoke(Move.superShoot(pick(_spreadPool(threats, rivals))));
    }

    // 빈 총 → 못 쏜다. 대개 장전, 위협 크면 방어(신중할수록 자주).
    if (myAmmo == 0) {
      if (threats.length >= 2 && _r.nextDouble() < 0.25 + p.caution * 0.4) {
        return smoke(const Move.defend());
      }
      if (threats.isNotEmpty && _r.nextDouble() < 0.10 + p.caution * 0.3) {
        return smoke(const Move.defend());
      }
      return smoke(const Move.reload());
    }

    // 무장했어도 위협받으면 가끔 방어(신중도 반영).
    if (threats.isNotEmpty) {
      final guard = (threats.length >= 2 ? 0.15 : 0.08) + p.caution * 0.35;
      if (_r.nextDouble() < guard) return smoke(const Move.defend());
    }

    // 저실력 봇의 실수 또는 소극적 성향 → 최선 대신 장전으로 넘긴다(사람처럼).
    final blunder = _r.nextDouble() < (1 - p.skill) * 0.30;
    if (blunder || _r.nextDouble() < 0.10 + (1 - p.aggression) * 0.20) {
      return smoke(const Move.reload());
    }

    // 그 외엔 쏜다.
    return smoke(Move.shoot(pick(_spreadPool(threats, rivals))));
  }

  /// 조준 풀: 절반은 무장한 위협만(전술), 절반은 **모든 상대**(분산) — 총알 있는
  /// 사람이 하나뿐이라 전 봇이 그리로 몰리는 '한 명 집중포화'를 완화한다.
  List<int> _spreadPool(List<int> threats, List<int> rivals) =>
      (threats.isNotEmpty && _r.nextDouble() < 0.5) ? threats : rivals;

  /// 표적 선택 — 성격(focus)·반격(grudge)·분산을 반영해 한 명(=사람)에게
  /// 몰리지 않게 한다. (예전엔 60%가 '최다 무장'만 노려 장전한 사람에게 몰빵됐다.)
  int _pickTarget(int seat, List<int> pool, List<int> ammo, _BotProfile p,
      List<Move?>? lastMoves) {
    if (pool.length == 1) return pool.first;
    // 반격: 직전 턴 나를 노린 상대가 pool에 있으면 grudge 확률로 그를 노린다.
    if (lastMoves != null && _r.nextDouble() < p.grudge) {
      final attackers = [
        for (final t in pool)
          if (t < lastMoves.length && _targetedMe(lastMoves[t], seat)) t
      ];
      if (attackers.isNotEmpty) return attackers[_r.nextInt(attackers.length)];
    }
    // focus 높으면 최다 무장 상대, 낮으면 무작위로 분산.
    if (_r.nextDouble() < p.focus) {
      var best = pool.first;
      for (final t in pool) {
        if (ammo[t] > ammo[best]) best = t;
      }
      return best;
    }
    return pool[_r.nextInt(pool.length)];
  }

  static bool _targetedMe(Move? m, int me) =>
      m != null && (m.target == me || m.target2 == me);

  /// 결투(반응속도) 대결에서 봇 [seat]의 반응 시간(ms). 실력이 높을수록 빠르다
  /// (고수 ~350ms, 허당 ~900ms). 그 게임의 봇 프로필을 그대로 쓴다.
  int showdownReactionMs(int seat) {
    final p = _profileFor(seat);
    final base = 900 - p.skill * 550; // skill 0→900, 1→350
    final jitter = _r.nextInt(160) - 40; // -40~+120ms
    return (base + jitter).round().clamp(200, 1100);
  }
}
