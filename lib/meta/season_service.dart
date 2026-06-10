import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../online/online_service.dart' show OnlineService;
import 'auth_service.dart';
import 'meta_service.dart';

class RankEntry {
  final String uid;
  final String name;
  final int pts;
  const RankEntry(this.uid, this.name, this.pts);
}

/// 월별 시즌 랭킹 — `/seasons/{yyyy-MM}/{uid}` {name, pts}.
/// 서버 기록은 Firebase Auth uid가 있을 때만(게스트는 로컬 표시 + 로그인 유도).
class SeasonService {
  SeasonService._();
  static final SeasonService I = SeasonService._();

  static String get seasonId {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}';
  }

  static String get seasonLabel {
    final n = DateTime.now();
    return '${n.year}년 ${n.month}월 시즌';
  }

  DatabaseReference? get _ref {
    try {
      return FirebaseDatabase.instanceFor(
              app: Firebase.app(), databaseURL: OnlineService.databaseUrl)
          .ref('seasons/$seasonId');
    } catch (_) {
      return null;
    }
  }

  /// 승리 포인트: 10 × (인원 - 1).
  static int winPts(int players) => 10 * (players.clamp(2, 6) - 1);

  /// 온라인 승리 시 호출 (베스트에포트).
  void recordWin(int players) {
    final uid = AuthService.I.cloudUid;
    final ref = _ref;
    if (uid == null || ref == null) return;
    final name = Meta.I.nickname.isNotEmpty
        ? Meta.I.nickname
        : (AuthService.I.displayName ?? '카우보이');
    ref.child(uid).update({
      'name': name,
      'pts': ServerValue.increment(winPts(players)),
    }).catchError((_) {});
  }

  /// 상위 [limit]명 (포인트 내림차순).
  Future<List<RankEntry>> fetchTop({int limit = 50}) async {
    final ref = _ref;
    if (ref == null) return const [];
    try {
      final snap = await ref.orderByChild('pts').limitToLast(limit).get();
      final v = snap.value;
      if (v is! Map) return const [];
      final out = <RankEntry>[];
      v.forEach((uid, raw) {
        if (raw is Map) {
          out.add(RankEntry(
            uid.toString(),
            (raw['name'] as String?) ?? '카우보이',
            raw['pts'] is int ? raw['pts'] as int : 0,
          ));
        }
      });
      out.sort((a, b) => b.pts.compareTo(a.pts));
      return out;
    } catch (_) {
      return const [];
    }
  }
}
