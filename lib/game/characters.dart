/// Character (총잡이) definitions for Cowboy Party.
///
/// Every player picks one character; its ability bends the base rules in
/// exactly one place. All randomness ("10% / 50% 확률") must be identical on
/// every client because each client independently replays the turn history —
/// so abilities never call [Random]. They use [seededRoll], a pure hash of
/// (roomSeed, turn, seat, salt) that every client computes identically.
library;

import 'package:flutter/material.dart';

enum CharId {
  none,
  sniper, // 스나이퍼: 빵야가 10% 확률로 방어 무시
  speedloader, // 스피드로더: 장전 시 50% 확률로 +2발
  duelist, // 결투가: 1대1이 되면 즉시 승리 (결투가 둘이면 무효)
  prepper, // 준비자: 장전 1 상태로 시작
  doctor, // 의사: 게임당 1회, 치명상을 자동으로 무효(자힐)
  hunter, // 사냥꾼: 게임당 1회 '덫'(그 턴 행동 불가) — 일반탄 반사
  smoker, // 스모커: '연막' 게임당 2회(행동과 병행) — 공격당 50% 회피
  pacifist, // 평화주의자: 빵야 불가, 장전 6회 성공 시 즉시 승리
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
];

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
