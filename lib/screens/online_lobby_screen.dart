import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/party_logic.dart';
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
  final _nameCtl = TextEditingController();
  final _codeCtl = TextEditingController();
  final _pwCtl = TextEditingController();
  int _capacity = 4;
  bool _isPublic = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameCtl.dispose();
    _codeCtl.dispose();
    _pwCtl.dispose();
    super.dispose();
  }

  String get _name {
    final n = _nameCtl.text.trim();
    return n.isEmpty ? OnlineService.randomNickname() : n;
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = OnlineService.generateRoomCode();
      await _service.createRoom(code, _name, _capacity,
          isPublic: _isPublic, password: _pwCtl.text);
      if (!mounted) return;
      _open(code);
    } catch (e) {
      setState(() => _error = '방을 만들지 못했어요. 연결을 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinByCode() async {
    final code = _codeCtl.text.trim().toUpperCase();
    if (code.length != 4) {
      setState(() => _error = '4자리 방 코드를 입력해요.');
      return;
    }
    await _attemptJoin(code);
  }

  /// Join [code], transparently prompting for a password if the room is locked.
  Future<void> _attemptJoin(String code, {String? password}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await _service.joinRoom(code, _name, password: password);
      if (!mounted) return;
      switch (res) {
        case JoinResult.joined:
          _open(code);
        case JoinResult.notFound:
          setState(() => _error = '그런 방이 없어요.');
        case JoinResult.full:
          setState(() => _error = '방이 꽉 찼어요.');
        case JoinResult.alreadyStarted:
          setState(() => _error = '이미 시작된 방이에요.');
        case JoinResult.wrongPassword:
          setState(() => _busy = false);
          final pw = await _promptPassword(code);
          if (pw != null && pw.isNotEmpty) {
            await _attemptJoin(code, password: pw);
          } else if (mounted) {
            setState(() => _error = '비밀번호가 필요한 방이에요.');
          }
          return;
      }
    } catch (e) {
      setState(() => _error = '입장에 실패했어요. 연결을 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _promptPassword(String code) async {
    final ctl = TextEditingController();
    final pw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CD.parchment,
        title: Text('🔒 방 $code', style: posterTitle(18)),
        content: TextField(
          controller: ctl,
          autofocus: true,
          obscureText: true,
          decoration: _dec('비밀번호'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CD.sage),
            onPressed: () => Navigator.pop(ctx, ctl.text),
            child: const Text('입장'),
          ),
        ],
      ),
    );
    ctl.dispose();
    return pw;
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('닉네임', style: posterTitle(18)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameCtl,
                        maxLength: 8,
                        decoration: _dec('비워두면 랜덤 이름'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _createCard(),
                const SizedBox(height: 16),
                _publicRoomsCard(),
                const SizedBox(height: 16),
                _joinByCodeCard(),
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

  Widget _createCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('새 방 만들기', style: posterTitle(18)),
          const SizedBox(height: 6),
          const Text('최대 인원을 고르고, 2명 이상 모이면 시작해요.',
              style: TextStyle(color: CD.muted, fontSize: 12.5)),
          const SizedBox(height: 12),
          const Text('최대 인원',
              style:
                  TextStyle(color: CD.leather, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (var c = kMinSeats; c <= kMaxSeats; c++)
                GestureDetector(
                  onTap: () => setState(() => _capacity = c),
                  child: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _capacity == c ? CD.sage : CD.sand,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: CD.sage, width: _capacity == c ? 2.5 : 1.5),
                    ),
                    child: Text('$c',
                        style: posterTitle(20,
                            color:
                                _capacity == c ? Colors.white : CD.leather)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeThumbColor: CD.sage,
            value: _isPublic,
            onChanged: (v) => setState(() => _isPublic = v),
            title: const Text('공개 방 (목록에 표시)',
                style: TextStyle(
                    color: CD.leather, fontWeight: FontWeight.w700)),
            subtitle: Text(_isPublic ? '누구나 목록에서 보고 들어와요' : '코드를 아는 사람만 입장',
                style: const TextStyle(color: CD.muted, fontSize: 12)),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _pwCtl,
            maxLength: 12,
            decoration: _dec('비밀번호(선택) — 비우면 누구나 입장'),
          ),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: _busy ? null : _create,
            style: FilledButton.styleFrom(
              backgroundColor: CD.rust,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.add),
            label: Text('방 만들기 ($_capacity인)',
                style: posterTitle(17, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _publicRoomsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('공개 방 찾기', style: posterTitle(18)),
              const Spacer(),
              const Icon(Icons.public, color: CD.sage, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<RoomSummary>>(
            stream: _service.watchPublicRooms(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                      child: SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(strokeWidth: 2.5))),
                );
              }
              final rooms = snap.data!;
              if (rooms.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('열려 있는 공개 방이 없어요. 새로 만들어 보세요!',
                      style: TextStyle(color: CD.muted)),
                );
              }
              return Column(
                children: [for (final r in rooms) _roomTile(r)],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _roomTile(RoomSummary r) {
    final full = r.count >= r.capacity;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: CD.sand.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: (_busy || full) ? null : () => _attemptJoin(r.code),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Text(r.code,
                    style: westernLatin(20, color: CD.leather, spacing: 3)),
                if (r.hasPassword) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.lock, size: 15, color: CD.muted),
                ],
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${r.hostName}의 방',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: CD.leather, fontWeight: FontWeight.w600)),
                ),
                Text('${r.count}/${r.capacity}',
                    style: TextStyle(
                        color: full ? CD.danger : CD.sage,
                        fontWeight: FontWeight.w800)),
                const SizedBox(width: 6),
                Icon(full ? Icons.block : Icons.login,
                    size: 18, color: full ? CD.danger : CD.rust),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _joinByCodeCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('방 코드로 입장', style: posterTitle(18)),
          const SizedBox(height: 10),
          TextField(
            controller: _codeCtl,
            textCapitalization: TextCapitalization.characters,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: westernLatin(28, color: CD.leather, spacing: 8),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              UpperCaseFormatter(),
            ],
            decoration: _dec('ABCD'),
          ),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: _busy ? null : _joinByCode,
            style: FilledButton.styleFrom(
              backgroundColor: CD.sage,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.login),
            label:
                Text('입장하기', style: posterTitle(17, color: Colors.white)),
          ),
        ],
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

/// Forces room-code input to upper case as the user types.
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
