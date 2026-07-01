/// 카우보이 규칙의 **순수 Dart 코어** — Flutter(위젯/아이콘/색) 의존이 전혀
/// 없어 헤드리스 환경(봇 러너)에서도 그대로 돌릴 수 있다.
///
/// UI용 `CharDef`·`kCharacters`·`charDef` 는 `characters.dart`(Flutter)에 남고,
/// characters.dart 가 이 파일을 그대로 re-export 하므로 앱 코드는 지금까지처럼
/// `characters.dart` 하나만 import 해도 된다. 규칙엔진(party_logic)·봇(cpu_ai)·
/// 봇 러너는 **이 파일**만 import 한다.
///
/// 규칙 랜덤은 전부 [seededRoll](결정적 해시)만 쓴다 — dart:math Random 금지
/// (모든 클라이언트가 독립 재계산해도 동일한 결과를 내야 하기 때문).
library;

// 새 값은 반드시 **뒤에 append** — RTDB에 enum index(정수)로 저장되므로 순서를
// 바꾸면 기존 저장값이 깨진다.
enum CharId {
  none,
  sniper, // 스나이퍼: 빵야가 10% 확률로 방어 무시
  speedloader, // 스피드로더: 장전 시 50% 확률로 +2발
  duelist, // 결투가: 1대1이 되면 즉시 승리 (결투가 둘이면 무효)
  prepper, // 준비자: 장전 1 상태로 시작
  doctor, // 의사: 게임당 1회 치명상 버팀(자힐) — 버틴 즉시 총알 0
  hunter, // 사냥꾼: 게임당 1회 '덫'(그 턴 행동 불가) — 일반탄 반사
  smoker, // 스모커: '연막' 게임당 2회(행동과 병행) — 공격당 50% 회피
  pacifist, // 평화주의자: 빵야 불가, 장전 6회 성공 시 즉시 승리
  roulette, // 러시안룰렛: '운명의 방아쇠' 상시 — 50:50로 나/상대 사망(상대 방어시 내가)
  shadow, // 그림자: 장전·방어·총알수가 상대에게 안 보임(빵야·피격시 방어는 보임)
  dualgun, // 쌍권총: '더블 빵야' 상시 — 2발로 두 명 동시 저격
  paparazzi, // 파파라치: '엿보기' 게임당 1회 — 1명 행동 미리보고 내 행동 결정
  mystery, // ???: 미공개 시작, 직업은 매 게임 랜덤(전 캐릭터 보유 시 구매)
  voodoo, // 부두술사: '저주' 상시 — 10턴 뒤 사망, 부두술사 죽으면 해제
  commoner, // 일반인: 능력 없음(장전/방어/빵야만). 유일한 무료 기본 캐릭터
  resetter, // 리셋터: '무효'(한 턴 소모, 게임당 1회) — 그 턴 다른 플레이어 행동 결과 무효
}

/// 특수행동 UI 배치 분류 (ARCHITECTURE §특수행동 배치 규칙).
/// - parallel: 행동과 병행(행동 칸 위 얇은 토글). 예) 스모커 연막.
/// - turnSlot: 한 턴을 소모(4번째 행동 칸). 예) 사냥꾼 덫, 부두 저주, 리셋터 무효.
/// - alwaysRow: 상시 공격형(별도 줄). 예) 운명의 방아쇠, 더블 빵야.
/// - none: 특수행동 없음.
enum SpecialSlot { none, parallel, turnSlot, alwaysRow }

/// 부두 저주 도화선: 건 턴으로부터 이 턴 수 뒤에 대상이 사망.
const int kCurseFuse = 10;

/// 실제 플레이 가능한 직업 목록(순수). `characters.dart`의 `kCharacters`(CharDef)
/// **순서와 일치**시킨다 — [kMysteryPool]이 이 순서로 인덱싱되므로. mystery는
/// 여기 넣지 않는다(??? 자기 자신으로는 변신하지 않는다). 캐릭터를 추가할 땐
/// kCharacters 와 이 목록 둘 다 갱신(ARCHITECTURE §I1 체크리스트).
const List<CharId> kPlayableCharIds = [
  CharId.commoner,
  CharId.prepper,
  CharId.sniper,
  CharId.speedloader,
  CharId.doctor,
  CharId.smoker,
  CharId.hunter,
  CharId.resetter,
  CharId.duelist,
  CharId.pacifist,
  CharId.shadow,
  CharId.roulette,
  CharId.dualgun,
  CharId.paparazzi,
  CharId.voodoo,
];

/// ???(mystery)가 매 게임 무작위로 변신할 수 있는 직업 풀
/// (mystery 본인만 제외 — 일반인 포함, 즉 ???는 일반인으로도 변신 가능).
List<CharId> get kMysteryPool =>
    [for (final c in kPlayableCharIds) if (c != CharId.mystery) c];

/// ???(mystery)를 좌석/게임 시드로 결정적으로 한 직업으로 변신시킨다.
/// 모든 클라이언트가 동일하게 계산하도록 [seededRoll] 사용.
CharId resolveMystery(String seed, int seat) {
  final pool = kMysteryPool;
  final r = seededRoll('$seed|mystery|$seat');
  return pool[(r * pool.length).floor().clamp(0, pool.length - 1)];
}

/// 게임 판정에 쓸 **실제** 직업. ???(mystery)는 그 게임의 랜덤 직업으로 변환,
/// 그 외엔 그대로. 규칙 엔진에 넘기기 전에 항상 이걸 통과시킨다.
CharId effectiveChar(CharId c, String seed, int seat) =>
    c == CharId.mystery ? resolveMystery(seed, seat) : c;

/// ??? 정체 공개 분류 --------------------------------------------------------
///
/// ???(mystery)가 변신한 **실제 직업**(effective char) 기준으로, 정체를 언제
/// 드러낼지 둘 중 하나로 나눈다:
/// - 시작 공개(start-reveal): 게임 내내 관측 가능한 능동 신호가 전혀 없는 직업.
///   준비자(시작 탄약 1발)·일반인(능력 없음)·그림자(패시브 은폐)는 어떤 트리거도
///   안 떠서 ???가 이 직업이면 영원히 ???로 남으므로 시작에 바로 공개.
/// - 턴 트리거 공개(turn-trigger): 능력이 실제 발동한 시점에 공개되는 나머지.
///   여기엔 **평화주의자(6장전 승리 순간)·결투가(결투 자동승 순간)**도 포함 —
///   둘은 능력이 게임 종반에 비로소 발동하므로 그 전엔 정체를 숨겨야 한다.
///   (파파라치는 엿보기[peekUsed] 사용 시 공개 — online_service에서 처리.)
///
/// 두 집합의 합집합은 [kMysteryPool] 전체와 **정확히 일치**해야 한다
/// (characters_test의 "시작공개 ∪ 턴트리거 == 전체 직업" 단위테스트로 보장).
const Set<CharId> kMysteryStartRevealChars = {
  CharId.commoner,
  CharId.prepper,
  CharId.shadow,
};

const Set<CharId> kMysteryTurnTriggerChars = {
  CharId.sniper,
  CharId.speedloader,
  CharId.doctor,
  CharId.hunter,
  CharId.smoker,
  CharId.roulette,
  CharId.dualgun,
  CharId.paparazzi,
  CharId.voodoo,
  CharId.resetter,
  // 능력이 게임 종반에 발동 — 그 순간에 공개(시작 공개 아님).
  CharId.pacifist, // 6장전 승리(specialWin 'pacifist')
  CharId.duelist, // 결투 자동승(specialWin 'duelist')
};

/// ???가 이 실제 직업으로 변신했을 때 게임 시작 즉시 정체를 공개할지(순수함수).
bool mysteryRevealsAtStart(CharId effective) =>
    kMysteryStartRevealChars.contains(effective);

/// enum index(정수) → CharId. 범위 밖/누락이면 [CharId.none].
CharId charFromIndex(int? i) =>
    (i == null || i < 0 || i >= CharId.values.length)
        ? CharId.none
        : CharId.values[i];

/// Deterministic pseudo-random roll in [0,1) from a string key — identical on
/// every client/platform (pure 32-bit FNV-1a, no dart:math Random involved).
double seededRoll(String key) {
  var h = 0x811c9dc5;
  for (final c in key.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  // Mix once more so short keys spread well.
  h ^= h >> 13;
  h = (h * 0x5bd1e995) & 0xFFFFFFFF;
  h ^= h >> 15;
  return h / 0x100000000;
}
