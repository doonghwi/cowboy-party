import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/sfx.dart';
import '../meta/meta_service.dart';
import '../theme.dart';

/// 보상 탭: 7일 출석 그리드 + 코인 얻는 법.
class RewardsTab extends StatefulWidget {
  const RewardsTab({super.key});

  @override
  State<RewardsTab> createState() => _RewardsTabState();
}

class _RewardsTabState extends State<RewardsTab> {
  @override
  void initState() {
    super.initState();
    Meta.I.addListener(_onMeta);
  }

  @override
  void dispose() {
    Meta.I.removeListener(_onMeta);
    super.dispose();
  }

  void _onMeta() {
    if (mounted) setState(() {});
  }

  void _claim() {
    final got = Meta.I.claimDaily();
    if (got > 0) {
      HapticFeedback.mediumImpact();
      Sfx.coin();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: CD.leather,
        content: Row(children: [
          const Icon(Icons.monetization_on, color: CD.gold, size: 20),
          const SizedBox(width: 8),
          Text('출석 보상 +$got 코인! (연속 ${Meta.I.dailyStreak}일)',
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = Meta.I;
    final today = meta.dailyCycleDay;
    final can = meta.canClaimDaily;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('매일 출석 보상', style: posterTitle(19)),
                  const Spacer(),
                  Text('연속 ${meta.dailyStreak}일',
                      style: const TextStyle(
                          color: CD.muted, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var d = 1; d <= 7; d++) ...[
                    Expanded(child: _dayCell(d, today, can)),
                    if (d < 7) const SizedBox(width: 6),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: CD.rust,
                  disabledBackgroundColor: CD.muted.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: can ? _claim : null,
                icon: const Icon(Icons.card_giftcard),
                label: Text(
                  can
                      ? '오늘 보상 받기 (+${kDailyCycle[today - 1]}코인)'
                      : '오늘은 받았어요 — 내일 또 만나요!',
                  style: posterTitle(16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('코인 얻는 법', style: posterTitle(19)),
              const SizedBox(height: 10),
              _earnRow(Icons.emoji_events, CD.gold, '온라인 승리',
                  '+${winCoins(2)}~${winCoins(6)} (인원이 많을수록 큼)'),
              _earnRow(Icons.sports_esports, CD.sage, '온라인 게임 완주',
                  '+$kPlayCoins'),
              _earnRow(Icons.event_available, CD.rust, '매일 출석',
                  '+${kDailyCycle.first}~${kDailyCycle.last} (7일 사이클)'),
              const SizedBox(height: 8),
              const Text('모은 코인으로 캐릭터 탭에서 새 총잡이를 해금하세요!',
                  style: TextStyle(color: CD.muted, fontSize: 12.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dayCell(int day, int today, bool canClaim) {
    final isToday = day == today;
    final passed = day < today || (day == today && !canClaim);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: passed
            ? CD.sage.withValues(alpha: 0.18)
            : isToday
                ? CD.gold.withValues(alpha: 0.3)
                : CD.sand.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isToday && canClaim ? CD.rust : CD.leather.withValues(alpha: 0.2),
          width: isToday && canClaim ? 2.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Text('$day일',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: passed ? CD.sage : CD.muted)),
          const SizedBox(height: 3),
          passed
              ? const Icon(Icons.check_circle, size: 18, color: CD.sage)
              : const Icon(Icons.monetization_on, size: 18, color: CD.gold),
          const SizedBox(height: 2),
          Text('${kDailyCycle[day - 1]}',
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w900, color: CD.leather)),
        ],
      ),
    );
  }

  Widget _earnRow(IconData icon, Color color, String title, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w800))),
          Text(amount,
              style: const TextStyle(color: CD.muted, fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CD.parchment.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CD.leather.withValues(alpha: 0.25)),
        ),
        child: child,
      );
}
