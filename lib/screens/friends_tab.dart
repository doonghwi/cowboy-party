import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/sfx.dart';
import '../game/characters.dart';
import '../meta/auth_service.dart';
import '../meta/meta_service.dart';
import '../online/friend_service.dart';
import '../online/online_service.dart';
import '../theme.dart';
import '../widgets/character_portrait.dart';
import '../widgets/rank_emblem.dart';
import '../widgets/top_toast.dart';
import 'online_game_screen.dart';

/// 친구 탭(#1, 2026-07-15 사용자 지시) — 클래시 로얄 로비처럼 소셜 허브 하나로:
/// 내 프로필 카드 · 받은 요청 · 친구 목록(프로필/친선전) · 최근 함께 플레이 ·
/// 닉네임으로 추가. 로비 컴포넌트는 배경을 채운 카드(테두리만 X — 사용자 규칙).
class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  final _nickCtl = TextEditingController();
  Map<String, bool> _online = {};
  Timer? _poll;
  List<FriendInfo> _friends = const [];
  List<String> _recent = const [];
  bool _sending = false;
  bool _makingRoom = false;

  @override
  void initState() {
    super.initState();
    // 게스트도 익명 인증을 마쳐야 친구 노드를 읽을 수 있다 — 탭 진입 시 보장.
    // (온라인 행동을 한 번도 안 한 게스트가 '연결 중'에 머물던 문제, 2026-07-15)
    AuthService.I.tryAnonymous().then((_) {
      if (mounted) setState(() {});
    });
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
    _loadRecent();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _nickCtl.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final r = await FriendService.I.recentPlayers();
    if (mounted) setState(() => _recent = r);
  }

  Future<void> _refresh() async {
    if (_friends.isEmpty) return;
    final m =
        await FriendService.I.presenceOf(_friends.map((f) => f.uid).toList());
    if (mounted) setState(() => _online = m);
  }

  Future<void> _add([String? nickname]) async {
    if (_sending) return;
    setState(() => _sending = true);
    final err = await FriendService.I.sendRequest(nickname ?? _nickCtl.text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (err.isEmpty) {
      if (nickname == null) _nickCtl.clear();
      Sfx.confirm();
      TopToast.show(context, message: '친구 요청을 보냈어요! 상대가 수락하면 친구가 돼요');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating, content: Text(err)));
    }
  }

  /// 친선전: 비공개 2인 방을 만들어 친구를 초대하고 바로 대기실로.
  Future<void> _friendly(FriendInfo f) async {
    if (_makingRoom) return;
    setState(() => _makingRoom = true);
    final service = OnlineService();
    final name = Meta.I.nickname.isNotEmpty
        ? Meta.I.nickname
        : OnlineService.randomNickname();
    final code = OnlineService.generateRoomCode();
    try {
      await service.createRoom(code, name, 2,
          charIndex: Meta.I.equippedIndex,
          public: false,
          title: '$name vs ${f.name} 친선전');
      await FriendService.I.invite(f.uid, code);
    } catch (_) {
      if (mounted) {
        setState(() => _makingRoom = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('친선전 방을 만들지 못했어요 — 연결을 확인해 주세요'),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _makingRoom = false);
    Sfx.confirm();
    TopToast.show(context, message: '${f.name}님에게 친선전 초대를 보냈어요!');
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OnlineGameScreen(service: service, code: code)));
  }

  /// 친구 프로필 — 지금 가진 정보(이름·온라인)만 담백하게 + 친선전/삭제.
  void _profile(FriendInfo f) {
    final online = _online[f.uid] ?? false;
    showModalBottomSheet(
      context: context,
      backgroundColor: CD.parchment,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: online ? CD.sage : CD.muted,
                child:
                    const Icon(Icons.person, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 10),
              Text(f.name, style: posterTitle(22)),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle,
                      size: 10,
                      color: online ? const Color(0xFF3FA66A) : CD.muted),
                  const SizedBox(width: 5),
                  Text(online ? '온라인' : '오프라인',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: online
                              ? const Color(0xFF3FA66A)
                              : CD.muted)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: online
                      ? () {
                          Navigator.pop(ctx);
                          _friendly(f);
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: CD.rust,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.sports_kabaddi, size: 18),
                  label: Text(online ? '1:1 친선전 신청' : '오프라인 — 친선전 불가',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  FriendService.I.removeFriend(f.uid);
                  TopToast.show(context, message: '${f.name}님을 친구에서 삭제했어요');
                },
                child: const Text('친구 삭제',
                    style: TextStyle(color: CD.muted, fontSize: 12.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 카드 프레임: 배경을 채운 컴포넌트(사용자 규칙 2026-07-15) ──
  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CD.parchment.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      );

  Widget _sectionTitle(String emoji, String title, [String? sub]) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('$emoji $title',
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: CD.leather)),
            if (sub != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 11, color: CD.muted)),
              ),
            ],
          ],
        ),
      );

  Widget _myProfileCard() {
    final def = charDef(Meta.I.equipped);
    final name =
        Meta.I.nickname.isNotEmpty ? Meta.I.nickname : '닉네임 미설정';
    final rank = OnlineService.profileRank;
    final tier = rank > 0 ? tierForRank(rank) : null;
    return _card(
      child: Row(
        children: [
          CharacterPortrait(
              id: def.id.name, icon: def.icon, color: def.color, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 17)),
                    ),
                    if (tier != null) ...[
                      const SizedBox(width: 6),
                      RankEmblem(tier: tier, size: 16),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text('Lv.${OnlineService.profileLevel} · ${def.name}',
                    style: const TextStyle(fontSize: 12, color: CD.muted)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: CD.sage,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: Colors.white),
                SizedBox(width: 5),
                Text('온라인',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _friendRow(FriendInfo f) {
    final online = _online[f.uid] ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: online ? CD.sage : CD.muted.withValues(alpha: 0.6),
            child: const Icon(Icons.person, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
                Text(online ? '온라인' : '오프라인',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: online
                            ? const Color(0xFF3FA66A)
                            : CD.muted)),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => _profile(f),
            style: FilledButton.styleFrom(
              backgroundColor: CD.leather,
              visualDensity: VisualDensity.compact,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('프로필',
                style:
                    TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: online && !_makingRoom ? () => _friendly(f) : null,
            style: FilledButton.styleFrom(
              backgroundColor: CD.rust,
              visualDensity: VisualDensity.compact,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('친선전',
                style:
                    TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reqStream = FriendService.I.watchRequests();
    final friendStream = FriendService.I.watchFriends();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        _myProfileCard(),
        // 받은 요청 — 있을 때만 카드로.
        if (reqStream != null)
          StreamBuilder<List<FriendRequest>>(
            stream: reqStream,
            builder: (context, snap) {
              final reqs = snap.data ?? const <FriendRequest>[];
              if (reqs.isEmpty) return const SizedBox.shrink();
              return _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionTitle('📨', '받은 요청'),
                    for (final q in reqs)
                      Row(
                        children: [
                          Expanded(
                              child: Text(q.fromName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800))),
                          FilledButton(
                            onPressed: () async {
                              final ok = await FriendService.I.accept(q);
                              if (ok && context.mounted) {
                                Sfx.coin();
                                TopToast.show(context,
                                    message: '${q.fromName}님과 친구가 됐어요!');
                              }
                            },
                            style: FilledButton.styleFrom(
                                backgroundColor: CD.sage,
                                visualDensity: VisualDensity.compact),
                            child: const Text('수락',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12)),
                          ),
                          TextButton(
                            onPressed: () => FriendService.I.decline(q),
                            child: const Text('거절',
                                style: TextStyle(
                                    color: CD.muted, fontSize: 12)),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        // 친구 목록.
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle('👥', '친구', '온라인 친구에게 1:1 친선전을 신청해 보세요'),
              if (friendStream == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('연결 중이에요 — 잠시 후 다시 열어주세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: CD.muted)),
                )
              else
                StreamBuilder<List<FriendInfo>>(
                  stream: friendStream,
                  builder: (context, snap) {
                    final fs = snap.data ?? const <FriendInfo>[];
                    if (fs.length != _friends.length) {
                      _friends = fs;
                      Future.microtask(_refresh);
                    } else {
                      _friends = fs;
                    }
                    if (fs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                            '아직 친구가 없어요 — 아래에서 닉네임으로 요청해 보세요!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: CD.muted)),
                      );
                    }
                    return Column(
                        children: [for (final f in fs) _friendRow(f)]);
                  },
                ),
            ],
          ),
        ),
        // 최근 함께 플레이 — 친구 추천.
        if (_recent.isNotEmpty)
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionTitle('🕰️', '최근 함께 플레이', '같이 논 카우보이에게 친구 요청'),
                for (final n in _recent.take(6))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              CD.duneFar.withValues(alpha: 0.8),
                          child: const Icon(Icons.history,
                              color: Colors.white, size: 15),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(n,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5))),
                        FilledButton.icon(
                          onPressed: _sending ? null : () => _add(n),
                          style: FilledButton.styleFrom(
                            backgroundColor: CD.sage,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.person_add_alt_1,
                              size: 14),
                          label: const Text('친구 요청',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11.5)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        // 닉네임으로 추가.
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle('🔍', '닉네임으로 친구 추가'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nickCtl,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _add(),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '친구 닉네임 입력',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.8),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ? null : _add,
                    style: FilledButton.styleFrom(
                      backgroundColor: CD.sage,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('요청',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text('닉네임은 랭킹에 보이는 이름 그대로 입력하면 돼요.',
                  style: TextStyle(fontSize: 11.5, color: CD.muted)),
            ],
          ),
        ),
      ],
    );
  }
}
