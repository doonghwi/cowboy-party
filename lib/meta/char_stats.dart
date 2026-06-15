/// 캐릭터 승률 트래커 (#12). 밸런스 패치용 집계.
///
/// 게임이 끝날 때 **각 클라이언트가 자기 캐릭터의 결과만** 기록한다(중복 없음).
/// 집계 경로: `/charstats/<charIndex>/{games, wins}` (party DB, 공개 read).
/// 승리 = 1등(최후의 1인 또는 결투 승). cowboy.gg 사이트가 이 노드를 읽어 보여준다.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../game/characters.dart';
import '../online/online_service.dart' show OnlineService;

class CharStats {
  CharStats._();
  static final CharStats I = CharStats._();

  DatabaseReference? _node(int charIndex) {
    try {
      return FirebaseDatabase.instanceFor(
              app: Firebase.app(), databaseURL: OnlineService.databaseUrl)
          .ref('charstats/$charIndex');
    } catch (_) {
      return null;
    }
  }

  /// 온라인 게임 종료 시 1회(게임당 내 좌석만) 호출. 베스트에포트(실패 무시).
  Future<void> record(CharId char, {required bool won}) async {
    if (char == CharId.none || char == CharId.mystery) return;
    final ref = _node(char.index);
    if (ref == null) return;
    Future<void> inc(String key) =>
        ref.child(key).runTransaction((cur) {
          final n = cur is int ? cur : 0;
          return Transaction.success(n + 1);
        });
    try {
      await inc('games');
      if (won) await inc('wins');
    } catch (_) {
      // 통계 실패는 게임 흐름과 무관 — 조용히 무시.
    }
  }
}
