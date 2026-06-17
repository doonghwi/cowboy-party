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

  group('??? 평화주의자·결투가는 능력 발동(승리) 시 공개 (제보 #1)', () {
    // mystery=13. effectiveChar는 seed로 결정적이므로, 좌석0이 원하는 직업으로
    // 변신하는 game 번호를 찾아 시드를 고정한다(seed = '$seedKey#$game').
    const key = 'RV';
    int gameFor(CharId target, {int seat = 0}) {
      for (var g = 0; g < 200000; g++) {
        if (effectiveChar(CharId.mystery, '$key#$g', seat) == target) return g;
      }
      throw StateError('$target 로 변신하는 시드를 못 찾음');
    }

    Map<String, Object?> room({
      required int game,
      required Map<String, Object?> turns,
      required int p1char,
      Map<String, Object?>? showdown,
    }) =>
        {
          'host': 'h',
          'capacity': 6,
          'started': true,
          'seatCount': 2,
          'game': game,
          'chars': {'p0': 13, 'p1': p1char}, // p0=??? p1=지정
          'players': {
            'p0': {'id': 'h', 'name': '미스터리', 'char': 13},
            'p1': {'id': 'g', 'name': '상대', 'char': p1char},
          },
          'turns': turns,
          'showdown': ?showdown,
        };

    test('평화주의자로 변신한 ???가 6장전 승리 순간 상대 시야에 공개된다', () {
      final game = gameFor(CharId.pacifist);
      // 승리 직전(5장전)엔 상대에게 아직 ???.
      final pre = <String, Object?>{
        for (var i = 0; i < kPacifistGoal - 1; i++)
          't$i': {'p0': reload(), 'p1': defend()},
      };
      final vPre = OnlineService.computeView(room(game: game, turns: pre, p1char: 0),
          'g',
          seedKey: key);
      expect(vPre.seats[0].char, CharId.mystery,
          reason: '승리 전엔 상대에게 정체 숨김');
      // 6장전 달성 턴에 평화 승리 → 공개.
      final win = <String, Object?>{
        for (var i = 0; i < kPacifistGoal; i++)
          't$i': {'p0': reload(), 'p1': defend()},
      };
      final vWin = OnlineService.computeView(room(game: game, turns: win, p1char: 0),
          'g',
          seedKey: key);
      expect(vWin.status, GameStatus.won);
      expect(vWin.seats[0].char, CharId.pacifist,
          reason: '6장전 승리 순간 정체 공개');
    });

    test('결투가로 변신한 ???가 결투 자동승 순간 상대 시야에 공개된다', () {
      final game = gameFor(CharId.duelist);
      // 둘 다 장전 후 상호 사살 → 전멸(draw) → 결투가 1명 자동승.
      final turns = <String, Object?>{
        't0': {'p0': reload(), 'p1': reload()},
        't1': {'p0': shoot(1), 'p1': shoot(0)},
      };
      final v = OnlineService.computeView(
          room(game: game, turns: turns, p1char: 0), 'g',
          seedKey: key);
      expect(v.status, GameStatus.won, reason: '결투가 자동승');
      expect(v.winnerSeat, 0);
      expect(v.seats[0].char, CharId.duelist,
          reason: '결투 자동승 순간 정체 공개');
    });

    test('6장전 도달 턴에 사살된 평화주의자 ???는 승리도 공개도 없다', () {
      // 능력(6장전 승리)이 실제로 발동하기 직전에 죽으면 reveal 트리거가 없어야 한다.
      final game = gameFor(CharId.pacifist);
      // p1(일반인=15)이 t0..t4 장전해 5발 모으고, t5에 평화주의자를 쏜다.
      // 평화주의자는 t0..t5 장전(6회 도달)하지만 그 턴에 죽어 승자가 못 된다.
      final turns = <String, Object?>{
        for (var i = 0; i < kPacifistGoal - 1; i++)
          't$i': {'p0': reload(), 'p1': reload()},
        't${kPacifistGoal - 1}': {'p0': reload(), 'p1': shoot(0)},
      };
      final v = OnlineService.computeView(
          room(game: game, turns: turns, p1char: 15), 'g',
          seedKey: key);
      expect(v.status, GameStatus.won);
      expect(v.winnerSeat, 1, reason: '쏜 일반인이 최후 생존');
      expect(v.seats[0].alive, isFalse, reason: '평화주의자는 죽음');
      expect(v.seats[0].char, CharId.mystery,
          reason: '능력 발동 전 사망 → 정체 미공개(거짓 reveal 금지)');
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

  group('파파라치 엿보기 사용량 (#11)', () {
    // paparazzi=12. peekUsed/{p0:true}면 사용량 라벨이 0이어야 한다.
    Map<String, Object?> papaRoom({required bool used}) => {
          'host': 'h',
          'capacity': 6,
          'started': true,
          'seatCount': 2,
          'game': 1,
          'chars': {'p0': 12, 'p1': 0},
          'players': {
            'p0': {'id': 'h', 'name': '파파', 'char': 12},
            'p1': {'id': 'g', 'name': 'B', 'char': 0},
          },
          'turns': const {},
          if (used) 'peekUsed': {'p0': true},
        };

    test('엿보기 전엔 1, 쓰면 0으로 줄어든다(모두에게)', () {
      final before = OnlineService.computeView(papaRoom(used: false), 'g');
      expect(before.seats[0].abilityUses, '1', reason: '아직 안 씀');
      final after = OnlineService.computeView(papaRoom(used: true), 'g');
      expect(after.seats[0].abilityUses, '0', reason: '엿보기 사용 후 0');
    });
  });

  group('??? → 준비자 즉시 공개', () {
    // mystery=13, prepper=4. seat0 ???가 준비자로 변신하는 game 번호를 찾는다.
    int prepperGame() {
      for (var g = 0; g < 500; g++) {
        if (resolveMystery('#$g', 0) == CharId.prepper) return g;
      }
      return -1;
    }

    test('준비자로 변신한 ???는 상대에게도 시작부터 준비자로 보인다', () {
      final g = prepperGame();
      expect(g, isNot(-1), reason: '준비자로 변신하는 game을 찾아야 함');
      final room = {
        'host': 'h',
        'capacity': 6,
        'started': true,
        'seatCount': 2,
        'game': g,
        'chars': {'p0': 13, 'p1': 0},
        'players': {
          'p0': {'id': 'h', 'name': 'A', 'char': 13},
          'p1': {'id': 'g', 'name': 'B', 'char': 0},
        },
        'turns': const {},
      };
      final theirs = OnlineService.computeView(room, 'g'); // 상대 시야
      expect(theirs.seats[0].char, CharId.prepper,
          reason: '준비자는 시작하자마자 정체 공개');
    });
  });

  group('방장 방 시스템 (F2)', () {
    Map<String, Object?> lobby({
      Map<String, Object?> blocked = const {},
      Map<String, Object?> kicked = const {},
    }) =>
        {
          'host': 'h',
          'capacity': 6,
          'started': false,
          'public': true,
          'players': {
            'p0': {'id': 'h', 'name': '방장'},
            'p1': {'id': 'g', 'name': 'B'},
          },
          'blocked': blocked,
          'kicked': kicked,
        };

    test('방장이 닫은 빈 자리는 blocked로 표시', () {
      final v = OnlineService.computeView(lobby(blocked: {'p3': true}), 'h');
      expect(v.seats[3].blocked, isTrue);
      expect(v.seats[2].blocked, isFalse);
    });

    test('사람이 있는 자리는 blocked로 안 뜬다', () {
      final v = OnlineService.computeView(lobby(blocked: {'p1': true}), 'h');
      expect(v.seats[1].blocked, isFalse, reason: '점유 중이면 닫힘 표시 안 함');
      expect(v.seats[1].joined, isTrue);
    });

    test('추방된 사람은 iWasKicked', () {
      final v = OnlineService.computeView(lobby(kicked: {'g': true}), 'g');
      expect(v.iWasKicked, isTrue);
      final host = OnlineService.computeView(lobby(kicked: {'g': true}), 'h');
      expect(host.iWasKicked, isFalse);
    });
  });

  group('방장 승계 (host migration)', () {
    // host='h'가 기록됨. players의 'id'로 좌석 점유를 표현.
    Map<String, Object?> lobby(Map<String, Object?> players,
            {String host = 'h'}) =>
        {
          'host': host,
          'capacity': 6,
          'started': false,
          'public': true,
          'players': players,
        };

    test('기록된 방장이 자리에 있으면 그대로 방장 — 승계 불필요', () {
      final data = lobby({
        'p0': {'id': 'h', 'name': '방장'},
        'p1': {'id': 'g', 'name': 'B'},
      });
      final host = OnlineService.computeView(data, 'h');
      expect(host.isHost, isTrue);
      expect(host.iShouldClaimHost, isFalse, reason: '이미 기록된 방장');
      final other = OnlineService.computeView(data, 'g');
      expect(other.isHost, isFalse);
    });

    test('방장이 나가면(노드 사라짐) 남은 최저 좌석이 새 방장이 된다', () {
      // p0(host 'h') 노드가 사라지고 p1('g')만 남음.
      final data = lobby({
        'p1': {'id': 'g', 'name': 'B'},
      });
      final v = OnlineService.computeView(data, 'g');
      expect(v.isHost, isTrue, reason: '남은 최저 좌석이 승계');
      expect(v.iShouldClaimHost, isTrue, reason: '새 방장은 RTDB에 확정해야');
    });

    test('기록된 방장이 더 높은 좌석에 있어도(낮은 좌석에 타인) 승계되지 않는다', () {
      // 낮은 좌석 p0=타인('g'), 높은 좌석 p1=기록 방장('h'). 방장 present → 유지.
      final data = lobby({
        'p0': {'id': 'g', 'name': 'B'},
        'p1': {'id': 'h', 'name': '방장'},
      });
      expect(OnlineService.computeView(data, 'h').isHost, isTrue);
      final g = OnlineService.computeView(data, 'g');
      expect(g.isHost, isFalse, reason: '기록 방장이 있으면 낮은 좌석이라도 안 뺏음');
      expect(g.iShouldClaimHost, isFalse);
    });

    test('방장 사라지고 여러 명 남으면 정확히 한 명(최저 좌석)만 방장', () {
      // host 'h' 사라짐. p1='g'(seat1), p2='k'(seat2) 남음.
      final data = lobby({
        'p1': {'id': 'g', 'name': 'B'},
        'p2': {'id': 'k', 'name': 'C'},
      });
      final g = OnlineService.computeView(data, 'g');
      final k = OnlineService.computeView(data, 'k');
      expect(g.isHost, isTrue);
      expect(k.isHost, isFalse, reason: '방장은 단 한 명(최저 좌석)');
      expect(g.iShouldClaimHost, isTrue);
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
