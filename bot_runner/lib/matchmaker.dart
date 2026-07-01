import 'dart:math';

import 'bot_pool.dart';
import 'config.dart';
import 'game/party_logic.dart';
import 'rtdb.dart';

int? _asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
Map? _asMap(Object? v) => v is Map ? v : null;

/// 매칭 감시. 사람이 빠른시작으로 판 **매칭 방**(match:true, started 아님)에 사람이
/// 혼자(살아서) 대기하면 유예 뒤 봇 2~4명을 빈 좌석에 투입한다. 사람이 이미 둘
/// 이상이거나 이미 봇이 들어간 방은 건드리지 않는다. 봇은 [BotPool]에서 빌린다
/// (공개방 사회성과 같은 풀 — busy면 여기 안 뽑힘).
class Matchmaker {
  Matchmaker(this._rtdb, this._pool);
  final Rtdb _rtdb;
  final BotPool _pool;

  final _handled = <String>{};
  final _firstSeen = <String, DateTime>{};
  final _rng = Random();

  void _log(String m) => print('[매칭] $m');

  Future<void> run() async {
    _log('감시 시작 (봇 ${_pool.total}명 풀, 유예 ${Config.graceDelayMs}ms)');
    while (true) {
      try {
        await _tick();
      } catch (e) {
        _log('tick 오류: $e');
      }
      await Future<void>.delayed(Duration(milliseconds: Config.roomsPollMs));
    }
  }

  Future<void> _tick() async {
    final rooms = _asMap(await _rtdb.get('rooms')) ?? const {};
    final live = rooms.keys.map((e) => e.toString()).toSet();
    _handled.removeWhere((c) => !live.contains(c));
    _firstSeen.removeWhere((c, _) => !live.contains(c));
    final botUids = _pool.uids;

    for (final entry in rooms.entries) {
      final code = entry.key.toString();
      final room = _asMap(entry.value);
      if (room == null) continue;
      if (room['match'] != true || room['started'] == true) continue;
      if (_handled.contains(code)) continue;

      final players = _asMap(room['players']) ?? const {};
      final occupied = <int>{};
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      var freshHumans = 0;
      var bots = 0;
      players.forEach((k, v) {
        final pv = _asMap(v);
        if (pv == null) return;
        final s = int.tryParse(k.toString().substring(1));
        if (s == null) return;
        occupied.add(s);
        final id = pv['id'];
        if (id == null) return; // 유령 노드(seen만 있음) — 사람 아님
        if (botUids.contains(id)) {
          bots++;
        } else {
          final seen = _asInt(pv['seen']) ?? 0;
          if (nowMs - seen < Config.humanFreshMs) freshHumans++;
        }
      });

      if (bots > 0) {
        _handled.add(code);
        continue;
      }
      if (freshHumans == 0) continue;
      if (freshHumans >= 2) {
        _handled.add(code);
        continue;
      }

      _firstSeen.putIfAbsent(code, () => DateTime.now());
      if (DateTime.now().difference(_firstSeen[code]!).inMilliseconds <
          Config.graceDelayMs) {
        continue;
      }

      final capacity =
          (_asInt(room['capacity']) ?? kMaxSeats).clamp(kMinSeats, kMaxSeats);
      final want = Config.minBotsFill +
          _rng.nextInt(Config.maxBotsFill - Config.minBotsFill + 1);
      final freeSeats = [
        for (var s = 0; s < capacity; s++)
          if (!occupied.contains(s)) s
      ];
      // 빠른시작은 우선 — 예비 없이 최대한 확보.
      final take = want < freeSeats.length ? want : freeSeats.length;
      final crew = _pool.acquire(take);
      if (crew.isEmpty) continue;

      _handled.add(code);
      _log('$code: 사람 $freshHumans명 대기 → 봇 ${crew.length}명 투입 (좌석 ${freeSeats.take(crew.length).toList()})');
      for (var i = 0; i < crew.length; i++) {
        final bot = crew[i];
        final seat = freeSeats[i];
        bot
            .playRoom(code, seat, joinDelayMs: i * Config.joinStaggerMs)
            .whenComplete(() => _pool.release(bot));
      }
    }
  }
}
