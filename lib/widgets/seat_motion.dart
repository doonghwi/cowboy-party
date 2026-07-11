import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 좌석 카드의 반동(발사)·넉백+흰 플래시(피격) — 타격감 1단계.
///
/// effects.dart와 같은 원칙: 표시 전용, 게임 상태 미참조. CircularTable이
/// 리빌 플래그로 방향을 계산해 턴마다 키를 바꿔 마운트하면 스스로 한 번
/// 재생하고 끝난다. 아케이드 과장 프리셋(사용자 승인): 반동 8px+2° 기울임,
/// 넉백 12px, 피격 흰 플래시 80ms.
class SeatMotion extends StatefulWidget {
  const SeatMotion({
    super.key,
    this.recoil,
    this.knock,
    this.knockDelay = const Duration(milliseconds: 430),
    required this.child,
  });

  /// 발사 반동 방향(단위벡터, 탄 반대방향). null이면 반동 없음. 즉시 재생.
  final Offset? recoil;

  /// 넉백 방향(단위벡터, 탄 진행방향). null이면 없음. [knockDelay] 후
  /// (탄환 코어가 도착하는 시점) 흰 플래시와 함께 재생.
  final Offset? knock;
  final Duration knockDelay;
  final Widget child;

  @override
  State<SeatMotion> createState() => _SeatMotionState();
}

class _SeatMotionState extends State<SeatMotion>
    with TickerProviderStateMixin {
  late final AnimationController _kick = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300))
    ..addListener(() => setState(() {}));
  late final AnimationController _knock = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420))
    ..addListener(() => setState(() {}));
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    if (widget.recoil != null) _kick.forward(from: 0);
    if (widget.knock != null) {
      _delay = Timer(widget.knockDelay, () {
        if (mounted) _knock.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _kick.dispose();
    _knock.dispose();
    super.dispose();
  }

  /// 임펄스 곡선: 앞 22%에 확 나갔다가 easeOut으로 복귀.
  static double _impulse(double t) => t < 0.22
      ? Curves.easeOut.transform(t / 0.22)
      : 1 - Curves.easeOutCubic.transform((t - 0.22) / 0.78);

  @override
  Widget build(BuildContext context) {
    Offset off = Offset.zero;
    double angle = 0;
    if (_kick.isAnimating) {
      final k = _impulse(_kick.value);
      off += widget.recoil! * 8 * k;
      // 반동 방향으로 살짝 기울어짐(±2°). 수평 성분이 없으면 수직 반동 느낌만.
      angle += 0.035 * k * (widget.recoil!.dx >= 0 ? 1 : -1);
    }
    double flash = 0;
    if (_knock.isAnimating) {
      final t = _knock.value;
      off += widget.knock! * 12 * _impulse(t);
      flash = (1 - t / 0.19).clamp(0.0, 1.0); // 흰 플래시 80ms
    }
    Widget w = widget.child;
    if (flash > 0) {
      w = Stack(
        fit: StackFit.passthrough,
        children: [
          w,
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ColoredBox(
                    color: Colors.white.withValues(alpha: 0.75 * flash)),
              ),
            ),
          ),
        ],
      );
    }
    if (off == Offset.zero && angle == 0) return w;
    return Transform.translate(
      offset: off,
      child: Transform.rotate(angle: math.min(angle.abs(), 0.05) * angle.sign, child: w),
    );
  }
}
