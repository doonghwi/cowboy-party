import 'package:flutter/material.dart';

import '../game/characters.dart';
import '../theme.dart';

/// 게임 중 좌석 탭 → 프로필 + 캐릭터 능력 팝업 (G3 + 결정④).
/// 개인정보는 표시하지 않는다(닉네임·점수·능력만). [score]가 null이면 점수 숨김.
void showSeatProfile(
  BuildContext context, {
  required String name,
  required CharId char,
  int? score,
}) {
  final def = charDef(char);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: CD.parchment,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: def.color,
            child: Icon(def.icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(name, style: posterTitle(20))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (score != null) ...[
            Text('점수 $score',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: CD.leather)),
            const SizedBox(height: 8),
          ],
          Text(char == CharId.none ? '캐릭터' : def.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            char == CharId.none ? '기본 총잡이' : def.ability,
            style: const TextStyle(fontSize: 13, height: 1.45, color: CD.muted),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
      ],
    ),
  );
}
