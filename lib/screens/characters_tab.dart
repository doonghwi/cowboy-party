import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/sfx.dart';
import '../game/characters.dart';
import '../meta/meta_service.dart';
import '../theme.dart';

/// 캐릭터 탭: 8종 카드 그리드 — 장착 / 코인 해금 (UX_UI.md §6 패턴).
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

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: kCharacters.length,
      itemBuilder: (context, i) => _CharCard(def: kCharacters[i]),
    );
  }
}

class _CharCard extends StatelessWidget {
  final CharDef def;
  const _CharCard({required this.def});

  @override
  Widget build(BuildContext context) {
    final meta = Meta.I;
    final unlocked = meta.isUnlocked(def.id);
    final equipped = meta.equipped == def.id;

    return AnimatedContainer(
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
              child: Text(
                def.ability,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11.5, color: CD.muted, height: 1.35),
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
                          icon: const Icon(Icons.monetization_on,
                              color: CD.gold, size: 16),
                          label: Text('${def.cost}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900)),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _tryUnlock(BuildContext context) {
    final meta = Meta.I;
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
