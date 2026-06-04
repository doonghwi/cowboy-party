import 'package:flutter/material.dart';

import '../online/auth_service.dart';
import '../online/ranking_service.dart';
import '../theme.dart';
import '../widgets/desert_background.dart';

/// Global ELO-style leaderboard. Online wins/losses move your rating; sign in
/// with Google so it follows you across devices.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ranking = RankingService();
    final myUid = AuthService().current?.uid;
    return Scaffold(
      appBar: AppBar(title: Text('랭킹', style: posterTitle(22))),
      body: DesertBackground(
        bright: true,
        child: SafeArea(
          child: StreamBuilder<List<RankEntry>>(
            stream: ranking.watchTop(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: CD.rust));
              }
              final rows = snap.data!;
              if (rows.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Text(
                      '아직 랭킹이 없어요.\n로그인하고 온라인에서 이겨 보세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: CD.leather,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                itemBuilder: (context, i) =>
                    _row(i + 1, rows[i], rows[i].uid == myUid),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _row(int rank, RankEntry e, bool isMe) {
    final medal = switch (rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => null,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? CD.gold.withValues(alpha: 0.28)
            : CD.parchment.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isMe ? CD.gold : CD.leather.withValues(alpha: 0.2),
            width: isMe ? 2 : 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: medal != null
                ? Text(medal, style: const TextStyle(fontSize: 22))
                : Text('$rank',
                    textAlign: TextAlign.center,
                    style: posterTitle(18, color: CD.muted)),
          ),
          const SizedBox(width: 6),
          if (e.photoUrl != null)
            CircleAvatar(radius: 16, backgroundImage: NetworkImage(e.photoUrl!))
          else
            const Icon(Icons.account_circle, color: CD.muted, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name,
                    overflow: TextOverflow.ellipsis,
                    style: posterTitle(16)),
                Text('${e.wins}승 ${e.losses}패',
                    style: const TextStyle(color: CD.muted, fontSize: 11.5)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${e.elo}',
                  style: posterTitle(20, color: CD.rust)),
              const Text('점',
                  style: TextStyle(color: CD.muted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
