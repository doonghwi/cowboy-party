import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

/// 화면 *상단*에서 내려오는 토스트. 탭하면 즉시 사라지고, [duration] 뒤 자동으로
/// 닫힌다. Flutter의 SnackBar은 항상 하단에 뜨고 탭으로 닫을 수 없어서, 게임
/// 결과·코인 획득처럼 상단에 띄우고 손쉽게 치우고 싶은 알림에 쓴다.
class TopToast {
  static OverlayEntry? _current;

  static void show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.monetization_on,
    Color iconColor = CD.gold,
    Color background = CD.leather,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    // 이전 토스트가 떠 있으면 먼저 치운다(겹침 방지).
    _current?.remove();
    _current = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _TopToastWidget(
        message: message,
        icon: icon,
        iconColor: iconColor,
        background: background,
        duration: duration,
        onDismiss: () {
          if (_current == entry) _current = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _TopToastWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color iconColor;
  final Color background;
  final Duration duration;
  final VoidCallback onDismiss;

  const _TopToastWidget({
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Timer? _timer;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _c.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _timer?.cancel();
    if (mounted) {
      _c.reverse().then((_) => widget.onDismiss());
    } else {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Positioned(
      top: mq.padding.top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1.6),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _c,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        )),
        child: FadeTransition(
          opacity: _c,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: widget.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: CD.gold, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(widget.icon, color: widget.iconColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14),
                      ),
                    ),
                    Text('탭하면 닫힘',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
