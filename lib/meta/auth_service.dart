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

  /// 'Apple로 로그인' 버튼을 보여줄 플랫폼인지(iOS/macOS). Apple은 다른
  /// 소셜 로그인을 제공하면 Apple 로그인도 필수(App Store 4.8 — iOS 앱 기준).
  /// 웹은 제외(2026-07-30): 웹 애플 로그인은 코드 플로우라 Apple Services ID+
  /// 키 설정이 따로 필요 — 설정 전엔 깨진 버튼이라 숨긴다(웹은 구글 로그인).
  bool get showAppleButton =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

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

  /// google_sign_in 인스턴스 — 플랫폼별 클라이언트 ID를 **명시**한다.
  /// iOS는 GoogleService-Info.plist가 Xcode 번들에 없어(Firebase는 Dart 옵션으로
  /// 초기화) 플러그인이 clientId를 못 찾아 **버튼 즉시 크래시**하던 원인
  /// (2026-07-27 제보). URL 스킴(REVERSED_CLIENT_ID)은 Info.plist에 이미 있음.
  static GoogleSignIn _googleSignIn() => GoogleSignIn(
        scopes: const ['email'],
        // iOS/macOS 전용 클라이언트(GoogleService-Info.plist의 CLIENT_ID).
        clientId: (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.macOS)
            ? '162098390378-cc79cakq7hehgimfr4kn7i7gajhq3svo.apps.googleusercontent.com'
            : null,
        // serverClientId(웹 클라이언트)를 명시해야 Android에서 Firebase용 idToken이
        // 확실히 발급된다. 없으면 계정 선택 뒤 토큰 교환이 조용히 실패(→게스트)할 수 있다.
        serverClientId:
            '162098390378-s2ad0lmi20u81aq3slp4lv581o06oh29.apps.googleusercontent.com',
      );

  /// Google 로그인. 성공 true. 실패 시 lastError에 사람이 읽을 메시지.
  Future<bool> signInWithGoogle() async {
    lastError = null;
    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      } else {
        final g = await _googleSignIn().signIn();
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

  /// Apple로 로그인. 성공 true. iOS/macOS에서 동작(웹은 버튼 숨김).
  ///
  /// 2026-07-30 credential 오류 대응: **1차 = Firebase SDK 일임**
  /// (signInWithProvider — nonce 등 전 과정을 네이티브 SDK가 처리, 권장 API),
  /// 실패 시 **2차 = sign_in_with_apple 수동 nonce 경로** 자동 폴백.
  /// 둘 다 실패하면 두 에러를 모두 표시해 원인을 특정한다.
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
      String detail(FirebaseAuthException e) => '${e.code}'
          '${(e.message != null && e.message!.isNotEmpty) ? ' · ${e.message}' : ''}';
      FirebaseAuthException? first;
      try {
        await FirebaseAuth.instance
            .signInWithProvider(AppleAuthProvider()..addScope('email'));
        return true;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'canceled' ||
            e.code == 'user-cancelled' ||
            e.code == 'web-context-cancelled') {
          lastError = '로그인이 취소됐어요';
          return false;
        }
        first = e; // 폴백 시도로
      }
      // 폴백: 수동 nonce 경로(구 방식).
      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
      final cred = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      try {
        await FirebaseAuth.instance.signInWithCredential(
          OAuthProvider('apple.com').credential(
            idToken: cred.identityToken,
            rawNonce: rawNonce,
          ),
        );
        return true;
      } on FirebaseAuthException catch (e2) {
        lastError = switch (e2.code) {
          'operation-not-allowed' =>
            '아직 서버에 Apple 로그인이 준비 중이에요. 게스트로 플레이해 주세요!',
          'network-request-failed' => '네트워크를 확인해 주세요',
          _ => '로그인 실패 [1차 ${detail(first)}] [2차 ${detail(e2)}]',
        };
        return false;
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      // 원인 파악용 상세 노출(2026-07-27 'credential 문제' 제보).
      lastError = e.code == AuthorizationErrorCode.canceled
          ? '로그인이 취소됐어요'
          : 'Apple 로그인 실패 (${e.code.name}'
              '${e.message.isNotEmpty ? ' · ${e.message}' : ''})';
      return false;
    } on FirebaseAuthException catch (e) {
      lastError = '로그인 실패 (${e.code}'
          '${(e.message != null && e.message!.isNotEmpty) ? ' · ${e.message}' : ''})';
      return false;
    } catch (e) {
      lastError = '로그인 실패: $e';
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

  /// 계정 삭제 직전 재인증 — Firebase가 requires-recent-login을 요구할 때.
  /// 로그인 공급자(Google/Apple)로 한 번 더 인증하고 true. 익명은 불필요(true).
  Future<bool> reauthenticate() async {
    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) return false;
      if (u.isAnonymous) return true;
      final providers = u.providerData.map((p) => p.providerId).toSet();
      if (providers.contains('google.com')) {
        if (kIsWeb) {
          await u.reauthenticateWithPopup(GoogleAuthProvider());
          return true;
        }
        final g = await _googleSignIn().signIn();
        if (g == null) return false;
        final auth = await g.authentication;
        await u.reauthenticateWithCredential(GoogleAuthProvider.credential(
            idToken: auth.idToken, accessToken: auth.accessToken));
        return true;
      }
      if (providers.contains('apple.com')) {
        if (kIsWeb) {
          await u.reauthenticateWithPopup(OAuthProvider('apple.com'));
          return true;
        }
        // 1차: SDK 일임(권장) → 실패 시 수동 nonce 폴백(로그인과 동일 구조).
        try {
          await u.reauthenticateWithProvider(AppleAuthProvider());
          return true;
        } on FirebaseAuthException {
          // 아래 폴백으로
        }
        final rawNonce = _generateNonce();
        final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
        final cred = await SignInWithApple.getAppleIDCredential(
          scopes: const [AppleIDAuthorizationScopes.email],
          nonce: hashedNonce,
        );
        await u.reauthenticateWithCredential(OAuthProvider('apple.com')
            .credential(idToken: cred.identityToken, rawNonce: rawNonce));
        return true;
      }
    } catch (_) {}
    return false;
  }
}
