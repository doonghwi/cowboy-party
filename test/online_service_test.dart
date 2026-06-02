import 'package:cowboy_party/game/party_logic.dart';
import 'package:cowboy_party/online/online_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Move encodings: reload=0, defend=1, shoot at seat t = 2 + t.
int reload() => const Move.reload().encode();
int shoot(int t) => Move.shoot(t).encode();

Map<String, Object?> startedRoom({
  required Map<String, Object?> players,
  required int seatCount,
  Map<String, Object?>? turns,
  Map<String, Object?>? showdown,
  String host = 'h',
}) =>
    {
      'host': host,
      'capacity': 6,
      'started': true,
      'seatCount': seatCount,
      'players': players,
      if (turns != null) 'turns': turns,
      if (showdown != null) 'showdown': showdown,
    };

void main() {
  group('computeView — a departing player never freezes the game', () {
    test('last player standing wins when everyone else has left', () {
      final data = startedRoom(
        players: {
          'p0': {'id': 'h', 'name': 'A'},
          // p1 left the room (node removed) while still "alive" in replay.
        },
        seatCount: 2,
        turns: const {}, // nobody submitted the live turn
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
          // p2 left.
        },
        seatCount: 3,
        turns: {
          't0': {'p0': reload(), 'p1': reload()}, // p2 never submits
        },
      );
      final v = OnlineService.computeView(data, 'h');
      // Game keeps going (didn't freeze on the absent p2), p2 folded out.
      expect(v.status, GameStatus.ongoing);
      expect(v.seats[2].alive, isFalse);
      expect(v.seats[0].alive, isTrue);
      expect(v.seats[1].alive, isTrue);
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
            't0': {'p0': reload(), 'p1': reload()}, // arm up
            't1': {'p0': shoot(1), 'p1': shoot(0)}, // shoot each other
          },
          showdown: showdown,
        );

    test('pending showdown: draw exposed with participants', () {
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

  group('computeView — presence & rematch counts', () {
    test('present count reflects who is still in the room', () {
      final data = startedRoom(
        players: {
          'p0': {'id': 'h', 'name': 'A'},
          'p1': {'id': 'g', 'name': 'B'},
          'p2': {'id': 'k', 'name': 'C'},
        },
        seatCount: 3,
        turns: {
          't0': {'p0': reload(), 'p1': reload(), 'p2': reload()},
        },
      );
      final v = OnlineService.computeView(data, 'h');
      expect(v.presentCount, 3);
      expect(v.seats.where((s) => s.joined).length, 3);
    });
  });
}
