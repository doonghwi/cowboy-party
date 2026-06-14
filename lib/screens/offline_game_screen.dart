import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../audio/sfx.dart';
import '../game/cpu_ai.dart';
import '../game/party_logic.dart';
import '../meta/meta_service.dart';
import '../theme.dart';
import '../widgets/action_bar.dart';
import '../widgets/circular_table.dart';
import '../widgets/desert_background.dart';
import '../widgets/emoji_bar.dart';
import '../widgets/reaction_panel.dart';
import '../widgets/super_flash.dart';

enum _Phase { setup, choosing, reveal, over, showdown, peeking }

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

  // 캐릭터 (좌석 0 = 내 장착 캐릭터, 봇은 랜덤).
  late List<CharId> _chars;
  late PartyState _pstate;
  late TurnOutcome? _lastOut;
  String _gameSeed = '';
  bool _smokeOn = false;
  String? _specialWin;

  int _turn = 0;
  _Phase _phase = _Phase.setup;
  String _banner = '';
  GameStatus _status = GameStatus.ongoing;
  int? _winner;

  ActKind? _selKind;
  int _selTarget = -1;
  // ignore: prefer_final_fields
  int _selTarget2 = -1; // 쌍권총 더블 빵야 두 번째 대상 (Stage 2 UI에서 갱신)

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

  // 턴 제한시간(20초) — 만료 시 가만히(idle)로 자동 진행.
  Timer? _turnTicker;
  int _secondsLeft = kTurnSeconds;

  // 파파라치 엿보기.
  bool _peekUsed = false; // 게임당 1회
  bool _peekSelecting = false; // 엿볼 대상 선택 중
  List<Move>? _frozenBots; // 엿보기 시점에 고정한 봇들의 행동

  // 슈퍼빵야 skill flash (one-shot overlay when a super shot fires).
  bool _superFlash = false;
  int _superFlashKey = 0;
  Timer? _superTimer;

  List<String> get _names =>
      ['나', for (var i = 0; i < _n - 1; i++) _botNames[i % _botNames.length]];

  @override
  void dispose() {
    _sdPrep?.cancel();
    _sdGo?.cancel();
    _superTimer?.cancel();
    _turnTicker?.cancel();
    for (final t in _rxTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  /// 내 차례(choosing·생존) 동안 20초 카운트다운. 만료 시 가만히로 자동 진행.
  void _startTurnTimer() {
    _turnTicker?.cancel();
    if (!_alive[0]) return; // 관전 중엔 타이머 없음
    _secondsLeft = kTurnSeconds;
    _turnTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() =>
          _secondsLeft = (_secondsLeft - 1).clamp(0, kTurnSeconds));
      if (_secondsLeft <= 0) {
        _turnTicker?.cancel();
        if (_phase == _Phase.choosing) {
          _resolve(const Move.idle());
        } else if (_phase == _Phase.peeking) {
          _resolve(const Move.idle(), frozenBots: _frozenBots);
        }
      }
    });
  }

  void _react(int seat, String emoji) {
    setState(() => _reactions[seat] = emoji);
    _rxTimers[seat]?.cancel();
    _rxTimers[seat] = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _reactions.remove(seat));
    });
  }

  void _fireSuperFlash() {
    _superFlash = true;
    _superFlashKey++;
    _superTimer?.cancel();
    _superTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _superFlash = false);
    });
  }

  void _start() {
    _n = 1 + _botCount;
    setState(() {
      final seed = 'OFF${_rand.nextInt(1 << 30)}';
      _gameSeed = seed;
      // 봇은 ???(mystery)·none을 제외한 실제 직업 중에서. 내 ???는 seed로 변환.
      final raw = <CharId>[
        Meta.I.equipped,
        for (var i = 1; i < _n; i++)
          kMysteryPool[_rand.nextInt(kMysteryPool.length)],
      ];
      _chars = [
        for (var s = 0; s < _n; s++) effectiveChar(raw[s], seed, s)
      ];
      _pstate = PartyState.initial(_chars);
      _lastOut = null;
      _specialWin = null;
      _smokeOn = false;
      _ammo = [for (var s = 0; s < _n; s++) startAmmoFor(_chars[s])];
      _alive = List<bool>.filled(_n, true);
      _last = List<Move?>.filled(_n, null);
      _fired = List<bool>.filled(_n, false);
      _superFired = List<bool>.filled(_n, false);
      _firedTarget = List<int>.filled(_n, -1);
      _hit = List<bool>.filled(_n, false);
      _turn = 0;
      _phase = _Phase.choosing;
      _banner = _chars[0] == CharId.prepper
          ? '준비자 — 총알 1발 장전된 채 시작!'
          : '첫 턴! 아직 총알이 없어요 — 장전부터.';
      _status = GameStatus.ongoing;
      _winner = null;
      _selKind = null;
      _selTarget = -1;
      _selTarget2 = -1;
      _peekUsed = false;
      _peekSelecting = false;
      _frozenBots = null;
    });
    _startTurnTimer();
  }

  /// 파파라치 엿보기 시작: 봇들의 이번 턴 행동을 고정하고, 대상 행동을 미리 본 뒤
  /// 내 행동을 다시 고르는 페이즈로 전환. (게임당 1회)
  void _doPeek(int target) {
    _turnTicker?.cancel();
    final frozen = <Move>[
      Move.empty, // 0번(나)은 placeholder
      for (var s = 1; s < _n; s++)
        _alive[s]
            ? _cpu.chooseMove(
                seat: s, ammo: _ammo, alive: _alive, chars: _chars, state: _pstate)
            : Move.empty,
    ];
    setState(() {
      _frozenBots = frozen;
      _peekUsed = true;
      _peekSelecting = false;
      _selKind = null;
      _selTarget = -1;
      _selTarget2 = -1;
      _phase = _Phase.peeking;
      _banner = '📸 ${_names[target]}의 행동: ${frozen[target].kind.ko}';
    });
    _startTurnTimer(); // 10초가 아니라 동일 20초 적용(오프라인)
  }

  static bool _isTargetAction(ActKind? k) =>
      k == ActKind.shoot ||
      k == ActKind.superShoot ||
      k == ActKind.roulette ||
      k == ActKind.voodoo ||
      k == ActKind.dualShoot;

  /// 좌석 탭. 더블 빵야는 두 명을 순서대로(다시 탭하면 재시작).
  void _onSeatTap(int s) {
    if (_peekSelecting) {
      if (s != 0 && _alive[s]) _doPeek(s); // 자신/사망자 제외
      return;
    }
    setState(() {
      if (_selKind == ActKind.dualShoot) {
        if (_selTarget < 0) {
          _selTarget = s;
        } else if (_selTarget2 < 0 && s != _selTarget) {
          _selTarget2 = s;
        } else {
          _selTarget = s;
          _selTarget2 = -1;
        }
      } else {
        _selTarget = s;
      }
    });
  }

  void _confirm() {
    if (_selKind == null) return;
    Sfx.confirm();
    var mine = switch (_selKind!) {
      ActKind.reload => const Move.reload(),
      ActKind.defend => const Move.defend(),
      ActKind.shoot => Move.shoot(_selTarget),
      ActKind.superShoot => Move.superShoot(_selTarget),
      ActKind.trap => const Move.trap(),
      ActKind.roulette => Move.roulette(_selTarget),
      ActKind.dualShoot => Move.dualShoot(_selTarget, _selTarget2),
      ActKind.voodoo => Move.voodoo(_selTarget),
      ActKind.reset => const Move.reset(),
      ActKind.idle => const Move.idle(),
    };
    if (_smokeOn &&
        _chars[0] == CharId.smoker &&
        _pstate.smokeLeft[0] > 0 &&
        mine.kind != ActKind.trap) {
      mine = mine.withSmoke(true);
    }
    _resolve(mine);
  }

  void _resolve(Move mine, {List<Move>? frozenBots}) {
    _turnTicker?.cancel();
    final moves = <Move>[
      _alive[0] ? mine : Move.empty,
      for (var s = 1; s < _n; s++)
        _alive[s]
            ? (frozenBots != null
                ? frozenBots[s]
                : _cpu.chooseMove(
                    seat: s,
                    ammo: _ammo,
                    alive: _alive,
                    chars: _chars,
                    state: _pstate))
            : Move.empty,
    ];
    final aliveBefore = List<bool>.from(_alive);
    final out = resolvePartyTurn(
      moves: moves,
      ammoBefore: _ammo,
      aliveBefore: _alive,
      chars: _chars,
      state: _pstate,
      seed: _gameSeed,
      turn: _turn,
    );
    _pstate = out.stateAfter!;
    if (out.superFired.any((x) => x)) _fireSuperFlash();
    _playRevealSound(out);
    setState(() {
      _lastOut = out;
      _last = List<Move?>.from(moves);
      _fired = out.fired;
      _superFired = out.superFired;
      _firedTarget = out.firedTarget;
      _hit = out.hit;
      _ammo = out.ammoAfter;
      _alive = out.aliveAfter;
      _banner = _turnBanner(out, moves, aliveBefore);
      _specialWin = out.specialWin;
      if (out.status == GameStatus.draw) {
        // Final simultaneous wipe → reaction showdown instead of a draw.
        _beginShowdown(aliveBefore);
      } else {
        _status = out.status;
        _winner = out.winner;
        _phase = out.status == GameStatus.ongoing ? _Phase.reveal : _Phase.over;
        if (_phase == _Phase.over) {
          _winner == 0 ? Sfx.win() : Sfx.lose();
        }
      }
      _selKind = null;
      _selTarget = -1;
      _selTarget2 = -1;
      _smokeOn = false;
    });
  }

  void _playRevealSound(TurnOutcome out) {
    if (out.superFired.any((x) => x)) {
      Sfx.play('super');
    } else if (out.reflectKill.any((x) => x)) {
      Sfx.play('trap');
    } else if (out.curseKill.any((x) => x)) {
      Sfx.play('hit');
    } else if (out.rouletteFired.any((x) => x)) {
      Sfx.play('shot');
      Timer(const Duration(milliseconds: 130), () => Sfx.play('hit'));
    } else if (out.voodooCast.any((x) => x)) {
      Sfx.play('smoke');
    } else if (out.fired.any((x) => x)) {
      Sfx.play('shot');
      if (out.hit.any((x) => x)) {
        Timer(const Duration(milliseconds: 130), () => Sfx.play('hit'));
      } else if (out.evaded.any((x) => x)) {
        Timer(const Duration(milliseconds: 130), () => Sfx.play('smoke'));
      } else {
        Timer(const Duration(milliseconds: 130), () => Sfx.play('shield'));
      }
    } else if (out.healed.any((x) => x)) {
      Sfx.play('shield');
    } else {
      Sfx.play('reload', volume: 0.7);
    }
  }

  void _next() {
    setState(() {
      _lastOut = null;
      _hit = List<bool>.filled(_n, false);
      _last = List<Move?>.filled(_n, null);
      _fired = List<bool>.filled(_n, false);
      _superFired = List<bool>.filled(_n, false);
      _firedTarget = List<int>.filled(_n, -1);
      _turn++;
      _phase = _Phase.choosing;
      _banner = '${_turn + 1}번째 턴 · 행동을 골라요';
    });
    _startTurnTimer();
  }

  String _turnBanner(TurnOutcome out, List<Move> moves, List<bool> aliveBefore) {
    final reflected = <String>[
      for (var s = 0; s < out.reflectKill.length; s++)
        if (out.reflectKill[s]) _names[s]
    ];
    if (reflected.isNotEmpty) return '덫 발동! ${reflected.join(", ")} 반사 명중!';
    final cursed = <String>[
      for (var s = 0; s < out.curseKill.length; s++)
        if (out.curseKill[s]) _names[s]
    ];
    if (cursed.isNotEmpty) return '저주 발동! ${cursed.join(", ")} 쓰러졌다!';
    final healed = <String>[
      for (var s = 0; s < out.healed.length; s++)
        if (out.healed[s]) _names[s]
    ];
    final downed = <String>[
      for (var s = 0; s < _n; s++)
        if (out.hit[s]) _names[s]
    ];
    if (healed.isNotEmpty && downed.isEmpty) {
      return '${healed.join(", ")}, 의사의 자힐로 버텼다!';
    }
    if (out.rouletteFired.any((x) => x) && downed.isNotEmpty) {
      return '운명의 방아쇠! ${downed.join(", ")} 쓰러졌다!';
    }
    if (downed.isNotEmpty) return '${downed.join(", ")} 명중!';
    final voodooCasters = <String>[
      for (var s = 0; s < out.voodooCast.length; s++)
        if (out.voodooCast[s]) _names[s]
    ];
    if (voodooCasters.isNotEmpty) {
      return '${voodooCasters.join(", ")}, 저주를 걸었다... ($kCurseFuse턴)';
    }
    final evaded = <String>[
      for (var s = 0; s < out.evaded.length; s++)
        if (out.evaded[s]) _names[s]
    ];
    if (evaded.isNotEmpty) return '${evaded.join(", ")}, 연막으로 회피!';
    if (out.fired.any((x) => x)) return '모두 막거나 빗나갔다!';
    // Nobody fired — name what the living cowboys actually did.
    final kinds = <ActKind>[
      for (var s = 0; s < moves.length; s++)
        if (s < aliveBefore.length && aliveBefore[s]) moves[s].kind
    ];
    final all = kinds.length <= 2 ? '둘 다' : '모두';
    if (kinds.isNotEmpty && kinds.every((k) => k == ActKind.defend)) {
      return '$all 방어! 다음 턴';
    }
    if (kinds.isNotEmpty && kinds.every((k) => k == ActKind.reload)) {
      return '$all 장전! 다음 턴';
    }
    return '장전과 방어... 다음 턴!';
  }

  // ---- Reaction showdown -------------------------------------------------

  void _beginShowdown(List<bool> aliveBefore) {
    _sdPlayers = [
      for (var s = 0; s < _n; s++)
        if (aliveBefore[s]) s
    ];
    // B2: 결투가가 결투(showdown) 참가자 중 정확히 1명이면 반응속도 없이 자동 승리.
    final duelists = [
      for (final s in _sdPlayers)
        if (_chars[s] == CharId.duelist) s
    ];
    if (duelists.length == 1) {
      _winner = duelists.first;
      _status = GameStatus.won;
      _specialWin = 'duelist';
      _phase = _Phase.over;
      return;
    }
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
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: CD.leather.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(charDef(Meta.I.equipped).icon,
                      size: 16, color: charDef(Meta.I.equipped).color),
                  const SizedBox(width: 6),
                  Text(
                    '내 캐릭터: ${charDef(Meta.I.equipped).name} · 봇들도 랜덤 캐릭터를 써요',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
    bool fx(List<bool>? l, int s) => l != null && s < l.length && l[s];
    // 그림자 봇은 나(0)에게 탄약·행동을 가린다.
    bool shotAt(int s) => _firedTarget.contains(s);
    bool shadowHide(int s) => s != 0 && _chars[s] == CharId.shadow;
    bool hideAct(int s) {
      if (!shadowHide(s)) return false;
      final m = _last[s];
      if (m == null) return false;
      final passive = m.kind == ActKind.reload ||
          m.kind == ActKind.defend ||
          m.kind == ActKind.idle;
      if (!passive) return false;
      if (m.kind == ActKind.defend && shotAt(s)) return false;
      return true;
    }
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
          char: _chars[s],
          healedFx: fx(_lastOut?.healed, s),
          evadedFx: fx(_lastOut?.evaded, s),
          reflectedFx: fx(_lastOut?.reflectKill, s),
          doubleLoadFx: fx(_lastOut?.doubleLoad, s),
          hideAmmo: shadowHide(s),
          hideAction: hideAct(s),
        ),
    ];
    final targetMode =
        (_phase == _Phase.choosing && _isTargetAction(_selKind)) ||
            _peekSelecting;
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
                  selectedTarget2: _selTarget2,
                  onSeatTap: _onSeatTap,
                  center: _centerBanner(),
                  reactions: _reactions,
                ),
                if (_phase == _Phase.choosing || _phase == _Phase.reveal)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: EmojiBar(onPick: (e) => _react(0, e)),
                  ),
                if (_superFlash)
                  Positioned.fill(
                    child: SuperBbangyaFlash(
                        key: ValueKey('sf-$_superFlashKey')),
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

  Widget _turnCountdown() {
    final low = _secondsLeft <= 10;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer, size: 16, color: low ? CD.danger : CD.muted),
          const SizedBox(width: 6),
          Text('$_secondsLeft초',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: low ? CD.danger : CD.leather)),
        ],
      ),
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
      case _Phase.peeking:
        final peeking = _phase == _Phase.peeking;
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _turnCountdown(),
            ActionBar(
            myAmmo: _ammo[0],
            selected: _selKind,
            selectedTarget: _selTarget,
            targetName: _selTarget >= 0 ? _names[_selTarget] : null,
            selectedTarget2: _selTarget2,
            targetName2: _selTarget2 >= 0 ? _names[_selTarget2] : null,
            myChar: _chars[0],
            trapAvailable: _chars[0] == CharId.hunter && !_pstate.trapUsed[0],
            resetAvailable:
                _chars[0] == CharId.resetter && !_pstate.resetterUsed[0],
            smokeLeft: _pstate.smokeLeft[0],
            smokeOn: _smokeOn,
            onSmokeToggle: (v) => setState(() => _smokeOn = v),
            showPeek: !peeking && _chars[0] == CharId.paparazzi && !_peekUsed,
            peekEnabled: true,
            onPeek: () => setState(() {
              Sfx.click();
              _peekSelecting = true;
              _selKind = null;
              _banner = '📸 엿볼 상대를 탭하세요';
            }),
            onSelect: (k) => setState(() {
              Sfx.click();
              _selKind = k;
              _selTarget = -1;
              _selTarget2 = -1;
              final opp = [for (var s = 1; s < _n; s++) if (_alive[s]) s];
              if (_isTargetAction(k) &&
                  k != ActKind.dualShoot &&
                  opp.length == 1) {
                _selTarget = opp.first;
              } else if (k == ActKind.dualShoot && opp.length == 2) {
                _selTarget = opp[0];
                _selTarget2 = opp[1];
              }
            }),
            onConfirm: peeking
                ? () {
                    if (_selKind == null) return;
                    Sfx.confirm();
                    final mine = switch (_selKind!) {
                      ActKind.reload => const Move.reload(),
                      ActKind.defend => const Move.defend(),
                      ActKind.shoot => Move.shoot(_selTarget),
                      ActKind.superShoot => Move.superShoot(_selTarget),
                      ActKind.trap => const Move.trap(),
                      ActKind.roulette => Move.roulette(_selTarget),
                      ActKind.dualShoot =>
                        Move.dualShoot(_selTarget, _selTarget2),
                      ActKind.voodoo => Move.voodoo(_selTarget),
                      ActKind.reset => const Move.reset(),
                      ActKind.idle => const Move.idle(),
                    };
                    _resolve(mine, frozenBots: _frozenBots);
                  }
                : _confirm,
          ),
          ]),
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
    } else if (_specialWin == 'pacifist') {
      title = iWon
          ? '장전 6회 — 평화의 승리!'
          : '${_names[_winner!]}, 평화의 승리! (장전 6회)';
    } else if (_specialWin == 'duelist') {
      title = iWon
          ? '1:1 결투 — 결투가의 즉시 승리!'
          : '${_names[_winner!]}, 결투가의 즉시 승리!';
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
