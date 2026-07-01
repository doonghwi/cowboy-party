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

/// 주간 시즌 랭킹 — `/seasons/{yyyy-MM-dd(그 주 월요일)}/{uid}` {name, pts}.
/// 매주 월요일 00:00(로컬)에 새 시즌으로 자동 전환 → 빈 랭킹으로 리셋(별도 크론 불필요).
/// 서버 기록은 Firebase Auth uid가 있을 때만(게스트는 로컬 표시 + 로그인 유도).
class SeasonService {
  SeasonService._();
  static final SeasonService I = SeasonService._();

  /// 이번 주 월요일(로컬 자정 기준). weekday: Mon=1 … Sun=7.
  static DateTime get _weekMonday {
    final n = DateTime.now();
    final d = DateTime(n.year, n.month, n.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  static String _weekId(DateTime monday) =>
      '${monday.year}-${monday.month.toString().padLeft(2, '0')}-'
      '${monday.day.toString().padLeft(2, '0')}';

  static String get seasonId => _weekId(_weekMonday);

  /// 지난 주(월요일 기준) 시즌 id — '지난 주 챔피언' 표시용.
  static String get prevSeasonId =>
      _weekId(_weekMonday.subtract(const Duration(days: 7)));

  static String get seasonLabel {
    final m = _weekMonday;
    final s = m.add(const Duration(days: 6));
    return '${m.month}/${m.day}~${s.month}/${s.day} 주간 랭킹';
  }

  DatabaseReference? _refFor(String sid) {
    try {
      return FirebaseDatabase.instanceFor(
              app: Firebase.app(), databaseURL: OnlineService.databaseUrl)
          .ref('seasons/$sid');
    } catch (_) {
      return null;
    }
  }

  DatabaseReference? get _ref => _refFor(seasonId);

  /// 승리 포인트: 10 × (인원 - 1).
  static int winPts(int players) => 10 * (players.clamp(2, 6) - 1);

  /// 온라인 승리 시 호출 (베스트에포트).
  /// G2: 랭킹은 **계정(구글 로그인)만** 등록 — 게스트/익명은 닉네임은 쓰되 미등록.
  void recordWin(int players) {
    if (!AuthService.I.isGoogle) return;
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

  /// 닉네임 변경 시 호출 — 이번 시즌 랭킹에 이미 올라 있으면 표시 이름을 갱신.
  /// (랭킹에 없으면 새로 만들지 않는다 — 안 한 사람이 0점으로 끼지 않게.)
  Future<void> updateName(String name) async {
    if (!AuthService.I.isGoogle) return;
    final uid = AuthService.I.cloudUid;
    final ref = _ref;
    if (uid == null || ref == null) return;
    try {
      final node = ref.child(uid);
      final snap = await node.get();
      if (!snap.exists) return; // 이번 시즌 기록 없음 → 갱신할 것 없음
      await node.update({'name': name}).catchError((_) {});
    } catch (_) {}
  }

  /// 이번 주 상위 [limit]명 (포인트 내림차순).
  Future<List<RankEntry>> fetchTop({int limit = 50}) =>
      _fetchTopFrom(_ref, limit);

  /// 지난 주 상위 [limit]명(기본 3) — '지난 주 챔피언' 표시용.
  Future<List<RankEntry>> fetchPrevTop({int limit = 3}) =>
      _fetchTopFrom(_refFor(prevSeasonId), limit);

  Future<List<RankEntry>> _fetchTopFrom(
      DatabaseReference? ref, int limit) async {
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
