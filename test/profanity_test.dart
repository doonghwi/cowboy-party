import 'package:cowboy_party/meta/profanity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 자산(badwords_ko.json)을 로드해야 하므로 바인딩 초기화.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Profanity.I.init();
  });

  test('한글 비속어가 차단된다 (예전엔 \\W가 한글을 지워 통과되던 버그)', () {
    expect(Profanity.I.isProfane('씨발'), isTrue);
  });

  test('공백·기호로 우회해도 차단된다', () {
    expect(Profanity.I.isProfane('씨 발'), isTrue);
    expect(Profanity.I.isProfane('씨-발'), isTrue);
  });

  test('평범한 닉네임은 통과한다', () {
    expect(Profanity.I.isProfane('총잡이'), isFalse);
    expect(Profanity.I.isProfane('방랑객42'), isFalse);
  });

  test('비속어가 긴 닉네임 속에 박혀 있어도 부분일치로 차단된다', () {
    expect(Profanity.I.isProfane('멋진씨발총잡이'), isTrue);
    expect(Profanity.I.isProfane('xx씨발'), isTrue);
  });

  test('별표·구두점을 끼워 우회해도 차단된다(정규화로 제거)', () {
    expect(Profanity.I.isProfane('씨★발'), isTrue);
    expect(Profanity.I.isProfane('씨...발'), isTrue);
    expect(Profanity.I.isProfane(r'씨@#$발'), isTrue);
  });

  test('빈 문자열·공백·기호만이면 비속어가 아니다(정규화 후 빈 문자열)', () {
    expect(Profanity.I.isProfane(''), isFalse);
    expect(Profanity.I.isProfane('   '), isFalse);
    expect(Profanity.I.isProfane('!@#%^&*()'), isFalse);
  });

  test('같은 입력은 항상 같은 판정(멱등)', () {
    for (final s in const ['씨발', '총잡이', '씨 발', '멋진닉네임']) {
      expect(Profanity.I.isProfane(s), Profanity.I.isProfane(s), reason: '$s 멱등');
    }
  });
}
