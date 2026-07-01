import 'dart:math';

import 'bot_client.dart';
import 'bot_pool.dart';
import 'config.dart';
import 'rtdb.dart';

int? _asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
Map? _asMap(Object? v) => v is Map ? v : null;

/// 공개방 "사회성" 시뮬 — 로비가 북적여 보이게 봇들이 공개방을 만들고 드나든다.
/// 랜덤성으로 사람처럼 연기: 시차 입장·랜덤 준비·약간의 시작 딜레이·중간 이탈·
/// 호스트 주기적 교체·가끔 적은 인원으로 시작·수명 지나면 해산 후 새 방 생성.
/// 봇은 [BotPool]에서 빌리되 [Config.socialReserveForQuickMatch]는 빠른시작용으로
/// 남긴다(공개방 봇은 busy라 빠른시작에 안 나타남).
class SocialSim {
  SocialSim(this._rtdb, this._pool);
  final Rtdb _rtdb;
  final BotPool _pool;
  final _rng = Random();
  int _activeRooms = 0;

  void _log(String m) => print('[사회성] $m');

  Future<void> run() async {
    _log('시작 (목표 공개방 ${Config.socialTargetRooms}개, 빠른시작 예비 ${Config.socialReserveForQuickMatch}명)');
    while (true) {
      try {
        while (_activeRooms < Config.socialTargetRooms &&
            _pool.freeCount > Config.socialReserveForQuickMatch + 1) {
          _activeRooms++;
          // fire-and-forget: 방 하나의 생애.
          _runRoom().whenComplete(() => _activeRooms--);
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      } catch (e) {
        _log('run 오류: $e');
      }
      await Future<void>.delayed(Duration(milliseconds: Config.socialTickMs));
    }
  }

  String _code() {
    const cs = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(4, (_) => cs[_rng.nextInt(cs.length)]).join();
  }

  double _rand() => _rng.nextDouble();
  int _between(int lo, int hi) => lo + _rng.nextInt(hi - lo + 1);

  Future<void> _runRoom() async {
    final host0 = _pool.acquire(1, reserve: Config.socialReserveForQuickMatch);
    if (host0.isEmpty) return;
    var host = host0.first;
    var hostSeat = 0;
    final code = _code();
    final members = <int, BotClient>{0: host}; // 봇 좌석만 추적(사람은 앱이 관리)
    final lifeEnd = DateTime.now().add(Duration(
        milliseconds: _between(
            Config.socialRoomLifeMinMs, Config.socialRoomLifeMaxMs)));
    DateTime? humanSince; // 사람이 들어온 시점(grace 시작 판단용)

    // 방 스냅샷 기준으로 members 좌석·호스트를 **uid로 재동기화**한다.
    // (startGame 좌석 압축·이탈 뒤 옛 좌석 키로 하트비트하면 seen만 있는
    //  유령 플레이어 노드가 생겨 "사람"으로 오인되던 버그의 근본 수정.)
    // 반환 false = 방에 봇이 하나도 안 남음(방 생애 종료).
    Future<bool> resync(Map data) async {
      final players = _asMap(data['players']) ?? const {};
      final seatByUid = <String, int>{};
      players.forEach((k, v) {
        final pv = _asMap(v);
        final s = int.tryParse('$k'.substring(1));
        final id = pv?['id'];
        if (s != null && id is String) seatByUid[id] = s;
      });
      final rebuilt = <int, BotClient>{};
      for (final b in members.values.toList()) {
        final s = seatByUid[b.uid];
        if (s != null) {
          rebuilt[s] = b;
        } else {
          _pool.release(b); // 방에서 사라짐(압축·청소 등)
        }
      }
      members
        ..clear()
        ..addAll(rebuilt);
      if (members.isEmpty) return false;
      final hs = seatByUid[host.uid];
      if (hs != null) {
        hostSeat = hs;
      } else {
        hostSeat = members.keys.reduce((a, b) => a < b ? a : b);
        host = members[hostSeat]!;
        await host.becomeHost(code);
      }
      return true;
    }

    try {
      await host.createPublicRoom(code);
      _log('$code 공개방 생성 (호스트 ${host.name})');
      // 호스트도 준비 표시(사람이 봐도 자연스럽게).
      _scheduleReady(host, code);

      final targetMembers =
          _between(Config.socialMinMembers, Config.socialMaxMembers);

      while (DateTime.now().isBefore(lifeEnd)) {
        final data = await host.getRoom(code);
        if (data == null) {
          _log('$code 사라짐 → 종료');
          return;
        }
        final botUids = _pool.uids;
        if (!await resync(data)) {
          _log('$code 봇 전원 이탈 → 종료');
          return;
        }

        // 유령 노드(id 없음)·하트비트 끊긴 사람 좌석 청소(호스트 역할, 대기실만).
        if (data['started'] != true) {
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          final players = _asMap(data['players']) ?? const {};
          for (final e in players.entries) {
            final pv = _asMap(e.value);
            if (pv == null) continue;
            final id = pv['id'];
            if (id == null) {
              await host.removeSeatEntry(code, '${e.key}');
              _log('$code 유령 좌석 ${e.key} 정리');
            } else if (id is String && !botUids.contains(id)) {
              final seen = _asInt(pv['seen']) ?? 0;
              if (nowMs - seen > Config.socialEvictStaleMs) {
                await host.removeSeatEntry(code, '${e.key}');
                _log('$code 연결 끊긴 좌석 ${e.key}(${pv['name']}) 정리');
              }
            }
          }
        }

        // 하트비트(봇 좌석 유지) — resync 직후라 좌석 키가 최신. **await 필수**:
        // 안 기다리면 같은 틱 뒤쪽의 이탈 delete/시작 압축과 경합해, 늦게 도착한
        // seen PUT이 지워진 좌석 경로를 되살려 유령 노드를 만든다.
        for (final e in members.entries) {
          await e.value.heartbeat(code, e.key);
        }

        // 모집: 시차 두고 한 명씩.
        if (members.length < targetMembers && _rand() < 0.5) {
          final crew =
              _pool.acquire(1, reserve: Config.socialReserveForQuickMatch);
          if (crew.isNotEmpty) {
            final seat = _firstEmptySeat(data);
            if (seat != null && seat >= 0) {
              final b = crew.first;
              await b.joinSeat(code, seat);
              members[seat] = b;
              _log('$code ← ${b.name} 좌석 $seat 입장 (${members.length}명)');
              _scheduleReady(b, code);
            } else {
              _pool.release(crew.first); // 빈자리 없음
            }
          }
        }

        // 중간 이탈(호스트 제외).
        if (members.length > 2 && _rand() < 0.12) {
          final leavers =
              members.keys.where((s) => s != hostSeat).toList();
          final s = leavers[_rng.nextInt(leavers.length)];
          final b = members.remove(s)!;
          await b.leaveSeat(code, s);
          _pool.release(b);
          _log('$code → 좌석 $s 이탈 (${members.length}명)');
        }

        // 호스트 교체.
        if (members.length >= 2 && _rand() < 0.08) {
          final old = members.remove(hostSeat)!;
          await old.leaveSeat(code, hostSeat);
          _pool.release(old);
          hostSeat = members.keys.reduce((a, b) => a < b ? a : b);
          host = members[hostSeat]!;
          await host.becomeHost(code);
          _log('$code ⤳ 호스트 교체 → 좌석 $hostSeat (${host.name})');
        }

        // 시작 조건: **살아있는(하트비트 최신) 사람이 최소 1명** 있어야 하고
        // (봇끼리·유령·끊긴 좌석으로는 시작 안 함), 그 사람들이 모두 준비돼야
        // 한다(방장 봇이 준비 확인 후 시작).
        final humans = _humanCount(data, botUids);
        humanSince = humans > 0 ? (humanSince ?? DateTime.now()) : null;
        final totalPresent = _presentCount(data);
        final ready = _humansReady(data, botUids, hostSeat);
        // 사람이 준비했거나(신버전) 오래 기다렸으면(구버전 대응) 시작.
        final waited = humanSince != null &&
            DateTime.now().difference(humanSince).inMilliseconds >
                Config.socialHumanStartGraceMs;
        if (humans >= 1 && totalPresent >= 2 && _rand() < 0.6 && (ready || waited)) {
          _log('$code ▶ 게임 시작 (사람 $humans + 봇 ${members.length}, 준비=$ready 대기시작=$waited)');
          await host.hostStartGame(code);
          // 시작 시 좌석이 압축됐으니 **다시 읽어 좌석 재동기화** 후 플레이
          // (옛 좌석으로 플레이하면 성향 프로필이 엉뚱한 좌석에 적용됨).
          final started = await host.getRoom(code);
          if (started == null || !await resync(started)) {
            _log('$code 시작 직후 방/봇 소실 → 종료');
            return;
          }
          // 봇 좌석들만 플레이(사람은 앱이 플레이) + 호스트 봇은 결투 심판도
          // 겸한다(무승부 시 showdown 생성·승자 확정 — 앱에선 사람 호스트 몫).
          await Future.wait([
            for (final e in members.entries) e.value.playSeatedGame(code, e.key),
            host.hostRefereeGame(code),
          ]);
          _log('$code ■ 라운드 종료');
          // 사람이 결과 화면을 볼 시간을 주고 대기실로(봇들이 즉시 리셋하면 승부
          // 결과가 눈 깜짝할 새 사라진다).
          await Future<void>.delayed(Duration(milliseconds: _between(4000, 7000)));
          await host.resetToLobby(code);
          // 라운드 뒤 비-호스트 봇들은 대개 흩어진다(자연스러운 churn).
          final leaving =
              members.entries.where((e) => e.key != hostSeat).toList();
          for (final e in leaving) {
            await e.value.leaveSeat(code, e.key);
            _pool.release(e.value);
            members.remove(e.key);
          }
        }

        await Future<void>.delayed(Duration(seconds: _between(2, 6)));
      }
    } catch (e) {
      _log('$code 오류: $e');
    } finally {
      // 해산: 남은 봇 전부 퇴장 + 방 삭제.
      for (final e in members.entries) {
        try {
          await e.value.leaveSeat(code, e.key);
        } catch (_) {}
        _pool.release(e.value);
      }
      try {
        await host.deleteRoom(code);
      } catch (_) {}
      _log('$code 해산');
    }
  }

  /// 준비를 랜덤 딜레이 뒤에 켠다(사람처럼). 좌석은 setReady가 실행 시점에
  /// uid로 다시 찾는다(그 사이 압축/이탈했으면 조용히 무시).
  void _scheduleReady(BotClient b, String code) {
    Future<void>.delayed(Duration(milliseconds: _between(1200, 6000)), () {
      b.setReady(code, true);
    });
  }

  int? _firstEmptySeat(Map data, {int capacity = 6}) {
    final players = _asMap(data['players']) ?? const {};
    final occupied = <int>{};
    players.forEach((k, v) {
      final s = int.tryParse('$k'.substring(1));
      if (s != null && _asMap(v) != null) occupied.add(s);
    });
    for (var s = 0; s < capacity; s++) {
      if (!occupied.contains(s)) return s;
    }
    return null;
  }

  /// 자리에 앉은(정상 엔트리=id 있는) 인원 수. 유령 노드는 제외.
  int _presentCount(Map data) {
    final players = _asMap(data['players']) ?? const {};
    var n = 0;
    for (final v in players.values) {
      final pv = _asMap(v);
      if (pv != null && pv['id'] != null) n++;
    }
    return n;
  }

  /// 방에 든 **살아있는** 사람(봇 아님 + 하트비트 최신) 수.
  /// 유령 노드(id 없음)·하트비트 끊긴 좌석은 사람으로 치지 않는다 —
  /// 옛날엔 이 둘을 사람으로 오인해 봇들끼리 유령을 기다리며 게임을 시작했다.
  int _humanCount(Map data, Set<String> botUids) {
    final players = _asMap(data['players']) ?? const {};
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    var n = 0;
    for (final v in players.values) {
      final pv = _asMap(v);
      if (pv == null) continue;
      final id = pv['id'];
      if (id == null || botUids.contains(id)) continue;
      final seen = _asInt(pv['seen']) ?? 0;
      if (nowMs - seen < Config.socialHumanActiveMs) n++;
    }
    return n;
  }

  /// 방에 든 살아있는 사람(봇 아님) 중 호스트 아닌 좌석이 전부 준비했는가.
  /// (봇만 있으면 true — 사람 없으니 바로 시작 가능. 끊긴/유령 좌석은 무시.)
  bool _humansReady(Map data, Set<String> botUids, int hostSeat) {
    final players = _asMap(data['players']) ?? const {};
    final ready = _asMap(data['ready']) ?? const {};
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (final e in players.entries) {
      final s = int.tryParse('${e.key}'.substring(1));
      final pv = _asMap(e.value);
      if (s == null || pv == null || s == hostSeat) continue;
      final id = pv['id'];
      if (id == null || botUids.contains(id)) continue; // 봇·유령은 준비 간주
      final seen = _asInt(pv['seen']) ?? 0;
      if (nowMs - seen >= Config.humanFreshMs) continue; // 끊긴 사람은 무시
      if (ready['p$s'] != true) return false; // 준비 안 한 사람 있음
    }
    return true;
  }
}
