// 순수 표시 헬퍼 커버리지 — 좌석 배지 '남은 N' 라벨 + Move 타겟 분류.
//
// 둘 다 UI(좌석 배지·행동 선택)를 직접 좌우하는데 직접 테스트가 없었다.
// abilityUsesLabel이 틀리면 모두에게 능력 잔여횟수가 잘못 보이고, needsTarget/
// needsTwoTargets가 틀리면 조준 UI가 깨진다.
import 'package:cowboy_party/game/party_logic.dart';
import 'package:flutter_test/flutter_test.dart';

/// 모든 1회성/유한 자원을 소진한 상태(라벨 '0' 검증용).
PartyState _used(List<CharId> chars) {
  final n = chars.length;
  return PartyState(
    doctorUsed: List.filled(n, true),
    trapUsed: List.filled(n, true),
    smokeLeft: List.filled(n, 0),
    reloads: List.filled(n, 0),
    paparazziUsed: List.filled(n, true),
    resetterUsed: List.filled(n, true),
    curseFuse: List.filled(n, 0),
    curseCaster: List.filled(n, -1),
  );
}

void main() {
  group('abilityUsesLabel (좌석 배지 남은 횟수)', () {
    test('초기 상태: 유한 능력은 시작 잔여, 무능력 직업은 null', () {
      final chars = [
        CharId.smoker,
        CharId.hunter,
        CharId.resetter,
        CharId.doctor,
        CharId.paparazzi,
        CharId.commoner,
      ];
      final st = PartyState.initial(chars);
      expect(abilityUsesLabel(CharId.smoker, st, 0), '2'); // 연막 2회
      expect(abilityUsesLabel(CharId.hunter, st, 1), '1'); // 덫 1회
      expect(abilityUsesLabel(CharId.resetter, st, 2), '1'); // 무효 1회
      expect(abilityUsesLabel(CharId.doctor, st, 3), '1'); // 자힐 1회
      expect(abilityUsesLabel(CharId.paparazzi, st, 4), '1'); // 엿보기 1회
      expect(abilityUsesLabel(CharId.commoner, st, 5), isNull, reason: '무능력');
    });

    test('소진 상태: 전부 0', () {
      final chars = [
        CharId.smoker,
        CharId.hunter,
        CharId.resetter,
        CharId.doctor,
        CharId.paparazzi,
      ];
      final st = _used(chars);
      expect(abilityUsesLabel(CharId.smoker, st, 0), '0');
      expect(abilityUsesLabel(CharId.hunter, st, 1), '0');
      expect(abilityUsesLabel(CharId.resetter, st, 2), '0');
      expect(abilityUsesLabel(CharId.doctor, st, 3), '0');
      expect(abilityUsesLabel(CharId.paparazzi, st, 4), '0');
    });

    test('연막은 1 남은 중간 상태도 정확히 보여준다', () {
      final st = PartyState(
        doctorUsed: const [false],
        trapUsed: const [false],
        smokeLeft: const [1], // 한 번 써서 1 남음
        reloads: const [0],
        paparazziUsed: const [false],
        resetterUsed: const [false],
        curseFuse: const [0],
        curseCaster: const [-1],
      );
      expect(abilityUsesLabel(CharId.smoker, st, 0), '1');
    });

    test('횟수 제한 없는 직업/무직은 null', () {
      final st = PartyState.initial([CharId.sniper, CharId.none]);
      expect(abilityUsesLabel(CharId.sniper, st, 0), isNull);
      expect(abilityUsesLabel(CharId.none, st, 1), isNull);
    });

    test('좌석 범위 밖이면 null(크래시 없이 방어)', () {
      final st = PartyState.initial([CharId.hunter]);
      expect(abilityUsesLabel(CharId.hunter, st, -1), isNull);
      expect(abilityUsesLabel(CharId.hunter, st, 5), isNull);
    });
  });

  group('Move 타겟 분류(조준 UI 구동)', () {
    test('needsTarget: 단일 조준 행동만 true', () {
      expect(const Move.shoot(1).needsTarget, isTrue);
      expect(const Move.superShoot(1).needsTarget, isTrue);
      expect(const Move.roulette(1).needsTarget, isTrue);
      expect(const Move.voodoo(1).needsTarget, isTrue);
      for (final m in [
        const Move.reload(),
        const Move.defend(),
        const Move.trap(),
        const Move.idle(),
        const Move.reset(),
        const Move.dualShoot(1, 2), // 둘은 needsTwoTargets로 따로
      ]) {
        expect(m.needsTarget, isFalse, reason: '$m 는 단일 조준 아님');
      }
    });

    test('needsTwoTargets: 더블 빵야만 true', () {
      expect(const Move.dualShoot(1, 2).needsTwoTargets, isTrue);
      expect(const Move.shoot(1).needsTwoTargets, isFalse);
      expect(const Move.reload().needsTwoTargets, isFalse);
    });

    test('isShoot: 일반/슈퍼 빵야만 true', () {
      expect(const Move.shoot(1).isShoot, isTrue);
      expect(const Move.superShoot(1).isShoot, isTrue);
      expect(const Move.roulette(1).isShoot, isFalse);
      expect(const Move.dualShoot(1, 2).isShoot, isFalse);
      expect(const Move.reload().isShoot, isFalse);
    });
  });
}
