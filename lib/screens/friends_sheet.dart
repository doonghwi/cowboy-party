import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/sfx.dart';
import '../online/friend_service.dart';
import '../theme.dart';
import '../widgets/top_toast.dart';

/// 친구 시트(MVP): 받은 요청 수락/거절 · 친구 목록(온라인 표시) ·
/// 닉네임으로 추가. [onInvite]가 있으면(대기실에서 열림) 온라인 친구에게
/// "초대" 버튼이 보인다.
Future<void> showFriendsSheet(BuildContext context,
    {void Function(String uid)? onInvite,
    Set<String> inRoomUids = const {}}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: CD.sand,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _FriendsSheet(onInvite: onInvite, inRoomUids: inRoomUids),
  );
}

class _FriendsSheet extends StatefulWidget {
  const _FriendsSheet({this.onInvite, this.inRoomUids = const {}});
  final void Function(String uid)? onInvite;

  /// 이미 이 방에 있는 친구 uid — 초대 대신 '같이 있음' 표시(2026-07-16 제보).
  final Set<String> inRoomUids;

  @override
  State<_FriendsSheet> createState() => _FriendsSheetState();
}

class _FriendsSheetState extends State<_FriendsSheet> {
  final _nickCtl = TextEditingController();
  Map<String, bool> _online = {};
  Timer? _poll;
  List<FriendInfo> _friends = const [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _nickCtl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_friends.isEmpty) return;
    final m =
        await FriendService.I.presenceOf(_friends.map((f) => f.uid).toList());
    if (mounted) setState(() => _online = m);
  }

  Future<void> _add() async {
    if (_sending) return;
    setState(() => _sending = true);
    final err = await FriendService.I.sendRequest(_nickCtl.text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (err.isEmpty) {
      _nickCtl.clear();
      Sfx.confirm();
      TopToast.show(context, message: '친구 요청을 보냈어요! 상대가 수락하면 친구가 돼요');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating, content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reqStream = FriendService.I.watchRequests();
    final friendStream = FriendService.I.watchFriends();
    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('👥 친구', style: posterTitle(20)),
              const Spacer(),
              const Text('온라인 친구를 방으로 초대해 보세요',
                  style: TextStyle(color: CD.muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          if (reqStream != null)
            StreamBuilder<List<FriendRequest>>(
              stream: reqStream,
              builder: (context, snap) {
                final reqs = snap.data ?? const <FriendRequest>[];
                if (reqs.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('받은 요청',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, color: CD.leather)),
                    for (final q in reqs)
                      Row(
                        children: [
                          Expanded(
                              child: Text(q.fromName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800))),
                          TextButton(
                            onPressed: () async {
                              final ok = await FriendService.I.accept(q);
                              if (ok && context.mounted) {
                                Sfx.coin();
                                TopToast.show(context,
                                    message: '${q.fromName}님과 친구가 됐어요!');
                              }
                            },
                            child: const Text('수락',
                                style: TextStyle(
                                    color: CD.sage,
                                    fontWeight: FontWeight.w900)),
                          ),
                          TextButton(
                            onPressed: () => FriendService.I.decline(q),
                            child: const Text('거절',
                                style: TextStyle(color: CD.muted)),
                          ),
                        ],
                      ),
                    const Divider(height: 18),
                  ],
                );
              },
            ),
          if (friendStream != null)
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
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text('아직 친구가 없어요 — 아래에 닉네임을 입력해 요청해 보세요!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: CD.muted)),
                  );
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final f in fs)
                        Row(
                          children: [
                            Icon(Icons.circle,
                                size: 10,
                                color: (_online[f.uid] ?? false)
                                    ? const Color(0xFF3FA66A)
                                    : CD.muted.withValues(alpha: 0.5)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(f.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800))),
                            Text((_online[f.uid] ?? false) ? '온라인' : '오프라인',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: (_online[f.uid] ?? false)
                                        ? const Color(0xFF3FA66A)
                                        : CD.muted)),
                            if (widget.onInvite != null &&
                                widget.inRoomUids.contains(f.uid)) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: CD.sage.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: const Text('같이 있음',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        color: CD.sage)),
                              ),
                            ] else if (widget.onInvite != null) ...[
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: (_online[f.uid] ?? false)
                                    ? () {
                                        widget.onInvite!(f.uid);
                                        Sfx.confirm();
                                        TopToast.show(context,
                                            message:
                                                '${f.name}님에게 초대를 보냈어요!');
                                      }
                                    : null,
                                style: FilledButton.styleFrom(
                                    backgroundColor: CD.rust,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8)),
                                child: const Text('초대',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12)),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
          const Divider(height: 20),
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
                    fillColor: Colors.white.withValues(alpha: 0.75),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: CD.leather)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _sending ? null : _add,
                style: FilledButton.styleFrom(
                    backgroundColor: CD.sage,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14)),
                child: const Text('친구 요청',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('닉네임은 랭킹에 보이는 이름 그대로 입력하면 돼요.',
              style: TextStyle(fontSize: 11.5, color: CD.muted)),
        ],
      ),
    );
  }
}
