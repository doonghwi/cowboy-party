import 'dart:async';

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
    // BGM도 같은 토글로 제어 (음소거 = 효과음+배경음 둘 다).
    Bgm.applyMute(v);
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

/// 배경음악(루프). 메뉴/전투 트랙을 페이드로 전환한다.
///
/// 파일은 `assets/music/<name>.mp3`. 아직 파일이 없어도(예: Suno로 제작 전)
/// 재생 실패는 전부 삼켜서 무음으로 동작 — 앱을 절대 깨지 않는다.
/// 음소거는 [Sfx]와 공유(단일 토글)한다.
class Bgm {
  Bgm._();

  static final AudioPlayer _p = AudioPlayer();
  static String? _current; // 재생을 원하는 트랙 (음소거여도 기억)
  static double _vol = 0.55; // 기본 배경음 볼륨 (효과음보다 낮게)
  static Timer? _fade;
  static bool _inited = false;

  static Future<void> init() async {
    if (_inited) return;
    _inited = true;
    try {
      await _p.setReleaseMode(ReleaseMode.loop);
      await _p.setVolume(0);
    } catch (_) {}
  }

  /// 원하는 트랙으로 전환. 같은 트랙이면 무시. 음소거면 기억만 하고 재생 안 함.
  /// 예: Bgm.play('menu'), Bgm.play('battle', volume: 0.5).
  static Future<void> play(String name, {double? volume}) async {
    if (volume != null) _vol = volume;
    if (_current == name) return;
    _current = name;
    if (Sfx.muted) return;
    await _switch(name);
  }

  /// 웹 자동재생 차단 대응: 브라우저는 첫 사용자 제스처 전엔 오디오를 막는다.
  /// 첫 탭에서 한 번 호출하면 기억해 둔 현재 트랙을 실제로 재생해 BGM을 살린다.
  /// (모바일은 이미 재생 중이라 호출하지 않는다 — main.dart에서 kIsWeb일 때만 건다.)
  static bool _unlocked = false;
  static void kickStart() {
    if (_unlocked) return;
    _unlocked = true;
    final cur = _current;
    if (cur != null && !Sfx.muted) {
      _switch(cur); // 제스처 컨텍스트 안에서 재생 → 브라우저가 허용
    }
  }

  /// 배경음 정지(페이드아웃). 트랙 기억도 해제.
  static Future<void> stop() async {
    _current = null;
    _fade?.cancel();
    await _fadeOutStop();
  }

  /// 음소거 토글 반영. 켜면 즉시 무음+일시정지, 끄면 마지막 트랙 재개.
  static Future<void> applyMute(bool muted) async {
    if (!_inited) return;
    if (muted) {
      _fade?.cancel();
      try {
        await _p.setVolume(0);
        await _p.pause();
      } catch (_) {}
    } else if (_current != null) {
      await _switch(_current!); // 안전하게 새로 시작
    }
  }

  static Future<void> _switch(String name) async {
    await _fadeOutStop();
    try {
      await _p.setReleaseMode(ReleaseMode.loop);
      await _p.setVolume(0);
      await _p.play(AssetSource('music/$name.mp3'));
      _fadeIn();
    } catch (_) {}
  }

  static Future<void> _fadeOutStop() async {
    _fade?.cancel();
    for (int i = 8; i >= 0; i--) {
      try {
        await _p.setVolume(_vol * i / 8);
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 22));
    }
    try {
      await _p.stop();
    } catch (_) {}
  }

  static void _fadeIn() {
    _fade?.cancel();
    int i = 0;
    const steps = 14;
    _fade = Timer.periodic(const Duration(milliseconds: 35), (t) async {
      i++;
      try {
        await _p.setVolume(_vol * i / steps);
      } catch (_) {}
      if (i >= steps) t.cancel();
    });
  }
}
