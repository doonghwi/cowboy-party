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
}
