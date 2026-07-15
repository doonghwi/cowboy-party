import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/sfx.dart';
import '../game/characters.dart';
import '../meta/meta_service.dart';
import '../theme.dart';
import '../widgets/character_portrait.dart';
import 'offline_game_screen.dart';

/// 상점 탭(2026-07-15 사용자 선택 A안): 캐릭터를 **캐러셀**로 한 명씩 —
/// 큰 일러스트가 주인공, 좌우 스와이프로 탐색. 문구는 C안(대사 칸 위 +
/// 능력 칸 아래, 두 칸 분리). 구매·장착·체험 로직은 기존 그대로.
class CharactersTab extends StatefulWidget {
  const CharactersTab({super.key});

  @override
  State<CharactersTab> createState() => _CharactersTabState();
}

class _CharactersTabState extends State<CharactersTab> {
  late final PageController _page;
  int _cur = 0;

  @override
  void initState() {
    super.initState();
    // 장착 중인 캐릭터에서 시작.
    _cur = kCharacters
        .indexWhere((c) => c.id == Meta.I.equipped)
        .clamp(0, kCharacters.length - 1);
    _page = PageController(initialPage: _cur, viewportFraction: 0.86);
    Meta.I.addListener(_onMeta);
  }

  @override
  void dispose() {
    Meta.I.removeListener(_onMeta);
    _page.dispose();
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

  void _tryUnlock(BuildContext context, CharDef def) {
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

  @override
  Widget build(BuildContext context) {
    // B5 도감(1차): 수집률 — 몇 명 모았는지 한눈에(완성 드라이브).
    final ownedCount =
        kCharacters.where((c) => Meta.I.isUnlocked(c.id)).length;
    final totalCount = kCharacters.length;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: CD.parchment.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Text('📖', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text('도감  $ownedCount / $totalCount',
                    style: posterTitle(16)),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: totalCount == 0 ? 0 : ownedCount / totalCount,
                      minHeight: 8,
                      backgroundColor: CD.sand,
                      color: CD.gold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                    '${(ownedCount * 100 / (totalCount == 0 ? 1 : totalCount)).round()}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, color: CD.leather)),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('좌우로 넘겨 총잡이들을 만나보세요 — 미보유 캐릭터도 체험할 수 있어요',
              style: TextStyle(color: CD.sand, fontSize: 12)),
        ),
        SizedBox(
          height: 470,
          child: PageView.builder(
            controller: _page,
            itemCount: kCharacters.length,
            onPageChanged: (i) => setState(() => _cur = i),
            itemBuilder: (context, i) => _CharPage(
                def: kCharacters[i],
                active: i == _cur,
                onUnlock: (d) => _tryUnlock(context, d)),
          ),
        ),
        const SizedBox(height: 8),
        // 페이지 도트 — 현재 캐릭터 색으로.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < kCharacters.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: i == _cur ? 9 : 5.5,
                height: i == _cur ? 9 : 5.5,
                margin: const EdgeInsets.symmetric(horizontal: 2.2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _cur
                      ? kCharacters[_cur].color
                      : CD.parchment.withValues(alpha: 0.5),
                ),
              ),
          ],
        ),
        // 닉네임 변경권은 캐러셀 아래(맨 밑)에 배치.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _NicknameTicketCard(
            onBuy: () => _buyNicknameTicket(context),
            onChange: () => _changeNickname(context),
          ),
        ),
      ],
    );
  }
}

/// 캐러셀 한 페이지 — 일러스트가 주인공, 대사 칸(위)/능력 칸(아래) 분리(C안).
class _CharPage extends StatelessWidget {
  final CharDef def;
  final bool active;
  final void Function(CharDef) onUnlock;
  const _CharPage(
      {required this.def, required this.active, required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    final meta = Meta.I;
    final unlocked = meta.isUnlocked(def.id);
    final equipped = meta.equipped == def.id;
    return AnimatedScale(
      scale: active ? 1 : 0.94,
      duration: const Duration(milliseconds: 180),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CD.parchment.withValues(alpha: unlocked ? 0.96 : 0.80),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: equipped ? CD.gold : def.color.withValues(alpha: 0.7),
            width: equipped ? 3 : 2,
          ),
          boxShadow: equipped
              ? [
                  BoxShadow(
                      color: CD.gold.withValues(alpha: 0.45), blurRadius: 10)
                ]
              : null,
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CharacterHero(
                        id: def.id.name,
                        icon: def.icon,
                        color: def.color,
                        height: 200),
                  ),
                  if (!unlocked)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                            color: CD.leather, shape: BoxShape.circle),
                        child: const Icon(Icons.lock,
                            size: 15, color: Colors.white),
                      ),
                    ),
                  if (equipped)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: CD.gold,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('장착 중',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(def.name, style: posterTitle(22)),
            const SizedBox(height: 6),
            // ── 대사 칸(위) — 캐릭터 개성 한 줄 ──
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: def.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(CD.rChip),
              ),
              child: Text(def.quote,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                      color: def.color,
                      height: 1.3)),
            ),
            const SizedBox(height: 6),
            // ── 능력 칸(아래) — 수치 포함 설명 ──
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(CD.rChip),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(def.icon, color: def.color, size: 16),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(def.ability,
                        style: const TextStyle(
                            fontSize: 12, height: 1.4, color: CD.ink)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: CD.leather,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Sfx.confirm();
                      // 미보유여도 그 직업으로 6명 봇전 체험.
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => OfflineGameScreen(
                            forcedChar: def.id, forcedBots: 5),
                      ));
                    },
                    icon: const Icon(Icons.sports_esports, size: 17),
                    label: const Text('체험',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _primaryAction(context, unlocked, equipped)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _primaryAction(BuildContext context, bool unlocked, bool equipped) {
    final lockedMystery =
        def.id == CharId.mystery && !Meta.I.canBuyMystery;
    if (equipped) {
      return FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(
          disabledBackgroundColor: CD.gold.withValues(alpha: 0.85),
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('장착됨',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900)),
      );
    }
    if (unlocked) {
      return FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: CD.sage,
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          Sfx.confirm();
          Meta.I.equip(def.id);
        },
        child: const Text('장착',
            style: TextStyle(fontWeight: FontWeight.w900)),
      );
    }
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: CD.rust,
        padding: const EdgeInsets.symmetric(vertical: 11),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => onUnlock(def),
      icon: Icon(lockedMystery ? Icons.lock : Icons.monetization_on,
          color: CD.gold, size: 17),
      label: Text(lockedMystery ? '모든 캐릭터 필요' : '${def.cost}',
          style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

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
