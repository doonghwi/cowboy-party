import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/characters.dart';
import '../online/online_service.dart' show OnlineService;
import 'auth_service.dart';
import 'gift_codes.dart';

/// 일일 출석 보상 사이클 (7일).
const List<int> kDailyCycle = [20, 20, 30, 30, 40, 40, 60];

/// 승리 보상: 30 + (인원-2)×8  → 2인 30 ~ 6인 62. 참가 보상 5.
int winCoins(int players) => 30 + (players.clamp(2, 6) - 2) * 8;
const int kPlayCoins = 5;

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

  int get coins => _coins;
  String get nickname => _nickname;
  int get dailyStreak => _dailyStreak;
  int get seasonPtsLocal => _seasonPtsLocal;

  CharId get equipped => charFromIndex(_equipped);
  int get equippedIndex => _equipped;

  Future<void> init() async {
    if (_sp != null) return;
    final sp = await SharedPreferences.getInstance();
    _sp = sp;
    _coins = sp.getInt('coins') ?? 0;
    _unlocked = (sp.getStringList('unlocked') ?? [])
        .map(int.parse)
        .toSet();
    // 기본 제공 캐릭터(cost==0)는 항상 해금.
    for (final c in kCharacters) {
      if (c.cost == 0) _unlocked.add(c.id.index);
    }
    _equipped = sp.getInt('equipped') ?? CharId.prepper.index;
    _dailyLast = sp.getString('daily_last') ?? '';
    _dailyStreak = sp.getInt('daily_streak') ?? 0;
    _seasonPtsLocal = sp.getInt('season_pts_local') ?? 0;
    _nickname = sp.getString('nickname') ?? '';
    _redeemed = (sp.getStringList('redeemed') ?? []).toSet();
    notifyListeners();
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
    _mirrorToCloud();
  }

  void setNickname(String n) {
    _nickname = n.trim();
    _save();
    notifyListeners();
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
