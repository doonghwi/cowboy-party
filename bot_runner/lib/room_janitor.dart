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

  /// 러너 시작 직후 1회: **모든 플레이어가 우리 봇 uid인 방**을 즉시 삭제.
  /// 러너가 죽으면(재시작·크래시) 봇 방이 청소 못 된 채 남는데, 스테일 기준
  /// (120초)까지 기다리는 동안 새 러너가 같은 이름의 방을 또 파서 로비에
  /// "같은 봇의 결투장"이 2개로 보인다(사용자 제보). 막 시작한 시점엔 어떤
  /// 봇도 정당하게 앉아있을 수 없으므로 봇 전용 방=고아 방. 사람이 한 명이라도
  /// 있으면 건드리지 않는다.
  Future<void> sweepOrphanBotRooms(Set<String> botUids) async {
    final rooms = _asMap(await _rtdb.get('rooms')) ?? const {};
    var deleted = 0;
    for (final e in rooms.entries) {
      final room = _asMap(e.value);
      final players = _asMap(room?['players']);
      if (players == null || players.isEmpty) continue;
      final allBots = players.values.every((v) {
        final id = _asMap(v)?['id'];
        return id is String && botUids.contains(id);
      });
      if (allBots) {
        try {
          await _authBot.deleteRoom(e.key.toString());
          deleted++;
        } catch (_) {}
      }
    }
    if (deleted > 0) _log('시작 스윕: 이전 러너의 고아 봇 방 $deleted개 정리');
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
