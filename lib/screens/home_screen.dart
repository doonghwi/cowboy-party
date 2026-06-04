import 'package:flutter/material.dart';

import '../online/auth_service.dart';
import '../theme.dart';
import '../widgets/desert_background.dart';
import '../widgets/emo.dart';
import 'how_to_play_screen.dart';
import 'offline_game_screen.dart';
import 'online_lobby_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DesertBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: _AuthChip(),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Emo('cowboy', size: 38),
                      Emo('cowboy', size: 52),
                      Emo('cowboy', size: 38),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('카우보이 파티',
                      textAlign: TextAlign.center,
                      style: posterTitle(46, color: Colors.white)),
                  Text('COWBOY PARTY',
                      style: westernLatin(20, color: CD.parchment, spacing: 4)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: CD.leather.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '2~6명이 원을 그려 앉는다 · 최후의 1인이 승리',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 38),
                  _MenuButton(
                    icon: Icons.smart_toy,
                    label: '컴퓨터와 대결',
                    sub: '나 + 컴퓨터 봇 1~5명',
                    color: CD.rust,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const OfflineGameScreen()),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _MenuButton(
                    icon: Icons.public,
                    label: '온라인 대전',
                    sub: '방 만들기 · 코드로 입장 (2~6인)',
                    color: CD.sage,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const OnlineLobbyScreen()),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _MenuButton(
                    icon: Icons.menu_book,
                    label: '게임 방법',
                    sub: '규칙 한눈에 보기',
                    color: CD.gold,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const HowToPlayScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sign-in pill at the top of the home screen. Shows a "Google로 로그인" button
/// when signed out, and the account avatar/name + sign-out when signed in.
class _AuthChip extends StatefulWidget {
  const _AuthChip();
  @override
  State<_AuthChip> createState() => _AuthChipState();
}

class _AuthChipState extends State<_AuthChip> {
  final _auth = AuthService();
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await _auth.signInWithGoogle();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('구글 로그인을 아직 사용할 수 없어요 (설정 준비 중).')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pill = BoxDecoration(
      color: CD.leather.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(20),
    );
    return StreamBuilder<AppUser?>(
      stream: _auth.userChanges(),
      builder: (context, snap) {
        if (_busy) {
          return const SizedBox(
              height: 34,
              width: 34,
              child: Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))));
        }
        final user = snap.data;
        if (user == null) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _signIn,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: pill,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.login, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Google로 로그인',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: pill,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (user.photoUrl != null)
                CircleAvatar(
                    radius: 11, backgroundImage: NetworkImage(user.photoUrl!))
              else
                const Icon(Icons.account_circle, color: Colors.white, size: 22),
              const SizedBox(width: 7),
              Text(user.displayName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _auth.signOut,
                child: const Icon(Icons.logout, color: Colors.white70, size: 16),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 320,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: CD.parchment.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: posterTitle(21)),
                  Text(sub,
                      style: const TextStyle(color: CD.muted, fontSize: 12.5)),
                ],
              ),
              const Spacer(),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
