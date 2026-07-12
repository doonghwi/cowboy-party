import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

enum ReactionStage { prep, go, falseStart, spectate }

/// The big, full-area reaction surface for the "카우보이!" tiebreak. Tapping
/// anywhere on it counts, so it fills the space and reads at a glance.
///
/// 타격감 2단계: 예열(정적 — 어두운 화면에 '준비…' 심장박동 펄스) →
/// 'DRAW!' 슬램(easeOutBack 확대 + 백열 플래시 + 헤비 햅틱)의 의식(Ceremony).
class ReactionPanel extends StatefulWidget {
  final ReactionStage stage;
  final List<String> opponents;
  final VoidCallback onTap;

  const ReactionPanel({
    super.key,
    required this.stage,
    required this.opponents,
    required this.onTap,
  });

  @override
  State<ReactionPanel> createState() => _ReactionPanelState();
}

class _ReactionPanelState extends State<ReactionPanel>
    with TickerProviderStateMixin {
  // 예열 심장박동(느린 펄스, 반복).
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);
  // DRAW! 슬램(1회).
  late final AnimationController _slam = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void initState() {
    super.initState();
    if (widget.stage == ReactionStage.go) _slam.value = 1;
  }

  @override
  void didUpdateWidget(covariant ReactionPanel old) {
    super.didUpdateWidget(old);
    if (old.stage != ReactionStage.go && widget.stage == ReactionStage.go) {
      _slam.forward(from: 0);
      HapticFeedback.heavyImpact();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _slam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final String big;
    final String sub;
    final IconData icon;
    switch (widget.stage) {
      case ReactionStage.prep:
        bg = const Color(0xFF241B14); // 예열: 살룬이 어두워진다(정적)
        big = '준비…';
        sub = '신호가 뜨면 바로 탭! (미리 누르면 패배)';
        icon = Icons.hourglass_top;
        break;
      case ReactionStage.go:
        bg = CD.danger;
        big = 'DRAW!';
        sub = '지금 탭! 가장 먼저 누르면 승리';
        icon = Icons.touch_app;
        break;
      case ReactionStage.falseStart:
        bg = CD.muted;
        big = '부정출발!\n패배';
        sub = '신호 전에 눌렀어요';
        icon = Icons.block;
        break;
      case ReactionStage.spectate:
        bg = CD.leather;
        big = '결투 중…';
        sub = '최후의 반응속도 대결 관전';
        icon = Icons.visibility;
        break;
    }
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        height: double.infinity,
        color: bg,
        padding: const EdgeInsets.all(24),
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulse, _slam]),
          builder: (context, _) {
            // 예열: 아이콘·텍스트가 심장박동처럼 은은히 커졌다 작아진다.
            final prepScale = widget.stage == ReactionStage.prep
                ? 1 + 0.05 * _pulse.value
                : 1.0;
            // DRAW!: 크게 날아와 박히는 슬램(1.7→1, easeOutBack).
            final st = Curves.easeOutBack.transform(_slam.value);
            final slamScale =
                widget.stage == ReactionStage.go ? 1.7 - 0.7 * st : 1.0;
            final flash = widget.stage == ReactionStage.go
                ? (1 - _slam.value / 0.35).clamp(0.0, 1.0)
                : 0.0;
            return Stack(
              fit: StackFit.expand,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    Transform.scale(
                        scale: prepScale,
                        child: Icon(icon, color: Colors.white, size: 64)),
                    const SizedBox(height: 18),
                    Transform.scale(
                      scale: prepScale * slamScale,
                      child: Text(
                        big,
                        textAlign: TextAlign.center,
                        style: posterTitle(
                            widget.stage == ReactionStage.go ? 64 : 40,
                            color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      sub,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                    if (widget.opponents.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('상대: ${widget.opponents.join(", ")}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 13)),
                    ],
                    const Spacer(),
                    Text('마지막 동시 탈락 — 반응속도로 최후의 1인을 가린다',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12)),
                  ],
                ),
                // 슬램 순간의 백열 플래시.
                if (flash > 0)
                  IgnorePointer(
                    child: ColoredBox(
                        color:
                            Colors.white.withValues(alpha: 0.55 * flash)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
