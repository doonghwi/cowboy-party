import 'package:flutter/material.dart';

import '../game/party_logic.dart';
import '../meta/meta_service.dart';
import '../online/online_service.dart';
import '../theme.dart';
import '../widgets/desert_background.dart';
import 'online_game_screen.dart';

class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  final _service = OnlineService();
  final _titleCtl = TextEditingController();
  final _pwCtl = TextEditingController(); // 비공개 방 비밀번호(F3)
  bool _public = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _titleCtl.dispose();
    _pwCtl.dispose();
    super.dispose();
  }

  // 닉네임은 계정 닉네임(상점/온보딩에서만 변경). 로비에서 자유롭게 못 바꾼다.
  String get _name {
    final n = Meta.I.nickname.trim();
    return n.isEmpty ? OnlineService.randomNickname() : n;
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    if (!_public && _pwCtl.text.trim().isEmpty) {
      setState(() {
        _busy = false;
        _error = '비공개 방은 비밀번호를 정해주세요.';
      });
      return;
    }
    try {
      final code = OnlineService.generateRoomCode();
      // F2: 항상 6인 방으로 생성 — 방장이 대기실에서 빈 자리를 닫아 인원 조절.
      await _service.createRoom(code, _name, kMaxSeats,
          charIndex: Meta.I.equippedIndex,
          title: _titleCtl.text,
          public: _public,
          password: _pwCtl.text);
      if (!mounted) return;
      _open(code);
    } catch (e) {
      setState(() => _error = '방을 만들지 못했어요. 연결을 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _open(String code) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OnlineGameScreen(service: _service, code: code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('온라인 대전', style: posterTitle(20))),
      body: DesertBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                _card(
                  child: Row(
                    children: [
                      const Icon(Icons.badge, color: CD.rust, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '닉네임: ${Meta.I.nickname.isEmpty ? "(미설정)" : Meta.I.nickname}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                      const Text('상점에서 변경',
                          style: TextStyle(fontSize: 11.5, color: CD.muted)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('새 방 만들기', style: posterTitle(18)),
                      const SizedBox(height: 6),
                      const Text('6인 방이 만들어져요. 방장이 빈 자리를 닫아 인원을 정하고, '
                          '2명 이상이면 시작해요.',
                          style: TextStyle(color: CD.muted, fontSize: 12.5)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _titleCtl,
                        maxLength: 16,
                        decoration: _dec('방 제목 (비워두면 자동)'),
                      ),
                      const SizedBox(height: 6),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeTrackColor: CD.sage,
                        value: _public,
                        onChanged: (v) => setState(() => _public = v),
                        title: Text(_public ? '공개 방' : '비공개 방',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14)),
                        subtitle: Text(
                          _public
                              ? '방 목록에 노출 — 누구나 들어올 수 있어요'
                              : '목록에 안 보임 — 비밀번호를 아는 사람만 입장',
                          style:
                              const TextStyle(fontSize: 11.5, color: CD.muted),
                        ),
                      ),
                      if (!_public) ...[
                        const SizedBox(height: 6),
                        TextField(
                          controller: _pwCtl,
                          maxLength: 12,
                          decoration: _dec('방 비밀번호 (입장 시 필요)'),
                        ),
                      ],
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _busy ? null : _create,
                        style: FilledButton.styleFrom(
                          backgroundColor: CD.rust,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.add),
                        label: Text('방 만들기 (6인)',
                            style: posterTitle(17, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!,
                      style: const TextStyle(
                          color: CD.danger, fontWeight: FontWeight.bold)),
                ],
                if (_busy) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(color: CD.rust),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.7),
        counterText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CD.leather),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: CD.leather.withValues(alpha: 0.4)),
        ),
      );

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: CD.parchment.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CD.leather.withValues(alpha: 0.25)),
        ),
        child: child,
      );
}
