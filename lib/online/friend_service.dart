import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../meta/auth_service.dart';
import '../meta/meta_service.dart';
import 'online_service.dart';

/// 친구 MVP(2026-07-13 사용자 결정): 닉네임으로 요청 → 상대 수락 시 친구,
/// 온라인/오프라인 표시(presence 하트비트), 대기방으로 인앱 초대(앱 켜져
/// 있을 때만 — 서버 푸시 없음). 전부 베스트에포트: 실패해도 게임을 안 깨움.
class FriendInfo {
  final String uid;
  final String name;

  /// 친선전 누적 전적(⑫ 2026-07-16) — 내 관점 승/패.
  final int friendlyWins;
  final int friendlyLosses;
  const FriendInfo(this.uid, this.name,
      {this.friendlyWins = 0, this.friendlyLosses = 0});
}

class FriendRequest {
  final String fromUid;
  final String fromName;
  const FriendRequest(this.fromUid, this.fromName);
}

/// 내가 보낸 친구 요청(대기중 표시용, 2026-07-18 사용자 요청).
/// 서버 규칙상 friendReqs는 받는 쪽만 읽을 수 있어 보낸 쪽은 로컬로 기억한다.
class SentRequest {
  final String uid; // 상대 uid
  final String name; // 보낼 때 입력한 닉네임
  final int at;
  const SentRequest(this.uid, this.name, this.at);
}

class RoomInvite {
  final String code;
  final String fromName;
  final int at;
  const RoomInvite(this.code, this.fromName, this.at);
}

class FriendService {
  FriendService._();
  static final FriendService I = FriendService._();

  /// presence가 이 시간 안에 갱신됐으면 온라인으로 본다.
  static const int kOnlineWithinMs = 90 * 1000;

  DatabaseReference? get _root {
    try {
      return FirebaseDatabase.instanceFor(
              app: Firebase.app(), databaseURL: OnlineService.databaseUrl)
          .ref();
    } catch (_) {
      return null;
    }
  }

  String? get _uid => AuthService.I.cloudUid;
  String get _myName =>
      Meta.I.nickname.isNotEmpty ? Meta.I.nickname : '카우보이';

  static String nickKey(String name) => name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[.#$\[\]/\s]'), '_');

  // ── presence(온라인 표시) ────────────────────────────────────────────────
  Timer? _beat;

  /// 앱이 살아있는 동안 40초마다 presence 갱신(셸에서 1회 시작).
  void startPresence() {
    if (_beat != null) return;
    Future<void> tick() async {
      final r = _root;
      final uid = _uid;
      if (r == null || uid == null) return;
      try {
        await r.child('presence/$uid').set({
          'at': ServerValue.timestamp,
          'name': _myName,
          'lv': Meta.I.level, // 친구 프로필 표시용(⑬ 2026-07-16)
        });
      } catch (_) {}
    }

    tick();
    _beat = Timer.periodic(const Duration(seconds: 40), (_) => tick());
  }

  /// 친구들의 온라인 여부 1회 조회(시트가 주기 폴링).
  Future<Map<String, bool>> presenceOf(List<String> uids) async {
    final r = _root;
    if (r == null || uids.isEmpty) return {};
    final now = DateTime.now().millisecondsSinceEpoch;
    final out = <String, bool>{};
    try {
      final snap = await r.child('presence').get();
      final v = snap.value;
      for (final uid in uids) {
        final p = (v is Map) ? v[uid] : null;
        final at = (p is Map && p['at'] is num) ? (p['at'] as num).toInt() : 0;
        // 서버 시계 vs 로컬 시계 오차는 온라인 판정(90초)에 비해 작다.
        out[uid] = now - at < kOnlineWithinMs;
      }
    } catch (_) {}
    return out;
  }

  /// 친구 한 명의 presence 상세(온라인 여부+레벨) — 프로필 시트용(⑬).
  Future<({bool on, int lv})> presenceInfo(String uid) async {
    final r = _root;
    if (r == null) return (on: false, lv: 0);
    try {
      final snap = await r.child('presence/$uid').get();
      final v = snap.value;
      final at = (v is Map && v['at'] is num) ? (v['at'] as num).toInt() : 0;
      final lv = (v is Map && v['lv'] is num) ? (v['lv'] as num).toInt() : 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      return (on: now - at < kOnlineWithinMs, lv: lv);
    } catch (_) {
      return (on: false, lv: 0);
    }
  }

  /// 친선전 결과 1건 누적(⑫) — friends/<나>/<친구>/{fw,fl}. 친구가 아니면 무시.
  Future<void> recordFriendly(String fuid, {required bool won}) async {
    final r = _root;
    final me = _uid;
    if (r == null || me == null || fuid.isEmpty || fuid == me) return;
    try {
      final entry = await r.child('friends/$me/$fuid/name').get();
      if (entry.value == null) return; // 친구 아님 — 유령 항목 방지
      await r
          .child('friends/$me/$fuid/${won ? 'fw' : 'fl'}')
          .runTransaction((cur) =>
              Transaction.success((cur is int ? cur : 0) + 1));
    } catch (_) {}
  }

  // ── 친구 요청/수락 ──────────────────────────────────────────────────────

  /// 닉네임으로 친구 요청. 반환: 빈 문자열=성공, 아니면 사용자 안내 문구.
  Future<String> sendRequest(String nickname) async {
    final r = _root;
    final me = _uid;
    if (r == null || me == null) return '연결이 필요해요. 잠시 후 다시 시도해 주세요';
    final key = nickKey(nickname);
    if (key.isEmpty) return '닉네임을 입력해 주세요';
    try {
      final snap = await r.child('nicknames/$key').get();
      final target = snap.value;
      if (target is! String || target.isEmpty) {
        return '그 닉네임의 카우보이를 찾지 못했어요';
      }
      if (target == me) return '자기 자신에게는 보낼 수 없어요';
      final already = await r.child('friends/$me/$target').get();
      if (already.exists) {
        await forgetSent(target); // 이미 친구인데 대기중으로 남았으면 정리
        return '이미 친구예요';
      }
      await r.child('friendReqs/$target/$me').set({
        'name': _myName,
        'at': ServerValue.timestamp,
      });
      await _rememberSent(target, nickname.trim());
      return '';
    } catch (_) {
      return '요청을 보내지 못했어요. 연결을 확인해 주세요';
    }
  }

  /// 받은 요청 수락 — 양쪽 friends에 기록하고 요청 삭제.
  Future<bool> accept(FriendRequest req) async {
    final r = _root;
    final me = _uid;
    if (r == null || me == null) return false;
    try {
      await r.child('friends/$me/${req.fromUid}').set({
        'name': req.fromName,
        'since': ServerValue.timestamp,
      });
      await r.child('friends/${req.fromUid}/$me').set({
        'name': _myName,
        'since': ServerValue.timestamp,
      });
      await r.child('friendReqs/$me/${req.fromUid}').remove();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> decline(FriendRequest req) async {
    final me = _uid;
    if (me == null) return;
    try {
      await _root?.child('friendReqs/$me/${req.fromUid}').remove();
    } catch (_) {}
  }

  Future<void> removeFriend(String fuid) async {
    final me = _uid;
    if (me == null) return;
    try {
      await _root?.child('friends/$me/$fuid').remove();
      await _root?.child('friends/$fuid/$me').remove();
    } catch (_) {}
  }

  Stream<List<FriendInfo>>? watchFriends() {
    final r = _root;
    final me = _uid;
    if (r == null || me == null) return null;
    return r.child('friends/$me').onValue.map((e) {
      final v = e.snapshot.value;
      final out = <FriendInfo>[];
      if (v is Map) {
        v.forEach((uid, raw) {
          final name =
              (raw is Map && raw['name'] is String) ? raw['name'] as String : '카우보이';
          int cnt(String k) =>
              (raw is Map && raw[k] is num) ? (raw[k] as num).toInt() : 0;
          out.add(FriendInfo(uid.toString(), name,
              friendlyWins: cnt('fw'), friendlyLosses: cnt('fl')));
        });
      }
      out.sort((a, b) => a.name.compareTo(b.name));
      return out;
    });
  }

  Stream<List<FriendRequest>>? watchRequests() {
    final r = _root;
    final me = _uid;
    if (r == null || me == null) return null;
    return r.child('friendReqs/$me').onValue.map((e) {
      final v = e.snapshot.value;
      final out = <FriendRequest>[];
      if (v is Map) {
        v.forEach((uid, raw) {
          final name =
              (raw is Map && raw['name'] is String) ? raw['name'] as String : '카우보이';
          out.add(FriendRequest(uid.toString(), name));
        });
      }
      return out;
    });
  }

  // ── 보낸 요청(로컬 기록) — '대기중' 표시용(2026-07-18 사용자 요청) ────────
  // 이 기기에서 보낸 요청만 안다(서버는 받는 쪽만 조회 가능). 상대가 수락해
  // 친구가 되면 pruneSentByFriends가 지우고, 취소는 원격 노드도 지운다.
  static const _kSentKey = 'sent_reqs_v1';
  static const int kSentMax = 20;

  Future<List<SentRequest>> sentRequests() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_kSentKey);
      if (raw == null || raw.isEmpty) return const [];
      final v = jsonDecode(raw);
      return [
        if (v is List)
          for (final e in v)
            if (e is Map && e['uid'] is String && e['name'] is String)
              SentRequest(e['uid'] as String, e['name'] as String,
                  e['at'] is num ? (e['at'] as num).toInt() : 0),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveSent(List<SentRequest> list) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
        _kSentKey,
        jsonEncode([
          for (final s in list.take(kSentMax))
            {'uid': s.uid, 'name': s.name, 'at': s.at},
        ]));
  }

  Future<void> _rememberSent(String uid, String name) async {
    try {
      final cur = await sentRequests();
      await _saveSent([
        SentRequest(uid, name, DateTime.now().millisecondsSinceEpoch),
        ...cur.where((s) => s.uid != uid),
      ]);
    } catch (_) {}
  }

  Future<void> forgetSent(String uid) async {
    try {
      final cur = await sentRequests();
      if (!cur.any((s) => s.uid == uid)) return;
      await _saveSent(cur.where((s) => s.uid != uid).toList());
    } catch (_) {}
  }

  /// 수락돼 친구가 된 상대를 대기중 목록에서 정리.
  Future<void> pruneSentByFriends(Iterable<String> friendUids) async {
    try {
      final set = friendUids.toSet();
      final cur = await sentRequests();
      if (!cur.any((s) => set.contains(s.uid))) return;
      await _saveSent(cur.where((s) => !set.contains(s.uid)).toList());
    } catch (_) {}
  }

  /// 보낸 요청 취소 — 상대의 받은 요청함에서도 지운다(쓰기 규칙: 보낸 이 허용).
  Future<void> cancelRequest(SentRequest s) async {
    final me = _uid;
    if (me != null) {
      try {
        await _root?.child('friendReqs/${s.uid}/$me').remove();
      } catch (_) {}
    }
    await forgetSent(s.uid);
  }

  // ── 최근 함께 플레이(로컬) — 친구 탭 추천용(#1, 2026-07-15) ──────────────
  static const _kRecentKey = 'recent_players_v1';
  static const int kRecentMax = 12;

  /// 온라인 게임이 끝날 때 같이 친 닉네임들을 기록(최신순, 중복 제거).
  Future<void> noteRecentPlayers(List<String> names) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final cur = sp.getStringList(_kRecentKey) ?? const [];
      final mine = _myName;
      final merged = <String>[
        for (final n in names)
          if (n.trim().isNotEmpty && n.trim() != mine && n != '빈자리')
            n.trim(),
        ...cur,
      ];
      final seen = <String>{};
      final out = [for (final n in merged) if (seen.add(n)) n];
      await sp.setStringList(_kRecentKey, out.take(kRecentMax).toList());
    } catch (_) {}
  }

  Future<List<String>> recentPlayers() async {
    try {
      final sp = await SharedPreferences.getInstance();
      return sp.getStringList(_kRecentKey) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  // ── 방 초대(인앱) ───────────────────────────────────────────────────────

  Future<void> invite(String toUid, String roomCode) async {
    final r = _root;
    if (r == null) return;
    try {
      await r.child('invites/$toUid').set({
        'code': roomCode,
        'from': _myName,
        'at': ServerValue.timestamp,
      });
    } catch (_) {}
  }

  Stream<RoomInvite?>? watchInvites() {
    final r = _root;
    final me = _uid;
    if (r == null || me == null) return null;
    return r.child('invites/$me').onValue.map((e) {
      final v = e.snapshot.value;
      if (v is! Map) return null;
      final code = v['code'];
      if (code is! String || code.isEmpty) return null;
      return RoomInvite(
        code,
        (v['from'] as String?) ?? '친구',
        v['at'] is num ? (v['at'] as num).toInt() : 0,
      );
    });
  }

  Future<void> clearInvite() async {
    final me = _uid;
    if (me == null) return;
    try {
      await _root?.child('invites/$me').remove();
    } catch (_) {}
  }
}
