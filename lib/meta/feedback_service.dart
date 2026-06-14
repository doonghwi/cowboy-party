/// 관리자 연락(제보/문의) — ntfy 채널로 전송 (H2).
///
/// **개인정보를 보내지 않는다.** 익명 식별자(게스트/로그인 uid의 짧은 해시)만 붙여
/// 같은 사용자의 여러 제보를 구분할 수 있게 한다.
library;

import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// ntfy 채널명(루트 CLAUDE.md/WORK_v3 확정). 공개 토픽이라 식별자 외 개인정보 금지.
const String kFeedbackNtfyTopic = 'cowboy-feedback-doonghwi';

class FeedbackService {
  FeedbackService._();
  static final FeedbackService I = FeedbackService._();

  /// 익명 식별자 — uid 일부만(개인정보 아님).
  String get _anonId {
    final uid = AuthService.I.uid;
    if (uid.isEmpty) return 'anon';
    return uid.length <= 6 ? uid : uid.substring(0, 6);
  }

  /// 제보/문의 전송. 성공 여부 반환(네트워크 실패는 false).
  Future<bool> send(String message) async {
    final text = message.trim();
    if (text.isEmpty) return false;
    try {
      final res = await http
          .post(
            Uri.parse('https://ntfy.sh/$kFeedbackNtfyTopic'),
            headers: const {
              'Title': 'Cowboy 제보',
              'Tags': 'cowboy_hat_face',
            },
            body: '[#$_anonId] $text',
          )
          .timeout(const Duration(seconds: 10));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
