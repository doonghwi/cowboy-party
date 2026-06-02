import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/desert_background.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('게임 방법', style: posterTitle(22))),
      body: DesertBackground(
        bright: true,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: const [
              _Rule(
                icon: Icons.groups,
                color: CD.rust,
                title: '2~6명이 원으로',
                body: '온라인 방 또는 컴퓨터와 대결로 2~6명이 둥글게 앉아요. '
                    '마지막까지 살아남은 한 명이 승리합니다.',
              ),
              _Rule(
                icon: Icons.touch_app,
                color: CD.gold,
                title: '매 턴 한 가지 행동',
                body: '장전 · 방어 · 빵야 중 매 턴 딱 하나만 골라요. '
                    '모두 동시에 고른 뒤 한꺼번에 공개해 판정합니다.',
              ),
              _Rule(
                icon: Icons.cached,
                color: CD.gold,
                title: '장전',
                body: '총알을 한 발 채워요(최대 6발). 빵야는 이전 턴까지 모아둔 총알로만 쏠 수 있어요. '
                    '이번 턴에 장전한 총알은 다음 턴부터 사용 — 그래서 첫 턴엔 못 쏴요.',
              ),
              _Rule(
                icon: Icons.local_fire_department,
                color: CD.danger,
                title: '빵야 (아무나 1명)',
                body: '살아있는 다른 누구든 한 명을 골라 쏴요(원에서 탭). '
                    '총알이 1발 이상 있어야 하고, 쏘면 1발이 줄어요.',
              ),
              _Rule(
                icon: Icons.shield,
                color: CD.sage,
                title: '방어 (전부 막기)',
                body: '이번 턴에 나에게 오는 공격을 모두 막아요. '
                    '여러 명이 동시에 나를 쏴도 방어 한 번이면 전부 무효!',
              ),
              _Rule(
                icon: Icons.emoji_events,
                color: CD.leather,
                title: '승리 / 무승부',
                body: '막지 못하고 한 발이라도 맞으면 즉시 탈락! 같은 턴에 여러 명이 함께 탈락할 수도 있어요. '
                    '마지막 1인이 승자, 모두 동시에 쓰러지면 무승부예요.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _Rule({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CD.parchment.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: posterTitle(18, color: color)),
                const SizedBox(height: 4),
                Text(body,
                    style: const TextStyle(
                        color: CD.ink, fontSize: 13.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
