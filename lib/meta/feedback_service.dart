/// 관리자 연락(제보/문의) — ntfy 알림 + RTDB 저장 + 운영자 답변 수신.
///
/// **개인정보를 보내지 않는다.** ntfy(동휘 알림용)에는 익명 식별자(uid 앞 6자)만,
/// RTDB `feedback/{uid}/{id}`에는 본인만 읽을 수 있게 저장한다(규칙).
/// 운영자 답변(`reply`)은 관리자 도구(`tools/feedback_reply.py`)만 쓸 수 있고,
/// 앱은 답변이 달리면 설정에 빨간 점을 띄운다(2026-11-06 기획).
library;

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../online/online_service.dart';
import 'auth_service.dart';

/// ntfy 채널명(루트 CLAUDE.md/WORK_v3 확정). 공개 토픽이라 식별자 외 개인정보 금지.
const String kFeedbackNtfyTopic = 'cowboy-feedback-doonghwi';

class FeedbackItem {
  final String id;
  final String text; // 내 제보(운영자가 먼저 보낸 메시지면 빈 문자열)
  final int at;
  final String? reply;
  final int? repliedAt;
  final int? readAt;
  const FeedbackItem({
    required this.id,
    required this.text,
    required this.at,
    this.reply,
    this.repliedAt,
    this.readAt,
  });
  bool get hasUnreadReply => reply != null && reply!.isNotEmpty && readAt == null;
}

class FeedbackService {
  FeedbackService._();
  static final FeedbackService I = FeedbackService._();

  /// 설정 버튼 빨간 점용 — 읽지 않은 운영자 답변이 있는가.
  final ValueNotifier<bool> hasUnread = ValueNotifier<bool>(false);

  /// 내 제보 목록(최신순). 구독 전엔 빈 목록.
  final ValueNotifier<List<FeedbackItem>> mine =
      ValueNotifier<List<FeedbackItem>>(const []);

  StreamSubscription<DatabaseEvent>? _sub;
  String? _subUid;

  /// 익명 식별자 — uid 일부만(개인정보 아님).
  String get _anonId {
    final uid = AuthService.I.uid;
    if (uid.isEmpty) return 'anon';
    return uid.length <= 6 ? uid : uid.substring(0, 6);
  }

  DatabaseReference? _myRef() {
    final uid = AuthService.I.cloudUid;
    if (uid == null || uid.isEmpty) return null;
    try {
      return FirebaseDatabase.instanceFor(
              app: Firebase.app(), databaseURL: OnlineService.databaseUrl)
          .ref('feedback/$uid');
    } catch (_) {
      return null;
    }
  }

  /// 로그인 상태가 바뀔 때마다 호출(앱 시작·로그인 후). 서버 계정 없으면 해제.
  void watch() {
    final uid = AuthService.I.cloudUid;
    if (uid == _subUid) return;
    _sub?.cancel();
    _sub = null;
    _subUid = uid;
    mine.value = const [];
    hasUnread.value = false;
    final ref = _myRef();
    if (ref == null) return;
    try {
      _sub = ref.limitToLast(20).onValue.listen((e) {
        final raw = e.snapshot.value;
        final items = <FeedbackItem>[];
        if (raw is Map) {
          raw.forEach((k, v) {
            if (v is! Map) return;
            items.add(FeedbackItem(
              id: k.toString(),
              text: (v['text'] ?? '').toString(),
              at: (v['at'] is num) ? (v['at'] as num).toInt() : 0,
              reply: v['reply']?.toString(),
              repliedAt:
                  (v['repliedAt'] is num) ? (v['repliedAt'] as num).toInt() : null,
              readAt: (v['readAt'] is num) ? (v['readAt'] as num).toInt() : null,
            ));
          });
        }
        items.sort((a, b) => b.at.compareTo(a.at));
        mine.value = items;
        hasUnread.value = items.any((i) => i.hasUnreadReply);
      }, onError: (_) {});
    } catch (_) {}
  }

  /// 제보·문의 창을 열었을 때: 안 읽은 답변을 읽음 처리.
  Future<void> markAllRead() async {
    final ref = _myRef();
    if (ref == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final i in mine.value.where((i) => i.hasUnreadReply)) {
      try {
        await ref.child('${i.id}/readAt').set(now);
      } catch (_) {}
    }
  }

  /// 제보/문의 전송. ntfy(동휘 알림) + RTDB 저장(답변 수신용). ntfy 성공이면 true.
  Future<bool> send(String message, {int build = 0}) async {
    final text = message.trim();
    if (text.isEmpty) return false;
    // 1) RTDB 저장 — 베스트에포트(게스트 미로그인 등이면 건너뜀).
    final ref = _myRef();
    if (ref != null) {
      try {
        await ref.push().set({
          'text': text,
          'at': ServerValue.timestamp,
          'build': build,
        }).timeout(const Duration(seconds: 6));
      } catch (_) {}
    }
    // 2) ntfy 알림.
    try {
      // ntfy 제목/태그 헤더는 ASCII만 가능 → 한글은 본문에만 둔다(헤더 한글이
      // 전송 실패의 원인이었음). 본문은 UTF-8로 안전하게 전송된다.
      // 웹 CORS 프리플라이트를 피하려고 커스텀 헤더는 쓰지 않는다.
      final res = await http
          .post(
            Uri.parse('https://ntfy.sh/$kFeedbackNtfyTopic'),
            body: 'Cowboy 제보 [#$_anonId]\n$text',
          )
          .timeout(const Duration(seconds: 10));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
