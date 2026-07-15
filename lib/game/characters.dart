/// Character (총잡이) definitions for Cowboy Party.
///
/// Every player picks one character; its ability bends the base rules in
/// exactly one place. All randomness ("10% / 50% 확률") must be identical on
/// every client because each client independently replays the turn history —
/// so abilities never call [Random]. They use [seededRoll], a pure hash of
/// (roomSeed, turn, seat, salt) that every client computes identically.
library;

import 'package:flutter/material.dart';

import 'char_core.dart';

// 순수 규칙 코어(CharId·SpecialSlot·seededRoll·kCurseFuse·mystery 로직·
// charFromIndex 등)는 char_core.dart 로 분리됐다(헤드리스 봇 러너 재사용용).
// 그대로 re-export 하므로 앱 코드는 지금처럼 characters.dart 하나만 import 해도
// 전부 쓸 수 있다.
export 'char_core.dart';

class CharDef {
  final CharId id;
  final String name;

  /// 캐릭터 대사 한 줄(2026-07-15 사용자 선택 C안) — 상점/선택 화면에서
  /// 능력 설명 **위 별도 칸**에 표시. 서부극 말투 플레이버.
  final String quote;
  final String ability; // 수치 포함 한 문장 (UX_UI.md §6)
  final IconData icon;
  final Color color;
  final int cost; // 코인 해금 비용, 0 = 기본 제공
  final SpecialSlot slot; // 특수행동 UI 배치 (D3)

  const CharDef({
    required this.id,
    required this.name,
    required this.quote,
    required this.ability,
    required this.icon,
    required this.color,
    required this.cost,
    this.slot = SpecialSlot.none,
  });
}

const List<CharDef> kCharacters = [
  CharDef(
    id: CharId.commoner,
    name: '일반인',
    quote: '"특별한 재주는 없어. 그래도 총은 쏠 줄 알지."',
    ability: '능력 없이 장전·방어·빵야로만 싸우는 기본 총잡이예요',
    icon: Icons.person,
    color: Color(0xFF8A7A5E),
    cost: 0,
  ),
  CharDef(
    id: CharId.prepper,
    name: '준비자',
    quote: '"준비된 자가 첫 방을 쏘는 법."',
    ability: '총알 1발을 장전한 채로 시작해요',
    icon: Icons.work_history,
    color: Color(0xFFD9A441),
    cost: 1000,
  ),
  CharDef(
    id: CharId.sniper,
    name: '스나이퍼',
    quote: '"방패 뒤에 숨어도 소용없지."',
    ability: '빵야가 20% 확률로 방어를 뚫어요',
    icon: Icons.my_location,
    color: Color(0xFF9E2B25),
    cost: 1500,
  ),
  CharDef(
    id: CharId.speedloader,
    name: '스피드로더',
    quote: '"내 손은 눈보다 빠르다."',
    ability: '장전할 때 50% 확률로 2발이 들어가요',
    icon: Icons.fast_forward,
    color: Color(0xFFC8541E),
    cost: 2000,
  ),
  CharDef(
    id: CharId.doctor,
    name: '의사',
    quote: '"한 번은 살려주지. 공짜는 아니지만."',
    ability: '게임당 1번, 죽을 공격을 버텨요 — 대신 그 직후 총알이 0이 돼요',
    icon: Icons.healing,
    color: Color(0xFF2E6E5A),
    cost: 2500,
  ),
  CharDef(
    id: CharId.smoker,
    name: '스모커',
    quote: '"연기 속에선 아무도 날 못 맞혀."',
    ability: '연막(게임당 2번, 행동과 함께): 그 턴 들어오는 공격을 발당 50% 확률로 피해요',
    icon: Icons.cloud,
    color: Color(0xFF6B7A8F),
    cost: 3000,
    slot: SpecialSlot.parallel,
  ),
  CharDef(
    id: CharId.hunter,
    name: '사냥꾼',
    quote: '"덫에 걸린 건 네 총알이야."',
    ability: '덫(게임당 1번, 그 턴 행동 불가): 나를 쏜 일반탄을 전부 돌려보내요',
    icon: Icons.crisis_alert,
    color: Color(0xFF7A3E18),
    cost: 3500,
    slot: SpecialSlot.turnSlot,
  ),
  CharDef(
    id: CharId.resetter,
    name: '리셋터',
    quote: '"오늘 일은 없던 걸로 하지."',
    ability: '무효(게임당 1번, 그 턴 행동 불가): 그 턴 다른 모두의 행동을 없던 일로 만들어요',
    icon: Icons.restart_alt,
    color: Color(0xFF2E5E8E),
    cost: 4000,
    slot: SpecialSlot.turnSlot,
  ),
  CharDef(
    id: CharId.duelist,
    name: '결투가',
    quote: '"마지막 결투는 언제나 내 것."',
    ability: '반응속도 결투(전원 동시 사망)에 가면 반드시 이겨요 (결투가끼리면 무효)',
    icon: Icons.sports_martial_arts,
    color: Color(0xFF3A2A55),
    cost: 4500,
  ),
  CharDef(
    id: CharId.pacifist,
    name: '평화주의자',
    quote: '"총구를 내려놔. 그게 이기는 길이야."',
    ability: '빵야를 쏠 수 없어요. 대신 장전을 6번 채우면 그 즉시 승리해요',
    icon: Icons.spa,
    color: Color(0xFF4E8D7C),
    cost: 5000,
  ),
  CharDef(
    id: CharId.shadow,
    name: '그림자',
    quote: '"내 패는 아무도 못 봐."',
    ability: '장전·방어와 총알 수가 상대에게 보이지 않아요 (빵야·피격 시 방어는 드러나요)',
    icon: Icons.visibility_off,
    color: Color(0xFF2B2B3A),
    cost: 5500,
  ),
  CharDef(
    id: CharId.roulette,
    name: '러시안룰렛',
    quote: '"운명이 정해줄 거야 — 너인지, 나인지."',
    ability: '운명의 방아쇠(한 턴): 50:50으로 나 또는 상대에게 총알을 쏴요. 상대를 향하면 일반탄처럼 방어에 막히고 덫에 반사돼요',
    icon: Icons.casino,
    color: Color(0xFF8E1E1E),
    cost: 6000,
    slot: SpecialSlot.turnSlot,
  ),
  CharDef(
    id: CharId.dualgun,
    name: '쌍권총',
    quote: '"한 발로는 부족하지."',
    ability: '더블 빵야(한 턴): 총알 2발로 두 명을 동시에 쏴요',
    icon: Icons.filter_2,
    color: Color(0xFFB5642A),
    cost: 6500,
    slot: SpecialSlot.turnSlot,
  ),
  CharDef(
    id: CharId.paparazzi,
    name: '파파라치',
    quote: '"네 다음 수, 이미 찍어뒀어."',
    ability: '엿보기(게임당 1번): 한 명의 이번 턴 행동을 미리 보고 내 행동을 정해요',
    icon: Icons.photo_camera,
    color: Color(0xFF4A6FA5),
    cost: 7000,
    slot: SpecialSlot.parallel,
  ),
  CharDef(
    id: CharId.voodoo,
    name: '부두술사',
    quote: '"저주는 천천히, 그러나 반드시 닿는다."',
    ability: '저주(턴당 1번, 그 턴 행동 불가): 한 명을 10턴 뒤 쓰러뜨려요. 부두술사가 먼저 죽으면 풀려요',
    icon: Icons.auto_fix_high,
    color: Color(0xFF5B3A8E),
    cost: 7500,
    slot: SpecialSlot.turnSlot,
  ),
  // ??? (mystery) 캐릭터 비활성화 — 선택 화면·게임 설명에서 제외(kCharacters를
  // 순회하는 곳이 모두 자동으로 빠진다). enum CharId.mystery와 resolveMystery/
  // effectiveChar/공개셋은 남겨두어(휴면) 인덱스와 참조가 깨지지 않게 한다.
  // 다시 켜려면 아래 CharDef 주석만 해제하면 된다.
  // CharDef(
  //   id: CharId.mystery,
  //   name: '???',
  //   quote: '"정체는 방아쇠가 말해줄 거야."',
  //   ability: '미공개로 시작 — 능력을 처음 쓰면 정체가 드러나요. 직업은 매 게임 랜덤 (모든 캐릭터를 가지면 구매 가능)',
  //   icon: Icons.help_center,
  //   color: Color(0xFF3A3A3A),
  //   cost: 10000,
  // ),
];

/// CharId → UI 정의(CharDef). 누락이면 첫 캐릭터로 폴백. (순수 규칙엔 char_core만
/// 필요하고, 이 함수는 아이콘/색이 필요한 화면 전용이라 characters.dart 에 남긴다.)
CharDef charDef(CharId id) =>
    kCharacters.firstWhere((c) => c.id == id, orElse: () => kCharacters[0]);
