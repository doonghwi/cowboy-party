import 'package:flutter/material.dart';

import '../theme.dart';

enum ReactionStage { prep, go, falseStart, spectate }

/// The big, full-area reaction surface for the "카우보이!" tiebreak. Tapping
/// anywhere on it counts, so it fills the space and reads at a glance.
class ReactionPanel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final Color bg;
    final String big;
    final String sub;
    final IconData icon;
    switch (stage) {
      case ReactionStage.prep:
        bg = CD.leather;
        big = '준비…';
        sub = '신호가 뜨면 바로 탭! (미리 누르면 패배)';
        icon = Icons.hourglass_top;
        break;
      case ReactionStage.go:
        bg = CD.danger;
        big = '카우보이!\n지금 탭!';
        sub = '가장 먼저 누르면 승리';
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
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        height: double.infinity,
        color: bg,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Icon(icon, color: Colors.white, size: 64),
            const SizedBox(height: 18),
            Text(
              big,
              textAlign: TextAlign.center,
              style: posterTitle(stage == ReactionStage.go ? 52 : 40,
                  color: Colors.white),
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
            if (opponents.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('상대: ${opponents.join(", ")}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13)),
            ],
            const Spacer(),
            Text('마지막 동시 탈락 — 반응속도로 최후의 1인을 가린다',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
