import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../game/cpu_ai.dart';
import '../game/party_logic.dart';
import '../theme.dart';
import '../widgets/action_bar.dart';
import '../widgets/circular_table.dart';
import '../widgets/desert_background.dart';
import '../widgets/emoji_bar.dart';
import '../widgets/reaction_panel.dart';

enum _Phase { setup, choosing, reveal, over, showdown }

enum _SdStage { prep, go, result }

class OfflineGameScreen extends StatefulWidget {
  const OfflineGameScreen({super.key});

  @override
  State<OfflineGameScreen> createState() => _OfflineGameScreenState();
}

class _OfflineGameScreenState extends State<OfflineGameScreen> {
  static const _botNames = ['잭', '빌', '한스', '로사', '듀크'];
  final _cpu = CpuAi();
  final _rand = Random();

  int _botCount = 2;
  int _n = 3;

  late List<int> _ammo;
  late List<bool> _alive;
  late List<Move?> _last;
  late List<bool> _fired;
  late List<bool> _superFired;
  late List<int> _firedTarget;
  late List<bool> _hit;

  int _turn = 0;
  _Phase _phase = _Phase.setup;
  String _banner = '';
  GameStatus _status = GameStatus.ongoing;
  int? _winner;

  ActKind? _selKind;
  int _selTarget = -1;

  // Reaction showdown state.
  _SdStage _sdStage = _SdStage.prep;
  List<int> _sdPlayers = [];
  bool _sdMeIn = false;
  int _sdFastestBot = -1;
  int _sdFastestMs = 9999;
  bool _sdIFalse = false;
  Timer? _sdPrep;
  Timer? _sdGo;

  final Map<int, String> _reactions = {};
  final Map<int, Timer> _rxTimers = {};

  List<String> get _names =>
      ['나', for (var i = 0; i < _n - 1; i++) _botNames[i % _botNames.length]];

  @override
  void dispose() {
    _sdPrep?.cancel();
    _sdGo?.cancel();
    for (final t in _rxTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  void _react(int seat, String emoji) {
    setState(() => _reactions[seat] = emoji);
    _rxTimers[seat]?.cancel();
    _rxTimers[seat] = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _reactions.remove(seat));
    });
  }

  void _start() {
    _n = 1 + _botCount;
    setState(() {
      _ammo = List<int>.filled(_n, 0);
      _alive = List<bool>.filled(_n, true);
      _last = List<Move?>.filled(_n, null);
      _fired = List<bool>.filled(_n, false);
      _superFired = List<bool>.filled(_n, false);
      _firedTarget = List<int>.filled(_n, -1);
      _hit = List<bool>.filled(_n, false);
      _turn = 0;
      _phase = _Phase.choosing;
      _banner = '첫 턴! 아직 총알이 없어요 — 장전부터.';
      _status = GameStatus.ongoing;
      _winner = null;
      _selKind = null;
      _selTarget = -1;
    });
  }

  void _confirm() {
    if (_selKind == null) return;
    final mine = switch (_selKind!) {
      ActKind.reload => const Move.reload(),
      ActKind.defend => const Move.defend(),
      ActKind.shoot => Move.shoot(_selTarget),
      ActKind.superShoot => Move.superShoot(_selTarget),
    };
    _resolve(mine);
  }

  void _resolve(Move mine) {
    final moves = <Move>[
      _alive[0] ? mine : Move.empty,
      for (var s = 1; s < _n; s++)
        _alive[s]
            ? _cpu.chooseMove(seat: s, ammo: _ammo, alive: _alive)
            : Move.empty,
    ];
    final aliveBefore = List<bool>.from(_alive);
    final out = resolveTurn(moves, _ammo, _alive);
    setState(() {
      _last = List<Move?>.from(moves);
      _fired = out.fired;
      _superFired = out.superFired;
      _firedTarget = out.firedTarget;
      _hit = out.hit;
      _ammo = out.ammoAfter;
      _alive = out.aliveAfter;
      _banner = _turnBanner(out);
      if (out.status == GameStatus.draw) {
        // Final simultaneous wipe → reaction showdown instead of a draw.
        _beginShowdown(aliveBefore);
      } else {
        _status = out.status;
        _winner = out.winner;
        _phase = out.status == GameStatus.ongoing ? _Phase.reveal : _Phase.over;
      }
      _selKind = null;
      _selTarget = -1;
    });
  }

  void _next() {
    setState(() {
      _hit = List<bool>.filled(_n, false);
      _last = List<Move?>.filled(_n, null);
      _fired = List<bool>.filled(_n, false);
      _superFired = List<bool>.filled(_n, false);
      _firedTarget = List<int>.filled(_n, -1);
      _turn++;
      _phase = _Phase.choosing;
      _banner = '${_turn + 1}번째 턴 · 행동을 골라요';
    });
  }

  String _turnBanner(TurnOutcome out) {
    final downed = <String>[
      for (var s = 0; s < _n; s++)
        if (out.hit[s]) _names[s]
    ];
    if (downed.isNotEmpty) return '${downed.join(", ")} 명중!';
    return out.fired.any((x) => x) ? '모두 막거나 빗나갔다!' : '장전과 방어... 다음 턴!';
  }

  // ---- Reaction showdown -------------------------------------------------

  void _beginShowdown(List<bool> aliveBefore) {
    _sdPlayers = [
      for (var s = 0; s < _n; s++)
        if (aliveBefore[s]) s
    ];
    _sdMeIn = _sdPlayers.contains(0);
    // Pre-roll each bot's reaction so the fastest is fixed for this round.
    _sdFastestBot = -1;
    _sdFastestMs = 9999;
    for (final s in _sdPlayers) {
      if (s == 0) continue;
      final r = 280 + _rand.nextInt(560); // 280~840ms
      if (r < _sdFastestMs) {
        _sdFastestMs = r;
        _sdFastestBot = s;
      }
    }
    _sdIFalse = false;
    _sdStage = _SdStage.prep;
    _phase = _Phase.showdown;
    _sdPrep?.cancel();
    _sdGo?.cancel();
    final prepMs = 500 + _rand.nextInt(900); // 0.5~1.4s
    _sdPrep = Timer(Duration(milliseconds: prepMs), () {
      if (!mounted) return;
      setState(() => _sdStage = _SdStage.go);
      // The fastest bot reacts after its pre-rolled time; if I don't beat it,
      // it wins.
      _sdGo = Timer(Duration(milliseconds: _sdFastestMs), () {
        if (mounted) _finishShowdown(_sdFastestBot);
      });
    });
  }

  void _sdTap() {
    if (!_sdMeIn || _sdStage == _SdStage.result) return;
    if (_sdStage == _SdStage.prep) {
      // Jumped the gun.
      _sdIFalse = true;
      _finishShowdown(_sdFastestBot >= 0 ? _sdFastestBot : _sdPlayers.first);
    } else {
      // Beat the bot.
      _finishShowdown(0);
    }
  }

  void _finishShowdown(int winner) {
    _sdPrep?.cancel();
    _sdGo?.cancel();
    setState(() {
      _sdStage = _SdStage.result;
      _winner = winner;
      _status = GameStatus.won;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('컴퓨터와 대결', style: posterTitle(20))),
      body: DesertBackground(
        child: SafeArea(
          child: switch (_phase) {
            _Phase.setup => _setup(),
            _Phase.showdown => _showdown(),
            _ => _game(),
          },
        ),
      ),
    );
  }

  // ---- Setup -------------------------------------------------------------

  Widget _setup() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('컴퓨터 봇 수', style: posterTitle(24, color: Colors.white)),
            const SizedBox(height: 6),
            const Text('나 + 봇으로 2~6명이 됩니다.',
                style: TextStyle(color: CD.parchment, fontSize: 13)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: CD.parchment.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: CD.leather.withValues(alpha: 0.25)),
              ),
              child: Column(
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var b = 1; b <= 5; b++)
                        GestureDetector(
                          onTap: () => setState(() => _botCount = b),
                          child: Container(
                            width: 56,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _botCount == b ? CD.rust : CD.sand,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: CD.rust,
                                  width: _botCount == b ? 2.5 : 1.5),
                            ),
                            child: Text('$b',
                                style: posterTitle(24,
                                    color: _botCount == b
                                        ? Colors.white
                                        : CD.leather)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('총 ${_botCount + 1}명이 원을 그려 앉습니다',
                      style: const TextStyle(
                          color: CD.muted, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 240,
              child: FilledButton.icon(
                onPressed: _start,
                style: FilledButton.styleFrom(
                  backgroundColor: CD.sage,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.play_arrow),
                label: Text('시작!', style: posterTitle(18, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Showdown ----------------------------------------------------------

  Widget _showdown() {
    if (_sdStage == _SdStage.result) return _resultCard(showdown: true);
    final others = _sdPlayers
        .where((s) => s != 0)
        .map((s) => _names[s])
        .toList();
    return ReactionPanel(
      stage: !_sdMeIn
          ? ReactionStage.spectate
          : (_sdStage == _SdStage.go ? ReactionStage.go : ReactionStage.prep),
      opponents: others,
      onTap: _sdTap,
    );
  }

  // ---- Game --------------------------------------------------------------

  Widget _game() {
    final reveal = _phase == _Phase.reveal || _phase == _Phase.over;
    final seats = [
      for (var s = 0; s < _n; s++)
        TableSeat(
          name: _names[s],
          ammo: _ammo[s],
          alive: _alive[s],
          isMe: s == 0,
          hit: _hit[s],
          lastMove: _last[s],
          fired: _fired[s],
          superFired: _superFired[s],
          firedTarget: _firedTarget[s],
        ),
    ];
    final targetMode = _phase == _Phase.choosing &&
        (_selKind == ActKind.shoot || _selKind == ActKind.superShoot);
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Stack(
              children: [
                CircularTable(
                  seats: seats,
                  mySeat: 0,
                  reveal: reveal,
                  targetMode: targetMode,
                  selectedTarget: _selTarget,
                  onSeatTap: (s) => setState(() => _selTarget = s),
                  center: _centerBanner(),
                  reactions: _reactions,
                ),
                if (_phase == _Phase.choosing || _phase == _Phase.reveal)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: EmojiBar(onPick: (e) => _react(0, e)),
                  ),
              ],
            ),
          ),
        ),
        _bottom(),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _centerBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: CD.leather.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        _banner,
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _bottom() {
    switch (_phase) {
      case _Phase.setup:
      case _Phase.showdown:
        return const SizedBox.shrink();
      case _Phase.choosing:
        if (!_alive[0]) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('탈락! 관전 중...',
                    style: TextStyle(
                        color: CD.danger,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _resolve(Move.empty),
                    style: FilledButton.styleFrom(
                      backgroundColor: CD.leather,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('다음 턴 보기',
                        style: posterTitle(17, color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ActionBar(
            myAmmo: _ammo[0],
            selected: _selKind,
            selectedTarget: _selTarget,
            targetName: _selTarget >= 0 ? _names[_selTarget] : null,
            onSelect: (k) => setState(() {
              _selKind = k;
              if (k != ActKind.shoot) _selTarget = -1;
            }),
            onConfirm: _confirm,
          ),
        );
      case _Phase.reveal:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _next,
              style: FilledButton.styleFrom(
                backgroundColor: CD.sage,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('계속하기', style: posterTitle(18, color: Colors.white)),
            ),
          ),
        );
      case _Phase.over:
        return _resultCard();
    }
  }

  Widget _resultCard({bool showdown = false}) {
    final iWon = _status == GameStatus.won && _winner == 0;
    final String title;
    if (showdown) {
      title = _sdIFalse
          ? '부정출발! 패배'
          : (iWon ? '반응 승리! 최후의 1인' : '${_names[_winner!]} 반응 승리');
    } else {
      title = iWon ? '승리! 최후의 1인' : '${_names[_winner!]} 승리';
    }
    final body = Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CD.parchment,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: iWon ? CD.gold : CD.danger, width: 3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: posterTitle(26, color: iWon ? CD.rust : CD.danger)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CD.leather,
                    side: const BorderSide(color: CD.leather),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('홈으로'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => setState(() => _phase = _Phase.setup),
                  style: FilledButton.styleFrom(
                    backgroundColor: CD.rust,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('다시하기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    // The showdown result stands alone (full screen); the normal result sits in
    // the bottom slot under the table.
    return showdown ? Center(child: body) : body;
  }
}
