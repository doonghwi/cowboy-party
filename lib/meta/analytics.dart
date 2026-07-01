import 'package:firebase_analytics/firebase_analytics.dart';

/// 제품 지표용 이벤트 로깅(Firebase Analytics) — 리텐션·퍼널 측정의 최소 셋.
///
/// 원칙은 [Sfx]와 동일: **실패는 전부 삼킨다** — 분석은 앱을 절대 깨지 않는다.
/// (Firebase 미초기화·웹 measurementId 없음 등 어떤 상황에도 no-op.)
///
/// 이벤트 사전(파라미터까지 여기서만 관리 — 새 이벤트도 여기에 추가):
/// - `game_start`  {mode: cpu|online, players}
/// - `game_end`    {mode: cpu|online, players, won: 0|1}
/// - `char_buy`    {char, cost}
/// - `daily_claim` {day, streak}
/// - `mission_done`{mission, gold}
/// - `share_result`{mode, won: 0|1}
class Ana {
  Ana._();

  static FirebaseAnalytics? _fa;

  /// Firebase.initializeApp 성공 후 한 번 호출(실패해도 무해).
  static void init() {
    try {
      _fa = FirebaseAnalytics.instance;
    } catch (_) {
      _fa = null;
    }
  }

  static void log(String name, [Map<String, Object>? params]) {
    try {
      _fa?.logEvent(name: name, parameters: params);
    } catch (_) {
      // 분석 실패는 조용히 무시.
    }
  }
}
