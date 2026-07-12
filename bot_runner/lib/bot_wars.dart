import 'dart:math';

import 'bot_client.dart';
import 'bot_pool.dart';
import 'config.dart';
import 'rtdb.dart';

int? _asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
Map? _asMap(Object? v) => v is Map ? v : null;

/// 봇 자체전 — **사람이 어딘가에서 게임 중일 때만** 봇 3~5명이 **비공개 방**에서
/// 자기들끼리 한 판 하고, 승자가 주간 랭킹 점수를 얻는다(playSeatedGame 안의
/// 기존 _recordWin 경로 그대로).
///
/// 의도: 랭킹 보드의 활력이 실제 사용자 활동과 비례하게 — 아무도 안 놀 때 봇
/// 점수가 24시간 쌓이면 부자연스럽다. 방이 비공개(public:false)라 로비를 어지럽히지
/// 않고 사람이 들어올 수도 없으며, 새 참가자 수용·로비 북적임은 SocialSim 공개방이
/// 계속 담당한다(봇 전원이 자체전에 빠지지 않음 — 동시 1판 + 예비 보존 + 휴식).
class BotWars {
  BotWars(this._rtdb, this._pool);
  final Rtdb _rtdb;
  final BotPool _pool;
  final _rng = Random();

  void _log(String m) => print('[자체전] $m');

  Future<void> run() async {
    _log('시작 (사람이 게임 중일 때만 봇 ${Config.botWarMinPlayers}~${Config.botWarMaxPlayers}명 비공개 1판씩)');
    while (true) {
      try {
        if (await _humanPlayingSomewhere()) {
          await _playOneGame();
          // 판 사이 휴식(점수 인플레 방지).
          await Future<void>.delayed(Duration(
              milliseconds:
                  _between(Config.botWarRestMinMs, Config.botWarRestMaxMs)));
          continue;
        }
      } catch (e) {
        _log('오류: $e');
      }
      await Future<void>.delayed(Duration(milliseconds: Config.botWarPollMs));
    }
  }

  int _between(int lo, int hi) => lo + _rng.nextInt(hi - lo + 1);

  /// started 방 어딘가에 **하트비트 신선한 사람**이 있는가.
  Future<bool> _humanPlayingSomewhere() async {
    final rooms = _asMap(await _rtdb.get('rooms')) ?? const {};
    final botUids = _pool.uids;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (final r in rooms.values) {
      final room = _asMap(r);
      if (room == null || room['started'] != true) continue;
      final players = _asMap(room['players']) ?? const {};
      for (final v in players.values) {
        final pv = _asMap(v);
        final id = pv?['id'];
        if (id is! String || botUids.contains(id)) continue;
        final seen = _asInt(pv?['seen']) ?? 0;
        if (nowMs - seen < Config.socialHumanActiveMs) return true;
      }
    }
    return false;
  }

  /// 비공개 방에서 봇들끼리 한 판(끝나면 방 삭제·봇 반납).
  Future<void> _playOneGame() async {
    final want = _between(Config.botWarMinPlayers, Config.botWarMaxPlayers);
    // 빠른시작 예비에 더해 사회성 충원용 여유까지 남긴다.
    final crew =
        _pool.acquire(want, reserve: Config.socialReserveForQuickMatch + 4);
    if (crew.length < Config.botWarMinPlayers) {
      _pool.releaseAll(crew);
      return; // 봇이 모자라면 이번 판은 쉼
    }
    const cs = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final code =
        List.generate(4, (_) => cs[_rng.nextInt(cs.length)]).join();
    final host = crew.first;
    try {
      await host.createPublicRoom(code, public: false);
      for (var i = 1; i < crew.length; i++) {
        await crew[i].joinSeat(code, i);
      }
      await host.hostStartGame(code);
      _log('$code ▶ ${crew.length}명 자체전 (${crew.map((b) => b.name).join("·")})');
      await Future.wait([
        for (var i = 0; i < crew.length; i++) crew[i].playSeatedGame(code, i),
        host.hostRefereeGame(code),
      ]);
      _log('$code ■ 자체전 종료');
    } catch (e) {
      _log('$code 오류: $e');
    } finally {
      try {
        await host.deleteRoom(code);
      } catch (_) {}
      _pool.releaseAll(crew);
    }
  }
}
