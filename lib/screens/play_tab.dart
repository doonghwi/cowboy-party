import 'dart:async';

import 'package:flutter/material.dart';

import '../meta/meta_service.dart';
import '../online/online_service.dart';
import '../theme.dart';
import '../widgets/emo.dart';
import 'how_to_play_screen.dart';
import 'offline_game_screen.dart';
import 'online_game_screen.dart';
import 'online_lobby_screen.dart';

/// 플레이 탭: 모드 버튼 + 공개 방 목록(방 브라우저).
class PlayTab extends StatefulWidget {
  const PlayTab({super.key});

  @override
  State<PlayTab> createState() => _PlayTabState();
}

class _PlayTabState extends State<PlayTab> {
  final _service = OnlineService();
  List<PublicRoomInfo>? _rooms;
  bool _loading = false;
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    _refresh();
    _auto = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  @override
  void dispose() {
    _auto?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    // 다른 화면(게임 등)이 위에 떠 있으면 폴링하지 않는다 — 트래픽 절약.
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    _loading = true;
    try {
      final rooms = await _service.fetchPublicRooms();
      if (mounted) setState(() => _rooms = rooms);
    } catch (_) {
      if (mounted && _rooms == null) setState(() => _rooms = const []);
    } finally {
      _loading = false;
    }
  }

  String get _myName {
    final n = Meta.I.nickname;
    return n.isEmpty ? OnlineService.randomNickname() : n;
  }

  Future<void> _joinPublic(PublicRoomInfo r) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final res = await _service.joinRoom(r.code, _myName,
        charIndex: Meta.I.equippedIndex);
    if (!mounted) return;
    switch (res) {
      case JoinResult.joined:
        nav.push(MaterialPageRoute(
            builder: (_) =>
                OnlineGameScreen(service: _service, code: r.code)));
      case JoinResult.full:
        messenger.showSnackBar(const SnackBar(content: Text('방이 꽉 찼어요')));
        _refresh();
      case JoinResult.notFound:
        messenger
            .showSnackBar(const SnackBar(content: Text('방이 사라졌어요')));
        _refresh();
      case JoinResult.alreadyStarted:
        messenger.showSnackBar(
            const SnackBar(content: Text('이미 시작된 방이에요 — 다음 판부터 참여돼요')));
      case JoinResult.wrongPassword:
        // 공개 방 목록에선 비밀번호가 없지만, 만약을 위해 안내.
        messenger.showSnackBar(
            const SnackBar(content: Text('비공개 방이에요 — 코드로 입장해 주세요')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: CD.rust,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          Row(
            children: [
              Expanded(
                child: _modeCard(
                  icon: Icons.smart_toy,
                  color: CD.rust,
                  title: '컴퓨터와 대결',
                  sub: '봇 1~5명',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const OfflineGameScreen())),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _modeCard(
                  icon: Icons.add_circle,
                  color: CD.sage,
                  title: '방 만들기',
                  sub: '공개/비공개 2~6인',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const OnlineLobbyScreen())),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // H3: 게임 방법 진입을 눈에 잘 띄는 전체폭 배너로.
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const HowToPlayScreen())),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: CD.gold.withValues(alpha: 0.16),
                border: Border.all(color: CD.gold.withValues(alpha: 0.7)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.menu_book, size: 20, color: CD.gold),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('처음이세요? 게임 방법 · 캐릭터 능력 보기',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5)),
                  ),
                  Icon(Icons.chevron_right,
                      color: CD.sand.withValues(alpha: 0.9), size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('공개 방', style: posterTitle(20, color: Colors.white)),
              const SizedBox(width: 8),
              if (_rooms != null)
                Text('${_rooms!.where((r) => !r.started).length}개 대기 중',
                    style: TextStyle(
                        color: CD.sand.withValues(alpha: 0.9), fontSize: 12.5)),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _refresh,
                icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const OnlineLobbyScreen(
                            startOnJoinCard: true))),
                child: const Text('코드로 입장',
                    style: TextStyle(
                        color: CD.gold, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_rooms == null)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: CD.rust)),
            )
          else if (_rooms!.isEmpty)
            _emptyState()
          else
            for (final r in _rooms!) _roomRow(r),
        ],
      ),
    );
  }

  Widget _modeCard({
    required IconData icon,
    required Color color,
    required String title,
    required String sub,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: CD.parchment.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 6),
              Text(title, style: posterTitle(17)),
              Text(sub,
                  style: const TextStyle(color: CD.muted, fontSize: 11.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Emo('cowboy', size: 52),
          const SizedBox(height: 10),
          Text('아직 열린 방이 없어요',
              style: posterTitle(18, color: Colors.white)),
          const SizedBox(height: 4),
          Text('첫 결투장을 열고 친구를 불러보세요!',
              style: TextStyle(color: CD.sand.withValues(alpha: 0.9))),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: CD.sage),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const OnlineLobbyScreen())),
            icon: const Icon(Icons.add),
            label: const Text('방 만들기',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _roomRow(PublicRoomInfo r) {
    final full = r.joined >= r.capacity;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: CD.parchment.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CD.leather.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  '${r.hostName} · ${r.joined}/${r.capacity}명'
                  '${r.started ? " · 게임 중" : ""}',
                  style: const TextStyle(color: CD.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: r.started ? CD.gold : CD.rust,
              disabledBackgroundColor: CD.muted.withValues(alpha: 0.35),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: full ? null : () => _joinPublic(r),
            child: Text(
              full ? '꽉 참' : (r.started ? '관전 입장' : '입장'),
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
