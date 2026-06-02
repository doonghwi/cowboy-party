import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../game/party_logic.dart';

/// Phase of an online room from one player's point of view.
enum OnlinePhase { waiting, choosing, submitted, over }

/// Render-ready snapshot of one seat at the table.
class SeatView {
  final int seat;
  final bool joined;
  final String name;
  final int ammo;
  final bool alive;
  final bool isMe;

  /// The seat's move on the most recently *resolved* turn (for the reveal).
  final Move? lastMove;
  final bool fired;
  final int firedTarget;
  final bool hitThisTurn;

  /// Whether this seat has locked a move for the current (unresolved) turn.
  final bool submittedThisTurn;
  final int score;

  const SeatView({
    required this.seat,
    required this.joined,
    required this.name,
    required this.ammo,
    required this.alive,
    required this.isMe,
    required this.lastMove,
    required this.fired,
    required this.firedTarget,
    required this.hitThisTurn,
    required this.submittedThisTurn,
    required this.score,
  });
}

/// A fully-derived, render-ready view of a room from one player's perspective.
class RoomView {
  final int capacity; // host's chosen max seats (waiting room layout)
  final int seatCount; // active seats; before start == joinedCount
  final bool started;
  final bool isHost;
  final OnlinePhase phase;
  final int turn;
  final int mySeat; // -1 if I'm not seated
  final List<SeatView> seats; // index == seat
  final int joinedCount;
  final bool canStart; // host may begin the round
  final Move? myPending;
  final bool iSubmitted;
  final int submittedAlive; // how many living seats have locked in
  final int aliveCount;
  final GameStatus status;
  final int? winnerSeat;
  final String banner;
  final bool justResolved;
  final bool iRequestedRematch;
  final int rematchCount;

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
  });

  bool get seated => mySeat >= 0;
  SeatView? get me => seated && mySeat < seats.length ? seats[mySeat] : null;
  bool get iWon => status == GameStatus.won && winnerSeat == mySeat;
}

/// Result of trying to join a room.
enum JoinResult { joined, notFound, full, alreadyStarted }

class OnlineService {
  OnlineService() : clientId = _genClientId();

  final String clientId;

  /// The RTDB lives in asia-southeast1. We pin the regional URL explicitly:
  /// relying on the default instance can connect to the wrong region (the
  /// server then force-closes the socket and writes hang forever).
  static const String databaseUrl =
      'https://cowboy-party-doonghwi-default-rtdb.asia-southeast1.firebasedatabase.app';

  final DatabaseReference _root = FirebaseDatabase.instanceFor(
          app: Firebase.app(), databaseURL: databaseUrl)
      .ref();

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

  /// RTDB slot key for a seat. Prefixed so Firebase never coerces the player
  /// map into a List (which happens with purely numeric keys).
  static String slotKey(int seat) => 'p$seat';
  static int seatOf(String slotKey) => int.parse(slotKey.substring(1));

  DatabaseReference room(String code) => _root.child('rooms/$code');
  Stream<DatabaseEvent> watch(String code) => room(code).onValue;

  /// Host creates the room at seat 0 and picks the max number of seats.
  Future<void> createRoom(String code, String name, int capacity) async {
    await room(code).set({
      'host': clientId,
      'capacity': capacity.clamp(kMinSeats, kMaxSeats),
      'started': false,
      'players': {
        'p0': {'id': clientId, 'name': name},
      },
      'turns': null,
      'rematch': null,
      'score': null,
      'createdAt': ServerValue.timestamp,
    });
  }

  /// Claim the lowest free guest seat. Each seat is claimed with its **own**
  /// transaction so two joiners can never land on the same seat.
  Future<JoinResult> joinRoom(String code, String name) async {
    final snap = await room(code).get();
    if (!snap.exists) return JoinResult.notFound;
    final data = _asMap(snap.value) ?? const {};
    final players = _asMap(data['players']) ?? const {};

    // Re-joining with the same client id? Keep my existing seat.
    for (final e in players.entries) {
      final v = _asMap(e.value);
      if (v != null && v['id'] == clientId) return JoinResult.joined;
    }
    if (data['started'] == true) return JoinResult.alreadyStarted;

    final capacity = _asInt(data['capacity']) ?? kMaxSeats;
    for (var s = 1; s < capacity; s++) {
      final res =
          await room(code).child('players/${slotKey(s)}').runTransaction(
        (current) {
          if (current == null) {
            return Transaction.success({'id': clientId, 'name': name});
          }
          final v = _asMap(current);
          if (v != null && v['id'] == clientId) {
            return Transaction.success(current);
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

  /// Host begins the round: compact the joined players into contiguous seats
  /// p0..p(n-1), lock [seatCount] and flip [started]. Compacting means a gap
  /// left by a pre-start departure never produces a dead seat mid-game.
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
      };
    }
    await room(code).update({
      'players': compact,
      'seatCount': entries.length,
      'started': true,
      'turns': null,
      'rematch': null,
    });
  }

  Future<void> submitMove(String code, int turn, int seat, Move m) {
    return room(code).child('turns/t$turn/${slotKey(seat)}').set(m.encode());
  }

  Future<void> requestRematch(String code, int seat) {
    return room(code).child('rematch/${slotKey(seat)}').set(true);
  }

  /// Host records the winner and clears the board for a fresh round.
  Future<void> recordWinAndReset(String code, int? winnerSeat) async {
    if (winnerSeat != null) {
      await room(code)
          .child('score/${slotKey(winnerSeat)}')
          .runTransaction((cur) {
        final n = cur is int ? cur : 0;
        return Transaction.success(n + 1);
      });
    }
    await room(code).update({'turns': null, 'rematch': null});
  }

  Future<void> leave(String code, int seat) async {
    await room(code).child('players/${slotKey(seat)}').remove();
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

  /// Deterministic replay of a room into a view for the caller's [myClientId].
  /// Mirrors the offline engine exactly by funnelling every turn through
  /// [resolveTurn].
  static RoomView computeView(Map data, String myClientId) {
    final players = _asMap(data['players']) ?? const {};
    final turnsMap = _asMap(data['turns']) ?? const {};
    final scoreMap = _asMap(data['score']) ?? const {};
    final rematchMap = _asMap(data['rematch']) ?? const {};
    final started = data['started'] == true;
    final isHost = data['host'] == myClientId;
    final capacity =
        (_asInt(data['capacity']) ?? kMaxSeats).clamp(kMinSeats, kMaxSeats);

    // Find my seat by client id, and gather names/scores for every slot.
    var mySeat = -1;
    final names = <int, String>{};
    final joinedSeats = <int>[];
    for (final e in players.entries) {
      final v = _asMap(e.value);
      if (v == null) continue;
      final s = seatOf(e.key.toString());
      names[s] = (v['name'] as String?) ?? '카우보이';
      joinedSeats.add(s);
      if (v['id'] == myClientId) mySeat = s;
    }
    joinedSeats.sort();
    final joinedCount = joinedSeats.length;

    int scoreFor(int s) => _asInt(scoreMap[slotKey(s)]) ?? 0;

    // ---- Waiting room (before the host starts) ---------------------------
    if (!started) {
      final seats = <SeatView>[
        for (var s = 0; s < capacity; s++)
          SeatView(
            seat: s,
            joined: names.containsKey(s),
            name: names[s] ?? '빈자리',
            ammo: 0,
            alive: true,
            isMe: s == mySeat,
            lastMove: null,
            fired: false,
            firedTarget: -1,
            hitThisTurn: false,
            submittedThisTurn: false,
            score: scoreFor(s),
          ),
      ];
      return RoomView(
        capacity: capacity,
        seatCount: joinedCount,
        started: false,
        isHost: isHost,
        phase: OnlinePhase.waiting,
        turn: 0,
        mySeat: mySeat,
        seats: seats,
        joinedCount: joinedCount,
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

    // ---- Live game (after start) -----------------------------------------
    final n =
        (_asInt(data['seatCount']) ?? joinedCount).clamp(kMinSeats, kMaxSeats);

    var ammo = List<int>.filled(n, 0);
    var alive = List<bool>.filled(n, true);
    var lastMoves = List<Move?>.filled(n, null);
    var fired = List<bool>.filled(n, false);
    var firedTarget = List<int>.filled(n, -1);
    var hit = List<bool>.filled(n, false);
    var banner = '행동을 골라라!';
    var t = 0;

    while (true) {
      final turn = _asMap(turnsMap['t$t']);
      final submitted = List<bool>.filled(n, false);
      final moves = List<Move>.filled(n, Move.empty);
      var allAliveSubmitted = true;
      for (var s = 0; s < n; s++) {
        if (!alive[s]) continue;
        final raw = turn == null ? null : _asInt(turn[slotKey(s)]);
        if (raw == null) {
          allAliveSubmitted = false;
        } else {
          submitted[s] = true;
          moves[s] = Move.decode(raw);
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
          ammo: ammo,
          alive: alive,
          lastMoves: lastMoves,
          fired: fired,
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
        );
      }

      final out = resolveTurn(moves, ammo, alive);
      ammo = out.ammoAfter;
      lastMoves = List<Move?>.from(moves);
      fired = out.fired;
      firedTarget = out.firedTarget;
      hit = out.hit;
      alive = out.aliveAfter;
      banner = _turnBanner(out, names);

      if (out.status != GameStatus.ongoing) {
        return _buildView(
          phase: OnlinePhase.over,
          capacity: capacity,
          seatCount: n,
          isHost: isHost,
          turn: -1,
          mySeat: mySeat,
          names: names,
          ammo: ammo,
          alive: alive,
          lastMoves: lastMoves,
          fired: fired,
          firedTarget: firedTarget,
          hit: hit,
          submitted: List<bool>.filled(n, false),
          scoreFor: scoreFor,
          joinedCount: joinedCount,
          myPending: null,
          iSubmitted: true,
          submittedAlive: 0,
          aliveCount: alive.where((a) => a).length,
          banner: out.status == GameStatus.won
              ? (out.winner == mySeat
                  ? '최후의 1인! 승리!'
                  : '${names[out.winner] ?? "카우보이"} 승리!')
              : '모두 쓰러졌다... 무승부!',
          status: out.status,
          winner: out.winner,
          rematchMap: rematchMap,
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
    required List<int> ammo,
    required List<bool> alive,
    required List<Move?> lastMoves,
    required List<bool> fired,
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
  }) {
    final seats = <SeatView>[
      for (var s = 0; s < seatCount; s++)
        SeatView(
          seat: s,
          joined: true,
          name: names[s] ?? '카우보이',
          ammo: ammo[s],
          alive: alive[s],
          isMe: s == mySeat,
          lastMove: lastMoves[s],
          fired: fired[s],
          firedTarget: firedTarget[s],
          hitThisTurn: hit[s],
          submittedThisTurn: submitted[s],
          score: scoreFor(s),
        ),
    ];
    var rematchCount = 0;
    var iRematch = false;
    for (var s = 0; s < seatCount; s++) {
      if (rematchMap[slotKey(s)] == true) {
        rematchCount++;
        if (s == mySeat) iRematch = true;
      }
    }
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
    );
  }

  static String _turnBanner(TurnOutcome out, Map<int, String> names) {
    final downed = <String>[
      for (var s = 0; s < out.hit.length; s++)
        if (out.hit[s]) names[s] ?? '카우보이'
    ];
    if (downed.isNotEmpty) return '${downed.join(", ")} 명중!';
    if (out.fired.any((x) => x)) return '모두 막거나 빗나갔다!';
    return '장전과 방어... 다음 턴!';
  }
}
