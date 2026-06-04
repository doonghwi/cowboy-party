import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../game/party_logic.dart';

/// Phase of an online room from one player's point of view.
enum OnlinePhase { waiting, choosing, submitted, over }

/// How long a player can go silent (no heartbeat) before they're treated as
/// gone — long enough that a quick app-backgrounding or network blip never
/// kicks anyone, short enough that a real departure unblocks the table.
const int kPresenceGraceMs = 14000;

/// Render-ready snapshot of one seat at the table.
class SeatView {
  final int seat;
  final bool joined; // player present in the room right now
  final String name;
  final int ammo;
  final bool alive;
  final bool isMe;

  final Move? lastMove;
  final bool fired;
  final bool superFired;
  final int firedTarget;
  final bool hitThisTurn;

  final bool submittedThisTurn;
  final int score;

  /// A CPU bot seat (host/driver submits its moves), not a human player.
  final bool isBot;

  const SeatView({
    required this.seat,
    required this.joined,
    required this.name,
    required this.ammo,
    required this.alive,
    required this.isMe,
    required this.lastMove,
    required this.fired,
    required this.superFired,
    required this.firedTarget,
    required this.hitThisTurn,
    required this.submittedThisTurn,
    required this.score,
    this.isBot = false,
  });
}

/// A fully-derived, render-ready view of a room from one player's perspective.
class RoomView {
  final int capacity;
  final int seatCount;
  final bool started;
  final bool isHost;
  final OnlinePhase phase;
  final int turn;
  final int mySeat; // -1 if I'm not seated
  final List<SeatView> seats;
  final int joinedCount;
  final int presentCount;
  final bool canStart;
  final Move? myPending;
  final bool iSubmitted;
  final int submittedAlive;
  final int aliveCount;
  final GameStatus status;
  final int? winnerSeat;
  final String banner;
  final bool justResolved;
  final bool iRequestedRematch;
  final int rematchCount;

  /// Seats that have gone silent mid-game and should be reaped (host writes a
  /// sticky `quit` marker so the departure is consistent across clients).
  final List<int> reapSeats;

  /// I was removed from a started game (left or timed out).
  final bool iAmOut;

  final int drawTurn;
  final List<int> drawParticipants;

  /// The seat responsible for submitting bot moves this game (lowest present
  /// human). The client sitting here drives every CPU bot. -1 if none.
  final int botDriverSeat;

  const RoomView({
    required this.capacity,
    required this.seatCount,
    required this.started,
    required this.isHost,
    required this.phase,
    required this.turn,
    required this.mySeat,
    required this.seats,
    required this.joinedCount,
    required this.presentCount,
    required this.canStart,
    required this.myPending,
    required this.iSubmitted,
    required this.submittedAlive,
    required this.aliveCount,
    required this.status,
    required this.winnerSeat,
    required this.banner,
    required this.justResolved,
    required this.iRequestedRematch,
    required this.rematchCount,
    this.reapSeats = const [],
    this.iAmOut = false,
    this.drawTurn = -1,
    this.drawParticipants = const [],
    this.botDriverSeat = -1,
  });

  bool get seated => mySeat >= 0;
  SeatView? get me => seated && mySeat < seats.length ? seats[mySeat] : null;
  bool get iWon => status == GameStatus.won && winnerSeat == mySeat;
}

enum JoinResult { joined, notFound, full, alreadyStarted }

class OnlineService {
  OnlineService() : clientId = _genClientId() {
    // Track clock skew so heartbeats/staleness use server time.
    serverOffsetRef().onValue.listen((e) {
      final v = e.snapshot.value;
      if (v is num) _offset = v.toInt();
    });
  }

  final String clientId;
  int _offset = 0;

  static const String databaseUrl =
      'https://cowboy-party-doonghwi-default-rtdb.asia-southeast1.firebasedatabase.app';

  final FirebaseDatabase _fdb = FirebaseDatabase.instanceFor(
      app: Firebase.app(), databaseURL: databaseUrl);

  late final DatabaseReference _root = _fdb.ref();

  DatabaseReference serverOffsetRef() => _fdb.ref('.info/serverTimeOffset');

  int get _now => DateTime.now().millisecondsSinceEpoch + _offset;

  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const _idChars = 'abcdefghijklmnopqrstuvwxyz0123456789';

  static String _genClientId() {
    final r = Random();
    return List.generate(10, (_) => _idChars[r.nextInt(_idChars.length)]).join();
  }

  static String generateRoomCode() {
    final r = Random();
    return List.generate(4, (_) => _codeChars[r.nextInt(_codeChars.length)])
        .join();
  }

  static const _nickPool = [
    '방랑객', '총잡이', '무법자', '보안관', '건맨', '독수리',
    '선인장', '리볼버', '데드샷', '현상금', '협곡', '먼지'
  ];

  static String randomNickname() {
    final r = Random();
    return '${_nickPool[r.nextInt(_nickPool.length)]}${10 + r.nextInt(90)}';
  }

  static String slotKey(int seat) => 'p$seat';
  static int seatOf(String slotKey) => int.parse(slotKey.substring(1));

  DatabaseReference room(String code) => _root.child('rooms/$code');
  Stream<DatabaseEvent> watch(String code) => room(code).onValue;

  Future<void> createRoom(String code, String name, int capacity) async {
    await room(code).set({
      'host': clientId,
      'capacity': capacity.clamp(kMinSeats, kMaxSeats),
      'started': false,
      'players': {
        'p0': {'id': clientId, 'name': name, 'seen': _now},
      },
      'turns': null,
      'rematch': null,
      'showdown': null,
      'quit': null,
      'createdAt': ServerValue.timestamp,
    });
  }

  /// Claim a seat. Re-joining with the same id reclaims the held seat; an empty
  /// or long-silent (stale) seat can be taken. No hard onDisconnect removal —
  /// the heartbeat + grace decides presence, so a brief blip never kicks you.
  Future<JoinResult> joinRoom(String code, String name) async {
    final snap = await room(code).get();
    if (!snap.exists) return JoinResult.notFound;
    final data = _asMap(snap.value) ?? const {};
    final players = _asMap(data['players']) ?? const {};

    // Already hold a seat? Reclaim it (refresh heartbeat).
    for (final e in players.entries) {
      final v = _asMap(e.value);
      if (v != null && v['id'] == clientId) {
        final s = seatOf(e.key.toString());
        await room(code).child('players/${slotKey(s)}/seen').set(_now);
        return JoinResult.joined;
      }
    }
    if (data['started'] == true) return JoinResult.alreadyStarted;

    final capacity = _asInt(data['capacity']) ?? kMaxSeats;
    final staleBefore = _now - kPresenceGraceMs;
    for (var s = 1; s < capacity; s++) {
      final res =
          await room(code).child('players/${slotKey(s)}').runTransaction(
        (current) {
          if (current == null) {
            return Transaction.success(
                {'id': clientId, 'name': name, 'seen': _now});
          }
          final v = _asMap(current);
          if (v != null && v['id'] == clientId) {
            return Transaction.success(current);
          }
          final seen = _asInt(v?['seen']);
          if (seen != null && seen < staleBefore) {
            // Silent long enough — take the seat.
            return Transaction.success(
                {'id': clientId, 'name': name, 'seen': _now});
          }
          return Transaction.abort();
        },
      );
      if (res.committed) {
        final v = _asMap(res.snapshot.value);
        if (v != null && v['id'] == clientId) return JoinResult.joined;
      }
    }
    return JoinResult.full;
  }

  static const _botNames = ['잭', '빌', '한스', '로사', '듀크', '머독'];

  /// Host adds a CPU bot to the first empty seat of a not-yet-started room.
  /// Bots have a synthetic id, a `bot:true` flag, and don't heartbeat — the
  /// driver client submits their moves and they're exempt from staleness.
  Future<void> addBot(String code) async {
    final snap = await room(code).get();
    if (!snap.exists) return;
    final data = _asMap(snap.value) ?? const {};
    if (data['started'] == true) return;
    final players = _asMap(data['players']) ?? const {};
    final capacity = _asInt(data['capacity']) ?? kMaxSeats;
    final taken = <int>{
      for (final e in players.entries) seatOf(e.key.toString())
    };
    var botCount = 0;
    for (final v in players.values) {
      if (_asMap(v)?['bot'] == true) botCount++;
    }
    for (var s = 1; s < capacity; s++) {
      if (taken.contains(s)) continue;
      final name = '봇 ${_botNames[botCount % _botNames.length]}';
      final res =
          await room(code).child('players/${slotKey(s)}').runTransaction((cur) {
        if (cur != null) return Transaction.abort();
        return Transaction.success(
            {'id': 'bot_$s', 'name': name, 'bot': true, 'seen': _now});
      });
      if (res.committed) return;
    }
  }

  /// Host removes a bot from a waiting room (no-op on a human seat).
  Future<void> removeBot(String code, int seat) async {
    final ref = room(code).child('players/${slotKey(seat)}');
    final snap = await ref.get();
    if (_asMap(snap.value)?['bot'] == true) await ref.remove();
  }

  /// Keep my seat alive. Called on a timer while I'm in the room.
  Future<void> heartbeat(String code, int seat) async {
    try {
      await room(code).child('players/${slotKey(seat)}/seen').set(_now);
    } catch (_) {}
  }

  Future<void> startGame(String code) async {
    final snap = await room(code).child('players').get();
    final players = _asMap(snap.value) ?? const {};
    final entries = <MapEntry<int, Map>>[];
    for (final e in players.entries) {
      final v = _asMap(e.value);
      if (v != null) entries.add(MapEntry(seatOf(e.key.toString()), v));
    }
    entries.sort((a, b) => a.key.compareTo(b.key));
    if (entries.length < kMinSeats) return;
    final compact = <String, Object?>{};
    for (var i = 0; i < entries.length; i++) {
      compact[slotKey(i)] = {
        'id': entries[i].value['id'],
        'name': entries[i].value['name'],
        'seen': _now,
        if (entries[i].value['bot'] == true) 'bot': true,
      };
    }
    await room(code).update({
      'players': compact,
      'seatCount': entries.length,
      'started': true,
      'turns': null,
      'rematch': null,
      'showdown': null,
      'quit': null,
      'scored': null,
      'react': null,
    });
  }

  Future<void> submitMove(String code, int turn, int seat, Move m) {
    room(code).child('players/${slotKey(seat)}/seen').set(_now);
    return room(code).child('turns/t$turn/${slotKey(seat)}').set(m.encode());
  }

  Future<void> requestRematch(String code, int seat) {
    return room(code).child('rematch/${slotKey(seat)}').set(true);
  }

  /// Broadcast an emoji reaction over my seat. Stamped with server time so each
  /// client shows it briefly then lets it fade.
  Future<void> sendReaction(String code, int seat, String emoji) {
    return room(code).child('react/${slotKey(seat)}').set({'e': emoji, 't': _now});
  }

  /// Host marks silent players as having quit — sticky, so the departure stays
  /// consistent even if their client later reconnects mid-game.
  Future<void> markQuit(String code, List<int> seats) async {
    final updates = <String, Object?>{
      for (final s in seats) 'quit/${slotKey(s)}': true,
    };
    if (updates.isNotEmpty) {
      try {
        await room(code).update(updates);
      } catch (_) {}
    }
  }

  /// Bump the winner's score the moment the game is decided (once per game,
  /// guarded by the sticky `scored` flag so a replay never double-counts).
  Future<void> recordScore(String code, int winnerSeat) async {
    try {
      final snap = await room(code).child('scored').get();
      if (snap.value == true) return;
      await room(code).child('scored').set(true);
      await room(code).child('score/${slotKey(winnerSeat)}').runTransaction((cur) {
        final n = cur is int ? cur : 0;
        return Transaction.success(n + 1);
      });
    } catch (_) {}
  }

  /// Clear the board for a fresh round (score is kept; it was already recorded
  /// at win time).
  Future<void> resetBoard(String code) async {
    await room(code).update({
      'turns': null,
      'rematch': null,
      'showdown': null,
      'quit': null,
      'scored': null,
      'react': null,
    });
  }

  /// Leave for good. In a started game this also writes a sticky quit so the
  /// seat is reaped immediately; in the lobby it just frees the seat. The
  /// leaver's [name] is stored in the quit marker so other clients can still
  /// say "OOO 님이 나갔어요" after the player node is removed.
  Future<void> leave(String code, int seat,
      {bool started = false, String? name}) async {
    try {
      if (started) {
        await room(code).child('quit/${slotKey(seat)}').set(
            (name != null && name.isNotEmpty) ? name : true);
      }
      await room(code).child('players/${slotKey(seat)}').remove();
    } catch (_) {}
  }

  // ---- Reaction showdown -------------------------------------------------

  Future<void> createShowdown(
      String code, int turn, List<int> participants, int goAtServerMs) {
    return room(code).child('showdown').set({
      'turn': turn,
      'round': 0,
      'goAt': goAtServerMs,
      'participants': {for (final s in participants) slotKey(s): true},
      'winner': null,
      'falseStart': null,
    });
  }

  Future<void> newShowdownRound(String code, int round, int goAtServerMs) {
    return room(code).child('showdown').update({
      'round': round,
      'goAt': goAtServerMs,
      'winner': null,
      'falseStart': null,
      'taps': null,
    });
  }

  Future<void> recordFalseStart(String code, int seat) {
    return room(code).child('showdown/falseStart/${slotKey(seat)}').set(true);
  }

  /// Record my reaction tap time (server clock). The host then awards the win
  /// to the *earliest* valid tap — fair by reaction speed, not network luck.
  Future<void> recordTap(String code, int seat, int tapMs) {
    return room(code).child('showdown/taps/${slotKey(seat)}').set(tapMs);
  }

  /// Host commits the showdown winner (once).
  Future<void> setShowdownWinner(String code, int seat) {
    return room(code).child('showdown/winner').runTransaction((cur) {
      if (cur == null) return Transaction.success(seat);
      return Transaction.abort();
    });
  }

  // ---- Pure helpers ------------------------------------------------------

  static int? _asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);

  static Map? _asMap(Object? v) {
    if (v is Map) return Map<String, Object?>.from(v);
    if (v is List) {
      final m = <String, Object?>{};
      for (var i = 0; i < v.length; i++) {
        if (v[i] != null) m['t$i'] = v[i];
      }
      return m;
    }
    return null;
  }

  /// Deterministic replay of a room into a view for [myClientId]. [nowServerMs]
  /// is the caller's best estimate of server time (local + offset); pass 0 in
  /// tests to disable staleness culling.
  static RoomView computeView(Map data, String myClientId,
      {int nowServerMs = 0}) {
    final players = _asMap(data['players']) ?? const {};
    final turnsMap = _asMap(data['turns']) ?? const {};
    final scoreMap = _asMap(data['score']) ?? const {};
    final rematchMap = _asMap(data['rematch']) ?? const {};
    final quitMap = _asMap(data['quit']) ?? const {};
    final showdown = _asMap(data['showdown']);
    final started = data['started'] == true;
    final isHost = data['host'] == myClientId;
    final capacity =
        (_asInt(data['capacity']) ?? kMaxSeats).clamp(kMinSeats, kMaxSeats);
    final staleBefore = nowServerMs <= 0 ? -1 : nowServerMs - kPresenceGraceMs;

    var mySeat = -1;
    final names = <int, String>{};
    final nodeExists = <int, bool>{};
    final stale = <int, bool>{};
    final isBotMap = <int, bool>{};
    for (final e in players.entries) {
      final v = _asMap(e.value);
      if (v == null) continue;
      final s = seatOf(e.key.toString());
      names[s] = (v['name'] as String?) ?? '카우보이';
      nodeExists[s] = true;
      isBotMap[s] = v['bot'] == true;
      final seen = _asInt(v['seen']);
      stale[s] = staleBefore > 0 && seen != null && seen < staleBefore;
      if (v['id'] == myClientId) mySeat = s;
    }
    bool isBot(int s) => isBotMap[s] == true;
    // A quit marker is either `true` (host-reaped silent seat) or the leaver's
    // name (written by leave()), kept sticky so departures stay consistent.
    bool quit(int s) {
      final v = quitMap[slotKey(s)];
      return v == true || v is String;
    }

    String? quitName(int s) {
      final v = quitMap[slotKey(s)];
      return v is String && v.isNotEmpty ? v : null;
    }

    // Best-effort display name for a seat even after its player node is gone.
    String? leftName(int s) => names[s] ?? quitName(s);

    // "present" = here, not timed out, not quit. Bots never heartbeat, so they
    // count as present until the game removes them or the host quits them.
    bool present(int s) {
      if (nodeExists[s] != true || quit(s)) return false;
      if (isBot(s)) return true;
      return stale[s] != true;
    }

    final joinedCount = [
      for (var s = 0; s < capacity; s++)
        if (present(s)) s
    ].length;

    int scoreFor(int s) => _asInt(scoreMap[slotKey(s)]) ?? 0;

    // ---- Waiting room ----------------------------------------------------
    if (!started) {
      final seats = <SeatView>[
        for (var s = 0; s < capacity; s++)
          SeatView(
            seat: s,
            joined: present(s),
            name: present(s) ? (names[s] ?? '카우보이') : '빈자리',
            ammo: 0,
            alive: true,
            isMe: s == mySeat,
            lastMove: null,
            fired: false,
            superFired: false,
            firedTarget: -1,
            hitThisTurn: false,
            submittedThisTurn: false,
            score: scoreFor(s),
            isBot: present(s) && isBot(s),
          ),
      ];
      return RoomView(
        capacity: capacity,
        seatCount: joinedCount,
        started: false,
        isHost: isHost,
        phase: OnlinePhase.waiting,
        turn: 0,
        mySeat: present(mySeat) ? mySeat : -1,
        seats: seats,
        joinedCount: joinedCount,
        presentCount: joinedCount,
        canStart: isHost && joinedCount >= kMinSeats,
        myPending: null,
        iSubmitted: false,
        submittedAlive: 0,
        aliveCount: joinedCount,
        status: GameStatus.ongoing,
        winnerSeat: null,
        banner:
            '총잡이 $joinedCount명 모임 · ${isHost ? "2명 이상이면 시작!" : "호스트의 시작을 기다리는 중"}',
        justResolved: false,
        iRequestedRematch: false,
        rematchCount: 0,
      );
    }

    // ---- Live game -------------------------------------------------------
    final n =
        (_asInt(data['seatCount']) ?? joinedCount).clamp(kMinSeats, kMaxSeats);

    var ammo = List<int>.filled(n, 0);
    var alive = List<bool>.filled(n, true);
    var lastMoves = List<Move?>.filled(n, null);
    var fired = List<bool>.filled(n, false);
    var superFired = List<bool>.filled(n, false);
    var firedTarget = List<int>.filled(n, -1);
    var hit = List<bool>.filled(n, false);
    var banner = '행동을 골라라!';
    final reap = <int>{};
    var t = 0;

    while (true) {
      final turn = _asMap(turnsMap['t$t']);
      var submitted = List<bool>.filled(n, false);
      var moves = List<Move>.filled(n, Move.empty);

      bool computeSubs() {
        submitted = List<bool>.filled(n, false);
        moves = List<Move>.filled(n, Move.empty);
        var all = true;
        for (var s = 0; s < n; s++) {
          if (!alive[s]) continue;
          final raw = turn == null ? null : _asInt(turn[slotKey(s)]);
          if (raw == null) {
            all = false;
          } else {
            submitted[s] = true;
            moves[s] = Move.decode(raw);
          }
        }
        return all;
      }

      var allAliveSubmitted = computeSubs();

      // Stuck waiting? Drop anyone who has gone (left/timed out) so the table
      // never freezes. Only at the live frontier — history is never rewritten.
      if (!allAliveSubmitted) {
        final justLeft = <int>[];
        for (var s = 0; s < n; s++) {
          if (alive[s] && !present(s)) {
            alive[s] = false;
            justLeft.add(s);
            // A silent-but-still-present node should be made a sticky quit.
            if (nodeExists[s] == true && !quit(s)) reap.add(s);
          }
        }
        if (justLeft.isNotEmpty) {
          final survivors = [
            for (var s = 0; s < n; s++)
              if (alive[s]) s
          ];
          if (survivors.length <= 1) {
            // The game didn't end by a real shot — someone left. Say so plainly
            // instead of crowning whoever happened to remain.
            final leftNames = [for (final s in justLeft) leftName(s) ?? '상대'];
            final banner = survivors.length == 1
                ? (leftNames.length == 1
                    ? '${leftNames.first} 님이 나갔어요'
                    : '상대가 모두 나갔어요')
                : '모두 떠났어요';
            return _buildView(
              phase: OnlinePhase.over,
              capacity: capacity,
              seatCount: n,
              isHost: isHost,
              turn: -1,
              mySeat: mySeat,
              names: names,
              presentFn: present,
              ammo: ammo,
              alive: alive,
              lastMoves: lastMoves,
              fired: List<bool>.filled(n, false),
              superFired: List<bool>.filled(n, false),
              firedTarget: List<int>.filled(n, -1),
              hit: List<bool>.filled(n, false),
              submitted: List<bool>.filled(n, false),
              scoreFor: scoreFor,
              joinedCount: joinedCount,
              myPending: null,
              iSubmitted: true,
              submittedAlive: 0,
              aliveCount: survivors.length,
              banner: banner,
              status:
                  survivors.length == 1 ? GameStatus.won : GameStatus.draw,
              winner: survivors.length == 1 ? survivors.first : null,
              rematchMap: rematchMap,
              quitFn: quit,
              isBotFn: isBot,
              reap: reap.toList()..sort(),
            );
          }
          allAliveSubmitted = computeSubs();
        }
      }

      if (!allAliveSubmitted) {
        final iAmAlive = mySeat >= 0 && mySeat < n && alive[mySeat];
        final iSubmitted = !iAmAlive || submitted[mySeat];
        final aliveCount = alive.where((a) => a).length;
        final submittedAlive = [
          for (var s = 0; s < n; s++)
            if (alive[s] && submitted[s]) s
        ].length;
        return _buildView(
          phase: iSubmitted && iAmAlive
              ? OnlinePhase.submitted
              : OnlinePhase.choosing,
          capacity: capacity,
          seatCount: n,
          isHost: isHost,
          turn: t,
          mySeat: mySeat,
          names: names,
          presentFn: present,
          ammo: ammo,
          alive: alive,
          lastMoves: lastMoves,
          fired: fired,
          superFired: superFired,
          firedTarget: firedTarget,
          hit: hit,
          submitted: submitted,
          scoreFor: scoreFor,
          joinedCount: joinedCount,
          myPending: (mySeat >= 0 && mySeat < n && submitted[mySeat])
              ? moves[mySeat]
              : null,
          iSubmitted: iSubmitted && iAmAlive,
          submittedAlive: submittedAlive,
          aliveCount: aliveCount,
          banner: iSubmitted && iAmAlive
              ? '다른 총잡이를 기다리는 중... ($submittedAlive/$aliveCount)'
              : banner,
          status: GameStatus.ongoing,
          winner: null,
          rematchMap: const {},
          quitFn: quit,
          isBotFn: isBot,
          reap: reap.toList()..sort(),
        );
      }

      final aliveBefore = List<bool>.from(alive);
      final out = resolveTurn(moves, ammo, alive);
      ammo = out.ammoAfter;
      lastMoves = List<Move?>.from(moves);
      fired = out.fired;
      superFired = out.superFired;
      firedTarget = out.firedTarget;
      hit = out.hit;
      alive = out.aliveAfter;
      banner = _turnBanner(out, names, moves, aliveBefore);

      if (out.status != GameStatus.ongoing) {
        var status = out.status;
        var winner = out.winner;
        var drawTurn = -1;
        var drawParticipants = const <int>[];
        if (out.status == GameStatus.draw) {
          // Everyone alive entering the turn fell together — they're the
          // reaction-showdown contestants.
          final parts = [
            for (var s = 0; s < n; s++)
              if (aliveBefore[s]) s
          ];
          final sdWinner = (showdown != null && _asInt(showdown['turn']) == t)
              ? _asInt(showdown['winner'])
              : null;
          if (sdWinner != null) {
            status = GameStatus.won;
            winner = sdWinner;
            // They won the reaction duel — bring them back to life so the table
            // shows the victor standing, not a skull next to "승리!".
            if (sdWinner >= 0 && sdWinner < n) {
              alive[sdWinner] = true;
              hit[sdWinner] = false;
            }
          } else {
            drawTurn = t;
            drawParticipants = parts;
          }
        }
        return _buildView(
          phase: OnlinePhase.over,
          capacity: capacity,
          seatCount: n,
          isHost: isHost,
          turn: -1,
          mySeat: mySeat,
          names: names,
          presentFn: present,
          ammo: ammo,
          alive: alive,
          lastMoves: lastMoves,
          fired: fired,
          superFired: superFired,
          firedTarget: firedTarget,
          hit: hit,
          submitted: List<bool>.filled(n, false),
          scoreFor: scoreFor,
          joinedCount: joinedCount,
          myPending: null,
          iSubmitted: true,
          submittedAlive: 0,
          aliveCount: alive.where((a) => a).length,
          banner: status == GameStatus.won
              ? (winner == mySeat
                  ? '최후의 1인! 승리!'
                  : (winner != null && !present(winner)
                      // The winner already left the room — don't degrade their
                      // banner to the default "카우보이 승리!"; show they're gone.
                      ? '${leftName(winner) ?? "상대"} 님이 나갔어요'
                      : '${names[winner] ?? "카우보이"} 승리!'))
              : '모두 쓰러졌다!',
          status: status,
          winner: winner,
          rematchMap: rematchMap,
          quitFn: quit,
          isBotFn: isBot,
          reap: reap.toList()..sort(),
          drawTurn: drawTurn,
          drawParticipants: drawParticipants,
        );
      }
      t++;
    }
  }

  static RoomView _buildView({
    required OnlinePhase phase,
    required int capacity,
    required int seatCount,
    required bool isHost,
    required int turn,
    required int mySeat,
    required Map<int, String> names,
    required bool Function(int) presentFn,
    required List<int> ammo,
    required List<bool> alive,
    required List<Move?> lastMoves,
    required List<bool> fired,
    required List<bool> superFired,
    required List<int> firedTarget,
    required List<bool> hit,
    required List<bool> submitted,
    required int Function(int) scoreFor,
    required int joinedCount,
    required Move? myPending,
    required bool iSubmitted,
    required int submittedAlive,
    required int aliveCount,
    required String banner,
    required GameStatus status,
    required int? winner,
    required Map rematchMap,
    required bool Function(int) quitFn,
    required bool Function(int) isBotFn,
    List<int> reap = const [],
    int drawTurn = -1,
    List<int> drawParticipants = const [],
  }) {
    final seats = <SeatView>[
      for (var s = 0; s < seatCount; s++)
        SeatView(
          seat: s,
          joined: presentFn(s),
          name: names[s] ?? '카우보이',
          ammo: ammo[s],
          alive: alive[s],
          isMe: s == mySeat,
          lastMove: lastMoves[s],
          fired: fired[s],
          superFired: superFired[s],
          firedTarget: firedTarget[s],
          hitThisTurn: hit[s],
          submittedThisTurn: submitted[s],
          score: scoreFor(s),
          isBot: isBotFn(s),
        ),
    ];
    final presentCount = [
      for (var s = 0; s < seatCount; s++)
        if (presentFn(s)) s
    ].length;
    // The lowest present human drives every bot's moves (survives host leaving).
    var botDriverSeat = -1;
    for (var s = 0; s < seatCount; s++) {
      if (presentFn(s) && !isBotFn(s)) {
        botDriverSeat = s;
        break;
      }
    }
    var rematchCount = 0;
    var iRematch = false;
    for (var s = 0; s < seatCount; s++) {
      if (rematchMap[slotKey(s)] == true) {
        rematchCount++;
        if (s == mySeat) iRematch = true;
      }
    }
    final iAmOut = mySeat < 0 || mySeat >= seatCount || quitFn(mySeat);
    return RoomView(
      capacity: capacity,
      seatCount: seatCount,
      started: true,
      isHost: isHost,
      phase: phase,
      turn: turn,
      mySeat: mySeat,
      seats: seats,
      joinedCount: joinedCount,
      presentCount: presentCount,
      canStart: false,
      myPending: myPending,
      iSubmitted: iSubmitted,
      submittedAlive: submittedAlive,
      aliveCount: aliveCount,
      status: status,
      winnerSeat: winner,
      banner: banner,
      justResolved: phase == OnlinePhase.over,
      iRequestedRematch: iRematch,
      rematchCount: rematchCount,
      reapSeats: reap,
      iAmOut: iAmOut,
      drawTurn: drawTurn,
      drawParticipants: drawParticipants,
      botDriverSeat: botDriverSeat,
    );
  }

  static String _turnBanner(TurnOutcome out, Map<int, String> names,
      List<Move> moves, List<bool> aliveBefore) {
    final downed = <String>[
      for (var s = 0; s < out.hit.length; s++)
        if (out.hit[s]) names[s] ?? '카우보이'
    ];
    if (downed.isNotEmpty) return '${downed.join(", ")} 명중!';
    if (out.fired.any((x) => x)) return '모두 막거나 빗나갔다!';
    return _quietBanner(moves, aliveBefore);
  }

  /// Nobody fired this turn — describe what the living cowboys actually did so
  /// "둘 다 방어" / "둘 다 장전" read true instead of a generic mixed message.
  static String _quietBanner(List<Move> moves, List<bool> aliveBefore) {
    final kinds = <ActKind>[
      for (var s = 0; s < moves.length; s++)
        if (s < aliveBefore.length && aliveBefore[s]) moves[s].kind
    ];
    final all = kinds.length <= 2 ? '둘 다' : '모두';
    if (kinds.isNotEmpty && kinds.every((k) => k == ActKind.defend)) {
      return '$all 방어! 다음 턴';
    }
    if (kinds.isNotEmpty && kinds.every((k) => k == ActKind.reload)) {
      return '$all 장전! 다음 턴';
    }
    return '장전과 방어... 다음 턴!';
  }
}
