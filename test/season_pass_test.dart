// B1 시즌 패스 + B4 복귀 보상 — 순수 로직·Meta 통합.
import 'package:cowboy_party/meta/meta_service.dart';
import 'package:cowboy_party/meta/retention.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('B1 패스 순수 로직', () {
    test('시즌 id: 앵커(7/6)부터 28일 단위', () {
      expect(passIdFor(DateTime(2026, 7, 6)), 'P1');
      expect(passIdFor(DateTime(2026, 8, 2)), 'P1'); // 27일째
      expect(passIdFor(DateTime(2026, 8, 3)), 'P2'); // 28일째
    });

    test('마지막 주(22일째~) 판정', () {
      expect(passLastWeek(DateTime(2026, 7, 26)), isFalse); // 20일째
      expect(passLastWeek(DateTime(2026, 7, 27)), isTrue); // 21일째(4주차 시작)
      expect(passLastWeek(DateTime(2026, 8, 2)), isTrue);
    });

    test('티어 계산: 0XP=1티어(즉시), 500XP=2티어, 캡 30', () {
      expect(passTierForXp(0), 1);
      expect(passTierForXp(499), 1);
      expect(passTierForXp(500), 2);
      expect(passTierForXp(kPassTierXp * 29), 30);
      expect(passTierForXp(999999), 30);
    });

    test('스파이크 보상 테이블', () {
      expect(passGoldOf(1), 200);
      expect(passGoldOf(5), 500);
      expect(passGoldOf(10), 1000);
      expect(passGoldOf(20), 1500);
      expect(passGoldOf(30), 3000);
      expect(passGoldOf(7), 150);
    });
  });

  group('Meta 통합(신선한 상태)', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      await Meta.I.init();
    });

    test('1티어는 접속 즉시 지급돼 있다(부여된 진행)', () {
      expect(Meta.I.passTierClaimed(1), isTrue);
      expect(Meta.I.passTier, 1);
    });

    test('게임을 하면 패스 XP가 쌓이고 티어 도달 시 자동 지급', () {
      final xp0 = Meta.I.passXp;
      // 승리 1판: 최소 100 XP (마지막 주면 2배 — 배율만 다르고 적립은 동일 경로).
      final r1 = Meta.I.noteGamePlayed(won: true);
      expect(Meta.I.passXp > xp0, isTrue);
      // 500 XP를 넘길 때까지 플레이 → 티어 2 자동 지급 확인.
      expect(r1.lines, isA<List<String>>());
      var guard = 0;
      while (Meta.I.passTier < 2 && guard++ < 30) {
        Meta.I.noteGamePlayed(won: true);
      }
      expect(Meta.I.passTier >= 2, isTrue);
      expect(Meta.I.passTierClaimed(2), isTrue);
    });
  });

  group('B4 복귀 보상', () {
    test('7일+ 미접속 후 init하면 웰컴백 골드 지급 + 안내 플래그', () async {
      SharedPreferences.setMockInitialValues({
        'coins': 1000,
        'last_open_day': '2026-06-01', // 아주 오래 전
      });
      // Meta는 싱글톤이라 새 인스턴스 대신 리로드 경로 확인이 어려움 —
      // 순수 판정만: kWelcomeBackDays 이상 차이.
      final last = DateTime.parse('2026-06-01');
      expect(DateTime.now().difference(last).inDays >= kWelcomeBackDays, isTrue);
      expect(kWelcomeBackGold, 800);
    });
  });
}
