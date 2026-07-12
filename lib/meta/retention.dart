/// 리텐션 A(2026-07-12 승인, growth/RETENTION_PLAN.md) 순수 로직·상수.
/// A1 스트릭 복구 · A2 계정 레벨(XP) · A4 주간 미션 · A5 트로피 로드.
/// 전부 순수 함수/상수 — 저장·지급은 Meta(meta_service.dart)가 담당.
library;

// ── A2. 계정 레벨 ──────────────────────────────────────────────────────────

/// 레벨 캡. 계획 문서 기준 Lv30.
const int kMaxLevel = 30;

/// 게임 1판 XP: 승 100 / 패(완주) 40 — 패배도 성장해 연패 이탈을 완화.
const int kXpWin = 100;
const int kXpLose = 40;

/// 레벨 L → L+1에 필요한 XP (계획 문서의 커브 `200+80×(L-1)`).
int xpNeedFor(int level) => 200 + 80 * (level - 1);

/// 만렙까지의 총 XP — 이 이상은 쌓지 않는다(진행바 고정).
final int kMaxTotalXp = () {
  var sum = 0;
  for (var l = 1; l < kMaxLevel; l++) {
    sum += xpNeedFor(l);
  }
  return sum;
}();

/// 누적 XP → 현재 레벨(1~[kMaxLevel]).
int levelForXp(int xp) {
  var level = 1;
  var rest = xp;
  while (level < kMaxLevel && rest >= xpNeedFor(level)) {
    rest -= xpNeedFor(level);
    level++;
  }
  return level;
}

/// 누적 XP → 현재 레벨 안에서 채운 XP(진행바 분자).
int xpIntoLevel(int xp) {
  var level = 1;
  var rest = xp;
  while (level < kMaxLevel && rest >= xpNeedFor(level)) {
    rest -= xpNeedFor(level);
    level++;
  }
  return rest;
}

/// 레벨 도달 보상 골드 — 홀수 레벨은 코인(레벨×100).
/// 짝수 레벨 치장(테두리·이모지 슬롯·Lv10 첫 스킨)은 B2 스킨 시스템에서.
int levelUpGold(int level) => level.isOdd ? level * 100 : 0;

// ── A4. 주간 미션 ──────────────────────────────────────────────────────────

enum WeeklyKind { games, wins, chars }

class WeeklyMission {
  final String key;
  final WeeklyKind kind;
  final int need;
  final int gold;
  final String label;
  const WeeklyMission(this.key, this.kind, this.need, this.gold, this.label);
}

/// 주간 미션 3종(월요일 리셋 — 주간 랭킹과 같은 주 기준).
const List<WeeklyMission> kWeeklyMissions = [
  WeeklyMission('w_play10', WeeklyKind.games, 10, 800, '이번 주 10판 플레이'),
  WeeklyMission('w_win5', WeeklyKind.wins, 5, 1000, '이번 주 5승'),
  WeeklyMission('w_chars3', WeeklyKind.chars, 3, 600, '서로 다른 캐릭터 3종으로 플레이'),
];

// ── A5. 트로피 로드 (통산, 리셋 없음) ─────────────────────────────────────

class TrophyMilestone {
  final String key;
  final bool wins; // true=통산 승수, false=통산 판수
  final int need;
  final int gold;
  const TrophyMilestone(this.key, this.wins, this.need, this.gold);

  String get label => wins ? '통산 $need승' : '통산 $need판 플레이';
}

/// 마일스톤 보상길 — 판수·승수 두 갈래(뒤로 갈수록 큰 보상).
const List<TrophyMilestone> kTrophyRoad = [
  TrophyMilestone('t_g10', false, 10, 200),
  TrophyMilestone('t_w5', true, 5, 300),
  TrophyMilestone('t_g30', false, 30, 400),
  TrophyMilestone('t_w15', true, 15, 500),
  TrophyMilestone('t_g60', false, 60, 600),
  TrophyMilestone('t_w30', true, 30, 800),
  TrophyMilestone('t_g100', false, 100, 1000),
  TrophyMilestone('t_w60', true, 60, 1200),
  TrophyMilestone('t_g200', false, 200, 1500),
  TrophyMilestone('t_w100', true, 100, 1800),
  TrophyMilestone('t_g400', false, 400, 2000),
  TrophyMilestone('t_w200', true, 200, 2500),
  TrophyMilestone('t_g700', false, 700, 2500),
  TrophyMilestone('t_w350', true, 350, 3500),
  TrophyMilestone('t_g1000', false, 1000, 4000),
  TrophyMilestone('t_w500', true, 500, 5000),
];

// ── A1. 스트릭 복구 ────────────────────────────────────────────────────────

/// 스트릭 복구 대상인지: 마지막 출석이 **정확히 그저께**(딱 하루 놓침)일 때만.
/// 이틀 이상 놓쳤으면 복구 불가(그건 새 시작).
bool missedExactlyOneDay(String lastClaim, DateTime now) {
  if (lastClaim.isEmpty) return false;
  final d = now.subtract(const Duration(days: 2));
  final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  return lastClaim == key;
}

/// 복구를 제안할 최소 스트릭 — 1~2일짜리는 복구 가치가 없어 노이즈만 된다.
const int kStreakReviveMin = 3;

// ── B1. 시즌 패스(무료 단일트랙 30티어 / 4주) ────────────────────────────

/// 시즌 앵커: 2026-07-06(월). 이후 28일 단위로 P1, P2, …
final DateTime kPassAnchor = DateTime(2026, 7, 6);

/// 티어 간격 XP. 티어 n은 누적 (n-1)×500 XP에서 열린다(1티어 즉시 지급).
const int kPassTierXp = 500;
const int kPassMaxTier = 30;

int _passIndex(DateTime now) {
  final d = now.difference(DateTime(kPassAnchor.year, kPassAnchor.month,
          kPassAnchor.day))
      .inDays;
  return d < 0 ? -1 : d ~/ 28;
}

/// 시즌 패스 id — 예: 'P1'.
String passIdFor(DateTime now) => 'P${_passIndex(now) + 1}';

/// 시즌 몇 일째(0~27).
int passDayOf(DateTime now) {
  final d = now
      .difference(
          DateTime(kPassAnchor.year, kPassAnchor.month, kPassAnchor.day))
      .inDays;
  return d < 0 ? 0 : d % 28;
}

/// 마지막 주(22일째~)면 패스 XP 2배(캐치업).
bool passLastWeek(DateTime now) => passDayOf(now) >= 21;

/// 시즌 종료까지 남은 일수(오늘 포함 안 함, 0~27).
int passDaysLeft(DateTime now) => 27 - passDayOf(now);

/// 누적 패스 XP → 현재 티어(1~30).
int passTierForXp(int xp) {
  final t = xp ~/ kPassTierXp + 1;
  return t > kPassMaxTier ? kPassMaxTier : t;
}

/// 티어별 골드 보상 — 1 즉시감(200), 5·10·20 스파이크, 30 피날레.
/// 30티어 시즌 한정 스킨은 B2 스킨 시스템 도입 후 소급(문서 참고).
int passGoldOf(int tier) => switch (tier) {
      1 => 200,
      5 => 500,
      10 => 1000,
      15 => 700,
      20 => 1500,
      25 => 1000,
      30 => 3000,
      _ => 150,
    };

/// 미션 달성이 패스 XP를 먹인다(계층 연결): 데일리 +100, 주간 +300.
const int kPassXpDaily = 100;
const int kPassXpWeekly = 300;

// ── B4. 복귀 보상 ──────────────────────────────────────────────────────────

/// 이 일수 이상 미접속 후 돌아오면 웰컴백 패키지를 준다.
const int kWelcomeBackDays = 7;
const int kWelcomeBackGold = 800;

// ── 게임 종료 보상 묶음(토스트용) ─────────────────────────────────────────

class GameEndRewards {
  final List<String> lines; // 사용자에게 보여줄 줄들(달성 순)
  final int coinsGained; // 미션·트로피·레벨업으로 이번에 받은 코인 합
  const GameEndRewards(this.lines, this.coinsGained);
  bool get isEmpty => lines.isEmpty;
}
