import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 효과음 재생 (음소거 토글 포함). 실패는 전부 무시 — 소리는 절대 앱을 깨지 않는다.
class Sfx {
  Sfx._();

  static bool _muted = false;
  static bool get muted => _muted;

  static Future<void> init() async {
    try {
      final sp = await SharedPreferences.getInstance();
      _muted = sp.getBool('sfx_muted') ?? false;
    } catch (_) {}
  }

  static Future<void> setMuted(bool v) async {
    _muted = v;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool('sfx_muted', v);
    } catch (_) {}
  }

  /// 파일명(확장자 제외)으로 재생: Sfx.play('shot').
  static void play(String name, {double volume = 1.0}) {
    if (_muted) return;
    try {
      final p = AudioPlayer();
      p.onPlayerComplete.listen((_) => p.dispose());
      p.play(AssetSource('sounds/$name.wav'), volume: volume);
    } catch (_) {}
  }

  static void click() => play('click', volume: 0.7);
  static void confirm() => play('confirm', volume: 0.8);
  static void coin() => play('coin');
  static void win() => play('win');
  static void lose() => play('lose', volume: 0.8);
}
