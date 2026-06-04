import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

/// A signed-in player (null when playing as a guest). [uid] is the stable,
/// cross-session identity the ranking system keys off.
class AppUser {
  final String uid;
  final String displayName;
  final String? photoUrl;
  const AppUser({required this.uid, required this.displayName, this.photoUrl});
}

/// Thin wrapper over Firebase Auth + Google Sign-In.
///
/// Web signs in with a popup (firebase_auth only); mobile uses the native
/// Google chooser then exchanges the token for a Firebase credential. Sign-in
/// is optional — the app still plays as a guest if it's not configured — so
/// nothing hard-depends on the OAuth setup being finished.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Emits the current player (or null) and updates on sign-in/out.
  Stream<AppUser?> userChanges() => _auth.userChanges().map(_toAppUser);

  AppUser? get current => _toAppUser(_auth.currentUser);

  AppUser? _toAppUser(User? u) {
    if (u == null) return null;
    final raw = u.displayName?.trim();
    return AppUser(
      uid: u.uid,
      displayName: (raw != null && raw.isNotEmpty) ? raw : '카우보이',
      photoUrl: u.photoURL,
    );
  }

  /// Sign in with Google. Returns null if the user cancelled. Throws on a real
  /// failure (e.g. provider not enabled yet) — callers should surface that.
  Future<AppUser?> signInWithGoogle() async {
    if (kIsWeb) {
      final cred = await _auth.signInWithPopup(GoogleAuthProvider());
      return _toAppUser(cred.user);
    }
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null; // cancelled
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    return _toAppUser(cred.user);
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
    }
    await _auth.signOut();
  }
}
