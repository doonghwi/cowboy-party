/// Character (총잡이) definitions for Cowboy Party.
///
/// Every player picks one character; its ability bends the base rules in
/// exactly one place. All randomness ("10% / 50% 확률") must be identical on
/// every client because each client independently replays the turn history —
/// so abilities never call [Random]. They use [seededRoll], a pure hash of
/// (roomSeed, turn, seat, salt) that every client computes identically.
library;

import 'package:flutter/material.dart';

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
}

class CharDef {
  final CharId id;
  final String name;
  final String ability; // 수치 포함 한 문장 (UX_UI.md §6)
  final IconData icon;
  final Color color;
  final int cost; // 코인 해금 비용, 0 = 기본 제공

  const CharDef({
    required this.id,
    required this.name,
    required this.ability,
    required this.icon,
    required this.color,
    required this.cost,
  });
}

const List<CharDef> kCharacters = [
  CharDef(
    id: CharId.prepper,
    name: '준비자',
    ability: '총알 1발을 장전한 채로 시작한다',
    icon: Icons.work_history,
    color: Color(0xFFD9A441),
    cost: 0,
  ),
  CharDef(
    id: CharId.sniper,
    name: '스나이퍼',
    ability: '빵야가 10% 확률로 방어를 무시한다',
    icon: Icons.my_location,
    color: Color(0xFF9E2B25),
    cost: 0,
  ),
  CharDef(
    id: CharId.speedloader,
    name: '스피드로더',
    ability: '장전할 때 50% 확률로 2발이 들어간다',
    icon: Icons.fast_forward,
    color: Color(0xFFC8541E),
    cost: 200,
  ),
  CharDef(
    id: CharId.doctor,
    name: '의사',
    ability: '게임당 1번, 죽을 공격을 자동으로 버텨낸다',
    icon: Icons.healing,
    color: Color(0xFF2E6E5A),
    cost: 250,
  ),
  CharDef(
    id: CharId.smoker,
    name: '스모커',
    ability: '연막(게임당 2번, 행동과 함께): 그 턴 공격을 50% 확률로 회피',
    icon: Icons.cloud,
    color: Color(0xFF6B7A8F),
    cost: 300,
  ),
  CharDef(
    id: CharId.hunter,
    name: '사냥꾼',
    ability: '덫(게임당 1번, 그 턴 행동 불가): 나를 쏜 일반탄을 전부 반사한다',
    icon: Icons.crisis_alert,
    color: Color(0xFF7A3E18),
    cost: 350,
  ),
  CharDef(
    id: CharId.duelist,
    name: '결투가',
    ability: '둘만 남으면 그 즉시 승리한다 (결투가끼리면 무효)',
    icon: Icons.sports_martial_arts,
    color: Color(0xFF3A2A55),
    cost: 450,
  ),
  CharDef(
    id: CharId.pacifist,
    name: '평화주의자',
    ability: '빵야를 쏠 수 없다. 장전을 6번 채우면 그 즉시 승리',
    icon: Icons.spa,
    color: Color(0xFF4E8D7C),
    cost: 500,
  ),
  CharDef(
    id: CharId.shadow,
    name: '그림자',
    ability: '장전·방어와 총알 수가 상대에게 보이지 않는다 (빵야·피격 시 방어는 드러남)',
    icon: Icons.visibility_off,
    color: Color(0xFF2B2B3A),
    cost: 550,
  ),
  CharDef(
    id: CharId.roulette,
    name: '러시안룰렛',
    ability: '운명의 방아쇠(상시): 총알 없이 즉시 발사 — 50:50로 나/상대 중 한 명 사망 (상대가 방어하면 내가 죽음)',
    icon: Icons.casino,
    color: Color(0xFF8E1E1E),
    cost: 600,
  ),
  CharDef(
    id: CharId.dualgun,
    name: '쌍권총',
    ability: '더블 빵야(상시): 총알 2발로 두 명을 동시에 쏜다',
    icon: Icons.filter_2,
    color: Color(0xFFB5642A),
    cost: 650,
  ),
  CharDef(
    id: CharId.paparazzi,
    name: '파파라치',
    ability: '엿보기(게임당 1회): 한 명의 이번 턴 행동을 미리 보고 내 행동을 정한다',
    icon: Icons.photo_camera,
    color: Color(0xFF4A6FA5),
    cost: 700,
  ),
  CharDef(
    id: CharId.voodoo,
    name: '부두술사',
    ability: '저주(상시): 한 명을 10턴 뒤 사망하게 한다. 부두술사가 죽으면 저주가 풀린다',
    icon: Icons.auto_fix_high,
    color: Color(0xFF5B3A8E),
    cost: 750,
  ),
  CharDef(
    id: CharId.mystery,
    name: '???',
    ability: '미공개로 시작 — 능력을 처음 쓰면 정체가 드러난다. 직업은 매 게임 랜덤. (모든 캐릭터를 가지면 구매 가능)',
    icon: Icons.help_center,
    color: Color(0xFF3A3A3A),
    cost: 1000,
  ),
];

/// 부두 저주 도화선: 건 턴으로부터 이 턴 수 뒤에 대상이 사망.
const int kCurseFuse = 10;

/// ???(mystery)가 매 게임 무작위로 변신할 수 있는 직업 풀
/// (none·mystery 제외 — 즉 실제로 플레이 가능한 모든 직업).
List<CharId> get kMysteryPool => [
      for (final c in kCharacters)
        if (c.id != CharId.mystery) c.id
    ];

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

CharDef charDef(CharId id) =>
    kCharacters.firstWhere((c) => c.id == id, orElse: () => kCharacters[0]);

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
