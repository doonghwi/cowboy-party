import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../game/party_logic.dart';
import '../meta/auth_service.dart';

/// Phase of an online room from one player's point of view.
enum OnlinePhase { waiting, choosing, submitted, over }

/// How long a player can go silent (no heartbeat) before they're treated as
/// gone — long enough that a quick app-backgrounding or network blip never
/// kicks anyone, short enough that a real departure unblocks the table.
const int kPresenceGraceMs = 14000;

/// Render-ready snapshot of one seat at the table.
class SeatView {
  final int seat;
  final bool joined; // player present in the room right now
  final String name;
  final int ammo;
  final bool alive;
  final bool isMe;

  final Move? lastMove;
  final bool fired;
  final bool superFired;
  final int firedTarget;
  final bool hitThisTurn;

  final bool submittedThisTurn;
  final int score;

  /// Character on this seat and one-turn ability effects (for the reveal).
  final CharId char;
  final bool healedFx; // 의사 자힐 발동
  final bool evadedFx; // 연막 회피 성공
  final bool reflectedFx; // 덫 반사로 사망
  final bool smokedFx; // 이 턴 연막 사용
  final bool doubleLoadFx; // 스피드로더 +2
  final bool piercedFx; // 스나이퍼 관통 발동(D1)
  final bool resetFx; // 리셋터 무효 발동(D4)
  final String? abilityUses; // 유한 능력 사용량 '사용/총'(#11, 모두에게 표시)
  final bool curseKillFx; // 저주 만료로 이 턴 사망
  final int curseTurnsLeft; // 부두 저주 남은 턴(0=저주 없음) — 모두에게 표시(C2)
  final bool late; // 게임 중 난입 — 다음 판부터 참여(관전)

  // 그림자(shadow): 상대가 볼 때 가려짐.
  final bool hideAmmo; // 탄약 수 숨김
  final bool hideAction; // 이번 턴 행동 숨김(장전/방어/가만히)

  /// 방장이 닫은 자리(F2, 크레이지아케이드식). 대기실에서만 의미.
  final bool blocked;

  const SeatView({
    required this.seat,
    required this.joined,
    required this.name,
    required this.ammo,
    required this.alive,
    required this.isMe,
    required this.lastMove,
    required this.fired,
    required this.superFired,
    required this.firedTarget,
    required this.hitThisTurn,
    required this.submittedThisTurn,
    required this.score,
    this.char = CharId.none,
    this.healedFx = false,
    this.evadedFx = false,
    this.reflectedFx = false,
    this.smokedFx = false,
    this.doubleLoadFx = false,
    this.piercedFx = false,
    this.resetFx = false,
    this.abilityUses,
    this.curseKillFx = false,
    this.curseTurnsLeft = 0,
    this.late = false,
    this.hideAmmo = false,
    this.hideAction = false,
    this.blocked = false,
  });
}

/// A public room as shown in the lobby browser.
class PublicRoomInfo {
  final String code;
  final String title;
  final String hostName;
  final int joined;
  final int capacity;
  final bool started;
  final int createdAt;

  const PublicRoomInfo({
    required this.code,
    required this.title,
    required this.hostName,
    required this.joined,
    required this.capacity,
    required this.started,
    required this.createdAt,
  });
}

/// A fully-derived, render-ready view of a room from one player's perspective.
class RoomView {
  final int capacity;
  final int seatCount;
  final bool started;
  final bool isHost;
  final OnlinePhase phase;
  final int turn;
  final int mySeat; // -1 if I'm not seated
  final List<SeatView> seats;
  final int joinedCount;
  final int presentCount;
  final bool canStart;
  final Move? myPending;
  final bool iSubmitted;
  final int submittedAlive;
  final int aliveCount;
  final GameStatus status;
  final int? winnerSeat;
  final String banner;
  final bool justResolved;
  final bool iRequestedRematch;
  final int rematchCount;

  /// Seats that have gone silent mid-game and should be reaped (host writes a
  /// sticky `quit` marker so the departure is consistent across clients).
  final List<int> reapSeats;

  /// I was removed from a started game (left or timed out).
  final bool iAmOut;

  /// I joined while a game was running — spectating until the next round.
  final bool iAmLate;
  final bool iWasKicked; // F2: 방장에게 추방됨 — 화면에서 내보낸다.
  final bool iShouldClaimHost; // 방장 승계: 내가 새 방장이면 RTDB에 확정.

  /// 내 캐릭터 능력 잔여량 (게임 화면의 버튼 상태용).
  final bool myTrapAvailable;
  final bool myResetAvailable;
  final int mySmokeLeft;

  /// 'duelist' | 'pacifist' when a character ability decided the game.
  final String? specialWin;

  // ---- 파파라치 엿보기 ----
  /// 이 턴 누군가 엿보기 중(전원 제출됨, 엿본 사람만 행동 미정).
  final bool peekActive;
  final int peekerSeat; // 엿보는 좌석
  final int peekTargetSeat; // 엿보는 대상
  final String peekerName;
  final bool iAmPeeker; // 내가 엿보는 사람
  final Move? peekedMove; // (엿보는 사람에게만) 대상의 이번 턴 행동
  final bool peekStale; // 10초+ 경과 — 호스트가 언블록
  final bool myPaparazziUsed; // 내 엿보기 사용됨(버튼 비활성)

  final int drawTurn;
  final List<int> drawParticipants;

  const RoomView({
    required this.capacity,
    required this.seatCount,
    required this.started,
    required this.isHost,
    required this.phase,
    required this.turn,
    required this.mySeat,
    required this.seats,
    required this.joinedCount,
    required this.presentCount,
    required this.canStart,
    required this.myPending,
    required this.iSubmitted,
    required this.submittedAlive,
    required this.aliveCount,
    required this.status,
    required this.winnerSeat,
    required this.banner,
    required this.justResolved,
    required this.iRequestedRematch,
    required this.rematchCount,
    this.reapSeats = const [],
    this.iAmOut = false,
    this.iAmLate = false,
    this.iWasKicked = false,
    this.iShouldClaimHost = false,
    this.myTrapAvailable = false,
    this.myResetAvailable = false,
    this.mySmokeLeft = 0,
    this.specialWin,
    this.peekActive = false,
    this.peekerSeat = -1,
    this.peekTargetSeat = -1,
    this.peekerName = '',
    this.iAmPeeker = false,
    this.peekedMove,
    this.peekStale = false,
    this.myPaparazziUsed = false,
    this.drawTurn = -1,
    this.drawParticipants = const [],
  });

  bool get seated => mySeat >= 0;
  SeatView? get me => seated && mySeat < seats.length ? seats[mySeat] : null;
  bool get iWon => status == GameStatus.won && winnerSeat == mySeat;
}

enum JoinResult { joined, notFound, full, alreadyStarted, wrongPassword, kicked }

class OnlineService {
  OnlineService() : clientId = _genClientId() {
    // Track clock skew so heartbeats/staleness use server time.
    serverOffsetRef().onValue.listen((e) {
      final v = e.snapshot.value;
      if (v is num) _offset = v.toInt();
    });
  }

  final String clientId;
  int _offset = 0;

  static const String databaseUrl =
      'https://cowboy-party-doonghwi-default-rtdb.asia-southeast1.firebasedatabase.app';

  final FirebaseDatabase _fdb = FirebaseDatabase.instanceFor(
      app: Firebase.app(), databaseURL: databaseUrl);

  late final DatabaseReference _root = _fdb.ref();

  DatabaseReference serverOffsetRef() => _fdb.ref('.info/serverTimeOffset');

  int get _now => DateTime.now().millisecondsSinceEpoch + _offset;

  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const _idChars = 'abcdefghijklmnopqrstuvwxyz0123456789';

  static String _genClientId() {
    final r = Random();
    return List.generate(10, (_) => _idChars[r.nextInt(_idChars.length)]).join();
  }

  static String generateRoomCode() {
    final r = Random();
    return List.generate(4, (_) => _codeChars[r.nextInt(_codeChars.length)])
        .join();
  }

  /// 배포된 웹 주소 (딥링크 기준). repo/URL은 유지(A1).
  static const String webBaseUrl = 'https://doonghwi.github.io/cowboy-party/';

  /// F4: 방 초대 링크. 이 링크로 들어오면 해당 방으로 입장(main.dart 딥링크 처리).
  static String inviteLink(String code) => '$webBaseUrl?room=$code';

  /// 현재 URL/딥링크에서 방 코드 추출(웹). 없으면 null.
  static String? roomCodeFromUrl() {
    try {
      final c = Uri.base.queryParameters['room'];
      if (c == null) return null;
      final code = c.trim().toUpperCase();
      return code.length == 4 ? code : null;
    } catch (_) {
      return null;
    }
  }

  static const _nickPool = [
    '방랑객', '총잡이', '무법자', '보안관', '건맨', '독수리',
    '선인장', '리볼버', '데드샷', '현상금', '협곡', '먼지'
  ];

  static String randomNickname() {
    final r = Random();
    return '${_nickPool[r.nextInt(_nickPool.length)]}${10 + r.nextInt(90)}';
  }

  static String slotKey(int seat) => 'p$seat';
  static int seatOf(String slotKey) => int.parse(slotKey.substring(1));

  DatabaseReference room(String code) => _root.child('rooms/$code');
  Stream<DatabaseEvent> watch(String code) => room(code).onValue;

  Future<void> createRoom(String code, String name, int capacity,
      {int charIndex = 0,
      String title = '',
      bool public = true,
      String password = '',
      bool match = false}) async {
    // 보안 규칙이 방 쓰기에 로그인을 요구함(익명 폴백) — 쓰기 전에 보장.
    await AuthService.I.tryAnonymous();
    await room(code).set({
      'host': clientId,
      'capacity': capacity.clamp(kMinSeats, kMaxSeats),
      'started': false,
      'public': public,
      // F3: 비공개 방은 비밀번호로 보호(공개 방은 비번 무시).
      'pw': public ? '' : password.trim(),
      // 매칭 전용 방(#2): 목록에 안 뜨고 빠른 시작끼리만 모임.
      'match': match,
      'title': title.trim().isEmpty ? '$name의 결투장' : title.trim(),
      'hostName': name,
      'game': 0,
      'players': {
        'p0': {'id': clientId, 'name': name, 'seen': _now, 'char': charIndex},
      },
      'turns': null,
      'rematch': null,
      'showdown': null,
      'quit': null,
      'createdAt': ServerValue.timestamp,
    });
  }

  /// 빠른 시작(#2): 모이는 중인 매칭 방이 있으면 합류, 없으면 새로 판다.
  /// 반환: (code, host=내가 만들었는지). 매칭 방은 public:false+match:true라
  /// 공개 목록·코드로는 접근 불가 — 빠른 시작끼리만 모인다.
  Future<({String code, bool host})> quickMatch(String name,
      {int charIndex = 0}) async {
    final snap = await _root
        .child('rooms')
        .orderByChild('createdAt')
        .limitToLast(30)
        .get();
    final rooms = _asMap(snap.value) ?? const {};
    final now = _now;
    final staleBefore = now - kPresenceGraceMs;
    String? best;
    int bestCreated = 1 << 62;
    rooms.forEach((code, raw) {
      final r = _asMap(raw);
      if (r == null) return;
      if (r['match'] != true || r['started'] == true) return;
      final created = _asInt(r['createdAt']) ?? 0;
      if (created < now - 60000) return; // 1분 지난 매칭 방은 유령 취급
      final players = _asMap(r['players']) ?? const {};
      var joined = 0;
      for (final v in players.values) {
        final m = _asMap(v);
        final seen = _asInt(m?['seen']);
        if (m != null && (seen == null || seen >= staleBefore)) joined++;
      }
      if (joined == 0 || joined >= kMaxSeats) return;
      if (created < bestCreated) {
        bestCreated = created;
        best = code.toString();
      }
    });
    if (best != null) {
      final res = await joinRoom(best!, name, charIndex: charIndex);
      if (res == JoinResult.joined) return (code: best!, host: false);
    }
    // 없으면 새 매칭 방 생성(내가 방장).
    final code = generateRoomCode();
    await createRoom(code, name, kMaxSeats,
        charIndex: charIndex, public: false, match: true, title: '매칭 방');
    return (code: code, host: true);
  }

  /// 매칭 취소/무산 — 아직 시작 안 된 매칭 방을 방장이 정리.
  Future<void> cancelMatch(String code) async {
    try {
      final snap = await room(code).get();
      final data = _asMap(snap.value) ?? const {};
      if (data['started'] == true) return; // 이미 시작됐으면 그대로 둠
      await room(code).remove();
    } catch (_) {}
  }

  /// Recent open public rooms for the lobby browser (fresh, not started, has
  /// room left). Best-effort: a stale entry just fails on join with a clear
  /// message.
  Future<List<PublicRoomInfo>> fetchPublicRooms() async {
    final snap = await _root
        .child('rooms')
        .orderByChild('createdAt')
        .limitToLast(40)
        .get();
    final rooms = _asMap(snap.value) ?? const {};
    final cutoff = _now - 2 * 60 * 60 * 1000; // 2시간 지난 방은 유령 취급
    final out = <PublicRoomInfo>[];
    rooms.forEach((code, raw) {
      final r = _asMap(raw);
      if (r == null || r['public'] != true) return;
      final createdAt = _asInt(r['createdAt']) ?? 0;
      if (createdAt < cutoff) return;
      final players = _asMap(r['players']) ?? const {};
      final staleBefore = _now - kPresenceGraceMs;
      var joined = 0;
      for (final e in players.entries) {
        final v = _asMap(e.value);
        final seen = _asInt(v?['seen']);
        if (v != null && (seen == null || seen >= staleBefore)) joined++;
      }
      if (joined == 0) return;
      final capacity = _asInt(r['capacity']) ?? kMaxSeats;
      out.add(PublicRoomInfo(
        code: code.toString(),
        title: (r['title'] as String?) ?? '결투장',
        hostName: (r['hostName'] as String?) ?? '카우보이',
        joined: joined,
        capacity: capacity,
        started: r['started'] == true,
        createdAt: createdAt,
      ));
    });
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  /// Claim a seat. Re-joining with the same id reclaims the held seat; an empty
  /// or long-silent (stale) seat can be taken. No hard onDisconnect removal —
  /// the heartbeat + grace decides presence, so a brief blip never kicks you.
  Future<JoinResult> joinRoom(String code, String name,
      {int charIndex = 0, String password = ''}) async {
    // 보안 규칙이 좌석 점유(쓰기)에 로그인을 요구함(익명 폴백) — 쓰기 전에 보장.
    await AuthService.I.tryAnonymous();
    final snap = await room(code).get();
    if (!snap.exists) return JoinResult.notFound;
    final data = _asMap(snap.value) ?? const {};
    final players = _asMap(data['players']) ?? const {};

    // F3: 비공개 방 비밀번호 확인 (이미 좌석을 가진 재입장은 통과).
    final isPublic = data['public'] == true;
    final roomPw = (data['pw'] as String?) ?? '';
    final alreadySeated = players.values.any((v) {
      final m = _asMap(v);
      return m != null && m['id'] == clientId;
    });
    if (!isPublic && roomPw.isNotEmpty && !alreadySeated) {
      if (password.trim() != roomPw) return JoinResult.wrongPassword;
    }

    // F2: 방장에게 추방당한 사람은 다시 못 들어옴.
    final kicked = _asMap(data['kicked']) ?? const {};
    if (kicked[clientId] == true && !alreadySeated) return JoinResult.kicked;
    final blocked = _asMap(data['blocked']) ?? const {};

    // Already hold a seat? Reclaim it (refresh heartbeat; keep the original
    // character — mid-game swaps would corrupt the deterministic replay).
    for (final e in players.entries) {
      final v = _asMap(e.value);
      if (v != null && v['id'] == clientId) {
        final s = seatOf(e.key.toString());
        await room(code).child('players/${slotKey(s)}/seen').set(_now);
        return JoinResult.joined;
      }
    }
    // A started room is still re-enterable: take any empty or long-silent seat
    // (a finished/abandoned spot), not just in the lobby. Mid-game the rejoiner
    // gets a sticky `late` marker — they spectate until the next round (never
    // pop into the running game alive); the next reset/start clears it.
    // Only seats 1..seatCount stay claimable (the host keeps seat 0).
    final started = data['started'] == true;
    final capacity = _asInt(data['capacity']) ?? kMaxSeats;
    final seatLimit =
        started ? (_asInt(data['seatCount']) ?? capacity) : capacity;
    final staleBefore = _now - kPresenceGraceMs;
    // 시작된 게임은 좌석0(방장)을 보존하지만, **대기실(미시작)**에서는 방장이
    // 나가 비어 있으면 좌석0도 가져갈 수 있어야 한다(안 그러면 1/6인데 "꽉 참" 버그).
    final firstSeat = started ? 1 : 0;
    for (var s = firstSeat; s < seatLimit; s++) {
      if (blocked[slotKey(s)] == true) continue; // 방장이 닫은 자리는 건너뜀
      final claim = {
        'id': clientId,
        'name': name,
        'seen': _now,
        'char': charIndex,
        if (started) 'late': true,
      };
      final res =
          await room(code).child('players/${slotKey(s)}').runTransaction(
        (current) {
          if (current == null) {
            return Transaction.success(claim);
          }
          final v = _asMap(current);
          if (v != null && v['id'] == clientId) {
            return Transaction.success(current);
          }
          final seen = _asInt(v?['seen']);
          if (seen != null && seen < staleBefore) {
            // Silent long enough — take the seat.
            return Transaction.success(claim);
          }
          return Transaction.abort();
        },
      );
      if (res.committed) {
        final v = _asMap(res.snapshot.value);
        if (v != null && v['id'] == clientId) {
          // Clear any sticky quit on this seat so the rejoiner reads as present.
          if (started) {
            try {
              await room(code).child('quit/${slotKey(s)}').remove();
            } catch (_) {}
          }
          return JoinResult.joined;
        }
      }
    }
    return JoinResult.full;
  }

  /// Keep my seat alive. Called on a timer while I'm in the room.
  Future<void> heartbeat(String code, int seat) async {
    try {
      await room(code).child('players/${slotKey(seat)}/seen').set(_now);
    } catch (_) {}
  }

  /// F1: 대기실에서 시작 전 내 캐릭터 변경. 시작된 방에서는 무시(결정성 보호).
  Future<void> setRoomChar(String code, int seat, int charIndex) async {
    final snap = await room(code).get();
    final data = _asMap(snap.value) ?? const {};
    if (data['started'] == true) return;
    await room(code).child('players/${slotKey(seat)}/char').set(charIndex);
  }

  /// F2: 방장이 빈 자리 열기/닫기(크레이지아케이드식). 시작 전·자리가 비어 있을 때만.
  /// 최소 2자리(방장 자리 포함)는 열려 있어야 하므로 닫기 한도는 호출 측에서 검사.
  Future<void> setSeatBlocked(String code, int seat, bool blocked) async {
    final snap = await room(code).get();
    final data = _asMap(snap.value) ?? const {};
    if (data['started'] == true) return;
    if (data['host'] != clientId) return; // 방장만
    if (seat == 0) return; // 방장 자리는 못 닫음
    final players = _asMap(data['players']) ?? const {};
    if (players.containsKey(slotKey(seat))) return; // 사람이 있으면 닫지 않음(추방 먼저)
    await room(code)
        .child('blocked/${slotKey(seat)}')
        .set(blocked ? true : null);
  }

  /// 방장 승계: 기록된 방장이 없으면(나갔으면) 현재 인원 중 가장 낮은 좌석이 방장을 이어받는다.
  /// 내가 그 후보일 때만 host를 내 id로 확정(트랜잭션, 베스트에포트).
  Future<void> ensureHost(String code) async {
    final snap = await room(code).get();
    final data = _asMap(snap.value) ?? const {};
    final players = _asMap(data['players']) ?? const {};
    final staleBefore = _now - kPresenceGraceMs;
    bool here(Map? v) {
      if (v == null) return false;
      final seen = _asInt(v['seen']);
      return seen == null || seen >= staleBefore;
    }

    final host = data['host'];
    final hostHere =
        players.values.any((v) => _asMap(v)?['id'] == host && here(_asMap(v)));
    if (hostHere) return;
    var lowest = 1 << 30;
    String? lowestId;
    players.forEach((k, v) {
      final m = _asMap(v);
      if (m != null && here(m)) {
        final s = seatOf(k.toString());
        if (s < lowest) {
          lowest = s;
          lowestId = m['id'] as String?;
        }
      }
    });
    if (lowestId != clientId) return;
    await room(code).child('host').runTransaction((cur) {
      // 다른 클라가 먼저 가져갔으면 양보.
      if (cur == host || cur == null || cur == clientId) {
        return Transaction.success(clientId);
      }
      return Transaction.abort();
    });
  }

  /// F2: 방장이 특정 자리 플레이어 추방. 그 자리를 비우고 다시 못 들어오게 표시.
  Future<void> kickSeat(String code, int seat) async {
    final snap = await room(code).get();
    final data = _asMap(snap.value) ?? const {};
    if (data['started'] == true) return;
    if (data['host'] != clientId) return; // 방장만
    if (seat == 0) return; // 방장 자신은 못 내보냄
    final players = _asMap(data['players']) ?? const {};
    final v = _asMap(players[slotKey(seat)]);
    final kickedId = v?['id'];
    final updates = <String, Object?>{
      'players/${slotKey(seat)}': null,
      if (kickedId is String) 'kicked/$kickedId': true,
    };
    await room(code).update(updates);
  }

  Future<void> startGame(String code) async {
    final roomSnap = await room(code).get();
    final roomData = _asMap(roomSnap.value) ?? const {};
    final players = _asMap(roomData['players']) ?? const {};
    final entries = <MapEntry<int, Map>>[];
    for (final e in players.entries) {
      final v = _asMap(e.value);
      if (v != null) entries.add(MapEntry(seatOf(e.key.toString()), v));
    }
    entries.sort((a, b) => a.key.compareTo(b.key));
    if (entries.length < kMinSeats) return;
    final compact = <String, Object?>{};
    // Character snapshot lives at room level so the replay still knows a
    // leaver's character after their player node is removed.
    final chars = <String, Object?>{};
    for (var i = 0; i < entries.length; i++) {
      final charIdx = _asInt(entries[i].value['char']) ?? 0;
      compact[slotKey(i)] = {
        'id': entries[i].value['id'],
        'name': entries[i].value['name'],
        'seen': _now,
        'char': charIdx,
      };
      chars[slotKey(i)] = charIdx;
    }
    await room(code).update({
      'players': compact,
      'chars': chars,
      'seatCount': entries.length,
      'started': true,
      'game': (_asInt(roomData['game']) ?? 0) + 1,
      'turns': null,
      'rematch': null,
      'showdown': null,
      'quit': null,
      'scored': null,
      'react': null,
      'peek': null,
      'peekUsed': null,
    });
  }

  Future<void> submitMove(String code, int turn, int seat, Move m) {
    room(code).child('players/${slotKey(seat)}/seen').set(_now);
    return room(code).child('turns/t$turn/${slotKey(seat)}').set(m.encode());
  }

  /// 파파라치 엿보기 시작: 이 턴에 한 명을 엿보기로 지목(아직 내 행동은 제출 안 함).
  /// 게임당 1회(peekUsed). 전원 제출되면 엿보기 페이즈로 들어가 대상 행동을 보고
  /// 내 행동을 다시 고른다(submitMove로 마무리).
  Future<void> startPeek(String code, int turn, int seat, int target) async {
    await room(code).update({
      'peek/t$turn': {'by': seat, 'target': target, 'at': ServerValue.timestamp},
      'peekUsed/${slotKey(seat)}': true,
    });
    await room(code).child('players/${slotKey(seat)}/seen').set(_now);
  }

  Future<void> requestRematch(String code, int seat) {
    return room(code).child('rematch/${slotKey(seat)}').set(true);
  }

  /// Broadcast an emoji reaction over my seat. Stamped with server time so each
  /// client shows it briefly then lets it fade.
  Future<void> sendReaction(String code, int seat, String emoji) {
    return room(code).child('react/${slotKey(seat)}').set({'e': emoji, 't': _now});
  }

  /// Host marks silent players as having quit — sticky, so the departure stays
  /// consistent even if their client later reconnects mid-game.
  Future<void> markQuit(String code, List<int> seats) async {
    final updates = <String, Object?>{
      for (final s in seats) 'quit/${slotKey(s)}': true,
    };
    if (updates.isNotEmpty) {
      try {
        await room(code).update(updates);
      } catch (_) {}
    }
  }

  /// Bump the winner's score the moment the game is decided (once per game,
  /// guarded by the sticky `scored` flag so a replay never double-counts).
  Future<void> recordScore(String code, int winnerSeat) async {
    try {
      final snap = await room(code).child('scored').get();
      if (snap.value == true) return;
      await room(code).child('scored').set(true);
      await room(code).child('score/${slotKey(winnerSeat)}').runTransaction((cur) {
        final n = cur is int ? cur : 0;
        return Transaction.success(n + 1);
      });
    } catch (_) {}
  }

  /// Clear the board for a fresh round (score is kept; it was already recorded
  /// at win time). Late joiners' markers clear here — they play from this
  /// round — and the character snapshot is rebuilt to include them.
  /// 보드 초기화. [toLobby]=true면 started:false로 되돌려 **대기실**로 보낸다
  /// (#1: 게임 끝나고 다시하기 대신 대기실에서 초대·캐릭터변경·시작).
  Future<void> resetBoard(String code, {bool toLobby = false}) async {
    final snap = await room(code).get();
    final data = _asMap(snap.value) ?? const {};
    final players = _asMap(data['players']) ?? const {};
    final updates = <String, Object?>{
      'turns': null,
      'rematch': null,
      'showdown': null,
      'quit': null,
      'scored': null,
      'react': null,
      'peek': null,
      'peekUsed': null,
      if (toLobby) 'started': false,
      'game': (_asInt(data['game']) ?? 0) + 1,
    };
    final chars = <String, Object?>{};
    for (final e in players.entries) {
      final v = _asMap(e.value);
      if (v == null) continue;
      final key = e.key.toString();
      chars[key] = _asInt(v['char']) ?? 0;
      if (v['late'] == true) updates['players/$key/late'] = null;
    }
    updates['chars'] = chars;
    await room(code).update(updates);
  }

  /// Leave for good. In a started game this also writes a sticky quit so the
  /// seat is reaped immediately; in the lobby it just frees the seat. The
  /// leaver's [name] is stored in the quit marker so other clients can still
  /// say "OOO 님이 나갔어요" after the player node is removed.
  Future<void> leave(String code, int seat,
      {bool started = false, String? name}) async {
    try {
      if (started) {
        await room(code).child('quit/${slotKey(seat)}').set(
            (name != null && name.isNotEmpty) ? name : true);
      }
      await room(code).child('players/${slotKey(seat)}').remove();
    } catch (_) {}
  }

  // ---- Reaction showdown -------------------------------------------------

  Future<void> createShowdown(
      String code, int turn, List<int> participants, int goAtServerMs) {
    return room(code).child('showdown').set({
      'turn': turn,
      'round': 0,
      'goAt': goAtServerMs,
      'participants': {for (final s in participants) slotKey(s): true},
      'winner': null,
      'falseStart': null,
    });
  }

  Future<void> newShowdownRound(String code, int round, int goAtServerMs) {
    return room(code).child('showdown').update({
      'round': round,
      'goAt': goAtServerMs,
      'winner': null,
      'falseStart': null,
      'taps': null,
    });
  }

  Future<void> recordFalseStart(String code, int seat) {
    return room(code).child('showdown/falseStart/${slotKey(seat)}').set(true);
  }

  /// Record my reaction tap time (server clock). The host then awards the win
  /// to the *earliest* valid tap — fair by reaction speed, not network luck.
  Future<void> recordTap(String code, int seat, int tapMs) {
    return room(code).child('showdown/taps/${slotKey(seat)}').set(tapMs);
  }

  /// Host commits the showdown winner (once).
  Future<void> setShowdownWinner(String code, int seat) {
    return room(code).child('showdown/winner').runTransaction((cur) {
      if (cur == null) return Transaction.success(seat);
      return Transaction.abort();
    });
  }

  // ---- Pure helpers ------------------------------------------------------

  static int? _asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);

  static Map? _asMap(Object? v) {
    if (v is Map) return Map<String, Object?>.from(v);
    if (v is List) {
      final m = <String, Object?>{};
      for (var i = 0; i < v.length; i++) {
        if (v[i] != null) m['t$i'] = v[i];
      }
      return m;
    }
    return null;
  }

  /// Deterministic replay of a room into a view for [myClientId]. [nowServerMs]
  /// is the caller's best estimate of server time (local + offset); pass 0 in
  /// tests to disable staleness culling. [seedKey] (the room code) keys the
  /// character-ability RNG so every client rolls identically.
  static RoomView computeView(Map data, String myClientId,
      {int nowServerMs = 0, String seedKey = ''}) {
    final players = _asMap(data['players']) ?? const {};
    final turnsMap = _asMap(data['turns']) ?? const {};
    final scoreMap = _asMap(data['score']) ?? const {};
    final rematchMap = _asMap(data['rematch']) ?? const {};
    final quitMap = _asMap(data['quit']) ?? const {};
    final charsMap = _asMap(data['chars']) ?? const {};
    final peekMap = _asMap(data['peek']) ?? const {};
    final peekUsedMap = _asMap(data['peekUsed']) ?? const {};
    final showdown = _asMap(data['showdown']);
    final blockedMap = _asMap(data['blocked']) ?? const {};
    bool seatBlocked(int s) => blockedMap[slotKey(s)] == true;
    final kickedMap = _asMap(data['kicked']) ?? const {};
    final iWasKicked = kickedMap[myClientId] == true;
    final started = data['started'] == true;
    final recordedHostId = (data['host'] as String?) ?? '';
    final capacity =
        (_asInt(data['capacity']) ?? kMaxSeats).clamp(kMinSeats, kMaxSeats);
    final staleBefore = nowServerMs <= 0 ? -1 : nowServerMs - kPresenceGraceMs;

    var mySeat = -1;
    final names = <int, String>{};
    final nodeExists = <int, bool>{};
    final stale = <int, bool>{};
    final lateSeat = <int, bool>{};
    final seatCharIdx = <int, int>{};
    final seatId = <int, String>{};
    for (final e in players.entries) {
      final v = _asMap(e.value);
      if (v == null) continue;
      final s = seatOf(e.key.toString());
      names[s] = (v['name'] as String?) ?? '카우보이';
      nodeExists[s] = true;
      final seen = _asInt(v['seen']);
      stale[s] = staleBefore > 0 && seen != null && seen < staleBefore;
      lateSeat[s] = v['late'] == true;
      seatCharIdx[s] = _asInt(v['char']) ?? 0;
      seatId[s] = (v['id'] as String?) ?? '';
      if (v['id'] == myClientId) mySeat = s;
    }
    // The room-level snapshot (written at start) wins over live player nodes —
    // it survives a leaver's node removal, keeping the replay deterministic.
    CharId charAt(int s) {
      final fromRoom = _asInt(charsMap[slotKey(s)]);
      return charFromIndex(fromRoom ?? seatCharIdx[s]);
    }
    // A quit marker is either `true` (host-reaped silent seat) or the leaver's
    // name (written by leave()), kept sticky so departures stay consistent.
    bool quit(int s) {
      final v = quitMap[slotKey(s)];
      return v == true || v is String;
    }

    String? quitName(int s) {
      final v = quitMap[slotKey(s)];
      return v is String && v.isNotEmpty ? v : null;
    }

    // Best-effort display name for a seat even after its player node is gone.
    String? leftName(int s) => names[s] ?? quitName(s);

    // "present" = here, not timed out, not quit.
    bool present(int s) =>
        nodeExists[s] == true && !quit(s) && stale[s] != true;

    // 방장 승계: 기록된 방장이 없으면(나갔으면) 가장 낮은 좌석의 현재 인원이 방장.
    var effHostId = recordedHostId;
    final recordedHostHere = seatId.entries
        .any((e) => e.value == recordedHostId && present(e.key));
    if (!recordedHostHere) {
      for (var s = 0; s < capacity; s++) {
        if (present(s) && (seatId[s] ?? '').isNotEmpty) {
          effHostId = seatId[s]!;
          break;
        }
      }
    }
    final isHost = effHostId.isNotEmpty && effHostId == myClientId;
    // 화면이 새 방장을 RTDB에 확정(베스트에포트)해야 하는지.
    final iShouldClaimHost = isHost &&
        recordedHostId != myClientId &&
        mySeat >= 0 &&
        present(mySeat);

    final joinedCount = [
      for (var s = 0; s < capacity; s++)
        if (present(s)) s
    ].length;

    int scoreFor(int s) => _asInt(scoreMap[slotKey(s)]) ?? 0;

    // ---- Waiting room ----------------------------------------------------
    if (!started) {
      final seats = <SeatView>[
        for (var s = 0; s < capacity; s++)
          SeatView(
            seat: s,
            joined: present(s),
            name: present(s)
                ? (names[s] ?? '카우보이')
                : (seatBlocked(s) ? '닫힘' : '빈자리'),
            ammo: 0,
            alive: true,
            isMe: s == mySeat,
            lastMove: null,
            fired: false,
            superFired: false,
            firedTarget: -1,
            hitThisTurn: false,
            submittedThisTurn: false,
            score: scoreFor(s),
            char: present(s) ? charFromIndex(seatCharIdx[s]) : CharId.none,
            blocked: seatBlocked(s) && !present(s),
          ),
      ];
      return RoomView(
        capacity: capacity,
        seatCount: joinedCount,
        started: false,
        isHost: isHost,
        phase: OnlinePhase.waiting,
        turn: 0,
        mySeat: present(mySeat) ? mySeat : -1,
        seats: seats,
        joinedCount: joinedCount,
        presentCount: joinedCount,
        canStart: isHost && joinedCount >= kMinSeats,
        myPending: null,
        iSubmitted: false,
        submittedAlive: 0,
        aliveCount: joinedCount,
        status: GameStatus.ongoing,
        winnerSeat: null,
        banner:
            '총잡이 $joinedCount명 모임 · ${isHost ? "2명 이상이면 시작!" : "호스트의 시작을 기다리는 중"}',
        justResolved: false,
        iRequestedRematch: false,
        rematchCount: 0,
        iWasKicked: iWasKicked,
        iShouldClaimHost: iShouldClaimHost,
      );
    }

    // ---- Live game -------------------------------------------------------
    final n =
        (_asInt(data['seatCount']) ?? joinedCount).clamp(kMinSeats, kMaxSeats);

    final gameNo = _asInt(data['game']) ?? 0;
    final seed = '$seedKey#$gameNo';
    // ???(mystery)는 이 게임의 랜덤 직업으로 변환(모든 클라이언트 동일).
    final chars = <CharId>[
      for (var s = 0; s < n; s++) effectiveChar(charAt(s), seed, s)
    ];
    // B8: ???(mystery)는 능력을 실제로 쓰기 전까지 상대에게 정체를 숨긴다.
    final origChars = <CharId>[for (var s = 0; s < n; s++) charAt(s)];
    final revealed = List<bool>.filled(n, false);
    List<CharId> displayCharsNow() => [
          for (var s = 0; s < n; s++)
            (origChars[s] == CharId.mystery && !revealed[s] && s != mySeat)
                ? CharId.mystery
                : chars[s]
        ];
    var pstate = PartyState.initial(chars);
    // #11 유한 능력 사용량(모두에게). ???로 숨겨진 좌석은 표시 안 함.
    List<String?> abilityUsesNow() {
      final disp = displayCharsNow();
      return [
        for (var s = 0; s < n; s++)
          disp[s] == CharId.mystery
              ? null
              : abilityUsesLabel(chars[s], pstate, s)
      ];
    }

    var ammo = <int>[for (var s = 0; s < n; s++) startAmmoFor(chars[s])];
    var alive = List<bool>.filled(n, true);
    var lastMoves = List<Move?>.filled(n, null);
    var fired = List<bool>.filled(n, false);
    var superFired = List<bool>.filled(n, false);
    var firedTarget = List<int>.filled(n, -1);
    var hit = List<bool>.filled(n, false);
    var healedFx = List<bool>.filled(n, false);
    var evadedFx = List<bool>.filled(n, false);
    var reflectedFx = List<bool>.filled(n, false);
    var smokedFx = List<bool>.filled(n, false);
    var doubleLoadFx = List<bool>.filled(n, false);
    var piercedFx = List<bool>.filled(n, false);
    var resetFx = List<bool>.filled(n, false);
    var banner = '행동을 골라라!';
    final reap = <int>{};
    var t = 0;

    while (true) {
      final turn = _asMap(turnsMap['t$t']);
      var submitted = List<bool>.filled(n, false);
      var moves = List<Move>.filled(n, Move.empty);

      bool computeSubs() {
        submitted = List<bool>.filled(n, false);
        moves = List<Move>.filled(n, Move.empty);
        var all = true;
        for (var s = 0; s < n; s++) {
          if (!alive[s]) continue;
          final raw = turn == null ? null : _asInt(turn[slotKey(s)]);
          if (raw == null) {
            all = false;
          } else {
            submitted[s] = true;
            moves[s] = Move.decode(raw);
          }
        }
        return all;
      }

      var allAliveSubmitted = computeSubs();

      // Stuck waiting? Drop anyone who has gone (left/timed out) so the table
      // never freezes. Only at the live frontier — history is never rewritten.
      // A `late` seat counts as absent here even though its NEW occupant is
      // present: the predecessor's past moves replay untouched, but the seat
      // still dies at the frontier exactly as if it were empty. (Without this,
      // a mid-game joiner used to resurrect the seat instantly — the 재입장
      // 즉시부활 버그.) The newcomer just spectates until the next round.
      if (!allAliveSubmitted) {
        final justLeft = <int>[];
        for (var s = 0; s < n; s++) {
          if (alive[s] && (!present(s) || lateSeat[s] == true)) {
            alive[s] = false;
            justLeft.add(s);
            // A silent-but-still-present node should be made a sticky quit —
            // but never a late seat: its new occupant is legitimately here.
            if (nodeExists[s] == true && !quit(s) && lateSeat[s] != true) {
              reap.add(s);
            }
          }
        }
        if (justLeft.isNotEmpty) {
          final survivors = [
            for (var s = 0; s < n; s++)
              if (alive[s]) s
          ];
          if (survivors.length <= 1) {
            // The game didn't end by a real shot — someone left. Say so plainly
            // instead of crowning whoever happened to remain.
            final leftNames = [for (final s in justLeft) leftName(s) ?? '상대'];
            final banner = survivors.length == 1
                ? (leftNames.length == 1
                    ? '${leftNames.first} 님이 나갔어요'
                    : '상대가 모두 나갔어요')
                : '모두 떠났어요';
            return _buildView(
              phase: OnlinePhase.over,
              capacity: capacity,
              seatCount: n,
              isHost: isHost,
              iShouldClaimHost: iShouldClaimHost,
              turn: -1,
              mySeat: mySeat,
              names: names,
              presentFn: present,
              ammo: ammo,
              alive: alive,
              lastMoves: lastMoves,
              fired: List<bool>.filled(n, false),
              superFired: List<bool>.filled(n, false),
              firedTarget: List<int>.filled(n, -1),
              hit: List<bool>.filled(n, false),
              submitted: List<bool>.filled(n, false),
              scoreFor: scoreFor,
              joinedCount: joinedCount,
              myPending: null,
              iSubmitted: true,
              submittedAlive: 0,
              aliveCount: survivors.length,
              banner: banner,
              status:
                  survivors.length == 1 ? GameStatus.won : GameStatus.draw,
              winner: survivors.length == 1 ? survivors.first : null,
              rematchMap: rematchMap,
              quitFn: quit,
              reap: reap.toList()..sort(),
              chars: chars,
              displayChars: displayCharsNow(),
              lateFn: (s) => lateSeat[s] == true,
            );
          }
          allAliveSubmitted = computeSubs();
        }
      }

      if (!allAliveSubmitted) {
        final iAmAlive = mySeat >= 0 && mySeat < n && alive[mySeat];
        final iSubmitted = !iAmAlive || submitted[mySeat];
        final aliveCount = alive.where((a) => a).length;
        final submittedAlive = [
          for (var s = 0; s < n; s++)
            if (alive[s] && submitted[s]) s
        ].length;
        // ---- 파파라치 엿보기 감지 ----
        final peekT = _asMap(peekMap['t$t']);
        final hasPeek = peekT != null;
        final pkBy = hasPeek ? (_asInt(peekT['by']) ?? -1) : -1;
        final pkTarget = hasPeek ? (_asInt(peekT['target']) ?? -1) : -1;
        final pkAt = hasPeek ? _asInt(peekT['at']) : null;
        var othersDone = hasPeek && pkBy >= 0 && pkBy < n;
        if (othersDone) {
          for (var s = 0; s < n; s++) {
            if (s == pkBy) continue;
            if (alive[s] && !submitted[s]) {
              othersDone = false;
              break;
            }
          }
        }
        final peekActive = othersDone &&
            pkBy >= 0 &&
            pkBy < n &&
            alive[pkBy] &&
            !submitted[pkBy];
        final iAmPeeker = hasPeek && mySeat == pkBy;
        final peekedMove = (iAmPeeker &&
                peekActive &&
                pkTarget >= 0 &&
                pkTarget < n &&
                submitted[pkTarget])
            ? moves[pkTarget]
            : null;
        final peekStale = peekActive &&
            pkAt != null &&
            nowServerMs > 0 &&
            nowServerMs - pkAt > 12000;
        return _buildView(
          phase: iSubmitted && iAmAlive
              ? OnlinePhase.submitted
              : OnlinePhase.choosing,
          capacity: capacity,
          seatCount: n,
          isHost: isHost,
          iShouldClaimHost: iShouldClaimHost,
          turn: t,
          mySeat: mySeat,
          names: names,
          presentFn: present,
          ammo: ammo,
          alive: alive,
          lastMoves: lastMoves,
          fired: fired,
          superFired: superFired,
          firedTarget: firedTarget,
          hit: hit,
          submitted: submitted,
          scoreFor: scoreFor,
          joinedCount: joinedCount,
          myPending: (mySeat >= 0 && mySeat < n && submitted[mySeat])
              ? moves[mySeat]
              : null,
          iSubmitted: iSubmitted && iAmAlive,
          submittedAlive: submittedAlive,
          aliveCount: aliveCount,
          banner: iSubmitted && iAmAlive
              ? '다른 총잡이를 기다리는 중... ($submittedAlive/$aliveCount)'
              : banner,
          status: GameStatus.ongoing,
          winner: null,
          rematchMap: const {},
          quitFn: quit,
          reap: reap.toList()..sort(),
          chars: chars,
          displayChars: displayCharsNow(),
          lateFn: (s) => lateSeat[s] == true,
          healedFx: healedFx,
          evadedFx: evadedFx,
          reflectedFx: reflectedFx,
          smokedFx: smokedFx,
          doubleLoadFx: doubleLoadFx,
          piercedFx: piercedFx,
          resetFx: resetFx,
          abilityUses: abilityUsesNow(),
          curseVictim: pstate.curseVictim,
          curseFuse: pstate.curseFuse,
          myTrapAvailable: mySeat >= 0 &&
              mySeat < n &&
              chars[mySeat] == CharId.hunter &&
              !pstate.trapUsed[mySeat],
          myResetAvailable: mySeat >= 0 &&
              mySeat < n &&
              chars[mySeat] == CharId.resetter &&
              !pstate.resetterUsed[mySeat],
          mySmokeLeft:
              (mySeat >= 0 && mySeat < n) ? pstate.smokeLeft[mySeat] : 0,
          peekActive: peekActive,
          peekerSeat: pkBy,
          peekTargetSeat: pkTarget,
          peekerName: pkBy >= 0 ? (names[pkBy] ?? '카우보이') : '',
          iAmPeeker: iAmPeeker,
          peekedMove: peekedMove,
          peekStale: peekStale,
          myPaparazziUsed:
              mySeat >= 0 && peekUsedMap[slotKey(mySeat)] == true,
        );
      }

      final aliveBefore = List<bool>.from(alive);
      final out = resolvePartyTurn(
        moves: moves,
        ammoBefore: ammo,
        aliveBefore: alive,
        chars: chars,
        state: pstate,
        seed: seed,
        turn: t,
      );
      pstate = out.stateAfter!;
      ammo = out.ammoAfter;
      lastMoves = List<Move?>.from(moves);
      fired = out.fired;
      superFired = out.superFired;
      firedTarget = out.firedTarget;
      hit = out.hit;
      healedFx = out.healed;
      evadedFx = out.evaded;
      reflectedFx = out.reflectKill;
      smokedFx = out.smoked;
      doubleLoadFx = out.doubleLoad;
      piercedFx = out.pierced;
      resetFx = out.resetActive;
      alive = out.aliveAfter;
      // B8: ??? 정체 공개 — 직업 고유 행동/능력이 실제로 발동한 턴.
      for (var s = 0; s < n; s++) {
        if (origChars[s] != CharId.mystery || revealed[s]) continue;
        final mk = moves[s].kind;
        final usedSpecial = mk == ActKind.trap ||
            mk == ActKind.roulette ||
            mk == ActKind.dualShoot ||
            mk == ActKind.voodoo ||
            mk == ActKind.reset;
        if (usedSpecial ||
            out.pierced[s] ||
            out.healed[s] ||
            out.doubleLoad[s] ||
            out.trapSet[s] ||
            out.smoked[s] ||
            out.evaded[s] ||
            out.rouletteFired[s] ||
            out.dualFired[s] ||
            out.voodooCast[s] ||
            out.resetActive[s]) {
          revealed[s] = true;
        }
      }
      banner = _turnBanner(out, names, moves, aliveBefore, seed, t, chars);

      if (out.status != GameStatus.ongoing) {
        var status = out.status;
        var winner = out.winner;
        var specialWin = out.specialWin;
        var drawTurn = -1;
        var drawParticipants = const <int>[];
        if (out.status == GameStatus.draw) {
          // Everyone alive entering the turn fell together — they're the
          // reaction-showdown contestants.
          final parts = [
            for (var s = 0; s < n; s++)
              if (aliveBefore[s]) s
          ];
          final sdWinner = (showdown != null && _asInt(showdown['turn']) == t)
              ? _asInt(showdown['winner'])
              : null;
          // B2: 결투가가 결투 참가자 중 정확히 1명이면 반응속도 없이 자동 승리.
          final duelists = [
            for (final s in parts)
              if (s < chars.length && chars[s] == CharId.duelist) s
          ];
          if (sdWinner != null) {
            status = GameStatus.won;
            winner = sdWinner;
            // They won the reaction duel — bring them back to life so the table
            // shows the victor standing, not a skull next to "승리!".
            if (sdWinner >= 0 && sdWinner < n) {
              alive[sdWinner] = true;
              hit[sdWinner] = false;
            }
          } else if (duelists.length == 1) {
            status = GameStatus.won;
            winner = duelists.first;
            specialWin = 'duelist';
            final w = duelists.first;
            alive[w] = true;
            hit[w] = false;
          } else if (parts.where(present).length == 1) {
            // #5: 결투(showdown) 도중 상대가 나가면 남은 한 명이 승리.
            // (예전엔 떠난 사람을 기다리며 무한 로딩)
            final w = parts.firstWhere(present);
            status = GameStatus.won;
            winner = w;
            alive[w] = true;
            hit[w] = false;
          } else {
            drawTurn = t;
            drawParticipants = parts;
          }
        }
        return _buildView(
          phase: OnlinePhase.over,
          capacity: capacity,
          seatCount: n,
          isHost: isHost,
          iShouldClaimHost: iShouldClaimHost,
          turn: -1,
          mySeat: mySeat,
          names: names,
          presentFn: present,
          ammo: ammo,
          alive: alive,
          lastMoves: lastMoves,
          fired: fired,
          superFired: superFired,
          firedTarget: firedTarget,
          hit: hit,
          submitted: List<bool>.filled(n, false),
          scoreFor: scoreFor,
          joinedCount: joinedCount,
          myPending: null,
          iSubmitted: true,
          submittedAlive: 0,
          aliveCount: alive.where((a) => a).length,
          banner: status == GameStatus.won
              ? (specialWin == 'pacifist'
                  ? (winner == mySeat
                      ? '장전 6회 달성 — 평화의 승리!'
                      : '${names[winner] ?? "카우보이"}, 평화의 승리! (장전 6회)')
                  : specialWin == 'duelist'
                      ? (winner == mySeat
                          ? '1:1 결투 — 결투가의 즉시 승리!'
                          : '${names[winner] ?? "카우보이"}, 결투가의 즉시 승리!')
                      : (winner == mySeat
                          ? '최후의 1인! 승리!'
                          : (winner != null && !present(winner)
                              // The winner already left the room — don't degrade
                              // their banner; show they're gone.
                              ? '${leftName(winner) ?? "상대"} 님이 나갔어요'
                              : '${names[winner] ?? "카우보이"} 승리!')))
              : '모두 쓰러졌다!',
          status: status,
          winner: winner,
          rematchMap: rematchMap,
          quitFn: quit,
          reap: reap.toList()..sort(),
          drawTurn: drawTurn,
          drawParticipants: drawParticipants,
          chars: chars,
          displayChars: displayCharsNow(),
          lateFn: (s) => lateSeat[s] == true,
          healedFx: healedFx,
          evadedFx: evadedFx,
          reflectedFx: reflectedFx,
          smokedFx: smokedFx,
          doubleLoadFx: doubleLoadFx,
          piercedFx: piercedFx,
          resetFx: resetFx,
          abilityUses: abilityUsesNow(),
          curseVictim: pstate.curseVictim,
          curseFuse: pstate.curseFuse,
          curseKillFx: out.curseKill,
          specialWin: specialWin,
        );
      }
      t++;
    }
  }

  static RoomView _buildView({
    required OnlinePhase phase,
    required int capacity,
    required int seatCount,
    required bool isHost,
    bool iShouldClaimHost = false,
    required int turn,
    required int mySeat,
    required Map<int, String> names,
    required bool Function(int) presentFn,
    required List<int> ammo,
    required List<bool> alive,
    required List<Move?> lastMoves,
    required List<bool> fired,
    required List<bool> superFired,
    required List<int> firedTarget,
    required List<bool> hit,
    required List<bool> submitted,
    required int Function(int) scoreFor,
    required int joinedCount,
    required Move? myPending,
    required bool iSubmitted,
    required int submittedAlive,
    required int aliveCount,
    required String banner,
    required GameStatus status,
    required int? winner,
    required Map rematchMap,
    required bool Function(int) quitFn,
    List<int> reap = const [],
    int drawTurn = -1,
    List<int> drawParticipants = const [],
    List<CharId> chars = const [],
    List<CharId> displayChars = const [],
    int curseVictim = -1,
    int curseFuse = 0,
    List<bool> curseKillFx = const [],
    bool Function(int)? lateFn,
    List<bool> healedFx = const [],
    List<bool> evadedFx = const [],
    List<bool> reflectedFx = const [],
    List<bool> smokedFx = const [],
    List<bool> doubleLoadFx = const [],
    List<bool> piercedFx = const [],
    List<bool> resetFx = const [],
    List<String?> abilityUses = const [],
    String? specialWin,
    bool myTrapAvailable = false,
    bool myResetAvailable = false,
    int mySmokeLeft = 0,
    bool peekActive = false,
    int peekerSeat = -1,
    int peekTargetSeat = -1,
    String peekerName = '',
    bool iAmPeeker = false,
    Move? peekedMove,
    bool peekStale = false,
    bool myPaparazziUsed = false,
  }) {
    bool fx(List<bool> l, int s) => s < l.length && l[s];
    bool late(int s) => lateFn != null && lateFn(s);
    bool shotAt(int s) => firedTarget.contains(s);
    // 그림자: 내가 아닌 그림자 좌석은 탄약을 가리고, 장전/방어/가만히 행동을 가린다.
    // 단 방어했는데 빵야를 당했다면 그 방어는 드러난다.
    bool isShadowHidden(int s) {
      if (s == mySeat) return false;
      if (s >= chars.length || chars[s] != CharId.shadow) return false;
      return true;
    }
    bool hideActFor(int s) {
      if (!isShadowHidden(s)) return false;
      final m = lastMoves[s];
      if (m == null) return false;
      final passive = m.kind == ActKind.reload ||
          m.kind == ActKind.defend ||
          m.kind == ActKind.idle;
      if (!passive) return false; // 공격 행동은 드러남
      if (m.kind == ActKind.defend && shotAt(s)) return false; // 막은 게 보임
      return true;
    }
    final seats = <SeatView>[
      for (var s = 0; s < seatCount; s++)
        SeatView(
          seat: s,
          joined: presentFn(s),
          name: names[s] ?? '카우보이',
          ammo: ammo[s],
          alive: alive[s],
          isMe: s == mySeat,
          lastMove: lastMoves[s],
          fired: fired[s],
          superFired: superFired[s],
          firedTarget: firedTarget[s],
          hitThisTurn: hit[s],
          submittedThisTurn: submitted[s],
          score: scoreFor(s),
          char: s < displayChars.length
              ? displayChars[s]
              : (s < chars.length ? chars[s] : CharId.none),
          healedFx: fx(healedFx, s),
          evadedFx: fx(evadedFx, s),
          reflectedFx: fx(reflectedFx, s),
          smokedFx: fx(smokedFx, s),
          doubleLoadFx: fx(doubleLoadFx, s),
          piercedFx: fx(piercedFx, s),
          resetFx: fx(resetFx, s),
          abilityUses: s < abilityUses.length ? abilityUses[s] : null,
          curseKillFx: fx(curseKillFx, s),
          curseTurnsLeft: s == curseVictim ? curseFuse : 0,
          late: late(s),
          hideAmmo: isShadowHidden(s),
          hideAction: hideActFor(s),
        ),
    ];
    final presentCount = [
      for (var s = 0; s < seatCount; s++)
        if (presentFn(s)) s
    ].length;
    var rematchCount = 0;
    var iRematch = false;
    for (var s = 0; s < seatCount; s++) {
      if (rematchMap[slotKey(s)] == true) {
        rematchCount++;
        if (s == mySeat) iRematch = true;
      }
    }
    final iAmOut = mySeat < 0 || mySeat >= seatCount || quitFn(mySeat);
    final iAmLate =
        mySeat >= 0 && mySeat < seatCount && late(mySeat) && !iAmOut;
    return RoomView(
      capacity: capacity,
      seatCount: seatCount,
      started: true,
      isHost: isHost,
      iShouldClaimHost: iShouldClaimHost,
      phase: phase,
      turn: turn,
      mySeat: mySeat,
      seats: seats,
      joinedCount: joinedCount,
      presentCount: presentCount,
      canStart: false,
      myPending: myPending,
      iSubmitted: iSubmitted,
      submittedAlive: submittedAlive,
      aliveCount: aliveCount,
      status: status,
      winnerSeat: winner,
      banner: banner,
      justResolved: phase == OnlinePhase.over,
      iRequestedRematch: iRematch,
      rematchCount: rematchCount,
      reapSeats: reap,
      iAmOut: iAmOut,
      iAmLate: iAmLate,
      myTrapAvailable: myTrapAvailable,
      myResetAvailable: myResetAvailable,
      mySmokeLeft: mySmokeLeft,
      specialWin: specialWin,
      peekActive: peekActive,
      peekerSeat: peekerSeat,
      peekTargetSeat: peekTargetSeat,
      peekerName: peekerName,
      iAmPeeker: iAmPeeker,
      peekedMove: peekedMove,
      peekStale: peekStale,
      myPaparazziUsed: myPaparazziUsed,
      drawTurn: drawTurn,
      drawParticipants: drawParticipants,
    );
  }

  static String _turnBanner(TurnOutcome out, Map<int, String> names,
      List<Move> moves, List<bool> aliveBefore, String seed, int turn,
      List<CharId> chars) {
    String nameOf(int s) => names[s] ?? '카우보이';
    bool isShadow(int s) => s < chars.length && chars[s] == CharId.shadow;
    // #10: 그림자가 살아 있으면 '둘 다 장전/방어' 같은 멘트로 행동이 유추되지 않게
    // 구체적 표현을 숨긴다(가만히 멘트도 그림자는 이름 노출 안 함).
    final shadowAlive = [
      for (var s = 0; s < aliveBefore.length; s++)
        if (aliveBefore[s] && isShadow(s)) s
    ].isNotEmpty;
    // 캐릭터 능력이 만든 드라마가 우선 — 평범한 결과 문구에 묻히지 않게.
    final reflected = <String>[
      for (var s = 0; s < out.reflectKill.length; s++)
        if (out.reflectKill[s]) nameOf(s)
    ];
    if (reflected.isNotEmpty) return '덫 발동! ${reflected.join(", ")} 반사 명중!';
    final cursed = <String>[
      for (var s = 0; s < out.curseKill.length; s++)
        if (out.curseKill[s]) nameOf(s)
    ];
    if (cursed.isNotEmpty) return '저주 발동! ${cursed.join(", ")} 쓰러졌다!';
    final voodooCasters = <String>[
      for (var s = 0; s < out.voodooCast.length; s++)
        if (out.voodooCast[s]) nameOf(s)
    ];
    final roulette = out.rouletteFired.any((x) => x);
    final healed = <String>[
      for (var s = 0; s < out.healed.length; s++)
        if (out.healed[s]) nameOf(s)
    ];
    final downed = <String>[
      for (var s = 0; s < out.hit.length; s++)
        if (out.hit[s]) nameOf(s)
    ];
    if (healed.isNotEmpty && downed.isEmpty) {
      return '${healed.join(", ")}, 의사의 자힐로 버텼다!';
    }
    if (roulette && downed.isNotEmpty) {
      return '운명의 방아쇠! ${downed.join(", ")} 쓰러졌다!';
    }
    if (downed.isNotEmpty) return '${downed.join(", ")} 명중!';
    if (voodooCasters.isNotEmpty) {
      return '${voodooCasters.join(", ")}, 저주를 걸었다... ($kCurseFuse턴)';
    }
    final evaded = <String>[
      for (var s = 0; s < out.evaded.length; s++)
        if (out.evaded[s]) nameOf(s)
    ];
    if (evaded.isNotEmpty) return '${evaded.join(", ")}, 연막으로 회피!';
    if (out.fired.any((x) => x)) return '모두 막거나 빗나갔다!';
    // 시간초과(가만히) 멘트 — 모두가 가만히면 한 명을 골라 보여준다.
    final idlers = <int>[
      for (var s = 0; s < moves.length; s++)
        if (s < aliveBefore.length &&
            aliveBefore[s] &&
            moves[s].kind == ActKind.idle)
          s
    ];
    // 그림자가 아닌 idler만 이름을 노출(그림자 idle은 숨김).
    final visibleIdler = idlers.where((s) => !isShadow(s)).toList();
    if (visibleIdler.isNotEmpty) {
      final s = visibleIdler.first;
      return '${nameOf(s)}, ${idleFlavor(seed, turn, s)}...';
    }
    if (shadowAlive) return '조용한 한 턴이 지나갔다...';
    return _quietBanner(moves, aliveBefore);
  }

  /// Nobody fired this turn — describe what the living cowboys actually did so
  /// "둘 다 방어" / "둘 다 장전" read true instead of a generic mixed message.
  static String _quietBanner(List<Move> moves, List<bool> aliveBefore) {
    final kinds = <ActKind>[
      for (var s = 0; s < moves.length; s++)
        if (s < aliveBefore.length && aliveBefore[s]) moves[s].kind
    ];
    final all = kinds.length <= 2 ? '둘 다' : '모두';
    if (kinds.isNotEmpty && kinds.every((k) => k == ActKind.defend)) {
      return '$all 방어! 다음 턴';
    }
    if (kinds.isNotEmpty && kinds.every((k) => k == ActKind.reload)) {
      return '$all 장전! 다음 턴';
    }
    return '장전과 방어... 다음 턴!';
  }
}
