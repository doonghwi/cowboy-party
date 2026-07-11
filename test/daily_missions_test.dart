// 데일리 미션 진행 전체 흐름 — 기존 meta_logic_test는 첫 승리(play1+firstwin)만
// 봤다. 여기선 **신선한 Meta 상태**(파일별 격리 isolate)에서 1→3→5판 진행과
// 승리 전용 firstwin, 중복 미지급을 순차로 못박는다.
// (리텐션 A 도입 후 noteGamePlayed는 GameEndRewards를 반환 — 데일리 라인만 필터해 검증.)
import 'package:cowboy_party/meta/meta_service.dart';
import 'package:cowboy_party/meta/retention.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Meta.I.init();
  });

  int goldOf(String key) =>
      kDailyMissions.firstWhere((m) => m.key == key).gold;
  String labelOf(String key) =>
      kDailyMissions.firstWhere((m) => m.key == key).label;
  Set<String> daily(GameEndRewards r) =>
      r.lines.where((l) => l.startsWith('데일리')).toSet();

  test('미션 진행: 1판→play1, 첫승→firstwin, 3판→play3, 5판→play5 (중복 미지급)', () {
    var coins = Meta.I.coins;

    // 1판차(패배): play1만 달성. firstwin은 승수 0이라 미달성.
    var rew = Meta.I.noteGamePlayed(won: false);
    expect(daily(rew), contains('데일리 · ${labelOf('play1')}'));
    expect(daily(rew).any((l) => l.contains(labelOf('firstwin'))), isFalse,
        reason: '아직 승리 0');
    expect(Meta.I.dailyGames, 1);
    expect(Meta.I.dailyWins, 0);
    coins += rew.coinsGained;
    expect(rew.coinsGained, goldOf('play1'), reason: '1판차 지급 = play1 골드');
    expect(Meta.I.coins, coins);

    // 2판차(패배): 새 데일리 달성 없음(play1 이미·play3는 3판 필요).
    rew = Meta.I.noteGamePlayed(won: false);
    expect(daily(rew), isEmpty);
    coins += rew.coinsGained; // 데일리 외(레벨업 등) 지급이 있어도 정합 유지
    expect(Meta.I.coins, coins, reason: '미달성이면 데일리 지급 없음');

    // 3판차(승리): play3(3판) + firstwin(첫 승) 동시 달성.
    rew = Meta.I.noteGamePlayed(won: true);
    expect(
        daily(rew),
        containsAll(<String>{
          '데일리 · ${labelOf('play3')}',
          '데일리 · ${labelOf('firstwin')}',
        }));
    expect(Meta.I.dailyGames, 3);
    expect(Meta.I.dailyWins, 1);
    coins += rew.coinsGained;
    expect(rew.coinsGained, goldOf('play3') + goldOf('firstwin'));
    expect(Meta.I.coins, coins);

    // 4판차(승리): 새 데일리 달성 없음. firstwin은 이미 받음(중복 미지급).
    rew = Meta.I.noteGamePlayed(won: true);
    expect(daily(rew), isEmpty, reason: 'firstwin 재지급 금지');
    coins += rew.coinsGained;
    expect(Meta.I.coins, coins);

    // 5판차(패배): play5 달성.
    rew = Meta.I.noteGamePlayed(won: false);
    expect(daily(rew), contains('데일리 · ${labelOf('play5')}'));
    expect(Meta.I.dailyGames, 5);
    coins += rew.coinsGained;
    expect(rew.coinsGained, goldOf('play5'));
    expect(Meta.I.coins, coins);

    // 6판차: 더 받을 데일리 없음.
    rew = Meta.I.noteGamePlayed(won: true);
    expect(daily(rew), isEmpty);
    coins += rew.coinsGained;
    expect(Meta.I.coins, coins);
  });
}
