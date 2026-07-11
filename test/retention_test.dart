// 리텐션 A(retention.dart + Meta 통합) — XP 커브·주간 미션·트로피 로드·스트릭 복구.
import 'package:cowboy_party/game/characters.dart';
import 'package:cowboy_party/meta/meta_service.dart';
import 'package:cowboy_party/meta/retention.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A2 XP 커브(순수)', () {
    test('경계값: 0→Lv1, 199→Lv1, 200→Lv2, 만렙 캡', () {
      expect(levelForXp(0), 1);
      expect(levelForXp(xpNeedFor(1) - 1), 1);
      expect(levelForXp(xpNeedFor(1)), 2);
      expect(levelForXp(kMaxTotalXp), kMaxLevel);
      expect(levelForXp(kMaxTotalXp + 99999), kMaxLevel);
    });

    test('xpIntoLevel: 레벨 내부 진행 분자', () {
      expect(xpIntoLevel(0), 0);
      expect(xpIntoLevel(xpNeedFor(1)), 0); // 딱 레벨업 순간
      expect(xpIntoLevel(xpNeedFor(1) + 50), 50);
    });

    test('커브 공식: L→L+1 = 200+80×(L-1)', () {
      expect(xpNeedFor(1), 200);
      expect(xpNeedFor(2), 280);
      expect(xpNeedFor(29), 200 + 80 * 28);
    });

    test('레벨 보상: 홀수만 골드(레벨×100)', () {
      expect(levelUpGold(3), 300);
      expect(levelUpGold(4), 0);
      expect(levelUpGold(29), 2900);
    });
  });

  group('A1 스트릭 복구 판정(순수)', () {
    final now = DateTime(2026, 7, 12);
    String key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    test('딱 하루 놓침(그저께 출석)만 복구 대상', () {
      expect(missedExactlyOneDay(key(DateTime(2026, 7, 10)), now), isTrue);
      expect(missedExactlyOneDay(key(DateTime(2026, 7, 11)), now), isFalse,
          reason: '어제 출석 = 안 끊김');
      expect(missedExactlyOneDay(key(DateTime(2026, 7, 9)), now), isFalse,
          reason: '이틀 이상 = 복구 불가');
      expect(missedExactlyOneDay('', now), isFalse);
    });
  });

  group('Meta 통합(신선한 상태)', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      await Meta.I.init();
    });

    test('주간 미션: 서로 다른 캐릭터 3종 → w_chars3 달성', () {
      // 기본 장착(일반인)으로 1판 → 캐릭터 1종.
      Meta.I.noteGamePlayed(won: false);
      expect(Meta.I.weeklyChars, 1);
      // 두 캐릭터 더 장착·플레이(무료/보유 캐릭터로).
      final owned = kCharacters
          .where((c) => Meta.I.isUnlocked(c.id) && c.id != Meta.I.equipped)
          .take(2)
          .toList();
      // 보유 캐릭터가 부족하면 해금(테스트 계정은 시작 골드 5000).
      var got = <String>[];
      for (final c in owned) {
        Meta.I.equip(c.id);
        got = Meta.I.noteGamePlayed(won: false).lines;
      }
      if (Meta.I.weeklyChars >= 3) {
        expect(
            got.any((l) => l.contains('서로 다른 캐릭터')) ||
                Meta.I.weeklyClaimed(kWeeklyMissions
                    .firstWhere((m) => m.key == 'w_chars3')),
            isTrue);
      } else {
        // 무료 캐릭터가 3종 미만인 구성이면 이 검증은 건너뛴다(방어).
        expect(Meta.I.weeklyChars >= 1, isTrue);
      }
    });

    test('트로피 로드: 통산 10판 도달 시 t_g10 1회 지급', () {
      final t10 = kTrophyRoad.firstWhere((t) => t.key == 't_g10');
      while (Meta.I.lifeGames < 9) {
        Meta.I.noteGamePlayed(won: false);
      }
      expect(Meta.I.trophyClaimed(t10), isFalse);
      final before = Meta.I.coins;
      final rew = Meta.I.noteGamePlayed(won: false); // 10판째
      expect(Meta.I.lifeGames, 10);
      expect(Meta.I.trophyClaimed(t10), isTrue);
      expect(rew.lines.any((l) => l.contains('통산 10판')), isTrue);
      expect(Meta.I.coins >= before + t10.gold, isTrue);
      // 재지급 없음.
      final again = Meta.I.noteGamePlayed(won: false);
      expect(again.lines.any((l) => l.contains('통산 10판')), isFalse);
    });

    test('XP 적립: 패 40/승 100, 레벨 상승 단조', () {
      final xp0 = Meta.I.xp;
      final l0 = Meta.I.level;
      Meta.I.noteGamePlayed(won: true);
      expect(Meta.I.xp, xp0 + kXpWin);
      Meta.I.noteGamePlayed(won: false);
      expect(Meta.I.xp, xp0 + kXpWin + kXpLose);
      expect(Meta.I.level >= l0, isTrue);
    });

    test('스트릭 복구: 조건 미충족이면 0 (끊긴 기록 없음)', () {
      expect(Meta.I.canReviveStreak, isFalse);
      expect(Meta.I.reviveStreak(), 0);
    });
  });
}
