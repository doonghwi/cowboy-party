// 초대/딥링크·방 코드·좌석 키·시즌 포인트 등 온라인 보조 로직 커버리지.
// (이 헬퍼들은 기존 0 커버리지였음 — 회귀 가드로 못박는다.)
import 'package:cowboy_party/meta/season_service.dart';
import 'package:cowboy_party/online/online_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseRoomCode (딥링크 방 코드 정규화)', () {
    test('소문자·공백은 정규화돼 대문자 4자로', () {
      expect(OnlineService.parseRoomCode('abcd'), 'ABCD');
      expect(OnlineService.parseRoomCode('  ab12 '), 'AB12');
    });
    test('길이가 4가 아니면 null', () {
      expect(OnlineService.parseRoomCode('abc'), isNull);
      expect(OnlineService.parseRoomCode('abcde'), isNull);
      expect(OnlineService.parseRoomCode(''), isNull);
    });
    test('null은 null', () {
      expect(OnlineService.parseRoomCode(null), isNull);
    });
  });

  group('inviteLink ↔ parseRoomCode 라운드트립', () {
    test('초대 링크에 박힌 코드를 같은 규칙으로 되뽑는다', () {
      const code = 'WXYZ';
      final link = OnlineService.inviteLink(code);
      expect(link, contains('?room=$code'));
      final raw = Uri.parse(link).queryParameters['room'];
      expect(OnlineService.parseRoomCode(raw), code);
    });
    test('생성된 코드 다수가 링크 라운드트립을 통과한다', () {
      for (var i = 0; i < 200; i++) {
        final code = OnlineService.generateRoomCode();
        final link = OnlineService.inviteLink(code);
        final raw = Uri.parse(link).queryParameters['room'];
        expect(OnlineService.parseRoomCode(raw), code,
            reason: '코드 $code 라운드트립 실패');
      }
    });
  });

  group('generateRoomCode', () {
    test('항상 길이 4, 헷갈리는 문자(I·O·0·1) 없음', () {
      const ambiguous = {'I', 'O', '0', '1'};
      for (var i = 0; i < 500; i++) {
        final code = OnlineService.generateRoomCode();
        expect(code.length, 4);
        for (final ch in code.split('')) {
          expect(ambiguous.contains(ch), isFalse,
              reason: '$code 에 혼동 문자 $ch');
          expect(RegExp(r'^[A-Z2-9]$').hasMatch(ch), isTrue,
              reason: '$code 의 $ch 가 허용 문자셋 밖');
        }
      }
    });
  });

  group('slotKey ↔ seatOf 라운드트립', () {
    test('좌석 인덱스가 키를 거쳐 그대로 복원된다', () {
      for (var s = 0; s < 6; s++) {
        expect(OnlineService.slotKey(s), 'p$s');
        expect(OnlineService.seatOf(OnlineService.slotKey(s)), s);
      }
    });
  });

  group('SeasonService.winPts (시즌 승점 곡선)', () {
    test('2인 10, 6인 50, 범위 밖 클램프', () {
      expect(SeasonService.winPts(2), 10);
      expect(SeasonService.winPts(3), 20);
      expect(SeasonService.winPts(6), 50);
      expect(SeasonService.winPts(1), 10, reason: '2로 클램프');
      expect(SeasonService.winPts(99), 50, reason: '6으로 클램프');
    });
    test('인원이 늘수록 단조 증가', () {
      for (var p = 2; p < 6; p++) {
        expect(SeasonService.winPts(p + 1), greaterThan(SeasonService.winPts(p)));
      }
    });
  });
}
