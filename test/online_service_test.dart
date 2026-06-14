import 'package:cowboy_party/game/party_logic.dart';
import 'package:cowboy_party/online/online_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Move encodings: reload=0, defend=1, shoot at seat t = 2 + t.
int reload() => const Move.reload().encode();
int defend() => const Move.defend().encode();
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

    test('resolved showdown winner overrides the draw and stands alive', () {
      final v = OnlineService.computeView(
        mutualKillRoom(showdown: {'turn': 1, 'winner': 1}),
        'h',
      );
      expect(v.status, GameStatus.won);
      expect(v.winnerSeat, 1);
      // The duel victor must be shown standing, not as a skull next to "승리!".
      expect(v.seats[1].alive, isTrue);
      expect(v.seats[1].hitThisTurn, isFalse);
      expect(v.seats[0].alive, isFalse);
    });
  });

  group('computeView — a quiet turn names what everyone did', () {
    RoomView quiet(int a, int b) => OnlineService.computeView(
          startedRoom(
            players: {
              'p0': {'id': 'h', 'name': 'A'},
              'p1': {'id': 'g', 'name': 'B'},
            },
            seatCount: 2,
            turns: {
              't0': {'p0': a, 'p1': b},
            },
          ),
          'h',
        );

    test('both defending reads "둘 다 방어", not "장전과 방어"', () {
      final v = quiet(defend(), defend());
      expect(v.banner, contains('둘 다'));
      expect(v.banner, contains('방어'));
      expect(v.banner, isNot(contains('장전과')));
    });

    test('both reloading reads "둘 다 장전"', () {
      final v = quiet(reload(), reload());
      expect(v.banner, contains('둘 다'));
      expect(v.banner, contains('장전'));
      expect(v.banner, isNot(contains('방어')));
    });

    test('a real mix still reads "장전과 방어"', () {
      final v = quiet(reload(), defend());
      expect(v.banner, contains('장전과 방어'));
    });
  });

  group('??? 정체 숨김 (B8) & 그림자 은폐 (B9)', () {
    // CharId index: mystery=13, shadow=10.
    Map<String, Object?> room({required int p0char}) => {
          'host': 'h',
          'capacity': 6,
          'started': true,
          'seatCount': 2,
          'game': 1,
          'chars': {'p0': p0char, 'p1': 0},
          'players': {
            'p0': {'id': 'h', 'name': 'A', 'char': p0char},
            'p1': {'id': 'g', 'name': 'B', 'char': 0},
          },
          'turns': const {},
        };

    test('B8: ???는 상대에게 정체를 숨긴다(상대 시야엔 mystery)', () {
      final v = OnlineService.computeView(room(p0char: 13), 'g'); // p1 시야
      expect(v.seats[0].char, CharId.mystery, reason: '상대에겐 ??? 그대로');
    });

    test('B8: ??? 본인은 자기 실제 직업을 본다', () {
      final v = OnlineService.computeView(room(p0char: 13), 'h'); // p0 본인
      expect(v.seats[0].char, isNot(CharId.mystery),
          reason: '본인은 변환된 실제 직업을 봄');
    });

    test('B9: 그림자는 상대 시야에서 탄약이 가려진다', () {
      final v = OnlineService.computeView(room(p0char: 10), 'g'); // p1 시야
      expect(v.seats[0].hideAmmo, isTrue, reason: '상대에겐 그림자 탄약 숨김');
      final mine = OnlineService.computeView(room(p0char: 10), 'h');
      expect(mine.seats[0].hideAmmo, isFalse, reason: '본인 탄약은 보임');
    });
  });

  group('저주 표시 (C2)', () {
    // voodoo=14. p0가 t0에 p1에게 저주 → t1 프론티어에서 남은 턴 표시.
    Map<String, Object?> cursedRoom() => {
          'host': 'h',
          'capacity': 6,
          'started': true,
          'seatCount': 2,
          'game': 1,
          'chars': {'p0': 14, 'p1': 0},
          'players': {
            'p0': {'id': 'h', 'name': '부두', 'char': 14},
            'p1': {'id': 'g', 'name': 'B', 'char': 0},
          },
          'turns': {
            't0': {'p0': Move.voodoo(1).encode(), 'p1': reload()},
          },
        };

    test('저주 대상 좌석에 남은 턴이 모두에게 보인다', () {
      final mine = OnlineService.computeView(cursedRoom(), 'h');
      expect(mine.seats[1].curseTurnsLeft, kCurseFuse);
      final theirs = OnlineService.computeView(cursedRoom(), 'g');
      expect(theirs.seats[1].curseTurnsLeft, kCurseFuse,
          reason: '저주는 모두에게 표시');
      expect(mine.seats[0].curseTurnsLeft, 0, reason: '시전자는 저주 아님');
    });
  });

  group('파파라치 온라인 엿보기 (computeView)', () {
    // p0=파파라치(12), p1·p2=일반. p0가 p1을 엿보기. p1·p2만 제출.
    Map<String, Object?> peekRoom() => {
          'host': 'h',
          'capacity': 6,
          'started': true,
          'seatCount': 3,
          'game': 1,
          'chars': {'p0': 12, 'p1': 0, 'p2': 0}, // 12 = paparazzi
          'players': {
            'p0': {'id': 'h', 'name': '파파', 'char': 12},
            'p1': {'id': 'g1', 'name': 'B', 'char': 0},
            'p2': {'id': 'g2', 'name': 'C', 'char': 0},
          },
          'turns': {
            't0': {'p1': defend(), 'p2': reload()}, // p0 미제출
          },
          'peek': {
            't0': {'by': 0, 'target': 1},
          },
          'peekUsed': {'p0': true},
        };

    test('엿보는 사람: peekActive·iAmPeeker·엿본 행동 노출', () {
      final v = OnlineService.computeView(peekRoom(), 'h');
      expect(v.peekActive, isTrue, reason: '다른 사람 전원 제출 → 엿보기 활성');
      expect(v.iAmPeeker, isTrue);
      expect(v.peekTargetSeat, 1);
      expect(v.peekedMove, const Move.defend(), reason: 'p1의 방어가 보여야');
      expect(v.myPaparazziUsed, isTrue);
    });

    test('다른 사람: 엿보기 활성이지만 본인은 엿보는 사람 아님', () {
      final v = OnlineService.computeView(peekRoom(), 'g1');
      expect(v.peekActive, isTrue);
      expect(v.iAmPeeker, isFalse);
      expect(v.peekerSeat, 0);
    });

    test('아직 다른 사람이 안 냈으면 엿보기 비활성(대기)', () {
      final data = peekRoom();
      (data['turns'] as Map)['t0'] = {'p1': defend()}; // p2 미제출
      final v = OnlineService.computeView(data, 'h');
      expect(v.peekActive, isFalse, reason: '전원 제출 전');
      expect(v.iAmPeeker, isTrue, reason: '엿보기 지목은 유지');
    });
  });
}
