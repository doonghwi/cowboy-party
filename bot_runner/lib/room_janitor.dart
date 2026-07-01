import 'bot_client.dart';
import 'config.dart';
import 'rtdb.dart';

int? _asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
Map? _asMap(Object? v) => v is Map ? v : null;

/// 죽은 방 청소부 — 앱이 방을 만들고 사람이 그냥 나가면 방 노드가 안 지워지고
/// 쌓인다(하드 disconnect 삭제 안 함). 러너가 상시 돌므로 여기서 **모든
/// 플레이어가 [Config.janitorStaleMs] 이상 하트비트 없는 방**을 주기적으로 지운다.
/// 앱은 대기실·게임에서 4초마다 하트비트하므로 사람이 있는 방은 절대 안 지워진다.
class RoomJanitor {
  RoomJanitor(this._rtdb, this._authBot);
  final Rtdb _rtdb;
  final BotClient _authBot; // 삭제 인증용(아무 봇 토큰이면 됨)

  void _log(String m) => print('[청소] $m');

  Future<void> run() async {
    _log('시작 (${Config.janitorStaleMs ~/ 1000}초+ 하트비트 없는 방 삭제, ${Config.janitorPollMs ~/ 1000}초 주기)');
    while (true) {
      try {
        await _scan();
      } catch (e) {
        _log('오류: $e');
      }
      await Future<void>.delayed(Duration(milliseconds: Config.janitorPollMs));
    }
  }

  Future<void> _scan() async {
    final rooms = _asMap(await _rtdb.get('rooms')) ?? const {};
    final now = DateTime.now().millisecondsSinceEpoch;
    var deleted = 0;
    for (final e in rooms.entries) {
      final room = _asMap(e.value);
      if (room == null) continue;
      if (_isDead(room, now)) {
        try {
          await _authBot.deleteRoom(e.key.toString());
          deleted++;
        } catch (_) {}
      }
    }
    if (deleted > 0) _log('죽은 방 $deleted개 정리');
  }

  bool _isDead(Map room, int now) {
    final players = _asMap(room['players']);
    if (players == null || players.isEmpty) return true; // 아무도 없음
    var freshest = 0;
    for (final v in players.values) {
      final pv = _asMap(v);
      if (pv == null || pv['id'] == null) continue; // 유령 노드 seen은 무시
      final seen = _asInt(pv['seen']) ?? 0;
      if (seen > freshest) freshest = seen;
    }
    // 매칭(빠른시작) 방은 짧게, 그 외(공개방 등)는 넉넉히.
    final threshold = room['match'] == true
        ? Config.janitorMatchStaleMs
        : Config.janitorStaleMs;
    return (now - freshest) > threshold;
  }
}
