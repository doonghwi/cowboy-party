import 'dart:math';

import 'auth.dart';
import 'config.dart';
import 'game/char_core.dart';
import 'game/cpu_ai.dart';
import 'game/party_logic.dart';
import 'game_replay.dart';
import 'rtdb.dart';

int? _asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
Map? _asMap(Object? v) => v is Map ? v : null;

/// 봇 한 명이 방 하나를 처음부터 끝까지 플레이한다(비-호스트). 사람 호스트가
/// 시작·showdown 생성·승자확정을 하고, 봇은 좌석을 잡아 하트비트·턴제출·결투탭을
/// 담당한다. 이기면 주간 랭킹에 기록한다.
class BotClient {
  BotClient(this._rtdb, this._auth, this._cred, this._spec);
  final Rtdb _rtdb;
  final BotAuth _auth;
  final BotCred _cred;
  final BotSpec _spec;
  final _cpu = CpuAi();
  final _rng = Random();

  int _tappedRound = -1;

  String get name => _cred.name;
  String get uid => _cred.uid;
  void _log(String m) => print('[봇 ${_cred.name}] $m');
  Future<String> get _tok => _auth.freshIdToken(_cred);

  /// 희망 좌석 [hintSeat] 근처로 방 [code]에 들어가 게임이 끝날 때까지 플레이한다.
  /// [joinDelayMs]만큼 늦게 입장해 여러 봇이 **순차적으로** 들어오게 한다
  /// (사람 화면에서 '1명→2명→3명'으로 자연스럽게 늘어나도록).
  Future<void> playRoom(String code, int hintSeat, {int joinDelayMs = 0}) async {
    _tappedRound = -1;
    var claimed = false;
    try {
      if (joinDelayMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: joinDelayMs));
      }
      final seat = await _claimSeat(code, hintSeat);
      if (seat == null) {
        _log('$code 빈자리 없음/이미 시작 → 입장 취소');
        return;
      }
      claimed = true;
      _log('$code 좌석 $seat 입장');
      if (!await _awaitStart(code)) {
        _log('시작 안 됨 → 퇴장');
        return;
      }
      _cpu.beginGame(); // 이 게임용 성격·실력 리롤
      _applyPersonality(seat); // 공격/수비 성향 봇이면 프로필 강제
      await _gameLoop(code, seat);
    } catch (e) {
      _log('오류: $e');
    } finally {
      if (claimed) await _leave(code, hintSeat);
    }
  }

  void _applyPersonality(int seat) {
    switch (_spec.personality) {
      case 'aggressive':
        _cpu.setProfile(seat, aggression: 0.92, caution: 0.08, focus: 0.7);
        break;
      case 'defensive':
        _cpu.setProfile(seat, aggression: 0.3, caution: 0.78);
        break;
    }
  }

  /// 입장 직전에 방 상태를 다시 보고 좌석을 잡는다(늦게 들어오는 사이 사람이
  /// 앉았거나 게임이 시작됐으면 덮어쓰지 않고 물러남). 잡은 좌석을 반환, 실패 null.
  Future<int?> _claimSeat(String code, int hintSeat) async {
    final data = _asMap(await _rtdb.get('rooms/$code'));
    if (data == null || data['started'] == true) return null;
    final players = _asMap(data['players']) ?? const {};
    final occupied = <int>{};
    players.forEach((k, v) {
      final s = int.tryParse('$k'.substring(1));
      if (s != null && _asMap(v) != null) occupied.add(s);
    });
    final capacity =
        (_asInt(data['capacity']) ?? kMaxSeats).clamp(kMinSeats, kMaxSeats);
    int? seat;
    if (hintSeat >= 0 && hintSeat < capacity && !occupied.contains(hintSeat)) {
      seat = hintSeat;
    } else {
      for (var s = 0; s < capacity; s++) {
        if (!occupied.contains(s)) {
          seat = s;
          break;
        }
      }
    }
    if (seat == null) return null;
    final charIdx = (_spec.fixedChar ??
            kPlayableCharIds[_rng.nextInt(kPlayableCharIds.length)])
        .index;
    await _rtdb.put('rooms/$code/players/p$seat', {
      'id': _cred.uid, // 봇의 클라이언트 식별자 = uid
      'name': _cred.name,
      'seen': Rtdb.serverTimestamp,
      'char': charIdx,
    }, auth: await _tok);
    return seat;
  }

  /// started:true 될 때까지 하트비트하며 대기(최대 ~40초).
  /// 하트비트 좌석은 매번 uid로 다시 찾는다 — 그 사이 좌석이 압축/이동돼도
  /// 엉뚱한 경로에 seen만 있는 유령 노드를 만들지 않는다.
  Future<bool> _awaitStart(String code) async {
    for (var i = 0; i < 400; i++) {
      final data = _asMap(await _rtdb.get('rooms/$code'));
      if (data == null) return false;
      if (data['started'] == true) return true;
      if (i % 3 == 0) {
        final s = _seatOfUid(data);
        if (s < 0) return false; // 내 좌석이 사라짐(강퇴 등) → 포기
        await _rtdb.put('rooms/$code/players/p$s/seen', Rtdb.serverTimestamp,
            auth: await _tok);
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return false;
  }

  Future<void> _gameLoop(String code, int hintSeat) async {
    var lastSubmitted = -1;
    var lastProgressAt = DateTime.now();

    while (true) {
      final data = _asMap(await _rtdb.get('rooms/$code'));
      if (data == null) {
        _log('방 사라짐 → 종료');
        return;
      }
      if (data['started'] != true) {
        _log('대기실로 복귀(라운드 종료) → 퇴장');
        return; // MVP: 다시하기 안 함
      }

      // ★ 시작 시 좌석이 압축(재번호)될 수 있으니 uid로 내 좌석을 매번 찾는다.
      //   (예전엔 입장 때 좌석을 그대로 써서, churn으로 좌석이 밀리면 봇이 엉뚱한
      //    좌석으로 판단해 가만히 있던 버그.)
      final seat = _seatOfUid(data);
      if (seat < 0) {
        _log('게임에 내 좌석 없음(원래 $hintSeat) → 종료');
        return;
      }

      final r = replay(data, code);

      // 게임이 나 없이 시작됨(seatCount 밖 좌석 = 다음 판 관전 상태).
      // 이대로 두면 r.submitted[seat] 인덱스 초과 → RangeError.
      if (seat >= r.n) {
        _log('시작된 게임 좌석 밖(관전 상태) → 퇴장');
        return;
      }

      if (r.over) {
        if (r.status == GameStatus.won) {
          if (r.winner == seat) {
            _log('승리! 랭킹 기록');
            await _recordWin(r.n);
          }
          return;
        }
        // 무승부(=반응속도 결투). 참가자면 탭한다 — 심판(사람 호스트의 앱 또는
        // 사회성 방의 봇 호스트 hostRefereeGame)이 승자를 확정하면 replay가
        // won 으로 바꿔줘서 위 분기로 끝난다.
        final decided = await _handleShowdown(code, seat, data);
        if (decided) return;
        lastProgressAt = DateTime.now(); // 결투 진행 중은 스톨로 보지 않음
      } else if (r.awaits(seat) && r.currentTurn > lastSubmitted) {
        lastProgressAt = DateTime.now();
        await _thinkDelay();
        final fresh = _asMap(await _rtdb.get('rooms/$code'));
        if (fresh == null || fresh['started'] != true) continue;
        final r2 = replay(fresh, code);
        if (r2.awaits(seat) && r2.currentTurn == r.currentTurn) {
          final move = _spec.reloadOnly
              ? const Move.reload()
              : _cpu.chooseMove(
                  seat: seat,
                  ammo: r2.ammo,
                  alive: r2.alive,
                  chars: r2.chars,
                  state: r2.pstate,
                  lastMoves: r2.lastMoves,
                );
          await _submit(code, seat, r2.currentTurn, move);
          lastSubmitted = r2.currentTurn;
          _log('턴 ${r2.currentTurn} 제출: ${move.kind.name}');
        }
      } else {
        if (r.currentTurn > lastSubmitted && r.submitted[seat]) {
          lastSubmitted = r.currentTurn;
          lastProgressAt = DateTime.now();
        }
      }

      if (DateTime.now().difference(lastProgressAt).inMilliseconds >
          Config.gameStallTimeoutMs) {
        _log('진전 없음(상대 이탈?) → 포기 퇴장');
        return;
      }
      await Future<void>.delayed(Duration(milliseconds: Config.gamePollMs));
    }
  }

  /// 방 데이터에서 **내 uid가 앉은 좌석**을 찾는다(없으면 -1). 시작 시 좌석 압축에
  /// 대응하는 핵심 — 봇은 늘 자기 uid로 좌석을 판단한다.
  int _seatOfUid(Map data) {
    final players = _asMap(data['players']) ?? const {};
    for (final e in players.entries) {
      final pv = _asMap(e.value);
      if (pv != null && pv['id'] == _cred.uid) {
        return int.tryParse('${e.key}'.substring(1)) ?? -1;
      }
    }
    return -1;
  }

  Future<void> _submit(String code, int seat, int turn, Move m) async {
    final tok = await _tok;
    await _rtdb.put('rooms/$code/turns/t$turn/p$seat', m.encode(), auth: tok);
    await _rtdb.put('rooms/$code/players/p$seat/seen', Rtdb.serverTimestamp,
        auth: tok);
  }

  Future<void> _thinkDelay() async {
    final ms = Config.thinkMinMs +
        _rng.nextInt(Config.thinkMaxMs - Config.thinkMinMs);
    await Future<void>.delayed(Duration(milliseconds: ms));
  }

  /// 반응속도 결투 처리(참가자로서 탭). 반환 true = 승부 확정(종료).
  /// 승자 확정은 replay가 showdown.winner를 읽어 won 으로 바꿔주므로 _gameLoop
  /// 쪽에서 처리된다 — 여기서는 탭만 담당.
  Future<bool> _handleShowdown(String code, int seat, Map data) async {
    final sd = _asMap(data['showdown']);
    if (sd == null) return false; // 호스트가 아직 안 만듦 — 대기
    final parts = _asMap(sd['participants']) ?? const {};
    if (parts['p$seat'] != true) return false; // 나는 참가자 아님 — 승자 확정 대기
    final round = _asInt(sd['round']) ?? 0;
    final taps = _asMap(sd['taps']) ?? const {};
    if (round == _tappedRound || taps['p$seat'] != null) return false;

    // 실력 기반 반응. 앱 호스트는 **goAt(서버 ms) 이상인 탭 시각** 중 가장 빠른
    // 좌석을 승자로 삼으므로, 탭 값은 반응시간이 아니라 서버시각(goAt+반응)이어야
    // 한다(로컬시계≈NTP 동기 가정). 반응시간을 그대로 쓰면 전부 무효 탭이 된다.
    _tappedRound = round;
    final goAt = _asInt(sd['goAt']) ?? DateTime.now().millisecondsSinceEpoch;
    final reactionMs = _cpu.showdownReactionMs(seat);
    final fireAt = goAt + reactionMs;
    final wait = fireAt - DateTime.now().millisecondsSinceEpoch;
    if (wait > 0) await Future<void>.delayed(Duration(milliseconds: wait));
    try {
      await _rtdb.put('rooms/$code/showdown/taps/p$seat', fireAt,
          auth: await _tok);
      _log('결투 탭 +${reactionMs}ms (라운드 $round)');
    } catch (_) {}
    return false;
  }

  /// **호스트가 봇인 방**(사회성 공개방)의 결투 심판 — 앱의 호스트 클라이언트가
  /// 하던 일을 대신한다: 무승부가 나면 showdown 생성 → 유효 탭(goAt 이후,
  /// 부정출발 아님) 중 가장 빠른 좌석을 승자로 확정. 전원 부정출발이면 라운드
  /// 재시작, 오래 응답 없으면 포기. 게임이 끝나거나 방이 리셋되면 반환.
  Future<void> hostRefereeGame(String code) async {
    final deadline = DateTime.now().add(const Duration(minutes: 5));
    DateTime? firstValidAt;
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(Duration(milliseconds: Config.gamePollMs));
      final data = _asMap(await _rtdb.get('rooms/$code'));
      if (data == null || data['started'] != true) return;
      final r = replay(data, code);
      if (!r.over) continue;
      if (r.status == GameStatus.won) return; // 승부 남(결투 승자 포함)
      if (r.drawTurn < 0 || r.drawParticipants.isEmpty) return;

      final sd = _asMap(data['showdown']);
      if (sd == null || _asInt(sd['turn']) != r.drawTurn) {
        final goAt =
            DateTime.now().millisecondsSinceEpoch + 1300 + _rng.nextInt(900);
        await _rtdb.put('rooms/$code/showdown', {
          'turn': r.drawTurn,
          'round': 0,
          'goAt': goAt,
          'participants': {for (final s in r.drawParticipants) 'p$s': true},
        }, auth: await _tok);
        _log('결투 심판: 개시 (참가 좌석 ${r.drawParticipants})');
        continue;
      }
      if (sd['winner'] != null) return; // (replay가 못 본 직후 상태) 확정됨

      final goAt = _asInt(sd['goAt']) ?? 0;
      final round = _asInt(sd['round']) ?? 0;
      final taps = _asMap(sd['taps']) ?? const {};
      final fs = _asMap(sd['falseStart']) ?? const {};
      final valid = <int, int>{}; // 좌석 → 탭 시각(goAt 이후)
      var accounted = true;
      for (final s in r.drawParticipants) {
        final t = _asInt(taps['p$s']);
        final isFalse = fs['p$s'] == true;
        if (t != null && t >= goAt && !isFalse) valid[s] = t;
        if (!(isFalse || (t != null && t >= goAt))) accounted = false;
      }
      if (valid.isNotEmpty) {
        firstValidAt ??= DateTime.now();
        final settled =
            DateTime.now().difference(firstValidAt).inMilliseconds > 900;
        if (accounted || settled) {
          var best = valid.keys.first;
          valid.forEach((s, t) {
            if (t < valid[best]!) best = s;
          });
          await _rtdb.put('rooms/$code/showdown/winner', best,
              auth: await _tok);
          _log('결투 심판: 승자 좌석 $best');
          return;
        }
      } else if (r.drawParticipants.every((s) => fs['p$s'] == true)) {
        // 전원 부정출발 → 라운드 재시작(앱과 동일).
        firstValidAt = null;
        await _rtdb.patch('rooms/$code/showdown', {
          'round': round + 1,
          'goAt': DateTime.now().millisecondsSinceEpoch + 1300 + _rng.nextInt(900),
          'winner': null,
          'falseStart': null,
          'taps': null,
        }, auth: await _tok);
        _log('결투 심판: 전원 부정출발 → 라운드 ${round + 1}');
      } else if (goAt > 0 &&
          DateTime.now().millisecondsSinceEpoch - goAt > 15000) {
        _log('결투 심판: 응답 없음(참가자 이탈?) → 종료');
        return;
      }
    }
  }

  /// 주간 랭킹 기록(seasons/{주}/{uid}). REST엔 원자적 increment이 없어
  /// read-modify-write(봇이라 경합 무시). 규칙상 +60 이하만 → winPts≤50 OK.
  Future<void> _recordWin(int players) async {
    try {
      final path = 'seasons/${_weeklySeasonId()}/${_cred.uid}';
      final cur = _asMap(await _rtdb.get(path, auth: await _tok));
      final curPts = _asInt(cur?['pts']) ?? 0;
      final add = 10 * (players.clamp(2, 6) - 1);
      await _rtdb.patch(path, {'name': _cred.name, 'pts': curPts + add},
          auth: await _tok);
      _log('랭킹 +$add (누적 ${curPts + add})');
    } catch (e) {
      _log('랭킹 기록 실패: $e');
    }
  }

  Future<void> _leave(String code, int seat) async {
    try {
      final data = _asMap(await _rtdb.get('rooms/$code'));
      if (data == null) return;
      // 압축으로 좌석이 바뀌었어도 내 uid가 앉은 실제 좌석을 비운다.
      final s = _seatOfUid(data);
      final target = s >= 0 ? s : seat;
      final p = _asMap(_asMap(data['players'])?['p$target']);
      if (p != null && p['id'] == _cred.uid) {
        await _rtdb.delete('rooms/$code/players/p$target', auth: await _tok);
      }
    } catch (_) {}
  }

  // ── 공개방 사회성 프리미티브(SocialSim이 호출) ─────────────────────────
  Future<Map?> getRoom(String code) async =>
      _asMap(await _rtdb.get('rooms/$code'));

  int _randCharIdx() => (_spec.fixedChar ??
          kPlayableCharIds[_rng.nextInt(kPlayableCharIds.length)])
      .index;

  /// 공개방 생성 + 좌석0 호스트로 입장.
  Future<void> createPublicRoom(String code) async {
    await _rtdb.put('rooms/$code', {
      'host': _cred.uid,
      'capacity': 6,
      'started': false,
      'public': true,
      'pw': '',
      'match': false,
      'title': '${_cred.name}의 결투장',
      'hostName': _cred.name,
      'game': 0,
      'players': {
        'p0': {
          'id': _cred.uid,
          'name': _cred.name,
          'seen': Rtdb.serverTimestamp,
          'char': _randCharIdx(),
        }
      },
      'createdAt': Rtdb.serverTimestamp,
    }, auth: await _tok);
  }

  Future<void> joinSeat(String code, int seat) async {
    _tappedRound = -1;
    await _rtdb.put('rooms/$code/players/p$seat', {
      'id': _cred.uid,
      'name': _cred.name,
      'seen': Rtdb.serverTimestamp,
      'char': _randCharIdx(),
    }, auth: await _tok);
  }

  /// 준비 토글 — 쓰기 직전에 **내 uid가 실제 앉은 좌석**을 다시 찾아 그 좌석에만
  /// 쓴다(지연 실행되는 사이 좌석 압축/이탈이 있었으면 조용히 무시 — 유령 ready 방지).
  Future<void> setReady(String code, bool ready) async {
    try {
      final data = _asMap(await _rtdb.get('rooms/$code'));
      if (data == null || data['started'] == true) return;
      final s = _seatOfUid(data);
      if (s < 0) return;
      await _rtdb.put('rooms/$code/ready/p$s', ready ? true : null,
          auth: await _tok);
    } catch (_) {}
  }

  /// 좌석 엔트리(플레이어+ready)를 지운다 — 호스트 봇이 유령 노드·하트비트 끊긴
  /// 좌석을 청소할 때 사용. [key] 는 'p0' 같은 좌석 키.
  Future<void> removeSeatEntry(String code, String key) async {
    try {
      final tok = await _tok;
      await _rtdb.delete('rooms/$code/players/$key', auth: tok);
      await _rtdb.delete('rooms/$code/ready/$key', auth: tok);
    } catch (_) {}
  }

  Future<void> heartbeat(String code, int seat) async {
    try {
      await _rtdb.put('rooms/$code/players/p$seat/seen', Rtdb.serverTimestamp,
          auth: await _tok);
    } catch (_) {}
  }

  Future<void> becomeHost(String code) async {
    try {
      await _rtdb.put('rooms/$code/host', _cred.uid, auth: await _tok);
    } catch (_) {}
  }

  Future<void> leaveSeat(String code, int seat) => _leave(code, seat);

  Future<void> deleteRoom(String code) async {
    try {
      await _rtdb.delete('rooms/$code', auth: await _tok);
    } catch (_) {}
  }

  /// 호스트가 게임 시작(좌석 압축 + chars 스냅샷 + started). 앱 startGame 미러.
  Future<void> hostStartGame(String code) async {
    final data = await getRoom(code);
    final players = _asMap(data?['players']) ?? const {};
    final entries = <MapEntry<int, Map>>[];
    players.forEach((k, v) {
      final m = _asMap(v);
      if (m != null) {
        final s = int.tryParse('$k'.substring(1));
        if (s != null) entries.add(MapEntry(s, m));
      }
    });
    entries.sort((a, b) => a.key.compareTo(b.key));
    if (entries.length < 2) return;
    final compact = <String, Object?>{};
    final charsMap = <String, Object?>{};
    for (var i = 0; i < entries.length; i++) {
      final ci = _asInt(entries[i].value['char']) ?? 0;
      compact['p$i'] = {
        'id': entries[i].value['id'],
        'name': entries[i].value['name'],
        'seen': Rtdb.serverTimestamp,
        'char': ci,
      };
      charsMap['p$i'] = ci;
    }
    await _rtdb.patch('rooms/$code', {
      'players': compact,
      'chars': charsMap,
      'seatCount': entries.length,
      'started': true,
      'game': (_asInt(data?['game']) ?? 0) + 1,
      'turns': null,
      'ready': null,
      'showdown': null,
      'quit': null,
      'scored': null,
      'react': null,
    }, auth: await _tok);
  }

  Future<void> resetToLobby(String code) async {
    try {
      await _rtdb.patch('rooms/$code', {
        'turns': null,
        'showdown': null,
        'quit': null,
        'scored': null,
        'ready': null,
        'react': null,
        'peek': null,
        'peekUsed': null,
        'started': false,
      }, auth: await _tok);
    } catch (_) {}
  }

  /// 이미 좌석에 앉아 게임이 시작된 뒤 그 라운드를 플레이(사회성용). 무승부면
  /// 결투에 참가해 탭한다(승자 확정은 봇 호스트의 hostRefereeGame). 이기면 랭킹 기록.
  Future<void> playSeatedGame(String code, int seat) async {
    _cpu.beginGame();
    _applyPersonality(seat);
    try {
      await _gameLoop(code, seat);
    } catch (e) {
      _log('사회성 플레이 오류: $e');
    }
  }

  /// 앱 season_service 와 동일: 그 주 월요일 날짜(yyyy-MM-dd).
  static String _weeklySeasonId() {
    final n = DateTime.now();
    final d = DateTime(n.year, n.month, n.day);
    final m = d.subtract(Duration(days: d.weekday - 1)); // Mon=1
    String two(int x) => x.toString().padLeft(2, '0');
    return '${m.year}-${two(m.month)}-${two(m.day)}';
  }
}
