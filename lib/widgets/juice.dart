import 'dart:math';

import 'package:flutter/material.dart';

/// 타격감(주스) 레이어 — 화면 흔들림 + 피격 붉은 비네트.
///
/// effects.dart와 같은 원칙: **표시 전용**(게임 상태 미참조), 의존성 0,
/// 게임로직 0줄. 화면(오프/온라인)이 리빌 플래그를 보고 [JuiceController]를
/// 흔들면 [JuiceLayer]가 자식(테이블)을 감싸 연출한다.
///
/// 강도 가이드: 내 피격/사망 12~14(+붉은 플래시), 슈퍼빵야 12,
/// 남 피격 6, 발사만(방어/빗나감) 2.5.
class JuiceController {
  _JuiceLayerState? _state;

  /// 화면을 [power]px 진폭으로 잠깐 흔든다.
  void shake(double power) => _state?._shake(power);

  /// 내가 맞았을 때 — 강한 흔들림 + 붉은 비네트 플래시.
  void hurt({double power = 13}) {
    _state?._shake(power);
    _state?._flash();
  }
}

class JuiceLayer extends StatefulWidget {
  final JuiceController controller;
  final Widget child;
  const JuiceLayer({super.key, required this.controller, required this.child});

  @override
  State<JuiceLayer> createState() => _JuiceLayerState();
}

class _JuiceLayerState extends State<JuiceLayer>
    with TickerProviderStateMixin {
  late final AnimationController _shakeCtl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420))
    ..addListener(() => setState(() {}));
  late final AnimationController _flashCtl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 380))
    ..addListener(() => setState(() {}));
  double _power = 0;
  // 흔들림 방향이 매번 살짝 달라지게 트리거마다 위상만 바꾼다(재현성 무관한 연출).
  double _phase = 0;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
  }

  @override
  void didUpdateWidget(covariant JuiceLayer old) {
    super.didUpdateWidget(old);
    old.controller._state = null;
    widget.controller._state = this;
  }

  @override
  void dispose() {
    widget.controller._state = null;
    _shakeCtl.dispose();
    _flashCtl.dispose();
    super.dispose();
  }

  void _shake(double power) {
    if (!mounted) return;
    _power = power;
    _phase += 2.399; // 황금각 — 연속 트리거여도 같은 방향으로 안 쏠림
    _shakeCtl.forward(from: 0);
  }

  void _flash() {
    if (!mounted) return;
    _flashCtl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // 감쇠 사인 진동: 진폭 (1-t)^2, 두 축 주파수를 다르게 해 원운동이 아닌
    // 손맛 나는 덜컹임을 만든다.
    Offset off = Offset.zero;
    if (_shakeCtl.isAnimating) {
      final t = _shakeCtl.value;
      final amp = _power * (1 - t) * (1 - t);
      off = Offset(
        sin(t * 34 + _phase) * amp,
        cos(t * 27 + _phase * 1.7) * amp * 0.8,
      );
    }
    // 피격 비네트: 확 떴다가 스르르 사라진다.
    final f = _flashCtl.isAnimating ? (1 - _flashCtl.value) : 0.0;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Transform.translate(offset: off, child: widget.child),
        if (f > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 1.1,
                    colors: [
                      Colors.transparent,
                      const Color(0xFFB3261E).withValues(alpha: 0.38 * f),
                    ],
                    stops: const [0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
