import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/sfx.dart';
import '../meta/meta_service.dart';
import '../meta/retention.dart';
import '../theme.dart';
import '../widgets/juice3.dart';
import '../widgets/top_toast.dart';

/// 보상 탭 — 계층적으로 재설계된 레이아웃.
/// ① 요약 스트립  ② 시즌 패스 가로 티어 트랙(Hero)
/// ③ 출석 스트립  ④ 미션(데일리+주간 통합 카드)
/// ⑤ 트로피 로드(ExpansionTile)  ⑥ 선물 코드(접힌 링크형)
class RewardsTab extends StatefulWidget {
  const RewardsTab({super.key});

  @override
  State<RewardsTab> createState() => _RewardsTabState();
}

class _RewardsTabState extends State<RewardsTab> {
  final _codeCtl = TextEditingController();
  bool _redeeming = false;

  @override
  void initState() {
    super.initState();
    Meta.I.addListener(_onMeta);
  }

  @override
  void dispose() {
    _codeCtl.dispose();
    Meta.I.removeListener(_onMeta);
    super.dispose();
  }

  void _onMeta() {
    if (mounted) setState(() {});
  }

  Future<void> _redeem() async {
    if (_redeeming) return;
    setState(() => _redeeming = true);
    final res = await Meta.I.redeemGiftCode(_codeCtl.text);
    if (!mounted) return;
    setState(() => _redeeming = false);
    if (res.ok) {
      _codeCtl.clear();
      Sfx.coin();
      TopToast.show(context, message: '선물 코드 ${res.message}');
    } else {
      Sfx.click();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(res.message),
      ));
    }
  }

  void _claim() {
    final got = Meta.I.claimDaily();
    if (got > 0) {
      HapticFeedback.mediumImpact();
      Sfx.coin();
      TopToast.show(
        context,
        message: '출석 보상 +$got 코인! (연속 ${Meta.I.dailyStreak}일)',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = Meta.I;
    final today = meta.dailyCycleDay;
    final canClaim = meta.canClaimDaily;

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      children: [
        // ① 요약 스트립 — 레벨 배지 + XP바 + 패스 티어 + D-일
        _SummaryStrip(meta: meta),

        // 스트릭 복구 배너 (조건부)
        if (meta.canReviveStreak)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _StreakReviveBanner(meta: meta, context: context),
          ),

        const SizedBox(height: 16),

        // ② Hero — 시즌 패스 가로 티어 트랙
        _PassTierTrack(meta: meta),

        const SizedBox(height: 16),

        // ③ 출석 스트립
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _AttendanceCard(
            today: today,
            canClaim: canClaim,
            streak: meta.dailyStreak,
            onClaim: _claim,
          ),
        ),

        const SizedBox(height: 12),

        // ④ 미션 통합 카드 (데일리 + 주간)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _MissionCard(meta: meta),
        ),

        const SizedBox(height: 12),

        // ⑤ 트로피 로드 — ExpansionTile로 접기
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _TrophyRoadTile(meta: meta),
        ),

        const SizedBox(height: 12),

        // ⑥ 코인 얻는 법 + 선물 코드(맨 아래 접힌 링크형)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _EarnInfoCard(meta: meta),
        ),

        const SizedBox(height: 8),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _GiftCodeTile(
            codeCtl: _codeCtl,
            redeeming: _redeeming,
            onRedeem: _redeem,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ① 요약 스트립
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.meta});
  final Meta meta;

  @override
  Widget build(BuildContext context) {
    final dLeft = passDaysLeft(DateTime.now()) + 1;
    final isLastWeek = passLastWeek(DateTime.now());

    return Container(
      color: CD.leather.withValues(alpha: 0.97),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 레벨 배지
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: CD.rust,
              borderRadius: BorderRadius.circular(CD.rChip),
              border: Border.all(color: CD.gold.withValues(alpha: 0.4), width: 1),
            ),
            child: Text('Lv.${meta.level}',
                style: westernLatin(14, color: Colors.white, spacing: 0.5)),
          ),
          const SizedBox(width: 10),
          // XP 미니바
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      meta.maxLevel
                          ? 'MAX LEVEL'
                          : '${meta.xpInto} / ${meta.xpNeed} XP',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.7),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: meta.maxLevel
                        ? 1.0
                        : (meta.xpNeed == 0
                            ? 0.0
                            : meta.xpInto / meta.xpNeed),
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    color: CD.rust,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 수직 구분선
          Container(
              width: 1,
              height: 28,
              color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(width: 12),
          // 패스 티어
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('패스',
                  style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
              Text('T${meta.passTier}',
                  style: westernLatin(15, color: CD.gold, spacing: 0.5)),
            ],
          ),
          const SizedBox(width: 12),
          Container(
              width: 1,
              height: 28,
              color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(width: 12),
          // D-일
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isLastWeek ? 'XP×2' : 'D-$dLeft',
                  style: westernLatin(15,
                      color: isLastWeek ? CD.nova : Colors.white,
                      spacing: 0.5)),
              Text('남은 날',
                  style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 스트릭 복구 배너
// ─────────────────────────────────────────────────────────────────────────────

class _StreakReviveBanner extends StatelessWidget {
  const _StreakReviveBanner({required this.meta, required this.context});
  final Meta meta;
  final BuildContext context;

  @override
  Widget build(BuildContext outerCtx) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFB3261E).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(CD.rCard),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department,
              color: Colors.white, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '연속 ${meta.brokenStreak}일 출석이 끊겼어요!\n주 1회 무료로 복구할 수 있어요',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13),
            ),
          ),
          FilledButton(
            onPressed: () {
              final n = Meta.I.reviveStreak();
              if (n > 0) {
                HapticFeedback.mediumImpact();
                TopToast.show(outerCtx,
                    message: '연속 출석 복구! 연속 $n일로 이어져요');
              }
            },
            style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFB3261E)),
            child: const Text('무료 복구',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ② 시즌 패스 가로 티어 트랙 (Hero)
// ─────────────────────────────────────────────────────────────────────────────

/// 스파이크 보상 티어 — 노드가 크게 강조됨.
const Set<int> _spikeTiers = {5, 10, 20, 30};

class _PassTierTrack extends StatefulWidget {
  const _PassTierTrack({required this.meta});
  final Meta meta;

  @override
  State<_PassTierTrack> createState() => _PassTierTrackState();
}

class _PassTierTrackState extends State<_PassTierTrack> {
  final _scrollCtl = ScrollController();
  static const double _nodeW = 56.0;
  static const double _spikeNodeW = 72.0;
  static const double _gapW = 12.0;
  static const double _trackHeight = 120.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentTier());
  }

  @override
  void didUpdateWidget(_PassTierTrack old) {
    super.didUpdateWidget(old);
    if (old.meta.passTier != widget.meta.passTier) {
      _scrollToCurrentTier();
    }
  }

  void _scrollToCurrentTier() {
    if (!_scrollCtl.hasClients) return;
    final tier = widget.meta.passTier.clamp(1, kPassMaxTier);
    // 현재 티어까지 누적 오프셋 계산
    double offset = 16.0; // leading padding
    for (var i = 1; i < tier; i++) {
      offset += _spikeTiers.contains(i) ? _spikeNodeW : _nodeW;
      offset += _gapW;
    }
    // 화면 중앙에 오도록
    final viewWidth = _scrollCtl.position.viewportDimension;
    final nodeW = _spikeTiers.contains(tier) ? _spikeNodeW : _nodeW;
    offset = offset - viewWidth / 2 + nodeW / 2;
    _scrollCtl.animateTo(
      offset.clamp(0.0, _scrollCtl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.meta;
    final currentTier = meta.passTier;
    final passXpInTier = meta.passXp % kPassTierXp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('시즌 패스', style: posterTitle(20)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: CD.sage,
                  borderRadius: BorderRadius.circular(CD.rChip),
                ),
                child: Text('30티어',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
              const Spacer(),
              if (meta.passTier < kPassMaxTier)
                Text(
                  '티어 XP  $passXpInTier / $kPassTierXp',
                  style: const TextStyle(
                      fontSize: 11, color: CD.muted, fontWeight: FontWeight.w700),
                )
              else
                Text('완주!',
                    style: posterTitle(14, color: CD.gold)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 티어 트랙
        SizedBox(
          height: _trackHeight,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: false,
            ),
            child: ListView.builder(
              controller: _scrollCtl,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: kPassMaxTier,
              itemBuilder: (context, index) {
                final tier = index + 1;
                final isSpike = _spikeTiers.contains(tier);
                final isDone = tier <= currentTier;
                final isCurrent = tier == currentTier;
                final isClaimed = meta.passTierClaimed(tier);
                final gold = passGoldOf(tier);

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 연결선(앞)
                    if (index > 0)
                      _TierConnector(
                        filled: isDone,
                        width: _gapW,
                      ),
                    _TierNode(
                      tier: tier,
                      gold: gold,
                      isSpike: isSpike,
                      isDone: isDone,
                      isCurrent: isCurrent,
                      isClaimed: isClaimed,
                      nodeWidth: isSpike ? _spikeNodeW : _nodeW,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        // XP 진행 레이블
        if (meta.passTier < kPassMaxTier)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              '게임·미션을 완료하면 패스 XP가 채워져요. 티어 보상은 자동 지급!',
              style: const TextStyle(fontSize: 11, color: CD.muted),
            ),
          ),
      ],
    );
  }
}

class _TierConnector extends StatelessWidget {
  const _TierConnector({required this.filled, required this.width});
  final bool filled;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 3,
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: filled
            ? CD.sage
            : CD.leather.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _TierNode extends StatelessWidget {
  const _TierNode({
    required this.tier,
    required this.gold,
    required this.isSpike,
    required this.isDone,
    required this.isCurrent,
    required this.isClaimed,
    required this.nodeWidth,
  });

  final int tier;
  final int gold;
  final bool isSpike;
  final bool isDone;
  final bool isCurrent;
  final bool isClaimed;
  final double nodeWidth;

  @override
  Widget build(BuildContext context) {
    // 색상 결정
    Color bgColor;
    Color borderColor;
    Color textColor;
    double borderWidth;

    if (isDone && isClaimed) {
      bgColor = CD.sage.withValues(alpha: 0.18);
      borderColor = CD.sage;
      textColor = CD.sage;
      borderWidth = 1.5;
    } else if (isCurrent) {
      bgColor = CD.gold.withValues(alpha: 0.22);
      borderColor = CD.gold;
      textColor = CD.leather;
      borderWidth = 2.5;
    } else {
      bgColor = CD.parchment.withValues(alpha: 0.85);
      borderColor = CD.leather.withValues(alpha: 0.2);
      textColor = CD.muted;
      borderWidth = 1;
    }

    final double nodeHeight = isSpike ? 96 : 80;
    final double iconSize = isSpike ? 20 : 16;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: nodeWidth,
      height: nodeHeight,
      margin: EdgeInsets.only(
        top: isSpike ? 0 : 8,
        bottom: isSpike ? 0 : 8,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(isSpike ? CD.rCard : CD.rChip),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                    color: CD.gold.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 티어 번호
          Text(
            '$tier',
            style: isSpike
                ? westernLatin(15, color: isCurrent ? CD.rust : textColor)
                : TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: textColor),
          ),
          const SizedBox(height: 3),
          // 아이콘
          if (isDone && isClaimed)
            Icon(Icons.check_circle, size: iconSize, color: CD.sage)
          else if (isSpike)
            Icon(
              tier == 30 ? Icons.emoji_events : Icons.bolt,
              size: iconSize,
              color: isCurrent ? CD.rust : CD.gold,
            )
          else
            Icon(Icons.monetization_on, size: iconSize, color: CD.gold),
          const SizedBox(height: 3),
          // 골드 표시
          Text(
            '+$gold',
            style: TextStyle(
              fontSize: isSpike ? 11 : 9,
              fontWeight: FontWeight.w900,
              color: isDone && isClaimed
                  ? CD.muted
                  : isSpike
                      ? CD.gold
                      : CD.leather.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ③ 출석 스트립
// ─────────────────────────────────────────────────────────────────────────────

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({
    required this.today,
    required this.canClaim,
    required this.streak,
    required this.onClaim,
  });

  final int today;
  final bool canClaim;
  final int streak;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('매일 출석', style: posterTitle(18)),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.local_fire_department,
                      size: 14, color: CD.rust),
                  const SizedBox(width: 3),
                  Text('$streak일 연속',
                      style: const TextStyle(
                          fontSize: 12,
                          color: CD.muted,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 7칸 스트립
          Row(
            children: [
              for (var d = 1; d <= 7; d++) ...[
                Expanded(child: _DayCell(day: d, today: today, canClaim: canClaim)),
                if (d < 7) const SizedBox(width: 5),
              ],
            ],
          ),
          const SizedBox(height: 12),
          TapScale(
            enabled: canClaim,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: canClaim ? CD.rust : CD.muted.withValues(alpha: 0.35),
                disabledBackgroundColor: CD.muted.withValues(alpha: 0.35),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CD.rCard)),
              ),
              onPressed: canClaim ? onClaim : null,
              icon: Icon(
                canClaim ? Icons.card_giftcard : Icons.check_circle_outline,
                size: 18,
              ),
              label: Text(
                canClaim
                    ? '오늘 보상 받기  +${kDailyCycle[today - 1]}코인'
                    : '오늘은 받았어요 — 내일 또!',
                style: posterTitle(15, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.today,
    required this.canClaim,
  });

  final int day;
  final int today;
  final bool canClaim;

  @override
  Widget build(BuildContext context) {
    final isToday = day == today;
    final passed = day < today || (day == today && !canClaim);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: passed
            ? CD.sage.withValues(alpha: 0.16)
            : isToday
                ? CD.gold.withValues(alpha: 0.28)
                : CD.sand.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(CD.rChip),
        border: Border.all(
          color: isToday && canClaim
              ? CD.rust
              : CD.leather.withValues(alpha: 0.18),
          width: isToday && canClaim ? 2.5 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$day일',
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: passed ? CD.sage : CD.muted)),
          const SizedBox(height: 2),
          passed
              ? const Icon(Icons.check_circle, size: 16, color: CD.sage)
              : const Icon(Icons.monetization_on, size: 16, color: CD.gold),
          const SizedBox(height: 2),
          Text('${kDailyCycle[day - 1]}',
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: CD.leather)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ④ 미션 통합 카드 (데일리 + 주간)
// ─────────────────────────────────────────────────────────────────────────────

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.meta});
  final Meta meta;

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 데일리 미션 섹션
          Row(
            children: [
              Text('데일리 미션', style: posterTitle(17)),
              const Spacer(),
              const Text('매일 0시 초기화',
                  style: TextStyle(
                      fontSize: 11,
                      color: CD.muted,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          for (final m in kDailyMissions) _MissionRow.daily(m, meta),
          // 구분선
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                    child: Divider(
                        color: CD.leather.withValues(alpha: 0.15),
                        height: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('주간',
                      style: TextStyle(
                          fontSize: 10,
                          color: CD.muted.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                ),
                Expanded(
                    child: Divider(
                        color: CD.leather.withValues(alpha: 0.15),
                        height: 1)),
              ],
            ),
          ),
          // 주간 미션 섹션
          Row(
            children: [
              Text('주간 미션', style: posterTitle(17)),
              const Spacer(),
              const Text('월요일 초기화',
                  style: TextStyle(
                      fontSize: 11,
                      color: CD.muted,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          for (final m in kWeeklyMissions) _MissionRow.weekly(m, meta),
          const SizedBox(height: 2),
          const Text('게임을 끝내면 자동으로 달성·지급돼요.',
              style: TextStyle(fontSize: 11, color: CD.muted)),
        ],
      ),
    );
  }
}

class _MissionRow extends StatelessWidget {
  const _MissionRow.daily(this.daily, this.meta)
      : weekly = null;
  const _MissionRow.weekly(this.weekly, this.meta)
      : daily = null;

  final DailyMission? daily;
  final WeeklyMission? weekly;
  final Meta meta;

  bool get _isDone => daily != null
      ? meta.missionClaimed(daily!)
      : meta.weeklyClaimed(weekly!);

  int get _prog => daily != null
      ? meta.missionProgress(daily!).clamp(0, daily!.need)
      : meta.weeklyProgress(weekly!).clamp(0, weekly!.need);

  int get _need => daily?.need ?? weekly!.need;
  int get _gold => daily?.gold ?? weekly!.gold;
  String get _label => daily?.label ?? weekly!.label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            _isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: _isDone ? CD.sage : CD.muted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _isDone ? CD.muted : CD.leather,
                    decoration:
                        _isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                // 인라인 얇은 진행바
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _need == 0 ? 0 : _prog / _need,
                    minHeight: 3,
                    backgroundColor: CD.sand,
                    color: _isDone ? CD.sage : CD.rust,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '+$_gold',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: _isDone ? CD.muted : CD.gold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ⑤ 트로피 로드 — ExpansionTile, 기본: 미달성 2개만 표시
// ─────────────────────────────────────────────────────────────────────────────

class _TrophyRoadTile extends StatefulWidget {
  const _TrophyRoadTile({required this.meta});
  final Meta meta;

  @override
  State<_TrophyRoadTile> createState() => _TrophyRoadTileState();
}

class _TrophyRoadTileState extends State<_TrophyRoadTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final meta = widget.meta;
    final claimedCount = kTrophyRoad.where(meta.trophyClaimed).length;
    final allDone = claimedCount == kTrophyRoad.length;
    // 기본 보여줄 항목: 미달성 첫 2개
    final preview = kTrophyRoad.where((t) => !meta.trophyClaimed(t)).take(2).toList();
    final all = kTrophyRoad.where((t) => !meta.trophyClaimed(t)).toList();

    return Container(
      decoration: BoxDecoration(
        color: CD.parchment.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(CD.rCard),
        border: Border.all(color: CD.leather.withValues(alpha: 0.25)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          childrenPadding: EdgeInsets.zero,
          onExpansionChanged: (v) => setState(() => _expanded = v),
          title: Row(
            children: [
              Text('트로피 로드', style: posterTitle(18)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: allDone
                      ? CD.gold.withValues(alpha: 0.2)
                      : CD.leather.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(CD.rChip),
                ),
                child: Text('$claimedCount/${kTrophyRoad.length}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: allDone ? CD.gold : CD.muted)),
              ),
            ],
          ),
          subtitle: Text(
              '통산 ${meta.lifeGames}판 · ${meta.lifeWins}승 (평생 기록)',
              style:
                  const TextStyle(fontSize: 11, color: CD.muted)),
          trailing: Icon(
            _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: CD.muted,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (allDone)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('모든 트로피를 달성했어요! 대단해요, 총잡이!',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    )
                  else ...[
                    // 접힌 상태: preview, 펼친 상태: all
                    for (final t in _expanded ? all : preview)
                      _TrophyRow(t: t, meta: meta),
                    if (!_expanded && all.length > 2)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '+ ${all.length - 2}개 더 — 탭하면 전부 보여요',
                          style: const TextStyle(
                              fontSize: 11,
                              color: CD.muted,
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrophyRow extends StatelessWidget {
  const _TrophyRow({required this.t, required this.meta});
  final TrophyMilestone t;
  final Meta meta;

  @override
  Widget build(BuildContext context) {
    final prog = meta.trophyProgress(t).clamp(0, t.need);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            t.wins ? Icons.emoji_events : Icons.sports_esports,
            size: 17,
            color: t.wins ? CD.gold : CD.sage,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('${t.label}  ($prog/${t.need})',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: CD.leather)),
                    ),
                    Text('+${t.gold}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: CD.gold,
                            fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: t.need == 0 ? 0 : prog / t.need,
                    minHeight: 4,
                    backgroundColor: CD.sand,
                    color: t.wins ? CD.gold : CD.sage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 코인 얻는 법 카드
// ─────────────────────────────────────────────────────────────────────────────

class _EarnInfoCard extends StatelessWidget {
  const _EarnInfoCard({required this.meta});
  final Meta meta;

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('코인 얻는 법', style: posterTitle(18)),
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
    );
  }

  Widget _earnRow(
      IconData icon, Color color, String title, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800))),
          Text(amount,
              style: const TextStyle(color: CD.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ⑥ 선물 코드 — 접힌 링크형 ExpansionTile
// ─────────────────────────────────────────────────────────────────────────────

class _GiftCodeTile extends StatelessWidget {
  const _GiftCodeTile({
    required this.codeCtl,
    required this.redeeming,
    required this.onRedeem,
  });

  final TextEditingController codeCtl;
  final bool redeeming;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CD.parchment.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(CD.rCard),
        border: Border.all(color: CD.leather.withValues(alpha: 0.25)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          childrenPadding: EdgeInsets.zero,
          leading: const Icon(Icons.card_giftcard, color: CD.rust, size: 20),
          title: Text('선물 코드', style: posterTitle(17)),
          subtitle: const Text('코드가 있다면 여기서 입력하세요',
              style: TextStyle(fontSize: 11, color: CD.muted)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('받은 코드를 입력하면 코인을 드려요. (코드당 계정 1회)',
                      style: TextStyle(color: CD.muted, fontSize: 12)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: codeCtl,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => onRedeem(),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: '코드 입력',
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.7),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(CD.rCard),
                              borderSide:
                                  const BorderSide(color: CD.leather),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: redeeming ? null : onRedeem,
                        style: FilledButton.styleFrom(
                          backgroundColor: CD.rust,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(CD.rCard)),
                        ),
                        child: redeeming
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Text('받기',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 공용 카드 컨테이너
// ─────────────────────────────────────────────────────────────────────────────

Widget _card({required Widget child}) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CD.parchment.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(CD.rCard),
        border: Border.all(color: CD.leather.withValues(alpha: 0.25)),
      ),
      child: child,
    );
