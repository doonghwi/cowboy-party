import 'package:flutter/material.dart';

import '../meta/auth_service.dart';
import '../meta/meta_service.dart';
import '../meta/season_service.dart';
import '../theme.dart';

/// 랭킹 탭: 월별 시즌 포인트 상위 50 + 내 상태 + 로그인 유도.
class RankingTab extends StatefulWidget {
  const RankingTab({super.key});

  @override
  State<RankingTab> createState() => _RankingTabState();
}

class _RankingTabState extends State<RankingTab> {
  late Future<List<RankEntry>> _top;

  @override
  void initState() {
    super.initState();
    _top = SeasonService.I.fetchTop();
  }

  Future<void> _refresh() async {
    setState(() => _top = SeasonService.I.fetchTop());
    await _top;
  }

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService.I.cloudUid;
    return RefreshIndicator(
      color: CD.rust,
      onRefresh: _refresh,
      child: FutureBuilder<List<RankEntry>>(
        future: _top,
        builder: (context, snap) {
          final list = snap.data;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              Row(
                children: [
                  Text(SeasonService.seasonLabel,
                      style: posterTitle(19, color: Colors.white)),
                  const Spacer(),
                  Text('승리 +10×(인원-1)점',
                      style: TextStyle(
                          color: CD.sand.withValues(alpha: 0.9),
                          fontSize: 11.5)),
                ],
              ),
              const SizedBox(height: 10),
              if (!AuthService.I.isGoogle) _loginNudge(),
              if (list == null)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child:
                      Center(child: CircularProgressIndicator(color: CD.rust)),
                )
              else if (list.isEmpty)
                _empty()
              else ...[
                for (var i = 0; i < list.length; i++)
                  _rankRow(i + 1, list[i], list[i].uid == myUid),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _loginNudge() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CD.parchment.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CD.gold, width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: CD.gold, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('랭킹에 이름을 올려보세요!',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                Text(
                  '지금은 게스트 — 설정(⚙️)에서 Google 로그인하면 승리 포인트가 랭킹에 등록돼요.'
                  ' (이번 시즌 내 포인트: ${Meta.I.seasonPtsLocal})',
                  style: const TextStyle(fontSize: 11.5, color: CD.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.emoji_events_outlined,
              size: 48, color: Colors.white70),
          const SizedBox(height: 10),
          Text('아직 이번 시즌 기록이 없어요',
              style: posterTitle(17, color: Colors.white)),
          Text('첫 승리의 주인공이 되어보세요!',
              style: TextStyle(color: CD.sand.withValues(alpha: 0.9))),
        ],
      ),
    );
  }

  Widget _rankRow(int rank, RankEntry e, bool isMe) {
    final medal = switch (rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => null,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? CD.gold.withValues(alpha: 0.35)
            : CD.parchment.withValues(alpha: rank <= 3 ? 0.98 : 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? CD.gold
              : rank <= 3
                  ? CD.rust.withValues(alpha: 0.5)
                  : CD.leather.withValues(alpha: 0.18),
          width: isMe ? 2.5 : 1.5,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: medal != null
                ? Text(medal, style: const TextStyle(fontSize: 20))
                : Text('$rank',
                    textAlign: TextAlign.center,
                    style: westernLatin(16, color: CD.muted)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isMe ? '${e.name} (나)' : e.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: isMe ? FontWeight.w900 : FontWeight.w700),
            ),
          ),
          Text('${e.pts}점',
              style: const TextStyle(
                  fontWeight: FontWeight.w900, color: CD.leather)),
        ],
      ),
    );
  }
}
