// 메타 로직(코인·해금·출석·미션·닉네임) 속성 테스트.
//
// Meta는 SharedPreferences 기반 싱글톤이라 Firebase 없이도 동작해야 한다
// (cloudUid는 미로그인 시 null → _save/_mirror는 안전한 no-op). 여기서는
// Firebase에 닿지 않는 동기 메서드 + 순수함수 nicknameChangeGate만 검증한다.
import 'package:cowboy_party/game/characters.dart';
import 'package:cowboy_party/meta/meta_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('nicknameChangeGate (닉네임 변경 사전 판정 — 전역점유 이전 게이트)', () {
    test('빈 문자열·공백뿐 → empty', () {
      expect(
          nicknameChangeGate(
              requested: '   ', current: 'A', nicknameSet: true, tickets: 5),
          NicknameChangeGate.empty);
    });

    test('현재 닉네임과 같으면 → unchanged (공백 트림 후 비교)', () {
      expect(
          nicknameChangeGate(
              requested: 'Alice',
              current: 'Alice',
              nicknameSet: true,
              tickets: 5),
          NicknameChangeGate.unchanged);
      expect(
          nicknameChangeGate(
              requested: '  Alice ',
              current: 'Alice',
              nicknameSet: true,
              tickets: 5),
          NicknameChangeGate.unchanged);
    });

    test('이미 설정 + 변경권 0 → needTicket (claimNickname 이전에 차단 = 버그수정 핵심)', () {
      // 이 판정이 claimNickname(전역 점유·예전 이름 해제)보다 먼저 와야
      // 변경권 없는 시도가 레지스트리를 오염시키지 않는다.
      expect(
          nicknameChangeGate(
              requested: 'Bob',
              current: 'Alice',
              nicknameSet: true,
              tickets: 0),
          NicknameChangeGate.needTicket);
    });

    test('첫 설정(미설정)은 변경권 없이도 → proceed', () {
      expect(
          nicknameChangeGate(
              requested: 'Alice',
              current: '',
              nicknameSet: false,
              tickets: 0),
          NicknameChangeGate.proceed);
    });

    test('이미 설정 + 변경권 보유 → proceed', () {
      expect(
          nicknameChangeGate(
              requested: 'Bob',
              current: 'Alice',
              nicknameSet: true,
              tickets: 1),
          NicknameChangeGate.proceed);
    });

    test('미설정 상태에선 변경권 0이어도 needTicket이 아니다(첫 설정 무료)', () {
      expect(
          nicknameChangeGate(
              requested: 'Zed',
              current: '',
              nicknameSet: false,
              tickets: 0),
          isNot(NicknameChangeGate.needTicket));
    });
  });

  group('winCoins 보상 곡선', () {
    test('2인 80, 6인 140, 범위 밖은 클램프', () {
      expect(winCoins(2), 80);
      expect(winCoins(3), 95);
      expect(winCoins(6), 140);
      expect(winCoins(1), 80, reason: '2로 클램프');
      expect(winCoins(99), 140, reason: '6으로 클램프');
    });
  });

  group('Meta 싱글톤: 코인·해금·출석·미션', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      await Meta.I.init();
    });

    test('신규 계정은 시작 골드 + 기본 캐릭터 장착', () {
      expect(Meta.I.coins, kNewAccountGold);
      expect(Meta.I.isUnlocked(CharId.commoner), isTrue);
      expect(Meta.I.equipped, CharId.commoner);
    });

    test('addCoins/trySpend: 음수·초과는 무시, 정상 가감', () {
      final c0 = Meta.I.coins;
      Meta.I.addCoins(100);
      expect(Meta.I.coins, c0 + 100);
      Meta.I.addCoins(0);
      Meta.I.addCoins(-50);
      expect(Meta.I.coins, c0 + 100, reason: '0·음수 추가는 무시');
      expect(Meta.I.trySpend(Meta.I.coins + 1), isFalse,
          reason: '잔액 초과 지출 거절');
      final c1 = Meta.I.coins;
      expect(Meta.I.trySpend(100), isTrue);
      expect(Meta.I.coins, c1 - 100);
    });

    test('unlock: 못 사면 false(차감 없음), 사면 true(차감), 재구매는 공짜 true', () {
      // 잔액 정리 후 정확히 통제.
      Meta.I.addCoins(5000);
      final sniper = charDef(CharId.sniper); // cost 1500
      if (!Meta.I.isUnlocked(CharId.sniper)) {
        final before = Meta.I.coins;
        expect(Meta.I.unlock(CharId.sniper), isTrue);
        expect(Meta.I.coins, before - sniper.cost);
      }
      expect(Meta.I.isUnlocked(CharId.sniper), isTrue);
      // 이미 보유한 캐릭터 재구매는 차감 없이 true.
      final c = Meta.I.coins;
      expect(Meta.I.unlock(CharId.sniper), isTrue);
      expect(Meta.I.coins, c);
    });

    test('unlock 실패: 잔액 부족이면 해금 안 되고 차감 없음', () {
      // 비싼 미보유 캐릭터를 찾고 잔액을 그보다 낮게 만든다.
      final target = kCharacters.firstWhere(
          (d) => d.id != CharId.mystery && !Meta.I.isUnlocked(d.id),
          orElse: () => charDef(CharId.mystery));
      if (target.id != CharId.mystery) {
        // 잔액을 target.cost 미만으로.
        Meta.I.trySpend(Meta.I.coins); // 0으로
        expect(Meta.I.coins, 0);
        expect(Meta.I.unlock(target.id), isFalse);
        expect(Meta.I.isUnlocked(target.id), isFalse);
        expect(Meta.I.coins, 0, reason: '실패 시 차감 없음');
      }
    });

    test('equip은 보유한 캐릭터만 — 미보유는 무시', () {
      expect(Meta.I.isUnlocked(CharId.sniper), isTrue);
      Meta.I.equip(CharId.sniper);
      expect(Meta.I.equipped, CharId.sniper);
      // 확실히 미보유인 캐릭터를 찾아 장착 시도 → 무시.
      final notOwned = kCharacters
          .firstWhere((d) => !Meta.I.isUnlocked(d.id), orElse: () => charDef(CharId.sniper));
      if (notOwned.id != CharId.sniper) {
        Meta.I.equip(notOwned.id);
        expect(Meta.I.equipped, CharId.sniper, reason: '미보유 장착 무시');
      }
    });

    test('??? 해금 게이트: 다른 전 캐릭터 보유 전엔 불가, 보유 후 가능', () {
      // 현재 일부만 보유 → canBuyMystery false.
      if (!Meta.I.canBuyMystery) {
        Meta.I.addCoins(1); // 잔액과 무관하게 게이트가 막아야 함
        expect(Meta.I.unlock(CharId.mystery), isFalse,
            reason: '전 캐릭터 미보유 시 ??? 불가');
      }
      // 전 캐릭터 해금.
      Meta.I.addCoins(1000000);
      for (final d in kCharacters) {
        if (d.id != CharId.mystery) Meta.I.unlock(d.id);
      }
      expect(Meta.I.canBuyMystery, isTrue);
      expect(Meta.I.unlock(CharId.mystery), isTrue);
      expect(Meta.I.isUnlocked(CharId.mystery), isTrue);
    });

    test('데일리 출석: 첫 수령은 사이클 1일차 금액, 재수령은 0', () {
      // (앞 테스트들에서 claimDaily를 부른 적 없음 → 오늘 첫 수령.)
      if (Meta.I.canClaimDaily) {
        final got = Meta.I.claimDaily();
        expect(got, kDailyCycle[0], reason: '첫 수령 = 사이클 1일차');
        expect(Meta.I.canClaimDaily, isFalse);
        expect(Meta.I.claimDaily(), 0, reason: '같은 날 재수령 0');
      }
    });

    test('데일리 미션: 첫 승리 시 play1+firstwin 동시 달성·지급', () {
      final before = Meta.I.coins;
      final newly = Meta.I.noteGamePlayed(won: true);
      final keys = newly.map((m) => m.key).toSet();
      expect(keys.contains('play1'), isTrue);
      expect(keys.contains('firstwin'), isTrue);
      final reward =
          kDailyMissions.where((m) => keys.contains(m.key)).fold<int>(0, (a, m) => a + m.gold);
      expect(Meta.I.coins, before + reward, reason: '달성 보상 합산 지급');
      expect(Meta.I.dailyGames, 1);
      expect(Meta.I.dailyWins, 1);
      // 같은 미션 재지급 없음.
      final again = Meta.I.noteGamePlayed(won: false);
      expect(again.map((m) => m.key).contains('play1'), isFalse);
    });
  });
}
