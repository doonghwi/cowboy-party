import 'package:cowboy_bot_runner/game/party_logic.dart';
import 'package:cowboy_bot_runner/game_replay.dart';
import 'package:test/test.dart';

void main() {
  final c = CharId.commoner.index;

  test('전원 제출된 게임을 끝까지 재현해 승자를 낸다', () {
    // t0: 둘 다 장전(0) → 탄약 1,1. t1: p0가 p1 저격(shoot(1)=3), p1 장전 → p1 사망, p0 승리.
    final data = {
      'game': 1,
      'seatCount': 2,
      'chars': {'p0': c, 'p1': c},
      'turns': {
        't0': {'p0': 0, 'p1': 0},
        't1': {'p0': Move.shoot(1).encode(), 'p1': 0},
      },
    };
    final r = replay(data, 'TEST');
    expect(r.over, isTrue);
    expect(r.status, GameStatus.won);
    expect(r.winner, 0);
  });

  test('프런티어(미완료) 턴과 내 차례를 정확히 짚는다', () {
    // t0 완료, t1은 p0만 제출 → 현재 턴 1, p1 차례.
    final data = {
      'game': 1,
      'seatCount': 2,
      'chars': {'p0': c, 'p1': c},
      'turns': {
        't0': {'p0': 0, 'p1': 0},
        't1': {'p0': Move.shoot(1).encode()},
      },
    };
    final r = replay(data, 'TEST');
    expect(r.over, isFalse);
    expect(r.currentTurn, 1);
    expect(r.awaits(1), isTrue); // p1 아직 제출 안 함
    expect(r.awaits(0), isFalse); // p0 제출함
    expect(r.ammo[0], 1); // t0 장전으로 1발
  });

  test('동시 사격 무승부 → 결투 대기(drawTurn·참가자) + 좌석범위 밖 awaits 안전', () {
    // t0: 둘 다 장전 → 1발씩. t1: 서로 쏨 → 동시 사망 = 무승부(반응속도 결투).
    final data = {
      'game': 1,
      'seatCount': 2,
      'chars': {'p0': c, 'p1': c},
      'turns': {
        't0': {'p0': 0, 'p1': 0},
        't1': {'p0': Move.shoot(1).encode(), 'p1': Move.shoot(0).encode()},
      },
    };
    final r = replay(data, 'TEST');
    expect(r.over, isTrue);
    expect(r.status, GameStatus.draw);
    expect(r.drawTurn, 1);
    expect(r.drawParticipants, [0, 1]);
    // 늦게 앉은 좌석(seatCount 밖)은 절대 내 차례가 아니다(RangeError 회귀 방지).
    expect(r.awaits(2), isFalse);
    expect(r.awaits(5), isFalse);
  });

  test('showdown.winner 가 확정되면 무승부가 승리로 바뀐다(앱 computeView 동일)', () {
    final data = {
      'game': 1,
      'seatCount': 2,
      'chars': {'p0': c, 'p1': c},
      'turns': {
        't0': {'p0': 0, 'p1': 0},
        't1': {'p0': Move.shoot(1).encode(), 'p1': Move.shoot(0).encode()},
      },
      'showdown': {'turn': 1, 'round': 0, 'winner': 1},
    };
    final r = replay(data, 'TEST');
    expect(r.status, GameStatus.won);
    expect(r.winner, 1);
    // 다른 턴의 낡은 showdown 은 무시.
    final stale = Map<String, Object?>.from(data)
      ..['showdown'] = {'turn': 0, 'winner': 0};
    final r2 = replay(stale, 'TEST');
    expect(r2.status, GameStatus.draw);
  });

  test('결투가가 참가자 중 1명이면 반응속도 없이 자동 승리', () {
    final d = CharId.duelist.index;
    final data = {
      'game': 1,
      'seatCount': 2,
      'chars': {'p0': c, 'p1': d},
      'turns': {
        't0': {'p0': 0, 'p1': 0},
        't1': {'p0': Move.shoot(1).encode(), 'p1': Move.shoot(0).encode()},
      },
    };
    final r = replay(data, 'TEST');
    expect(r.status, GameStatus.won);
    expect(r.winner, 1);
  });

  test('아무 턴도 없으면 첫 턴이 현재 턴, 전원 대기', () {
    final data = {
      'game': 3,
      'seatCount': 3,
      'chars': {'p0': c, 'p1': c, 'p2': c},
      'turns': null,
    };
    final r = replay(data, 'RM');
    expect(r.currentTurn, 0);
    expect(r.n, 3);
    expect(r.awaits(0), isTrue);
    expect(r.awaits(1), isTrue);
    expect(r.awaits(2), isTrue);
    expect(r.seed, 'RM#3');
  });
}
