import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// 로그인 상태.
enum AuthState { localGuest, anonymous, google }

/// Google + 게스트 로그인. **콘솔에서 Authentication이 아직 활성화되지 않아도
/// 앱은 절대 깨지지 않는다** — 모든 실패는 로컬 게스트(기기 고정 ID)로 폴백.
/// 랭킹 등록 같은 서버 기능만 로그인 시 열린다.
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService I = AuthService._();

  User? _user;
  String _localGuestId = '';
  String? lastError;

  AuthState get state {
    final u = _user;
    if (u == null) return AuthState.localGuest;
    return u.isAnonymous ? AuthState.anonymous : AuthState.google;
  }

  /// 실제 클라우드 계정(Google 또는 Apple)으로 로그인된 상태인지.
  /// (랭킹 등록·기기 간 연동의 게이트. 이름은 호환을 위해 유지.)
  bool get isGoogle => state == AuthState.google;

  /// 'Apple로 로그인' 버튼을 보여줄 플랫폼인지(iOS/macOS/웹). Apple은 다른
  /// 소셜 로그인을 제공하면 Apple 로그인도 필수(App Store 4.8).
  bool get showAppleButton =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// 서버 기록에 쓸 수 있는 uid (Firebase Auth 로그인 시에만).
  String? get cloudUid => _user?.uid;

  /// 항상 존재하는 식별자 — 로그인 전엔 기기 고정 게스트 ID.
  String get uid => _user?.uid ?? _localGuestId;

  String? get displayName => _user?.displayName;
  String? get photoUrl => _user?.photoURL;

  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    var g = sp.getString('guest_id');
    if (g == null) {
      const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
      final r = Random();
      g = 'g${List.generate(12, (_) => chars[r.nextInt(chars.length)]).join()}';
      await sp.setString('guest_id', g);
    }
    _localGuestId = g;
    try {
      FirebaseAuth.instance.authStateChanges().listen((u) {
        _user = u;
        notifyListeners();
      });
      _user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      // Firebase 자체가 없는 환경(테스트 등) — 로컬 게스트로 동작.
    }
    notifyListeners();
  }

  /// Google 로그인. 성공 true. 실패 시 lastError에 사람이 읽을 메시지.
  Future<bool> signInWithGoogle() async {
    lastError = null;
    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      } else {
        // serverClientId(웹 클라이언트)를 명시해야 Android에서 Firebase용 idToken이
        // 확실히 발급된다. 없으면 계정 선택 뒤 토큰 교환이 조용히 실패(→게스트)할 수 있다.
        final g = await GoogleSignIn(
          scopes: const ['email'],
          serverClientId:
              '162098390378-s2ad0lmi20u81aq3slp4lv581o06oh29.apps.googleusercontent.com',
        ).signIn();
        if (g == null) {
          lastError = '로그인이 취소됐어요';
          return false;
        }
        final auth = await g.authentication;
        await FirebaseAuth.instance.signInWithCredential(
          GoogleAuthProvider.credential(
            idToken: auth.idToken,
            accessToken: auth.accessToken,
          ),
        );
      }
      return true;
    } on FirebaseAuthException catch (e) {
      lastError = switch (e.code) {
        'operation-not-allowed' =>
          '아직 서버에 Google 로그인이 준비 중이에요. 게스트로 플레이해 주세요!',
        'popup-closed-by-user' => '로그인이 취소됐어요',
        'network-request-failed' => '네트워크를 확인해 주세요',
        // 원인 파악용: code + message를 그대로 노출(예: unknown 뒤 실제 사유).
        _ => '로그인 실패 (${e.code}'
            '${(e.message != null && e.message!.isNotEmpty) ? ' · ${e.message}' : ''})',
      };
      return false;
    } catch (e) {
      // google_sign_in의 PlatformException(sign_in_failed, ApiException: 10 등)이
      // 여기로 온다 — 삼키지 말고 실제 내용을 보여줘 원인을 좁힌다.
      lastError = '로그인 실패: $e';
      return false;
    }
  }

  /// Apple로 로그인. 성공 true. iOS/macOS/웹에서 동작.
  /// **Firebase 콘솔에 Apple 공급자가 켜져 있어야 실제로 작동** — 꺼져 있으면
  /// operation-not-allowed로 안내 후 게스트 유지(앱은 안 깨짐).
  Future<bool> signInWithApple() async {
    lastError = null;
    try {
      if (kIsWeb) {
        final provider = OAuthProvider('apple.com')
          ..addScope('email')
          ..addScope('name');
        await FirebaseAuth.instance.signInWithPopup(provider);
        return true;
      }
      // 네이티브: nonce로 리플레이 공격 방지(Apple → Firebase 표준 절차).
      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
      final cred = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      final oauth = OAuthProvider('apple.com').credential(
        idToken: cred.identityToken,
        rawNonce: rawNonce,
      );
      await FirebaseAuth.instance.signInWithCredential(oauth);
      // Apple은 첫 로그인에만 이름을 준다 — displayName이 비어 있으면 채운다.
      final name = [cred.givenName, cred.familyName]
          .where((e) => e != null && e.isNotEmpty)
          .join(' ');
      final u = FirebaseAuth.instance.currentUser;
      if (name.isNotEmpty && (u?.displayName == null || u!.displayName!.isEmpty)) {
        await u?.updateDisplayName(name);
      }
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      lastError = e.code == AuthorizationErrorCode.canceled
          ? '로그인이 취소됐어요'
          : 'Apple 로그인 실패';
      return false;
    } on FirebaseAuthException catch (e) {
      lastError = switch (e.code) {
        'operation-not-allowed' =>
          '아직 서버에 Apple 로그인이 준비 중이에요. 게스트로 플레이해 주세요!',
        'network-request-failed' => '네트워크를 확인해 주세요',
        _ => '로그인 실패 (${e.code})',
      };
      return false;
    } catch (_) {
      lastError = '로그인 실패 — 잠시 후 다시 시도해 주세요';
      return false;
    }
  }

  /// Apple 로그인 nonce 생성용 랜덤 문자열.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final r = Random.secure();
    return List.generate(length, (_) => charset[r.nextInt(charset.length)])
        .join();
  }

  /// 익명(게스트) 로그인 — 콘솔에서 익명 제공자가 켜져 있으면 cloudUid가 생겨
  /// 랭킹 등록이 가능해진다. 꺼져 있으면 조용히 로컬 게스트 유지.
  Future<void> tryAnonymous() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (_) {}
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!kIsWeb) await GoogleSignIn().signOut();
    } catch (_) {}
  }
}
