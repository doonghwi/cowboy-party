import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/characters.dart';
import '../online/online_service.dart' show OnlineService;
import 'auth_service.dart';
import 'gift_codes.dart';
import 'profanity.dart';
import 'season_service.dart';

/// 일일 출석 보상 사이클 (7일). (#9: 상향)
const List<int> kDailyCycle = [100, 100, 150, 150, 200, 200, 400];

/// 승리 보상: 80 + (인원-2)×15 → 2인 80 ~ 6인 140. 참가 보상 30. (#9: 상향)
/// LoL/배그처럼 "플레이 자체"와 "데일리 미션"으로 통화가 의미있게 쌓이게 한다.
int winCoins(int players) => 80 + (players.clamp(2, 6) - 2) * 15;
const int kPlayCoins = 30;

/// 데일리 미션(매일 0시 리셋). key → (목표 판수 또는 승수, 보상, 라벨, 승리미션 여부).
/// 활동 유저 하루 합계 ≈ 1,250골드 + 판당 보상 → 중간 캐릭터 며칠, 최고가 1~2주.
class DailyMission {
  final String key;
  final int need; // 필요 횟수
  final int gold;
  final String label;
  final bool winMission; // true면 승수, false면 플레이 판수
  const DailyMission(this.key, this.need, this.gold, this.label,
      {this.winMission = false});
}

const List<DailyMission> kDailyMissions = [
  DailyMission('play1', 1, 100, '오늘 1판 플레이'),
  DailyMission('firstwin', 1, 300, '오늘 첫 승리', winMission: true),
  DailyMission('play3', 3, 250, '오늘 3판 플레이'),
  DailyMission('play5', 5, 600, '오늘 5판 플레이'),
];

/// 닉네임 변경권 가격(G2). 첫 닉네임 설정은 무료, 이후 변경은 변경권 소모.
const int kNicknameTicketCost = 10000;

/// 닉네임 변경 사전 판정 결과.
enum NicknameChangeGate { empty, unchanged, needTicket, proceed }

/// 닉네임 변경을 **진행해도 되는지** 순수 판정(네트워크 이전).
/// 전역 유일성 점유([OnlineService.claimNickname])는 부작용으로 **예전 닉네임을
/// 해제**하므로, 변경권이 없는데 점유부터 하면 내 현재 이름이 풀려 남이 가로채는
/// 버그가 생긴다 → 점유 **전에** 이 게이트로 거른다.
NicknameChangeGate nicknameChangeGate({
  required String requested,
  required String current,
  required bool nicknameSet,
  required int tickets,
}) {
  final n = requested.trim();
  if (n.isEmpty) return NicknameChangeGate.empty;
  if (n == current) return NicknameChangeGate.unchanged;
  if (nicknameSet && tickets <= 0) return NicknameChangeGate.needTicket;
  return NicknameChangeGate.proceed;
}

/// 신규 계정 시작 골드(G4).
const int kNewAccountGold = 5000;

/// 코인·캐릭터 해금·장착·출석 — 로컬 우선(SharedPreferences), 로그인 시
/// /users/$uid 로 미러(기기 간 이동). 서버 실패는 전부 조용히 무시:
/// 게임은 메타 서버 없이도 완전히 동작해야 한다.
class Meta extends ChangeNotifier {
  Meta._();
  static final Meta I = Meta._();

  SharedPreferences? _sp;
  bool get ready => _sp != null;

  int _coins = 0;
  Set<int> _unlocked = {};
  int _equipped = 0; // CharId index
  String _dailyLast = '';
  int _dailyStreak = 0;
  int _seasonPtsLocal = 0;
  String _nickname = '';
  Set<String> _redeemed = {}; // 사용한 선물 코드(계정당 1회)
  int _nicknameTickets = 0; // 닉네임 변경권 보유 수(G2)
  // 데일리 미션 진행(매일 리셋) (#9)
  String _dDay = '';
  int _dGames = 0;
  int _dWins = 0;
  Set<String> _dClaimed = {};
  bool _nicknameSet = false; // 첫 닉네임 설정 여부(첫 설정은 무료)

  int get coins => _coins;
  String get nickname => _nickname;
  int get nicknameTickets => _nicknameTickets;
  bool get nicknameSet => _nicknameSet;
  bool get canChangeNicknameFree => !_nicknameSet;
  int get dailyStreak => _dailyStreak;
  int get seasonPtsLocal => _seasonPtsLocal;

  CharId get equipped => charFromIndex(_equipped);
  int get equippedIndex => _equipped;

  Future<void> init() async {
    if (_sp != null) return;
    final sp = await SharedPreferences.getInstance();
    _sp = sp;
    // G4: 신규 계정(코인 기록 없음)에 시작 골드 지급.
    final brandNew = !sp.containsKey('coins');
    _coins = sp.getInt('coins') ?? kNewAccountGold;
    _unlocked = (sp.getStringList('unlocked') ?? [])
        .map(int.parse)
        .toSet();
    // 기본 제공 캐릭터(cost==0)는 항상 해금.
    for (final c in kCharacters) {
      if (c.cost == 0) _unlocked.add(c.id.index);
    }
    // B4: 기본 장착은 무료 기본 캐릭터(일반인). 기존 사용자는 저장값 유지.
    _equipped = sp.getInt('equipped') ?? CharId.commoner.index;
    // 안전장치: 보유하지 않은 캐릭터가 장착돼 있으면 일반인으로.
    if (!_unlocked.contains(_equipped)) _equipped = CharId.commoner.index;
    _dailyLast = sp.getString('daily_last') ?? '';
    _dailyStreak = sp.getInt('daily_streak') ?? 0;
    _seasonPtsLocal = sp.getInt('season_pts_local') ?? 0;
    _nickname = sp.getString('nickname') ?? '';
    _redeemed = (sp.getStringList('redeemed') ?? []).toSet();
    _nicknameTickets = sp.getInt('nick_tickets') ?? 0;
    _nicknameSet = sp.getBool('nick_set') ?? _nickname.isNotEmpty;
    _dDay = sp.getString('d_day') ?? '';
    _dGames = sp.getInt('d_games') ?? 0;
    _dWins = sp.getInt('d_wins') ?? 0;
    _dClaimed = (sp.getStringList('d_claimed') ?? []).toSet();
    _rollDailyMissions(); // 날짜 바뀌었으면 리셋
    if (brandNew) _save();
    notifyListeners();
  }

  /// 날짜가 바뀌면 데일리 미션 진행을 리셋한다.
  void _rollDailyMissions() {
    final today = _today();
    if (_dDay != today) {
      _dDay = today;
      _dGames = 0;
      _dWins = 0;
      _dClaimed = {};
    }
  }

  Future<void> _save() async {
    final sp = _sp;
    if (sp == null) return;
    await sp.setInt('coins', _coins);
    await sp.setStringList(
        'unlocked', _unlocked.map((e) => e.toString()).toList());
    await sp.setInt('equipped', _equipped);
    await sp.setString('daily_last', _dailyLast);
    await sp.setInt('daily_streak', _dailyStreak);
    await sp.setInt('season_pts_local', _seasonPtsLocal);
    await sp.setString('nickname', _nickname);
    await sp.setStringList('redeemed', _redeemed.toList());
    await sp.setInt('nick_tickets', _nicknameTickets);
    await sp.setBool('nick_set', _nicknameSet);
    await sp.setString('d_day', _dDay);
    await sp.setInt('d_games', _dGames);
    await sp.setInt('d_wins', _dWins);
    await sp.setStringList('d_claimed', _dClaimed.toList());
    _mirrorToCloud();
  }

  // ── 데일리 미션 (#9) ──────────────────────────────────────────────────
  int get dailyGames => _dGames;
  int get dailyWins => _dWins;
  bool missionClaimed(DailyMission m) => _dClaimed.contains(m.key);
  int missionProgress(DailyMission m) => m.winMission ? _dWins : _dGames;

  /// 게임 1판 종료 시 호출(온/오프 공통). 데일리 카운트를 올리고, 새로 달성한
  /// 미션 보상을 즉시 지급한다. 반환: 이번에 달성한 미션 목록(토스트용).
  List<DailyMission> noteGamePlayed({required bool won}) {
    _rollDailyMissions();
    _dGames += 1;
    if (won) _dWins += 1;
    final newly = <DailyMission>[];
    for (final m in kDailyMissions) {
      if (_dClaimed.contains(m.key)) continue;
      if (missionProgress(m) >= m.need) {
        _dClaimed.add(m.key);
        _coins += m.gold;
        newly.add(m);
      }
    }
    _save();
    notifyListeners();
    return newly;
  }

  /// 저수준 닉네임 설정 — 첫 진입/로비에서 직접 정할 때만 사용(첫 설정 무료).
  /// 설정 탭의 '변경'은 [changeNickname](변경권 게이트)을 쓴다.
  void setNickname(String n) {
    final t = n.trim();
    if (t.isEmpty || Profanity.I.isProfane(t)) return; // 비속어 차단(#1)
    _nickname = t;
    _nicknameSet = true;
    _save();
    SeasonService.I.updateName(t); // 랭킹 표시 이름도 동기화(있으면)
    notifyListeners();
  }

  /// 닉네임 변경권 구매(G2). 성공 시 true.
  bool buyNicknameTicket() {
    if (!trySpend(kNicknameTicketCost)) return false;
    _nicknameTickets += 1;
    _save();
    notifyListeners();
    return true;
  }

  /// 닉네임 설정/변경(G2). 첫 설정은 무료, 이후 변경은 변경권 소모.
  /// 닉네임은 **전역 유일** — 이미 존재하면 거절(변경권도 소모 안 함).
  /// 반환: (ok, message).
  Future<({bool ok, String message})> changeNickname(String raw) async {
    final n = raw.trim();
    // 변경권 게이트를 **전역 점유 이전에** 적용 — 권한이 없으면 닉네임 레지스트리를
    // 절대 건드리지 않는다(예전 이름이 풀려 남이 가로채는 버그 방지).
    switch (nicknameChangeGate(
      requested: raw,
      current: _nickname,
      nicknameSet: _nicknameSet,
      tickets: _nicknameTickets,
    )) {
      case NicknameChangeGate.empty:
        return (ok: false, message: '닉네임을 입력해 주세요');
      case NicknameChangeGate.unchanged:
        return (ok: false, message: '같은 닉네임이에요');
      case NicknameChangeGate.needTicket:
        return (ok: false, message: '닉네임 변경권이 필요해요 (상점에서 구매)');
      case NicknameChangeGate.proceed:
        break;
    }
    await Profanity.I.init(); // 비속어 목록 로드 보장(이미 로드됐으면 즉시 반환)
    if (Profanity.I.isProfane(n)) {
      return (ok: false, message: '닉네임에 부적절한 표현이 있어요');
    }
    // 유일성 확보 — 이미 쓰는 사람이 있으면 여기서 거절(자원 소모 전).
    final claimed = await OnlineService().claimNickname(n, previous: _nickname);
    if (!claimed) {
      return (ok: false, message: '이미 존재하는 닉네임이에요');
    }
    if (!_nicknameSet) {
      _nickname = n;
      _nicknameSet = true;
      _save();
      SeasonService.I.updateName(n);
      notifyListeners();
      return (ok: true, message: '닉네임을 정했어요!');
    }
    _nicknameTickets -= 1;
    _nickname = n;
    _save();
    SeasonService.I.updateName(n); // 랭킹 표시 이름 동기화
    notifyListeners();
    return (ok: true, message: '닉네임을 변경했어요 (변경권 1장 사용)');
  }

  // ---- 코인 ---------------------------------------------------------------

  void addCoins(int n) {
    if (n <= 0) return;
    _coins += n;
    _save();
    notifyListeners();
  }

  bool trySpend(int n) {
    if (_coins < n) return false;
    _coins -= n;
    _save();
    notifyListeners();
    return true;
  }

  // ---- 선물 코드 ----------------------------------------------------------

  bool hasRedeemed(String code) => _redeemed.contains(normalizeGiftCode(code));

  /// 선물 코드 사용. 계정당 1회. 공용 코드는 [kGiftCodes], 단일 코드는 RTDB
  /// `/giftcodes/<code>`(선착순 점유). 골드 지급.
  Future<({bool ok, String message, int gold})> redeemGiftCode(
      String raw) async {
    final code = normalizeGiftCode(raw);
    if (code.isEmpty) {
      return (ok: false, message: '코드를 입력해 주세요', gold: 0);
    }
    if (_redeemed.contains(code)) {
      return (ok: false, message: '이미 사용한 코드예요', gold: 0);
    }
    GiftCode? def = kGiftCodes[code] ?? await _fetchGiftCodeFromCloud(code);
    if (def == null) {
      return (ok: false, message: '없는 코드예요', gold: 0);
    }
    if (def.single) {
      final claimed = await _claimSingleUse(code);
      if (!claimed) {
        return (ok: false, message: '이미 누군가 사용한 코드예요', gold: 0);
      }
    }
    _redeemed.add(code);
    addCoins(def.gold); // _save 포함
    return (ok: true, message: '+${def.gold} 골드 획득!', gold: def.gold);
  }

  DatabaseReference? _giftRef(String code) {
    try {
      return FirebaseDatabase.instanceFor(
              app: Firebase.app(), databaseURL: OnlineService.databaseUrl)
          .ref('giftcodes/$code');
    } catch (_) {
      return null;
    }
  }

  Future<GiftCode?> _fetchGiftCodeFromCloud(String code) async {
    final ref = _giftRef(code);
    if (ref == null) return null;
    try {
      final snap = await ref.get();
      final v = snap.value;
      if (v is! Map) return null;
      final gold = v['gold'];
      if (gold is! int) return null;
      return GiftCode(gold: gold, single: v['single'] == true);
    } catch (_) {
      return null;
    }
  }

  /// 단일 코드 선착순 점유. 비어 있으면 내 id로 점유 성공, 아니면 실패.
  Future<bool> _claimSingleUse(String code) async {
    final ref = _giftRef(code);
    if (ref == null) return false;
    final id = AuthService.I.uid; // 로그인 uid 또는 기기 게스트 id
    try {
      final res = await ref.child('claimedBy').runTransaction((cur) {
        if (cur == null || cur == id) return Transaction.success(id);
        return Transaction.abort();
      });
      return res.committed && res.snapshot.value == id;
    } catch (_) {
      return false;
    }
  }

  // ---- 캐릭터 -------------------------------------------------------------

  bool isUnlocked(CharId c) => _unlocked.contains(c.index);

  /// ??? 구매 전제: ??? 외 모든 캐릭터를 이미 보유.
  /// (한번 사면 이후 새 캐릭터가 추가돼도 보유는 유지 — _unlocked는 영구.)
  bool get canBuyMystery => kCharacters
      .where((c) => c.id != CharId.mystery)
      .every((c) => isUnlocked(c.id));

  /// 코인으로 해금. 성공 시 true. 실패 사유 없이 false.
  bool unlock(CharId c) {
    if (isUnlocked(c)) return true;
    if (c == CharId.mystery && !canBuyMystery) return false; // 전 캐릭터 보유 필요
    final def = charDef(c);
    if (!trySpend(def.cost)) return false;
    _unlocked.add(c.index);
    _save();
    notifyListeners();
    return true;
  }

  void equip(CharId c) {
    if (!isUnlocked(c)) return;
    _equipped = c.index;
    _save();
    notifyListeners();
  }

  // ---- 데일리 출석 ----------------------------------------------------------

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  bool get canClaimDaily => _dailyLast != _today();

  /// 오늘 보상 수령. 반환: 받은 코인 (이미 받았으면 0).
  int claimDaily() {
    final today = _today();
    if (_dailyLast == today) return 0;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yKey =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    _dailyStreak = (_dailyLast == yKey) ? _dailyStreak + 1 : 1;
    _dailyLast = today;
    final amount = kDailyCycle[(_dailyStreak - 1) % kDailyCycle.length];
    _coins += amount;
    _save();
    notifyListeners();
    return amount;
  }

  /// 오늘이 사이클 며칠째인지 (1~7, 수령 전 기준).
  int get dailyCycleDay {
    if (canClaimDaily) {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yKey =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      final next = (_dailyLast == yKey) ? _dailyStreak + 1 : 1;
      return ((next - 1) % kDailyCycle.length) + 1;
    }
    return ((_dailyStreak - 1) % kDailyCycle.length) + 1;
  }

  // ---- 게임 보상 ------------------------------------------------------------

  /// 온라인 승리 시 1회 호출.
  int grantWin(int players) {
    final c = winCoins(players);
    addCoins(c);
    _seasonPtsLocal += 10 * (players.clamp(2, 6) - 1);
    _save();
    return c;
  }

  /// 온라인 패배/완주 시 1회 호출.
  int grantPlay() {
    addCoins(kPlayCoins);
    return kPlayCoins;
  }

  // ---- 클라우드 미러 (로그인 시) ---------------------------------------------

  DatabaseReference? get _userRef {
    final uid = AuthService.I.cloudUid;
    if (uid == null) return null;
    try {
      return FirebaseDatabase.instanceFor(
              app: Firebase.app(), databaseURL: OnlineService.databaseUrl)
          .ref('users/$uid');
    } catch (_) {
      return null;
    }
  }

  void _mirrorToCloud() {
    final ref = _userRef;
    if (ref == null) return;
    ref.update({
      'name': _nickname.isEmpty ? (AuthService.I.displayName ?? '카우보이') : _nickname,
      'coins': _coins,
      'unlocked': _unlocked.toList()..sort(),
      'equipped': _equipped,
      'dailyLast': _dailyLast,
      'dailyStreak': _dailyStreak,
      'redeemed': _redeemed.toList(),
      'updatedAt': ServerValue.timestamp,
    }).catchError((_) {});
  }

  /// 로그인 직후: 클라우드와 로컬을 너그럽게 병합 (코인 max, 해금 union).
  Future<void> mergeFromCloud() async {
    final ref = _userRef;
    if (ref == null) return;
    try {
      final snap = await ref.get();
      final v = snap.value;
      if (v is! Map) {
        _mirrorToCloud();
        return;
      }
      final cloud = jsonDecode(jsonEncode(v)) as Map;
      final cCoins = cloud['coins'];
      if (cCoins is int && cCoins > _coins) _coins = cCoins;
      final cUnlocked = cloud['unlocked'];
      if (cUnlocked is List) {
        for (final e in cUnlocked) {
          if (e is int) _unlocked.add(e);
        }
      }
      final cRedeemed = cloud['redeemed'];
      if (cRedeemed is List) {
        for (final e in cRedeemed) {
          if (e is String) _redeemed.add(e);
        }
      }
      final cStreak = cloud['dailyStreak'];
      final cLast = cloud['dailyLast'];
      if (cStreak is int && cLast is String && cLast.compareTo(_dailyLast) > 0) {
        _dailyStreak = cStreak;
        _dailyLast = cLast;
      }
      await _save();
      notifyListeners();
    } catch (_) {}
  }
}
