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
    final joinedAt = <String, DateTime>{host.uid: DateTime.now()};
    var lifeEnd = DateTime.now().add(Duration(
        milliseconds: _between(
            Config.socialRoomLifeMinMs, Config.socialRoomLifeMaxMs)));
    var lastRoundEnd = DateTime.fromMillisecondsSinceEpoch(0);
    var lastPlayedGame = -1; // 참전을 마친 판 번호(중복 참전·재시작 방지)
    var rematchPressedGame = -1; // "다시하기"를 눌러둔 판 번호

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
        // 관리 봇이 방에서 사라짐 → 남은 봇 중 최저 좌석이 관리 승계.
        // (RTDB host 필드/제목 인수는 대기실에서 **봇이 상석일 때만** — 앱 규약상
        //  방장=가장 낮은 좌석이라, 사람이 상석이면 방장은 사람이다.)
        hostSeat = members.keys.reduce((a, b) => a < b ? a : b);
        host = members[hostSeat]!;
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

      while (true) {
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
        final humans = _humanCount(data, botUids);

        // 방 수명 — **사람이 있으면 절대 해산하지 않는다**(놀던 방이 눈앞에서
        // 사라지는 것 방지). 사람이 나가고 나서야 수명 만료로 해산.
        if (!DateTime.now().isBefore(lifeEnd)) {
          if (humans > 0) {
            lifeEnd = DateTime.now()
                .add(Duration(milliseconds: _between(60000, 150000)));
          } else {
            break; // 수명 끝 + 사람 없음 → 해산
          }
        }

        final startedFlag = data['started'] == true;
        final gameNo = _asInt(data['game']) ?? 0;
        // 앱 규약: 방장 = 참여 좌석 중 가장 낮은 좌석(끊긴 좌석 제외). 그 자리가
        // 사람이면 이 방의 주인은 사람 — 봇은 시작·리셋·방장 인수를 하지 않는다.
        // (사용자 제보 "내가 방장인데 시작도 안 했는데 시작됨" 수정.)
        final bossId = _bossUid(data, botUids);
        final humanIsBoss = bossId != null && !botUids.contains(bossId);

        // 하트비트(봇 좌석 유지) — 대기실·결과 화면 가리지 않고 매 틱. **await
        // 필수**: 안 기다리면 같은 틱 뒤쪽의 이탈 delete/시작 압축과 경합해,
        // 늦게 도착한 seen PUT이 지워진 좌석 경로를 되살려 유령 노드를 만든다.
        for (final e in members.entries) {
          await e.value.heartbeat(code, e.key);
        }

        // ── 시작된 게임 처리(봇 방장이 시작했든 **사람 방장이 시작**했든) ──
        if (startedFlag) {
          if (gameNo != lastPlayedGame && members.isNotEmpty) {
            lastPlayedGame = gameNo;
            _log('$code ▶ 판 #$gameNo 참전 (봇 ${members.length}${humanIsBoss ? ", 방장=사람" : ""})');
            await Future.wait([
              for (final e in members.entries)
                e.value.playSeatedGame(code, e.key, botUids: botUids),
              if (!humanIsBoss) host.hostRefereeGame(code),
            ]);
            _log('$code ■ 라운드 종료');
            lastRoundEnd = DateTime.now();
            if (!humanIsBoss) {
              // 결과를 볼 시간을 주고 대기실로. (사람 방장 방은 사람 앱이
              // rematch 리셋을 관리하므로 봇이 손대지 않는다.)
              await Future<void>.delayed(
                  Duration(milliseconds: _between(4000, 7000)));
              await host.resetToLobby(code);
            }
            // 라운드 뒤 **일부만** 떠난다(예전엔 전원 해산이라 "한 판 하면
            // 무조건 다 나가"로 보였다). 남는 봇은 다음 판 준비를 켠다.
            for (final e in members.entries.toList()) {
              if (!humanIsBoss && e.key == hostSeat) continue;
              if (_rand() < 0.35) {
                members.remove(e.key);
                final b = e.value;
                joinedAt.remove(b.uid);
                Future<void>.delayed(
                    Duration(milliseconds: _between(2000, 9000)), () async {
                  try {
                    await b.leaveSeat(code, e.key);
                  } catch (_) {}
                  _pool.release(b);
                  _log('$code → ${b.name} 한 판 하고 떠남');
                });
              } else if (!humanIsBoss) {
                _scheduleReady(e.value, code);
              }
            }
            if (!humanIsBoss) _scheduleReady(host, code);
          } else if (humanIsBoss && rematchPressedGame != gameNo) {
            // 사람 방장 방의 결과 화면 — 남은 봇들이 "다시하기"를 눌러 둔다.
            // (전원이 눌러야 앱이 다음 판으로 넘어가므로, 봇이 안 누르면 사람이
            //  다시하기를 눌러도 영영 시작이 안 된다.)
            rematchPressedGame = gameNo;
            for (final e in members.entries) {
              final b = e.value;
              Future<void>.delayed(
                  Duration(milliseconds: _between(2000, 7000)),
                  () => b.pressRematch(code));
            }
          }
          await Future<void>.delayed(Duration(seconds: _between(2, 5)));
          continue;
        }

        // ── 이하 대기실(로비) 관리 ──

        // 봇이 상석이면 상석 봇이 방장 노릇(RTDB host 필드·방 제목을 그 봇으로).
        // 사람이 상석이 되면 손대지 않는다(앱의 ensureHost가 사람에게 넘김).
        if (!humanIsBoss && members.isNotEmpty) {
          final lowest = members.keys.reduce((a, b) => a < b ? a : b);
          if (members[lowest] != host) {
            host = members[lowest]!;
            hostSeat = lowest;
          }
          if (data['host'] != host.uid) {
            await host.becomeHost(code);
            _log('$code 방장 인수 → ${host.name}');
          }
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
              joinedAt[b.uid] = DateTime.now();
              _log('$code ← ${b.name} 좌석 $seat 입장 (${members.length}명)');
              _scheduleReady(b, code);
            } else {
              _pool.release(crew.first); // 빈자리 없음
            }
          }
        }

        // 중간 이탈(호스트 제외). **막 들어온 봇은 안 나간다**(입장하자마자
        // 나가면 어색) + 사람이 기다리는 방은 덜 빠진다(곧 게임할 거니까).
        final churnP = humans > 0 ? 0.06 : 0.12;
        if (members.length > 2 && _rand() < churnP) {
          final leavers = members.keys.where((s) {
            if (s == hostSeat) return false;
            final since = joinedAt[members[s]!.uid];
            return since == null ||
                DateTime.now().difference(since).inMilliseconds > 25000;
          }).toList();
          if (leavers.isNotEmpty) {
            final s = leavers[_rng.nextInt(leavers.length)];
            final b = members.remove(s)!;
            await b.leaveSeat(code, s);
            joinedAt.remove(b.uid);
            _pool.release(b);
            _log('$code → 좌석 $s 이탈 (${members.length}명)');
          }
        }

        // 호스트 교체(봇이 상석일 때만). 교체 후 상석이 사람이 되면(사람 좌석이
        // 더 낮으면) becomeHost 하지 않는다 — 방장은 사람에게 넘어간다.
        if (!humanIsBoss && members.length >= 2 && _rand() < 0.08) {
          final oldSeat = hostSeat;
          final old = members.remove(oldSeat)!;
          await old.leaveSeat(code, oldSeat);
          joinedAt.remove(old.uid);
          _pool.release(old);
          hostSeat = members.keys.reduce((a, b) => a < b ? a : b);
          host = members[hostSeat]!;
          final players = _asMap(data['players']) ?? const {};
          var humanLower = false;
          players.forEach((k, v) {
            final s = int.tryParse('$k'.substring(1));
            final id = _asMap(v)?['id'];
            if (s != null && s != oldSeat && id is String &&
                !botUids.contains(id) && s < hostSeat) {
              humanLower = true;
            }
          });
          if (!humanLower) await host.becomeHost(code);
          _log('$code ⤳ 호스트 교체 → ${humanLower ? "사람에게 넘김" : "좌석 $hostSeat (${host.name})"}');
        }

        // 시작 조건(**봇이 상석일 때만**): 살아있는(하트비트 최신) 사람이 최소
        // 1명 + 그 사람들 **전원 준비**. 예전의 "15초 지나면 준비 없이도 시작"
        // grace는 제거 — "준비 안 눌렀는데 시작된다"는 제보의 원인이었다.
        // 직전 라운드 종료 후 12초 쿨다운(떠나는 봇의 시차 퇴장과 안 겹치게).
        final totalPresent = _presentCount(data);
        final ready = _humansReady(data, botUids, hostSeat);
        final cooled =
            DateTime.now().difference(lastRoundEnd).inMilliseconds > 12000;
        if (!humanIsBoss &&
            cooled &&
            humans >= 1 &&
            totalPresent >= 2 &&
            ready &&
            _rand() < 0.6) {
          _log('$code ▶ 게임 시작 (사람 $humans 전원 준비, 봇 ${members.length})');
          await host.hostStartGame(code);
          // 참전은 다음 틱의 started 브랜치가 처리(좌석 재동기화 포함).
        }

        await Future<void>.delayed(Duration(seconds: _between(2, 6)));
      }
    } catch (e) {
      _log('$code 오류: $e');
    } finally {
      // 해산. **사람이 남아 있으면 방을 지우지 않는다**(놀고 있는 방을 봇이
      // 없애면 안 됨) — 봇들만 자리 비우고 나온다. 사람이 없으면 방 삭제를
      // **먼저** 하고 봇 반납은 그 다음(순서가 반대면 방금 반납된 호스트가 곧장
      // 새 방을 파서, 옛 방이 지워지기 전 같은 이름 방이 2개로 보인다).
      try {
        final data = await host.getRoom(code);
        final humansLeft = data != null && _humanCount(data, _pool.uids) > 0;
        if (humansLeft) {
          for (final e in members.entries) {
            try {
              await e.value.leaveSeat(code, e.key);
            } catch (_) {}
          }
        } else {
          await host.deleteRoom(code);
        }
      } catch (_) {}
      for (final e in members.entries) {
        _pool.release(e.value);
      }
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

  /// 방장(상석) 주인 uid — 앱 규약: 참여 좌석 중 **가장 낮은 좌석**이 방장.
  /// 유령(id 없음)과 하트비트 끊긴 사람 좌석(앱이 "나감"으로 침)은 제외.
  /// 봇 좌석은 러너가 매 틱 하트비트하므로 항상 신선 취급.
  /// 방장 판정 — 앱 규약(2026-07-13 변경)과 동일해야 한다:
  /// ① RTDB `host` 필드의 주인이 신선하게 앉아 있으면 그가 방장.
  /// ② 아니면 입장 시각(at) 오름차순, at 없는 구노드는 좌석 순으로 뒤처짐.
  /// 예전 "최저 좌석" 규약은 사람이 승계 방장일 때 낮은 좌석 봇이 방장을
  /// 뺏는(becomeHost) 사고를 냈다.
  String? _bossUid(Map data, Set<String> botUids) {
    final players = _asMap(data['players']) ?? const {};
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    bool fresh(Map? pv, String id) =>
        botUids.contains(id) ||
        nowMs - (_asInt(pv?['seen']) ?? 0) < 14000;
    // ① 기록된 host가 착석·신선하면 그대로.
    final recorded = data['host'];
    if (recorded is String && recorded.isNotEmpty) {
      for (final e in players.entries) {
        final pv = _asMap(e.value);
        if (pv?['id'] == recorded && fresh(pv, recorded)) return recorded;
      }
    }
    // ② 승계: at 오름차순(없으면 좌석 순 뒤로) — 앱 computeView와 동일 키.
    var bestKey = 1 << 62;
    String? boss;
    for (final e in players.entries) {
      final s = int.tryParse('${e.key}'.substring(1));
      final pv = _asMap(e.value);
      final id = pv?['id'];
      if (s == null || id is! String || !fresh(pv, id)) continue;
      final key = (_asInt(pv?['at']) ?? (1 << 50)) * 64 + s;
      if (key < bestKey) {
        bestKey = key;
        boss = id;
      }
    }
    return boss;
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
      // 준비 값 규약(앱 v19, 2026-07-12 변경): 구버전은 true, 신버전은 **그 좌석
      // 주인의 uid**를 저장(좌석 재사용 오염 방지). 앱 computeView와 동일하게
      // 둘 다 인정 — true만 보면 v19+ 사람의 준비를 영영 못 알아본다(실제 사고:
      // 봇 방이 전혀 시작 안 됨).
      final rv = ready['p$s'];
      if (!(rv == true || rv == id)) return false; // 준비 안 한 사람 있음
    }
    return true;
  }
}
