import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../audio/sfx.dart';
import '../meta/announcements.dart';
import '../meta/auth_service.dart';
import '../meta/feedback_service.dart';
import '../meta/meta_service.dart';
import '../online/online_service.dart';
import '../theme.dart';
import '../widgets/desert_background.dart';
import 'characters_tab.dart';
import 'online_game_screen.dart';
import 'how_to_play_screen.dart';
import 'play_tab.dart';
import 'ranking_tab.dart';
import 'rewards_tab.dart';

/// 공식 디스코드 — 서버가 생기면 초대 링크만 넣으면 버튼이 살아난다.
const String kDiscordUrl = 'https://discord.com/invite/UhAV5zjKP';

/// 광고 배너 자리 표시 여부 (실제 광고 SDK 전이라 점선 placeholder).
const bool kShowAdPlaceholder = true;

/// 하단 4탭 셸: [플레이] [상점] [랭킹] [보상] + 코인칩 + 설정.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _tab = 0;

  static const _titles = ['카우보이', '상점', '랭킹', '보상'];

  @override
  void initState() {
    super.initState();
    Meta.I.addListener(_onMeta);
    AuthService.I.addListener(_onMeta);
    // 메뉴 배경음 — 게임 화면에서 돌아오면 게임 화면 dispose가 다시 'menu'로 전환.
    Bgm.play('menu', volume: 0.10);
    // F4: 초대 링크(?room=CODE)로 들어오면 그 방으로 바로 입장.
    final code = OnlineService.roomCodeFromUrl();
    if (code != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _enterRoom(code));
    } else if (Meta.I.nickname.isEmpty) {
      // G4: 기록 없는 첫 진입 → 게스트/구글 선택 + 닉네임 안내.
      WidgetsBinding.instance.addPostFrameCallback((_) => _showOnboarding());
    }
  }

  void _showOnboarding() {
    if (!mounted) return;
    final ctl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: CD.parchment,
        title: Text('카우보이에 온 걸 환영해요!', style: posterTitle(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('시작 보너스로 $kNewAccountGold골드를 드렸어요 🎉',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: CD.leather)),
            const SizedBox(height: 10),
            TextField(
              controller: ctl,
              maxLength: 8,
              decoration: const InputDecoration(
                counterText: '',
                labelText: '닉네임 (최대 8자)',
                border: OutlineInputBorder(),
              ),
            ),
            const Text('닉네임은 나중에 바꾸려면 변경권이 필요해요. 신중히 정해주세요!',
                style: TextStyle(fontSize: 11.5, color: CD.muted)),
            const SizedBox(height: 6),
            const Text('랭킹에 오르려면 구글 로그인이 필요해요(게스트는 미등록).',
                style: TextStyle(fontSize: 11.5, color: CD.muted)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              if (!await _applyOnboardName(ctx, ctl.text)) return;
              nav.pop();
            },
            child: const Text('게스트로 시작'),
          ),
          if (AuthService.I.showAppleButton)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.black),
              onPressed: () async {
                if (!await _applyOnboardName(ctx, ctl.text)) return;
                final ok = await AuthService.I.signInWithApple();
                if (ok) await Meta.I.mergeFromCloud();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              icon: const Icon(Icons.apple, size: 20),
              label: const Text('Apple로 로그인',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: CD.rust),
            onPressed: () async {
              if (!await _applyOnboardName(ctx, ctl.text)) return;
              final ok = await AuthService.I.signInWithGoogle();
              if (ok) await Meta.I.mergeFromCloud();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            icon: const Icon(Icons.login, size: 18),
            label: const Text('구글 로그인',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  // 온보딩 닉네임 적용. 비속어·중복이면 막고 false 반환(다이얼로그 유지). 빈 값은 통과.
  Future<bool> _applyOnboardName(BuildContext dialogCtx, String raw) async {
    final n = raw.trim();
    if (n.isEmpty) return true;
    final messenger = ScaffoldMessenger.of(dialogCtx);
    final r = await Meta.I.changeNickname(n);
    if (!r.ok) {
      messenger.showSnackBar(SnackBar(
        content: Text(r.message), behavior: SnackBarBehavior.floating));
      return false;
    }
    return true;
  }

  Future<void> _enterRoom(String code, {String password = ''}) async {
    final service = OnlineService();
    final name = Meta.I.nickname.isNotEmpty
        ? Meta.I.nickname
        : OnlineService.randomNickname();
    final res = await service.joinRoom(code, name,
        charIndex: Meta.I.equippedIndex, password: password);
    if (!mounted) return;
    if (res == JoinResult.joined) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OnlineGameScreen(service: service, code: code)));
    } else if (res == JoinResult.wrongPassword) {
      // 비공개 방(초대 링크) → 비밀번호 입력 후 재시도.
      _promptRoomPassword(code);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('초대받은 방에 들어갈 수 없어요 (사라졌거나 가득 참)'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _promptRoomPassword(String code) {
    final ctl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CD.parchment,
        title: const Text('비공개 방'),
        content: TextField(
          controller: ctl,
          maxLength: 12,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: '방 비밀번호', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CD.rust),
            onPressed: () {
              Navigator.pop(ctx);
              _enterRoom(code, password: ctl.text);
            },
            child: const Text('입장'),
          ),
        ],
      ),
    );
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
            NavigationDestination(icon: Icon(Icons.storefront), label: '상점'),
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
          const SizedBox(width: 4),
          IconButton(
            onPressed: () {
              final nowMuted = !Sfx.muted;
              Sfx.setMuted(nowMuted);
              if (!nowMuted) Sfx.click(); // 켤 때 살짝 피드백
              setState(() {});
            },
            icon: Icon(Sfx.muted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white),
            tooltip: Sfx.muted ? '소리 켜기' : '소리 끄기',
          ),
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: '설정',
          ),
        ],
      ),
    );
  }

  // H1: 'AD 광고 자리'를 사용자 공지로 사용. 최신 공지를 보여주고, 탭하면 전체.
  Widget _adPlaceholder() {
    final latest = kAnnouncements.isNotEmpty ? kAnnouncements.first : null;
    return GestureDetector(
      onTap: latest == null ? null : _openAnnouncements,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: CD.leather.withValues(alpha: 0.3),
          border: Border.all(color: CD.gold.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.campaign, color: CD.gold, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                latest == null ? '공지가 없어요' : latest.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800),
              ),
            ),
            if (latest != null)
              Text('자세히',
                  style: TextStyle(
                      color: CD.sand.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  void _openAnnouncements() {
    Sfx.click();
    showModalBottomSheet(
      context: context,
      backgroundColor: CD.parchment,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Row(
              children: [
                const Icon(Icons.campaign, color: CD.rust),
                const SizedBox(width: 8),
                Text('공지', style: posterTitle(22)),
              ],
            ),
            const SizedBox(height: 12),
            for (final a in kAnnouncements) ...[
              Text(a.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(height: 2),
              Text(a.date,
                  style: const TextStyle(fontSize: 11, color: CD.muted)),
              const SizedBox(height: 6),
              Text(a.body,
                  style: const TextStyle(fontSize: 13, height: 1.5)),
              const Divider(height: 28),
            ],
          ],
        ),
      ),
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
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mail_outline, color: CD.rust),
                title: const Text('관리자에게 제보·문의',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('버그·건의를 보내요 (개인정보는 보내지 않아요)',
                    style: TextStyle(fontSize: 12)),
                onTap: () => _openFeedback(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // H2: 관리자 연락 — ntfy 채널로 익명 전송.
  void _openFeedback(BuildContext sheetContext) {
    final ctl = TextEditingController();
    bool sending = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: CD.parchment,
          title: Text('제보·문의', style: posterTitle(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctl,
                maxLength: 500,
                maxLines: 4,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '버그·건의 내용을 적어주세요',
                  border: OutlineInputBorder(),
                ),
              ),
              const Text('익명 식별자만 함께 전송돼요. 개인정보는 적지 마세요.',
                  style: TextStyle(fontSize: 11, color: CD.muted)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: sending ? null : () => Navigator.pop(ctx),
                child: const Text('취소')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: CD.rust),
              onPressed: sending
                  ? null
                  : () async {
                      setLocal(() => sending = true);
                      final ok = await FeedbackService.I.send(ctl.text);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok
                              ? '제보를 보냈어요. 고마워요!'
                              : '전송 실패 — 잠시 후 다시 시도해 주세요'),
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    },
              child: Text(sending ? '보내는 중…' : '보내기',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
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
                google ? (auth.displayName ?? '로그인됨') : '게스트로 플레이 중',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                google ? '랭킹 등록 · 기기 간 코인 연동 중' : '로그인하면 랭킹에 등록돼요',
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
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: CD.sage,
                            visualDensity: VisualDensity.compact),
                        onPressed: () => _signIn(AuthService.I.signInWithGoogle),
                        icon: const Icon(Icons.login, size: 18),
                        label: const Text('Google'),
                      ),
                      if (AuthService.I.showAppleButton) ...[
                        const SizedBox(height: 6),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: Colors.black,
                              visualDensity: VisualDensity.compact),
                          onPressed: () =>
                              _signIn(AuthService.I.signInWithApple),
                          icon: const Icon(Icons.apple, size: 20),
                          label: const Text('Apple'),
                        ),
                      ],
                    ],
                  ),
      ],
    );
  }

  /// 로그인 공통 처리(Google/Apple) — busy 토글 + 클라우드 머지 + 에러 토스트.
  Future<void> _signIn(Future<bool> Function() signInFn) async {
    setState(() => _busy = true);
    final ok = await signInFn();
    if (ok) await Meta.I.mergeFromCloud();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok && AuthService.I.lastError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AuthService.I.lastError!)));
    }
    widget.onChanged();
  }
}
