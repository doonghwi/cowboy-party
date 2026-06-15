/// 닉네임 비속어 필터 (#1).
///
/// 단어 목록은 빌드에 번들된 `assets/badwords_ko.json`(약 1,145개, 출처:
/// github.com/hlog2e/bad_word_list, 한국어 비속어 모음)에서 로드한다.
/// 닉네임 검사 시 공백/특수문자를 제거하고 부분일치로 막는다.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class Profanity {
  Profanity._();
  static final Profanity I = Profanity._();

  final Set<String> _words = {};
  bool _loaded = false;

  /// 앱 시작 시 1회 호출(실패해도 게임은 계속 — 그땐 필터가 비어 통과).
  Future<void> init() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/badwords_ko.json');
      final data = jsonDecode(raw);
      final list = (data is Map ? data['words'] : data) as List?;
      if (list != null) {
        for (final w in list) {
          final s = _normalize(w.toString());
          if (s.length >= 2) _words.add(s); // 1글자는 오탐 많아 제외
        }
      }
    } catch (_) {
      // 자산 로드 실패 — 필터 없이 통과(닉네임 기능 자체는 살린다).
    }
    _loaded = true;
  }

  /// 비교용 정규화: 공백·특수문자 제거 + 소문자.
  String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[\s\W_]+'), '');

  /// 닉네임에 비속어가 포함돼 있으면 true.
  bool isProfane(String nickname) {
    if (_words.isEmpty) return false;
    final n = _normalize(nickname);
    if (n.isEmpty) return false;
    for (final w in _words) {
      if (n.contains(w)) return true;
    }
    return false;
  }
}
