import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../audio/sfx.dart';
import '../meta/auth_service.dart';
import '../meta/meta_service.dart';
import '../theme.dart';
import '../widgets/desert_background.dart';
import 'characters_tab.dart';
import 'how_to_play_screen.dart';
import 'play_tab.dart';
import 'ranking_tab.dart';
import 'rewards_tab.dart';

/// 공식 디스코드 — 서버가 생기면 초대 링크만 넣으면 버튼이 살아난다.
const String kDiscordUrl = '';

/// 광고 배너 자리 표시 여부 (실제 광고 SDK 전이라 점선 placeholder).
const bool kShowAdPlaceholder = true;

/// 하단 4탭 셸: [플레이] [캐릭터] [랭킹] [보상] + 코인칩 + 설정.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _tab = 0;

  static const _titles = ['카우보이 파티', '캐릭터', '랭킹', '보상'];

  @override
  void initState() {
    super.initState();
    Meta.I.addListener(_onMeta);
    AuthService.I.addListener(_onMeta);
  }

  @override
  void dispose() {
    Meta.I.removeListener(_onMeta);
    AuthService.I.removeListener(_onMeta);
    super.dispose();
  }

  void _onMeta() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DesertBackground(
        child: SafeArea(
          bottom: false,
          // 웹/태블릿 와이드에서 콘텐츠가 풀폭으로 퍼지지 않게 (UX_UI §1).
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
            children: [
              _topBar(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(
                              begin: const Offset(0, 0.02), end: Offset.zero)
                          .animate(anim),
                      child: child,
                    ),
                  ),
                  child: switch (_tab) {
                    0 => const PlayTab(key: ValueKey('play')),
                    1 => const CharactersTab(key: ValueKey('chars')),
                    2 => const RankingTab(key: ValueKey('rank')),
                    _ => const RewardsTab(key: ValueKey('rewards')),
                  },
                ),
              ),
              if (kShowAdPlaceholder) _adPlaceholder(),
            ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: CD.leather,
          indicatorColor: CD.rust,
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(
                color: CD.parchment, fontSize: 12, fontWeight: FontWeight.w800),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? Colors.white
                  : CD.sand.withValues(alpha: 0.75),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          height: 64,
          onDestinationSelected: (i) => setState(() {
            if (i != _tab) Sfx.click();
            _tab = i;
          }),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.sports_esports), label: '플레이'),
            NavigationDestination(icon: Icon(Icons.face_6), label: '캐릭터'),
            NavigationDestination(icon: Icon(Icons.emoji_events), label: '랭킹'),
            NavigationDestination(
                icon: Icon(Icons.card_giftcard), label: '보상'),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(_titles[_tab],
                style: posterTitle(24, color: Colors.white)),
          ),
          CoinChip(coins: Meta.I.coins),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: '설정',
          ),
        ],
      ),
    );
  }

  Widget _adPlaceholder() {
    return Container(
      height: 56,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: CD.leather.withValues(alpha: 0.25),
        border: Border.all(
            color: CD.sand.withValues(alpha: 0.5),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside),
      ),
      alignment: Alignment.center,
      child: Text('AD — 광고 자리',
          style: TextStyle(
              color: CD.sand.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2)),
    );
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: CD.parchment,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('설정', style: posterTitle(22)),
              const SizedBox(height: 12),
              _AccountRow(onChanged: () => setState(() {})),
              const SizedBox(height: 8),
              _NicknameRow(),
              const Divider(height: 24),
              StatefulBuilder(
                builder: (ctx2, setSheet) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeTrackColor: CD.sage,
                  secondary: Icon(
                      Sfx.muted ? Icons.volume_off : Icons.volume_up,
                      color: CD.rust),
                  title: const Text('효과음',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  value: !Sfx.muted,
                  onChanged: (v) {
                    Sfx.setMuted(!v);
                    if (v) Sfx.click();
                    setSheet(() {});
                  },
                ),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.menu_book, color: CD.gold),
                title: const Text('게임 방법',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const HowToPlayScreen()));
                },
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.discord,
                    color: kDiscordUrl.isEmpty ? CD.muted : const Color(0xFF5865F2)),
                title: Text(
                  kDiscordUrl.isEmpty ? '공식 디스코드 (준비 중)' : '공식 디스코드',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: kDiscordUrl.isEmpty
                    ? const Text('서버가 열리면 여기서 바로 들어갈 수 있어요',
                        style: TextStyle(fontSize: 12))
                    : null,
                enabled: kDiscordUrl.isNotEmpty,
                onTap: kDiscordUrl.isEmpty
                    ? null
                    : () => launchUrl(Uri.parse(kDiscordUrl),
                        mode: LaunchMode.externalApplication),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 우상단 상시 노출 코인 잔액 — 변할 때 굴러가는 숫자 (UX_UI.md §3).
class CoinChip extends StatelessWidget {
  final int coins;
  const CoinChip({super.key, required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: CD.leather.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CD.gold, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on, color: CD.gold, size: 18),
          const SizedBox(width: 5),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: coins),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (_, v, child) => Text('$v',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

/// 설정에서 바로 닉네임 변경 (로비 안 가도 됨).
class _NicknameRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ctl = TextEditingController(text: Meta.I.nickname);
    return Row(
      children: [
        const Icon(Icons.badge, color: CD.rust, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: ctl,
            maxLength: 8,
            decoration: const InputDecoration(
              isDense: true,
              counterText: '',
              hintText: '닉네임 (비우면 랜덤)',
              border: UnderlineInputBorder(),
            ),
            onSubmitted: (v) => Meta.I.setNickname(v),
          ),
        ),
        TextButton(
          onPressed: () {
            Meta.I.setNickname(ctl.text);
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('닉네임 저장됨')));
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _AccountRow extends StatefulWidget {
  final VoidCallback onChanged;
  const _AccountRow({required this.onChanged});

  @override
  State<_AccountRow> createState() => _AccountRowState();
}

class _AccountRowState extends State<_AccountRow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.I;
    final google = auth.isGoogle;
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: CD.sage,
          foregroundImage:
              auth.photoUrl != null ? NetworkImage(auth.photoUrl!) : null,
          child: Icon(google ? Icons.person : Icons.person_outline,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                google ? (auth.displayName ?? 'Google 계정') : '게스트로 플레이 중',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                google ? '랭킹 등록 · 기기 간 코인 연동 중' : 'Google 로그인하면 랭킹에 등록돼요',
                style: const TextStyle(fontSize: 11.5, color: CD.muted),
              ),
            ],
          ),
        ),
        _busy
            ? const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator())
            : google
                ? TextButton(
                    onPressed: () async {
                      await AuthService.I.signOut();
                      widget.onChanged();
                      if (mounted) setState(() {});
                    },
                    child: const Text('로그아웃'))
                : FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: CD.sage),
                    onPressed: () async {
                      setState(() => _busy = true);
                      final ok = await AuthService.I.signInWithGoogle();
                      if (ok) await Meta.I.mergeFromCloud();
                      if (!mounted) return;
                      setState(() => _busy = false);
                      if (!ok && AuthService.I.lastError != null) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                                content: Text(AuthService.I.lastError!)));
                      }
                      widget.onChanged();
                    },
                    icon: const Icon(Icons.login, size: 18),
                    label: const Text('Google 로그인'),
                  ),
      ],
    );
  }
}
