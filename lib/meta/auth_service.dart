import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  bool get isGoogle => state == AuthState.google;

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
        final g = await GoogleSignIn(scopes: const ['email']).signIn();
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
        _ => '로그인 실패 (${e.code})',
      };
      return false;
    } catch (_) {
      lastError = '로그인 실패 — 잠시 후 다시 시도해 주세요';
      return false;
    }
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
