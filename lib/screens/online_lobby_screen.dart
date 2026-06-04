import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/party_logic.dart';
import '../online/auth_service.dart';
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
  final _auth = AuthService();
  final _nameCtl = TextEditingController();
  final _codeCtl = TextEditingController();
  int _capacity = 4;
  bool _busy = false;
  String? _error;
  AppUser? _user;
  StreamSubscription<AppUser?>? _authSub;

  @override
  void initState() {
    super.initState();
    _user = _auth.current;
    _authSub = _auth.userChanges().listen((u) {
      if (mounted) setState(() => _user = u);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _nameCtl.dispose();
    _codeCtl.dispose();
    super.dispose();
  }

  /// Signed-in players play under their Google name; guests type one (or get a
  /// random one).
  String get _name {
    if (_user != null) return _user!.displayName;
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
      await _service.createRoom(code, _name, _capacity);
      if (!mounted) return;
      _open(code);
    } catch (e) {
      setState(() => _error = '방을 만들지 못했어요. 연결을 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final code = _codeCtl.text.trim().toUpperCase();
    if (code.length != 4) {
      setState(() => _error = '4자리 방 코드를 입력해요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await _service.joinRoom(code, _name);
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
      }
    } catch (e) {
      setState(() => _error = '입장에 실패했어요. 연결을 확인해 주세요.');
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
                _user != null
                    ? _card(
                        child: Row(
                          children: [
                            if (_user!.photoUrl != null)
                              CircleAvatar(
                                  radius: 16,
                                  backgroundImage:
                                      NetworkImage(_user!.photoUrl!))
                            else
                              const Icon(Icons.account_circle,
                                  color: CD.sage, size: 32),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_user!.displayName,
                                      style: posterTitle(18)),
                                  const Text('로 입장합니다',
                                      style: TextStyle(
                                          color: CD.muted, fontSize: 12)),
                                ],
                              ),
                            ),
                            const Icon(Icons.verified_user, color: CD.sage),
                          ],
                        ),
                      )
                    : _card(
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
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('새 방 만들기', style: posterTitle(18)),
                      const SizedBox(height: 6),
                      const Text('최대 인원을 고르고, 2명 이상 모이면 시작해요.',
                          style: TextStyle(color: CD.muted, fontSize: 12.5)),
                      const SizedBox(height: 12),
                      const Text('최대 인원',
                          style: TextStyle(
                              color: CD.leather, fontWeight: FontWeight.w700)),
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
                                      color: CD.sage,
                                      width: _capacity == c ? 2.5 : 1.5),
                                ),
                                child: Text('$c',
                                    style: posterTitle(20,
                                        color: _capacity == c
                                            ? Colors.white
                                            : CD.leather)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
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
                ),
                const SizedBox(height: 16),
                _card(
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
                          FilteringTextInputFormatter.allow(
                              RegExp('[A-Za-z0-9]')),
                          UpperCaseFormatter(),
                        ],
                        decoration: _dec('ABCD'),
                      ),
                      const SizedBox(height: 6),
                      FilledButton.icon(
                        onPressed: _busy ? null : _join,
                        style: FilledButton.styleFrom(
                          backgroundColor: CD.sage,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.login),
                        label: Text('입장하기',
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

/// Forces room-code input to upper case as the user types.
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
