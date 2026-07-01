import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';

/// RTDB REST 최소 클라이언트. rooms 는 규칙상 공개 read(auth 불필요), 쓰기는
/// auth(idToken) 필요. 서버 타임스탬프는 `{".sv":"timestamp"}` 로 넣는다(앱의
/// ServerValue.timestamp / _now 와 정합).
class Rtdb {
  Rtdb(this._http);
  final http.Client _http;

  static const serverTimestamp = {'.sv': 'timestamp'};

  Uri _uri(String path, String? auth) {
    final q = auth == null ? '' : '?auth=$auth';
    return Uri.parse('${Config.databaseUrl}/$path.json$q');
  }

  /// GET. 없으면 null.
  Future<Object?> get(String path, {String? auth}) async {
    final res = await _http.get(_uri(path, auth));
    if (res.statusCode != 200) {
      throw StateError('GET $path 실패: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body);
  }

  /// shallow=true 로 최상위 키만(방 목록 감시용).
  Future<Map<String, Object?>> getShallow(String path, {String? auth}) async {
    final q = StringBuffer('?shallow=true');
    if (auth != null) q.write('&auth=$auth');
    final res =
        await _http.get(Uri.parse('${Config.databaseUrl}/$path.json$q'));
    if (res.statusCode != 200) return {};
    final v = jsonDecode(res.body);
    return v is Map ? v.cast<String, Object?>() : {};
  }

  /// PUT(set).
  Future<void> put(String path, Object? value, {required String auth}) async {
    final res = await _http.put(_uri(path, auth),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(value));
    if (res.statusCode != 200) {
      throw StateError('PUT $path 실패: ${res.statusCode} ${res.body}');
    }
  }

  /// PATCH(update, 얕은 병합).
  Future<void> patch(String path, Map<String, Object?> value,
      {required String auth}) async {
    final res = await _http.patch(_uri(path, auth),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(value));
    if (res.statusCode != 200) {
      throw StateError('PATCH $path 실패: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> delete(String path, {required String auth}) async {
    final res = await _http.delete(_uri(path, auth));
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw StateError('DELETE $path 실패: ${res.statusCode} ${res.body}');
    }
  }
}
