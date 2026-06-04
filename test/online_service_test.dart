import 'package:cowboy_party/game/party_logic.dart';
import 'package:cowboy_party/online/online_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Move encodings: reload=0, defend=1, shoot at seat t = 2 + t.
int reload() => const Move.reload().encode();
int shoot(int t) => Move.shoot(t).encode();

Map<String, Object?> startedRoom({
  required Map<String, Object?> players,
  required int seatCount,
  Map<String, Object?> turns = const {},
  Map<String, Object?>? showdown,
  Map<String, Object?>? quit,
  String host = 'h',
}) {
  final m = <String, Object?>{
    'host': host,
    'capacity': 6,
    'started': true,
    'seatCount': seatCount,
    'players': players,
    'turns': turns,
  };
  if (showdown != null) m['showdown'] = showdown;
  if (quit != null) m['quit'] = quit;
  return m;
}

void main() {
  group('computeView — a departing player never freezes the game', () {
    test('last player standing wins when everyone else has left (node gone)',
        () {
      final data = startedRoom(
        players: {
          'p0': {'id': 'h', 'name': 'A'},
        },
        seatCount: 2,
      );
      final v = OnlineService.computeView(data, 'h');
      expect(v.status, GameStatus.won);
      expect(v.winnerSeat, 0);
    });

    test('a left player is dropped so the turn resolves and play continues', () {
      final data = startedRoom(
        players: {
          'p0': {'id': 'h', 'name': 'A'},
          'p1': {'id': 'g', 'name': 'B'},
        },
        seatCount: 3,
        turns: {
          't0': {'p0': reload(), 'p1': reload()},
        },
      );
      final v = OnlineService.computeView(data, 'h');
      expect(v.status, GameStatus.ongoing);
      expect(v.seats[2].alive, isFalse);
      expect(v.seats[0].alive, isTrue);
    });
  });

  group('computeView — heartbeat staleness (the false-kick fix)', () {
    test('a fresh (heartbeating) player is NOT dropped, game waits for them',
        () {
      const now = 5000000;
      final data = startedRoom(
        players: {
          'p0': {'id': 'h', 'name': 'A', 'seen': now},
          'p1': {'id': 'g', 'name': 'B', 'seen': now - 2000}, // 2s ago: fresh
        },
        seatCount: 2,
        turns: {
          't0': {'p0': reload()}, // p1 hasn't submitted yet
        },
      );
      final v = OnlineService.computeView(data, 'h', nowServerMs: now);
      expect(v.status, GameStatus.ongoing); // not frozen, not won — just waiting
      expect(v.presentCount, 2);
      expect(v.reapSeats, isEmpty);
    });

    test('a long-silent player is reaped and the table unblocks', () {
      const now = 5000000;
      final data = startedRoom(
        players: {
          'p0': {'id': 'h', 'name': 'A', 'seen': now},
          'p1': {'id': 'g', 'name': 'B', 'seen': now - 30000}, // 30s ago: stale
        },
        seatCount: 2,
        turns: {
          't0': {'p0': reload()},
        },
      );
      final v = OnlineService.computeView(data, 'h', nowServerMs: now);
      expect(v.status, GameStatus.won);
      expect(v.winnerSeat, 0);
      expect(v.reapSeats, contains(1)); // host should write a sticky quit
    });

    test('a quit marker is sticky even if the node looks fresh', () {
      const now = 5000000;
      final data = startedRoom(
        players: {
          'p0': {'id': 'h', 'name': 'A', 'seen': now},
          'p1': {'id': 'g', 'name': 'B', 'seen': now}, // looks present...
        },
        seatCount: 2,
        turns: {
          't0': {'p0': reload()},
        },
        quit: {'p1': true}, // ...but marked quit
      );
      final v = OnlineService.computeView(data, 'h', nowServerMs: now);
      expect(v.status, GameStatus.won);
      expect(v.winnerSeat, 0);
    });
  });

  group('computeView — a departing player is named, not crowned over', () {
    test('winner who then left shows "<name> 나갔어요", not "카우보이 승리!"', () {
      // p1 legitimately won (shot p0 on t1) and then left: their node is gone
      // but the quit marker keeps their name so we don't fall back to 카우보이.
      final data = startedRoom(
        players: {
          'p0': {'id': 'h', 'name': '나'},
        },
        seatCount: 2,
        turns: {
          't0': {'p0': reload(), 'p1': reload()},
          't1': {'p0': reload(), 'p1': shoot(0)},
        },
        quit: {'p1': '무법자42'},
      );
      final v = OnlineService.computeView(data, 'h');
      expect(v.status, GameStatus.won);
      expect(v.winnerSeat, 1);
      expect(v.banner, contains('무법자42'));
      expect(v.banner, contains('나갔어요'));
      expect(v.banner, isNot(contains('승리')));
    });

    test('opponent leaving mid-game ends with their name, not a fake win', () {
      // I'm waiting on p1's move; p1 has left (sticky quit holds the name).
      final data = startedRoom(
        players: {
          'p0': {'id': 'h', 'name': '나'},
        },
        seatCount: 2,
        turns: {
          't0': {'p0': reload()}, // p1 never submitted — they're gone
        },
        quit: {'p1': '보안관7'},
      );
      final v = OnlineService.computeView(data, 'h');
      expect(v.status, GameStatus.won);
      expect(v.winnerSeat, 0);
      expect(v.banner, contains('보안관7'));
      expect(v.banner, contains('나갔어요'));
    });
  });

  group('computeView — final wipe becomes a reaction showdown, not a draw', () {
    Map<String, Object?> mutualKillRoom({Map<String, Object?>? showdown}) =>
        startedRoom(
          players: {
            'p0': {'id': 'h', 'name': 'A'},
            'p1': {'id': 'g', 'name': 'B'},
          },
          seatCount: 2,
          turns: {
            't0': {'p0': reload(), 'p1': reload()},
            't1': {'p0': shoot(1), 'p1': shoot(0)},
          },
          showdown: showdown,
        );

    test('pending showdown: draw exposed with both participants', () {
      final v = OnlineService.computeView(mutualKillRoom(), 'h');
      expect(v.status, GameStatus.draw);
      expect(v.drawTurn, 1);
      expect(v.drawParticipants, [0, 1]);
    });

    test('resolved showdown winner overrides the draw', () {
      final v = OnlineService.computeView(
        mutualKillRoom(showdown: {'turn': 1, 'winner': 1}),
        'h',
      );
      expect(v.status, GameStatus.won);
      expect(v.winnerSeat, 1);
    });
  });
}
