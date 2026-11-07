/// 원격 공지 — RTDB `notices/` (2026-11-06, 제보 답변 채널 기획).
///
/// 앱 업데이트 없이 공지를 띄우기 위해 서버에서 읽어 내장 공지([kAnnouncements])
/// 앞에 합친다. 읽기 실패(오프라인 등)면 내장 공지만 — 화면이 비지 않는다.
/// 쓰기는 관리자 도구(`tools/notice.py`)만 — 규칙상 클라이언트 쓰기 불가.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../online/online_service.dart';
import 'announcements.dart';

class RemoteNotices {
  RemoteNotices._();
  static final RemoteNotices I = RemoteNotices._();

  /// 내장 + 원격 합본(날짜 내림차순). 원격 로드 전엔 내장만.
  final ValueNotifier<List<Announcement>> all =
      ValueNotifier<List<Announcement>>(kAnnouncements);

  bool _loaded = false;

  /// 앱 시작 시 한 번(실패해도 조용히). 중복 호출 무시.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final ref = FirebaseDatabase.instanceFor(
              app: Firebase.app(), databaseURL: OnlineService.databaseUrl)
          .ref('notices');
      final snap = await ref.get().timeout(const Duration(seconds: 6));
      final raw = snap.value;
      if (raw is! Map) return;
      final now = DateTime.now();
      final remote = <Announcement>[];
      for (final v in raw.values) {
        if (v is! Map) continue;
        final until = v['until'];
        if (until is String && until.isNotEmpty) {
          final u = DateTime.tryParse(until);
          if (u != null && now.isAfter(u)) continue; // 기한 지난 공지
        }
        final date = (v['date'] ?? '').toString();
        final title = (v['title'] ?? '').toString();
        final body = (v['body'] ?? '').toString();
        if (title.isEmpty) continue;
        remote.add(Announcement(date, title, body));
      }
      if (remote.isEmpty) return;
      final merged = [...remote, ...kAnnouncements]
        ..sort((a, b) => b.date.compareTo(a.date));
      all.value = merged;
    } catch (_) {
      // 오프라인/권한 문제 — 내장 공지 유지.
    }
  }
}
