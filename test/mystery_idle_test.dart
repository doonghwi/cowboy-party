// ??? 변신 분포 + idle 멘트 결정성/도달성.
//
// 온라인은 모든 클라이언트가 같은 (시드, 좌석)에서 동일 결과를 봐야 하므로
// resolveMystery·idleFlavor의 결정성이 중요하다. 또 ???가 특정 직업으로 영영
// 변신 못 하면(분포 버그) 그 직업은 ???로 못 만난다 — 도달성도 검사한다.
import 'package:cowboy_party/game/party_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('idleFlavor: 결정적이고 항상 유효한 멘트만 돌려준다', () {
    for (final seed in const ['A', 'GAME#1', 'xyz', '한글시드']) {
      for (var t = 0; t < 25; t++) {
        for (var s = 0; s < 6; s++) {
          final f = idleFlavor(seed, t, s);
          expect(idleFlavor(seed, t, s), f, reason: '같은 입력 → 같은 멘트(결정적)');
          expect(kIdleFlavors.contains(f), isTrue, reason: '풀 밖 멘트 $f');
        }
      }
    }
  });

  test('resolveMystery: 결정적이고 모든 변신 직업이 도달 가능하다', () {
    final pool = kMysteryPool.toSet();
    expect(pool.contains(CharId.mystery), isFalse, reason: '??? 자신은 풀 제외');
    expect(pool.contains(CharId.none), isFalse, reason: '무직(none)은 풀 제외');

    final seen = <CharId>{};
    for (var i = 0; i < 6000; i++) {
      final c = resolveMystery('SEED$i', i % 6);
      expect(pool.contains(c), isTrue, reason: '$c 가 풀 밖');
      seen.add(c);
    }
    expect(seen, containsAll(pool),
        reason: '도달 못 하는 변신 직업이 있으면 분포 버그(영영 그 ???를 못 만남)');

    // 결정성: 같은 (시드, 좌석)은 항상 같은 직업.
    expect(resolveMystery('FIX', 2), resolveMystery('FIX', 2));
    expect(resolveMystery('GAME#3', 5), resolveMystery('GAME#3', 5));
  });

  test('effectiveChar: 비-??? 직업은 그대로, ???만 실제 직업으로 변환', () {
    for (final c in kMysteryPool) {
      expect(effectiveChar(c, 'X', 0), c, reason: '$c 는 변환 없이 그대로');
    }
    final e = effectiveChar(CharId.mystery, 'X', 0);
    expect(e, isNot(CharId.mystery));
    expect(kMysteryPool.contains(e), isTrue);
    // resolveMystery와 동일한 변환이어야 한다.
    expect(effectiveChar(CharId.mystery, 'X', 0), resolveMystery('X', 0));
  });
}
