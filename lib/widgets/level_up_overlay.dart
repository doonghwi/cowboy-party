import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/sfx.dart';
import '../theme.dart';

/// 게임 종료 후 레벨업 연출(2026-07-16 사용자 요청) — 금빛 방사광 + LEVEL UP 배지가
/// 팝 하고 떠올랐다 사라진다. 표시 전용, 2.4초 뒤 자동 제거.
class LevelUpOverlay {
  static void show(BuildContext context, int level) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    Sfx.confirm();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _LevelUpWidget(
        level: level,
        onDone: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _LevelUpWidget extends StatefulWidget {
  const _LevelUpWidget({required this.level, required this.onDone});
  final int level;
  final VoidCallback onDone;

  @override
  State<_LevelUpWidget> createState() => _LevelUpWidgetState();
}

class _LevelUpWidgetState extends State<_LevelUpWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          // 0~0.18 팝인 / 0.18~0.75 유지+상승 / 0.75~1 페이드아웃.
          final pop = t < 0.18
              ? Curves.easeOutBack.transform(t / 0.18)
              : 1.0;
          final fade = t > 0.75 ? 1 - (t - 0.75) / 0.25 : 1.0;
          final rise = t > 0.18 ? (t - 0.18) * 26 : 0.0;
          return Center(
            child: Opacity(
              opacity: fade.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -rise),
                child: Transform.scale(
                  scale: pop,
                  child: SizedBox(
                    width: 250,
                    height: 190,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(250, 190),
                          painter: _RaysPainter(t),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 6),
                              decoration: BoxDecoration(
                                color: CD.gold,
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                      color: CD.gold.withValues(alpha: 0.6),
                                      blurRadius: 18),
                                ],
                              ),
                              child: Text('LEVEL UP!',
                                  style: posterTitle(22, color: Colors.white)),
                            ),
                            const SizedBox(height: 8),
                            Text('Lv.${widget.level}',
                                style: posterTitle(34, color: CD.gold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 회전하는 금빛 방사광.
class _RaysPainter extends CustomPainter {
  _RaysPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2 - 6);
    final rot = t * 0.9;
    for (var i = 0; i < 12; i++) {
      final a = rot + i * math.pi / 6;
      final len = 78.0 + (i.isEven ? 14 : 0);
      final p = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a - 0.045) * len,
            c.dy + math.sin(a - 0.045) * len)
        ..lineTo(c.dx + math.cos(a + 0.045) * len,
            c.dy + math.sin(a + 0.045) * len)
        ..close();
      canvas.drawPath(
          p,
          Paint()
            ..color = CD.gold.withValues(alpha: i.isEven ? 0.28 : 0.16));
    }
    // 반짝 별 4개.
    for (final (dx, dy, r) in [
      (-88.0, -34.0, 5.0),
      (84.0, -50.0, 4.0),
      (72.0, 44.0, 5.0),
      (-70.0, 52.0, 3.5),
    ]) {
      final o = c + Offset(dx, dy);
      for (final a in [0.0, math.pi / 2]) {
        canvas.drawLine(
            o + Offset(math.cos(a), math.sin(a)) * r,
            o - Offset(math.cos(a), math.sin(a)) * r,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.9)
              ..strokeWidth = 1.6
              ..strokeCap = StrokeCap.round);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter old) => old.t != t;
}
