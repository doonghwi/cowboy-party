import 'package:flutter/material.dart';

import '../game/characters.dart';
import '../theme.dart';
import 'character_portrait.dart';

/// 캐릭터 선택 페이저 시트(#8, 2026-07-15 사용자 지시).
///
/// 아이콘 그리드 대신 **일러스트가 주인공**: 한 장씩 좌우 스와이프로 넘기며
/// 능력 설명을 함께 읽고 고른다. 표시 전용 — 선택 결과는 [onPick]으로 위임.
Future<void> showCharPagerSheet(
  BuildContext context, {
  required List<CharDef> chars,
  required CharId current,
  required void Function(CharDef) onPick,
  String title = '캐릭터 변경',
  String confirmLabel = '이 캐릭터로 출전',
}) {
  final initial = chars.indexWhere((d) => d.id == current).clamp(0, chars.length - 1);
  final controller = PageController(initialPage: initial, viewportFraction: 0.82);
  return showModalBottomSheet(
    context: context,
    backgroundColor: CD.parchment,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      var page = initial;
      return StatefulBuilder(
        builder: (ctx, setState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: CD.muted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 10),
                Text(title, style: posterTitle(20)),
                const SizedBox(height: 4),
                const Text('좌우로 넘겨 능력을 살펴보세요',
                    style: TextStyle(color: CD.muted, fontSize: 12)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 330,
                  child: PageView.builder(
                    controller: controller,
                    itemCount: chars.length,
                    onPageChanged: (i) => setState(() => page = i),
                    itemBuilder: (ctx, i) {
                      final d = chars[i];
                      final active = i == page;
                      return AnimatedScale(
                        scale: active ? 1 : 0.92,
                        duration: const Duration(milliseconds: 180),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: active
                                    ? d.color
                                    : CD.leather.withValues(alpha: 0.25),
                                width: active ? 2.5 : 1.5),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: CharacterHero(
                                    id: d.id.name,
                                    icon: d.icon,
                                    color: d.color,
                                    height: 170),
                              ),
                              const SizedBox(height: 8),
                              Text(d.name, style: posterTitle(20)),
                              const SizedBox(height: 5),
                              // 대사 칸(위) + 능력 칸(아래) — 문구 C안(2026-07-15).
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: d.color.withValues(alpha: 0.14),
                                  borderRadius:
                                      BorderRadius.circular(CD.rChip),
                                ),
                                child: Text(d.quote,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.w700,
                                        color: d.color)),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.white.withValues(alpha: 0.6),
                                  borderRadius:
                                      BorderRadius.circular(CD.rChip),
                                ),
                                child: Text(d.ability,
                                    textAlign: TextAlign.center,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        height: 1.35,
                                        color: CD.ink)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < chars.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: i == page ? 9 : 6,
                        height: i == page ? 9 : 6,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == page
                              ? chars[page].color
                              : CD.muted.withValues(alpha: 0.4),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        onPick(chars[page]);
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: chars[page].color,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: Icon(
                          chars[page].id == current
                              ? Icons.check_circle
                              : Icons.swap_horiz,
                          size: 18),
                      label: Text(
                          chars[page].id == current
                              ? '지금 캐릭터예요'
                              : confirmLabel,
                          style:
                              const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  ).whenComplete(controller.dispose);
}
