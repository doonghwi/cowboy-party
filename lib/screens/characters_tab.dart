import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/sfx.dart';
import '../game/characters.dart';
import '../meta/meta_service.dart';
import '../theme.dart';
import 'offline_game_screen.dart';

/// 상점 탭: 캐릭터 구매·장착 + 튜토리얼 진입(E1/E3). 설명은 잘리지 않게 스크롤(E2).
class CharactersTab extends StatefulWidget {
  const CharactersTab({super.key});

  @override
  State<CharactersTab> createState() => _CharactersTabState();
}

class _CharactersTabState extends State<CharactersTab> {
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

  // G2: 닉네임 변경(변경권 1장 소모, 첫 설정은 무료). 상점에서 진행.
  void _changeNickname(BuildContext context) {
    final meta = Meta.I;
    final free = meta.canChangeNicknameFree;
    if (!free && meta.nicknameTickets <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('닉네임 변경권이 없어요 — 먼저 구매해 주세요'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final ctl = TextEditingController(text: meta.nickname);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CD.parchment,
        title: Text(free ? '닉네임 정하기' : '닉네임 변경', style: posterTitle(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctl,
              maxLength: 8,
              autofocus: true,
              decoration: const InputDecoration(
                counterText: '',
                hintText: '닉네임 (최대 8자)',
                border: UnderlineInputBorder(),
              ),
            ),
            Text(
              free
                  ? '첫 설정은 무료예요.'
                  : '변경권 ${meta.nicknameTickets}장 보유 — 변경 시 1장 사용',
              style: const TextStyle(fontSize: 12, color: CD.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CD.rust),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(ctx);
              final r = await Meta.I.changeNickname(ctl.text);
              nav.pop();
              messenger.showSnackBar(SnackBar(
                content: Text(r.message),
                behavior: SnackBarBehavior.floating,
              ));
            },
            child: Text(free ? '저장' : '변경권 사용',
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _buyNicknameTicket(BuildContext context) {
    final meta = Meta.I;
    if (meta.coins < kNicknameTicketCost) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '코인이 ${kNicknameTicketCost - meta.coins}개 부족해요'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CD.parchment,
        title: Text('닉네임 변경권', style: posterTitle(20)),
        content: const Text(
            '$kNicknameTicketCost코인으로 닉네임 변경권 1장을 살까요?\n'
            '여기 상점에서 닉네임을 바꿀 때 1장이 사용돼요.',
            style: TextStyle(height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CD.rust),
            onPressed: () {
              Navigator.pop(ctx);
              if (Meta.I.buyNicknameTicket()) {
                HapticFeedback.mediumImpact();
                Sfx.coin();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('닉네임 변경권 1장 구매 완료!'),
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            child: const Text('구매',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('카드를 누르면 능력 설명 + 체험(6명 봇전)을 할 수 있어요',
                style: TextStyle(color: CD.sand, fontSize: 12)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.70,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _CharCard(def: kCharacters[i]),
              childCount: kCharacters.length,
            ),
          ),
        ),
        // 닉네임 변경권은 모든 캐릭터 아래(맨 밑)에 배치.
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: _NicknameTicketCard(
              onBuy: () => _buyNicknameTicket(context),
              onChange: () => _changeNickname(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// 상점 상단 튜토리얼 진입 카드(E1/E3) — 일반인으로 vs 컴퓨터.
/// 닉네임 변경권 판매 + 변경 카드(E1/G2).
class _NicknameTicketCard extends StatelessWidget {
  final VoidCallback onBuy;
  final VoidCallback onChange;
  const _NicknameTicketCard({required this.onBuy, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final have = Meta.I.nicknameTickets;
    return Container(
      decoration: BoxDecoration(
        color: CD.parchment.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CD.gold, width: 2),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.badge, color: CD.gold, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('닉네임 변경권',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 15)),
                    if (have > 0) ...[
                      const SizedBox(width: 6),
                      Text('보유 $have장',
                          style: const TextStyle(
                              fontSize: 11.5,
                              color: CD.sage,
                              fontWeight: FontWeight.w800)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                const Text('상점에서 닉네임을 바꿀 때 1장 사용 (첫 설정은 무료)',
                    style: TextStyle(fontSize: 11.5, color: CD.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: CD.leather,
                    visualDensity: VisualDensity.compact),
                onPressed: onBuy,
                icon:
                    const Icon(Icons.monetization_on, color: CD.gold, size: 16),
                label: const Text('$kNicknameTicketCost',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              TextButton(
                onPressed: onChange,
                style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact),
                child: Text(Meta.I.canChangeNicknameFree ? '닉네임 정하기' : '바꾸기',
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CharCard extends StatelessWidget {
  final CharDef def;
  const _CharCard({required this.def});

  // E2/E3: 카드 탭 → 능력 전문(잘림 없음) + '체험'(6명 봇전, 미보유도 가능).
  void _showDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CD.parchment,
        title: Row(
          children: [
            CircleAvatar(
                radius: 18,
                backgroundColor: def.color,
                child: Icon(def.icon, color: Colors.white, size: 20)),
            const SizedBox(width: 10),
            Expanded(child: Text(def.name, style: posterTitle(20))),
          ],
        ),
        content: Text(def.ability,
            style: const TextStyle(fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: CD.sage),
            onPressed: () {
              Navigator.pop(ctx);
              Sfx.confirm();
              // 미보유여도 그 직업으로 6명 봇전 체험.
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    OfflineGameScreen(forcedChar: def.id, forcedBots: 5),
              ));
            },
            icon: const Icon(Icons.sports_esports, size: 18),
            label: const Text('체험 (6명 봇전)',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meta = Meta.I;
    final unlocked = meta.isUnlocked(def.id);
    final equipped = meta.equipped == def.id;

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: CD.parchment.withValues(alpha: unlocked ? 0.96 : 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: equipped ? CD.gold : def.color.withValues(alpha: 0.65),
          width: equipped ? 3 : 2,
        ),
        boxShadow: equipped
            ? [BoxShadow(color: CD.gold.withValues(alpha: 0.45), blurRadius: 10)]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: def.color.withValues(alpha: unlocked ? 1 : 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(def.icon, color: Colors.white, size: 32),
                ),
                if (equipped)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: CD.gold, shape: BoxShape.circle),
                      child: const Icon(Icons.check,
                          size: 14, color: Colors.white),
                    ),
                  ),
                if (!unlocked)
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                          color: CD.leather, shape: BoxShape.circle),
                      child: const Icon(Icons.lock,
                          size: 13, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(def.name, style: posterTitle(17)),
            const SizedBox(height: 4),
            Expanded(
              // E2: 긴 설명도 잘리지 않게 — 넘치면 스크롤로 전부 읽힌다.
              child: SingleChildScrollView(
                child: Text(
                  def.ability,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11.5, color: CD.muted, height: 1.35),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: equipped
                  ? FilledButton(
                      onPressed: null,
                      style: FilledButton.styleFrom(
                        disabledBackgroundColor:
                            CD.gold.withValues(alpha: 0.85),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('장착됨',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900)),
                    )
                  : unlocked
                      ? FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: CD.sage,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Sfx.confirm();
                            Meta.I.equip(def.id);
                          },
                          child: const Text('장착',
                              style:
                                  TextStyle(fontWeight: FontWeight.w900)),
                        )
                      : FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: CD.leather,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _tryUnlock(context),
                          icon: Icon(
                              (def.id == CharId.mystery && !Meta.I.canBuyMystery)
                                  ? Icons.lock
                                  : Icons.monetization_on,
                              color: CD.gold,
                              size: 16),
                          label: Text(
                              (def.id == CharId.mystery && !Meta.I.canBuyMystery)
                                  ? '전 캐릭터 필요'
                                  : '${def.cost}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900)),
                        ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  void _tryUnlock(BuildContext context) {
    final meta = Meta.I;
    // ???는 다른 캐릭터를 모두 보유해야 구매 가능.
    if (def.id == CharId.mystery && !meta.canBuyMystery) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('다른 캐릭터를 모두 모은 뒤에 구매할 수 있어요'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (meta.coins < def.cost) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '코인이 ${def.cost - meta.coins}개 부족해요 — 승리·출석으로 모아보세요!'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CD.parchment,
        title: Text('${def.name} 해금', style: posterTitle(20)),
        content: Text('${def.ability}\n\n${def.cost}코인으로 해금할까요?',
            style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CD.rust),
            onPressed: () {
              Navigator.pop(ctx);
              if (Meta.I.unlock(def.id)) {
                HapticFeedback.mediumImpact();
                Sfx.coin();
                Meta.I.equip(def.id);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${def.name} 해금 + 장착 완료!'),
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            child: const Text('해금!',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}
