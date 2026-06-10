import 'package:cowboy_party/game/party_logic.dart';
import 'package:cowboy_party/online/online_service.dart';
import 'package:flutter_test/flutter_test.dart';

int reload() => const Move.reload().encode();
int shoot(int t) => Move.shoot(t).encode();

/// 재입장 즉시부활 버그 회귀 테스트.
/// 시나리오: 3인 게임 도중 p2가 떠났고, 새 클라이언트(me2)가 그 자리를
/// `late: true`로 차지했다. 게임은 아직 p0·p1이 진행 중.
Map<String, Object?> roomWithLateJoiner({required bool lateFlag}) => {
      'host': 'h',
      'capacity': 6,
      'started': true,
      'seatCount': 3,
      'game': 1,
      'chars': {'p0': 0, 'p1': 0, 'p2': 0},
      'players': {
        'p0': {'id': 'h', 'name': 'A', 'char': 0},
        'p1': {'id': 'g', 'name': 'B', 'char': 0},
        'p2': {
          'id': 'me2',
          'name': '난입자',
          'char': 0,
          if (lateFlag) 'late': true,
        },
      },
      'turns': {
        // t0: 전원(전임 p2 포함) 장전 — 전임자의 히스토리.
        't0': {'p0': reload(), 'p1': reload(), 'p2': reload()},
        // t1: p0·p1만 제출, p2(전임자)는 떠나서 미제출 — 라이브 프런티어.
        't1': {'p0': reload(), 'p1': reload()},
      },
    };

void main() {
  test('late 좌석은 라이브 프런티어에서 죽는다 — 난입자가 살아나지 않는다', () {
    final v = OnlineService.computeView(roomWithLateJoiner(lateFlag: true), 'me2');
    expect(v.status, GameStatus.ongoing, reason: 'p0·p1의 게임은 계속');
    expect(v.seats[2].alive, isFalse, reason: '난입자 좌석은 사망(빈자리와 동일)');
    expect(v.iAmLate, isTrue);
    expect(v.reapSeats, isNot(contains(2)),
        reason: '난입자를 강퇴(quit) 대상으로 잡으면 안 됨');
    // 전임자의 t0 장전은 히스토리에 남는다 (p0 탄약: t0+t1 = 2발).
    expect(v.seats[0].ammo, 2);
  });

  test('(대조군) late 플래그가 없으면 난입자가 부활했었다 — 버그 재현', () {
    final v =
        OnlineService.computeView(roomWithLateJoiner(lateFlag: false), 'me2');
    // 버그 동작: 좌석이 현재 presence로 살아있다고 계산돼 게임에 즉시 참여됨.
    expect(v.seats[2].alive, isTrue);
    expect(v.iAmLate, isFalse);
  });

  test('전임자가 쏴 죽인 히스토리는 late여도 그대로 유지된다', () {
    final data = {
      'host': 'h',
      'capacity': 6,
      'started': true,
      'seatCount': 3,
      'game': 1,
      'chars': {'p0': 0, 'p1': 0, 'p2': 0},
      'players': {
        'p0': {'id': 'h', 'name': 'A', 'char': 0},
        'p1': {'id': 'g', 'name': 'B', 'char': 0},
        'p2': {'id': 'me2', 'name': '난입자', 'char': 0, 'late': true},
      },
      'turns': {
        't0': {'p0': reload(), 'p1': reload(), 'p2': reload()},
        // 전임 p2가 t1에서 p1을 사살.
        't1': {'p0': reload(), 'p1': reload(), 'p2': shoot(1)},
        // t2 프런티어: p0만 제출.
        't2': {'p0': reload()},
      },
    };
    final v = OnlineService.computeView(data, 'h');
    expect(v.seats[1].alive, isFalse, reason: '전임자의 사살은 지워지지 않는다');
    // p1 사망 + p2(late) 프런티어 컬링 → p0만 생존 = 게임 종료.
    expect(v.status, GameStatus.won);
    expect(v.winnerSeat, 0);
  });
}
