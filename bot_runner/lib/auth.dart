import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';

/// 봇 하나의 Firebase 자격증명. uid 는 저장되어 재실행에도 고정된다(랭킹 이름 안정).
class BotCred {
  final String name;
  String uid;
  String idToken;
  String refreshToken;
  DateTime expiry;

  BotCred({
    required this.name,
    required this.uid,
    required this.idToken,
    required this.refreshToken,
    required this.expiry,
  });

  bool get expired => DateTime.now().isAfter(
      expiry.subtract(const Duration(minutes: 2))); // 여유 2분

  Map<String, Object?> toJson() => {
        'name': name,
        'uid': uid,
        'refreshToken': refreshToken,
      };
}

/// 봇 계정 발급·갱신·저장 관리. 저장형 익명: 처음엔 익명 가입(signUp)으로 uid를
/// 만들고 refreshToken 을 파일에 저장 → 다음부터는 refresh 로 같은 uid 재사용.
class BotAuth {
  BotAuth(this._http);
  final http.Client _http;

  static const _signUpUrl =
      'https://identitytoolkit.googleapis.com/v1/accounts:signUp';
  static const _tokenUrl = 'https://securetoken.googleapis.com/v1/token';

  final Map<String, BotCred> _byName = {};

  /// 이름 목록만큼 계정을 준비한다(없으면 새로 익명 가입, 있으면 refresh).
  Future<List<BotCred>> ensureAccounts(List<String> names) async {
    final saved = _loadSaved(); // name -> {uid, refreshToken}
    final out = <BotCred>[];
    for (final name in names) {
      final s = saved[name];
      BotCred cred;
      if (s != null && (s['refreshToken'] as String?)?.isNotEmpty == true) {
        cred = await _refresh(name, s['uid'] as String, s['refreshToken'] as String);
      } else {
        cred = await _signUpAnonymous(name);
      }
      _byName[name] = cred;
      out.add(cred);
    }
    _persist();
    return out;
  }

  /// 만료 임박 시 idToken 갱신(호출 전에 쓰는 쪽에서 확인).
  Future<String> freshIdToken(BotCred cred) async {
    if (!cred.expired) return cred.idToken;
    final r = await _refresh(cred.name, cred.uid, cred.refreshToken);
    cred
      ..idToken = r.idToken
      ..refreshToken = r.refreshToken
      ..expiry = r.expiry
      ..uid = r.uid;
    _persist();
    return cred.idToken;
  }

  Future<BotCred> _signUpAnonymous(String name) async {
    final res = await _http.post(
      Uri.parse('$_signUpUrl?key=${Config.authApiKey}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'returnSecureToken': true}),
    );
    final body = jsonDecode(res.body) as Map<String, Object?>;
    if (res.statusCode != 200) {
      throw StateError('익명 가입 실패($name): ${res.statusCode} ${res.body}');
    }
    return BotCred(
      name: name,
      uid: body['localId'] as String,
      idToken: body['idToken'] as String,
      refreshToken: body['refreshToken'] as String,
      expiry: _expiryFrom(body['expiresIn']),
    );
  }

  Future<BotCred> _refresh(String name, String uid, String refreshToken) async {
    final res = await _http.post(
      Uri.parse('$_tokenUrl?key=${Config.authApiKey}'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'grant_type=refresh_token&refresh_token=$refreshToken',
    );
    final body = jsonDecode(res.body) as Map<String, Object?>;
    if (res.statusCode != 200) {
      // refresh 실패(폐기된 토큰 등) → 새 계정으로 폴백.
      stderr.writeln('토큰 refresh 실패($name) → 새 익명 계정 발급: ${res.body}');
      return _signUpAnonymous(name);
    }
    return BotCred(
      name: name,
      uid: (body['user_id'] as String?) ?? uid,
      idToken: body['id_token'] as String,
      refreshToken: (body['refresh_token'] as String?) ?? refreshToken,
      expiry: _expiryFrom(body['expires_in']),
    );
  }

  DateTime _expiryFrom(Object? expiresIn) {
    final secs = int.tryParse('${expiresIn ?? 3600}') ?? 3600;
    return DateTime.now().add(Duration(seconds: secs));
  }

  Map<String, Map<String, Object?>> _loadSaved() {
    try {
      final f = File(Config.credsPath);
      if (!f.existsSync()) return {};
      final list = jsonDecode(f.readAsStringSync()) as List;
      return {
        for (final e in list.cast<Map>())
          e['name'] as String: {
            'uid': e['uid'],
            'refreshToken': e['refreshToken'],
          }
      };
    } catch (_) {
      return {};
    }
  }

  void _persist() {
    try {
      File(Config.credsPath)
          .writeAsStringSync(jsonEncode(_byName.values.map((c) => c.toJson()).toList()));
    } catch (e) {
      stderr.writeln('자격증명 저장 실패: $e');
    }
  }
}
