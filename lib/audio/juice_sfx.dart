import 'dart:math';

import 'package:flutter_soloud/flutter_soloud.dart';

import 'sfx.dart';

/// 저지연 총성·타격음(flutter_soloud) — 타격감 1단계.
///
/// 사운드 반복 회피 표준(JUICE_PLAN): 발사음은 3종 풀에서 직전과 다른 것을
/// 랜덤 재생하고, 재생마다 피치 ±8%·볼륨 ±10% 변주. 총성 3종은 사용자가
/// 시청 보드에서 승인한 "크랙+펀치" 레이어드(jsfxr+Kenney CC0) 변형이다.
///
/// 엔진 초기화 실패(웹 빌드·기기 이슈) 시 기존 audioplayers 경로([Sfx])로
/// 자동 폴백 — 소리는 절대 앱을 깨지 않는다.
class JuiceSfx {
  JuiceSfx._();

  static SoLoud? _engine;
  static final Map<String, AudioSource> _src = {};
  static final Random _rnd = Random();
  static int _lastShot = -1;
  static const _shotPool = ['gunshot_a', 'gunshot_b', 'gunshot_c'];

  static Future<void> init() async {
    try {
      final so = SoLoud.instance;
      await so.init();
      for (final n in [..._shotPool, 'hit']) {
        _src[n] = await so.loadAsset('assets/sounds/$n.wav');
      }
      _engine = so;
    } catch (_) {
      _engine = null; // 폴백: Sfx(audioplayers)로 재생
    }
  }

  static void _play(String name, {double volume = 1}) {
    if (Sfx.muted) return;
    final vol = (volume * (0.9 + _rnd.nextDouble() * 0.2)).clamp(0.0, 1.0);
    final so = _engine;
    final src = _src[name];
    if (so == null || src == null) {
      Sfx.play(name, volume: vol);
      return;
    }
    try {
      final h = so.play(src, volume: vol);
      // 피치 ±8% (재생속도 변화 — 짧은 SFX라 길이 차는 안 느껴진다).
      so.setRelativePlaySpeed(h, 0.92 + _rnd.nextDouble() * 0.16);
    } catch (_) {}
  }

  /// 발사음 — 3종 풀에서 직전과 다른 것.
  static void shot() {
    var i = _rnd.nextInt(_shotPool.length);
    if (i == _lastShot) i = (i + 1) % _shotPool.length;
    _lastShot = i;
    _play(_shotPool[i], volume: 0.9);
  }

  /// 타격음 — 기존 hit.wav에 피치·볼륨 변주만 더한다.
  static void hit() => _play('hit');
}
