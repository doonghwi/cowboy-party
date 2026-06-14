import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/sfx.dart';
import '../game/party_logic.dart';
import '../meta/meta_service.dart';
import '../meta/season_service.dart';
import '../online/online_service.dart';
import '../theme.dart';
import '../widgets/action_bar.dart';
import '../widgets/circular_table.dart';
import '../widgets/desert_background.dart';
import '../widgets/emoji_bar.dart';
import '../widgets/online_showdown.dart';
import '../widgets/super_flash.dart';
import '../widgets/top_toast.dart';

class OnlineGameScreen extends StatefulWidget {
  final OnlineService service;
  final String code;

  const OnlineGameScreen({
    super.key,
    required this.service,
    required this.code,
  });

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  bool _resetting = false;
  int _presenceSeat = -1;
  bool _startedNow = false;
  String _myName = '';

  // 슈퍼빵야 skill flash (one-shot overlay when a super shot fires).
  bool _superFlash = false;
  int _superFlashKey = 0;
  bool _superFlashedOver = false;
  Timer? _superTimer;

  // Pending action for the current turn.
  int _pendingTurn = -1;
  ActKind? _selKind;
  int _selTarget = -1;
  int _selTarget2 = -1; // 쌍권총 더블 빵야 두 번째 대상
  bool _smokeOn = false; // 스모커 연막 토글 (턴마다 리셋)
  bool _peekSelecting = false; // 파파라치 엿볼 대상 선택 중

  // 턴 제한시간(20초) — 만료 시 자동 idle 제출.
  Timer? _turnTicker;
  int _timerTurn = -1;
  int _secondsLeft = kTurnSeconds;

  // 코인/포인트는 게임(판)당 한 번만 지급.
  bool _rewarded = false;

  // Mid-game reveal: briefly show who shot whom before the next turn's picker.
  int _shownTurn = 0;
  bool _revealing = false;
  Timer? _revealTimer;

  // Server clock skew (for both staleness and the reaction showdown).
  int _serverOffset = 0;
  StreamSubscription<DatabaseEvent>? _offsetSub;
  Timer? _heartbeat;
  Timer? _staleTick;

  // Emoji reactions floating over seats.
  final Map<int, String> _reactions = {};
  final Map<int, Timer> _rxTimers = {};
  final Map<int, int> _seenReactTs = {};

  @override
  void initState() {
    super.initState();
    _offsetSub = widget.service.serverOffsetRef().onValue.listen((e) {
      final v = e.snapshot.value;
      if (v is num && mounted) setState(() => _serverOffset = v.toInt());
    });
    // Keep my seat alive so a brief blip never reads as "left".
    _heartbeat = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_presenceSeat >= 0) widget.service.heartbeat(widget.code, _presenceSeat);
    });
    // Re-evaluate staleness even when no RTDB events arrive.
    _staleTick = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  int get _nowServer =>
      DateTime.now().millisecondsSinceEpoch + _serverOffset;

  @override
  void dispose() {
    _revealTimer?.cancel();
    _turnTicker?.cancel();
    _offsetSub?.cancel();
    _heartbeat?.cancel();
    _staleTick?.cancel();
    _superTimer?.cancel();
    for (final t in _rxTimers.values) {
      t.cancel();
    }
    if (_presenceSeat >= 0) {
      widget.service.leave(widget.code, _presenceSeat,
          started: _startedNow, name: _myName);
    }
    super.dispose();
  }

  /// Float an emoji over [seat] for a couple seconds. Safe to call during build
  /// (mutates state without setState; the clear timer triggers the rebuild).
  void _showReaction(int seat, String emoji) {
    _reactions[seat] = emoji;
    _rxTimers[seat]?.cancel();
    _rxTimers[seat] = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _reactions.remove(seat));
    });
  }

  void _react(int seat, String emoji) {
    setState(() => _showReaction(seat, emoji));
  }

  void _handleReactions(Map data) {
    final react = data['react'];
    if (react is! Map) return;
    react.forEach((k, v) {
      if (v is! Map) return;
      final seat = int.tryParse(k.toString().replaceAll('p', ''));
      final t = v['t'];
      final e = v['e'];
      if (seat == null || t is! num || e is! String) return;
      final ts = t.toInt();
      if (ts > (_seenReactTs[seat] ?? 0) && _nowServer - ts < 4000) {
        _seenReactTs[seat] = ts;
        _showReaction(seat, e);
      }
    });
  }

  Future<void> _leaveAndPop() async {
    final seat = _presenceSeat;
    final started = _startedNow;
    _presenceSeat = -1;
    if (seat >= 0) {
      await widget.service
          .leave(widget.code, seat, started: started, name: _myName);
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _track(RoomView view) {
    _presenceSeat = view.mySeat;
    _startedNow = view.started;
    // Remember my name so a sticky quit can show it after my node is gone.
    final myName = view.me?.name;
    if (myName != null && myName.isNotEmpty) _myName = myName;
    // Host makes silent players' departures sticky so all clients agree.
    if (view.isHost && view.reapSeats.isNotEmpty) {
      widget.service.markQuit(widget.code, view.reapSeats);
    }
  }

  bool _endSoundPlayed = false;

  void _handleReveal(RoomView view) {
    if (view.phase == OnlinePhase.over) {
      // A game-ending 슈퍼빵야 jumps straight to "over" with no live reveal
      // window — fire the flash here, once, before the result card lands.
      if (!_superFlashedOver && view.seats.any((s) => s.superFired)) {
        _superFlashedOver = true;
        _fireSuperFlash();
        Sfx.play('super');
      }
      if (!_endSoundPlayed) {
        _endSoundPlayed = true;
        if (view.status == GameStatus.won) {
          view.iWon ? Sfx.win() : Sfx.lose();
        }
      }
      return;
    }
    _superFlashedOver = false; // re-arm for the next game's finale
    _endSoundPlayed = false;
    if (view.phase == OnlinePhase.waiting) {
      _shownTurn = 0;
      return;
    }
    // A rematch resets the turn counter — re-sync so reveals work next game.
    if (view.turn < _shownTurn) _shownTurn = view.turn;
    if (view.turn > _shownTurn) {
      final hadAction =
          view.seats.any((s) => s.fired) || view.seats.any((s) => s.hitThisTurn);
      final hadSuper = view.seats.any((s) => s.superFired);
      _shownTurn = view.turn;
      _playRevealSound(view, hadSuper);
      // Always reveal so the 장전(+1)·방어(방패) effects show even on a quiet
      // turn with no shots; a quiet turn just gets a shorter window.
      _revealing = true;
      _revealTimer?.cancel();
      _revealTimer = Timer(Duration(milliseconds: hadAction ? 2600 : 1500), () {
        if (mounted) setState(() => _revealing = false);
      });
      if (hadSuper) _fireSuperFlash();
    }
  }

  /// 턴 결과에 맞는 효과음 — 드라마(덫/연막/자힐)가 우선, 그다음 총성.
  void _playRevealSound(RoomView view, bool hadSuper) {
    final seats = view.seats;
    if (hadSuper) {
      Sfx.play('super');
    } else if (seats.any((s) => s.reflectedFx)) {
      Sfx.play('trap');
    } else if (seats.any((s) => s.fired)) {
      Sfx.play('shot');
      if (seats.any((s) => s.hitThisTurn)) {
        Timer(const Duration(milliseconds: 130), () => Sfx.play('hit'));
      } else if (seats.any((s) => s.evadedFx)) {
        Timer(const Duration(milliseconds: 130), () => Sfx.play('smoke'));
      } else {
        Timer(const Duration(milliseconds: 130), () => Sfx.play('shield'));
      }
    } else if (seats.any((s) => s.healedFx)) {
      Sfx.play('shield');
    } else if (seats.any((s) => s.hitThisTurn)) {
      // 총성 없는 죽음(저주·운명의 방아쇠 반사 등).
      Sfx.play('hit');
    } else {
      Sfx.play('reload', volume: 0.7);
    }
  }

  void _fireSuperFlash() {
    _superFlash = true;
    _superFlashKey++;
    _superTimer?.cancel();
    _superTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _superFlash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leaveAndPop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _leaveAndPop,
          ),
          title: Text('방 ${widget.code}', style: posterTitle(20)),
          actions: [
            IconButton(
              tooltip: '방 코드 복사',
              icon: const Icon(Icons.copy, size: 20),
              onPressed: _copyCode,
            ),
          ],
        ),
        body: DesertBackground(
          child: SafeArea(
            child: StreamBuilder<DatabaseEvent>(
              stream: widget.service.watch(widget.code),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(color: CD.rust));
                }
                final raw = snap.data!.snapshot.value;
                if (raw is! Map) return _info('방이 사라졌어요.', back: true);
                final data = Map.from(raw);
                final view = OnlineService.computeView(
                    data, widget.service.clientId,
                    nowServerMs: _nowServer, seedKey: widget.code);
                _track(view);
                _handleReveal(view);
                _handleReactions(data);
                _maybeReset(view, data['scored'] == true);
                _maybeReward(view);
                _manageTurnTimer(view);
                _maybePeekUnblock(view);
                if (view.phase == OnlinePhase.waiting) {
                  if (view.mySeat < 0) {
                    return _info('방에서 나왔어요.', back: true);
                  }
                  return _waiting(view);
                }
                if (view.iAmOut) {
                  return _info('연결이 끊겨 방에서 나가졌어요.\n다시 입장하려면 방 코드로 들어오세요.',
                      back: true);
                }
                if (view.status == GameStatus.draw && view.drawTurn >= 0) {
                  return _showdownBody(view, data['showdown']);
                }
                return _table(view);
              },
            ),
          ),
        ),
      ),
    );
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('방 코드 ${widget.code} 복사됨')),
    );
  }

  void _maybeReset(RoomView view, bool scored) {
    if (view.phase == OnlinePhase.over &&
        view.status == GameStatus.won &&
        view.isHost) {
      // Score the instant the game is decided (guarded server-side too).
      if (!scored && view.winnerSeat != null) {
        widget.service.recordScore(widget.code, view.winnerSeat!);
      }
      // Once everyone present wants a rematch, clear the board.
      if (view.presentCount >= kMinSeats &&
          view.rematchCount >= view.presentCount &&
          !_resetting) {
        _resetting = true;
        widget.service.resetBoard(widget.code);
      }
    }
    if (view.phase != OnlinePhase.over) _resetting = false;
  }

  /// 게임이 결판나면 코인·시즌 포인트를 1회 지급 (관전자 제외).
  void _maybeReward(RoomView view) {
    if (view.phase != OnlinePhase.over || view.status != GameStatus.won) {
      if (view.phase != OnlinePhase.over) _rewarded = false;
      return;
    }
    if (_rewarded || !view.seated || view.iAmLate || view.iAmOut) return;
    _rewarded = true;
    final players = view.seatCount;
    final iWon = view.winnerSeat == view.mySeat;
    final coins = iWon ? Meta.I.grantWin(players) : Meta.I.grantPlay();
    if (iWon) SeasonService.I.recordWin(players);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TopToast.show(
        context,
        message: iWon ? '승리 보상 +$coins 코인!' : '참가 보상 +$coins 코인',
      );
    });
  }

  // ---- Reaction showdown -------------------------------------------------

  Widget _showdownBody(RoomView view, Object? sdRaw) {
    final seatNames = {for (final s in view.seats) s.seat: s.name};
    return OnlineShowdown(
      service: widget.service,
      code: widget.code,
      drawTurn: view.drawTurn,
      participants: view.drawParticipants,
      mySeat: view.mySeat,
      seatNames: seatNames,
      sdRaw: sdRaw is Map ? sdRaw : null,
      serverOffset: _serverOffset,
      isHost: view.isHost,
    );
  }

  // ---- Waiting room ------------------------------------------------------

  Widget _waiting(RoomView view) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Text('방 코드', style: posterTitle(18)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _copyCode,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
            decoration: BoxDecoration(
              color: CD.parchment,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: CD.rust, width: 3),
            ),
            child: Text(widget.code,
                style: westernLatin(40, color: CD.leather, spacing: 10)),
          ),
        ),
        const SizedBox(height: 6),
        const Text('친구에게 코드를 알려주세요 (탭하면 복사)',
            style: TextStyle(color: CD.muted)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: CircularTable(
              seats: _seatsOf(view, false),
              mySeat: view.mySeat < 0 ? 0 : view.mySeat,
              center: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: CD.leather.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text('${view.joinedCount} / ${view.capacity}',
                    style: posterTitle(22, color: Colors.white)),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: view.isHost
              ? SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: view.canStart
                        ? () => widget.service.startGame(widget.code)
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: CD.rust,
                      disabledBackgroundColor: CD.muted.withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                        view.canStart
                            ? '시작! (${view.joinedCount}명)'
                            : '2명 이상 모이면 시작',
                        style: posterTitle(18, color: Colors.white)),
                  ),
                )
              : const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('호스트가 시작하기를 기다리는 중...',
                      style: TextStyle(
                          color: CD.leather, fontWeight: FontWeight.w700)),
                ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ---- Table -------------------------------------------------------------

  List<TableSeat> _seatsOf(RoomView view, bool reveal) => [
        for (final sv in view.seats)
          TableSeat(
            name: view.started && !sv.joined ? '나감' : sv.name,
            ammo: sv.ammo,
            alive: sv.alive,
            isMe: sv.isMe,
            joined: sv.joined || !view.started,
            submitted: sv.submittedThisTurn && view.phase != OnlinePhase.over,
            hit: sv.hitThisTurn && reveal,
            lastMove: sv.lastMove,
            fired: sv.fired,
            superFired: sv.superFired,
            firedTarget: sv.firedTarget,
            char: sv.char,
            late: sv.late,
            healedFx: sv.healedFx,
            evadedFx: sv.evadedFx,
            reflectedFx: sv.reflectedFx,
            doubleLoadFx: sv.doubleLoadFx,
            hideAmmo: sv.hideAmmo,
            hideAction: sv.hideAction,
          ),
      ];

  Widget _table(RoomView view) {
    final reveal = view.phase == OnlinePhase.over || _revealing;
    final choosing =
        view.phase == OnlinePhase.choosing && view.seated && !_revealing;
    if (choosing) _resetPendingFor(view.turn);
    final targetMode =
        choosing && (_isTargetAction(_selKind) || _peekSelecting);
    final canReact = view.seated && view.phase != OnlinePhase.over;
    return Column(
      children: [
        const SizedBox(height: 6),
        _scoreStrip(view),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Stack(
              children: [
                CircularTable(
                  seats: _seatsOf(view, reveal),
                  mySeat: view.mySeat < 0 ? 0 : view.mySeat,
                  reveal: reveal,
                  targetMode: targetMode,
                  selectedTarget: _selTarget,
                  selectedTarget2: _selTarget2,
                  onSeatTap: (s) {
                    if (_peekSelecting) {
                      if (s != view.mySeat &&
                          s < view.seats.length &&
                          view.seats[s].alive) {
                        setState(() => _peekSelecting = false);
                        Sfx.confirm();
                        widget.service
                            .startPeek(widget.code, view.turn, view.mySeat, s);
                      }
                    } else {
                      _onSeatTap(s);
                    }
                  },
                  center: _centerBanner(view.banner),
                  reactions: _reactions,
                ),
                if (canReact)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: EmojiBar(
                      onPick: (e) {
                        _react(view.mySeat, e);
                        widget.service.sendReaction(widget.code, view.mySeat, e);
                      },
                    ),
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
        _bottom(view),
        const SizedBox(height: 10),
      ],
    );
  }

  /// 타겟을 골라야 하는 액션인가 (테이블 탭 활성화 조건).
  static bool _isTargetAction(ActKind? k) =>
      k == ActKind.shoot ||
      k == ActKind.superShoot ||
      k == ActKind.roulette ||
      k == ActKind.voodoo ||
      k == ActKind.dualShoot;

  /// 좌석 탭 처리. 더블 빵야는 두 명을 순서대로 고른다(다시 탭하면 재시작).
  void _onSeatTap(int s) {
    setState(() {
      if (_selKind == ActKind.dualShoot) {
        if (_selTarget < 0) {
          _selTarget = s;
        } else if (_selTarget2 < 0 && s != _selTarget) {
          _selTarget2 = s;
        } else {
          _selTarget = s; // 재시작
          _selTarget2 = -1;
        }
      } else {
        _selTarget = s;
      }
    });
  }

  bool _peekUnblocking = false;

  /// 엿보기가 10초+ 멈춰 있으면(엿보는 사람이 끊김 등) 호스트가 그 좌석을 가만히로
  /// 제출해 전체를 언블록한다.
  void _maybePeekUnblock(RoomView view) {
    if (view.isHost &&
        view.peekActive &&
        view.peekStale &&
        view.peekerSeat >= 0 &&
        !_peekUnblocking) {
      _peekUnblocking = true;
      widget.service
          .submitMove(widget.code, view.turn, view.peekerSeat, const Move.idle())
          .whenComplete(() => _peekUnblocking = false);
    }
  }

  /// 내가 행동을 골라야 하는 동안만 20초 카운트다운. 만료되면 자동으로 가만히(idle).
  void _manageTurnTimer(RoomView view) {
    // 엿보는 사람이 전원 제출을 기다리는 동안엔 타이머를 멈춘다(잘못된 자동 idle 방지).
    final peekerWaiting = view.iAmPeeker && !view.peekActive;
    final myTurn = view.phase == OnlinePhase.choosing &&
        view.seated &&
        !view.iAmLate &&
        !peekerWaiting &&
        (view.me?.alive ?? false);
    if (myTurn) {
      if (_timerTurn != view.turn) {
        _timerTurn = view.turn;
        _secondsLeft = kTurnSeconds;
        final mySeat = view.mySeat;
        final turn = view.turn;
        _turnTicker?.cancel();
        _turnTicker = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          setState(() => _secondsLeft = (_secondsLeft - 1).clamp(0, kTurnSeconds));
          if (_secondsLeft <= 0) {
            _turnTicker?.cancel();
            // 시간초과 → 아무것도 안 함(가만히) 자동 제출.
            widget.service
                .submitMove(widget.code, turn, mySeat, const Move.idle());
          }
        });
      }
    } else {
      _turnTicker?.cancel();
      _timerTurn = -1;
    }
  }

  void _resetPendingFor(int turn) {
    if (_pendingTurn != turn) {
      _pendingTurn = turn;
      _selKind = null;
      _selTarget = -1;
      _selTarget2 = -1;
      _smokeOn = false;
      _peekSelecting = false;
    }
  }

  Widget _centerBanner(String banner) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: CD.leather.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(banner,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _scoreStrip(RoomView view) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: CD.leather.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        children: [
          for (final s in view.seats)
            if (s.joined)
              Text('${s.name} ${s.score}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _bottom(RoomView view) {
    if (view.phase == OnlinePhase.over) return _result(view);

    if (_revealing) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('결과 공개 중...',
            style: TextStyle(color: CD.leather, fontWeight: FontWeight.w700)),
      );
    }

    if (view.iAmLate) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('게임 진행 중 — 다음 판부터 참여해요! 관전 중...',
            style: TextStyle(
                color: CD.sage, fontSize: 15, fontWeight: FontWeight.bold)),
      );
    }

    if (!view.seated || (view.me != null && !view.me!.alive)) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('탈락! 관전 중...',
            style: TextStyle(
                color: CD.danger, fontSize: 16, fontWeight: FontWeight.bold)),
      );
    }

    // 파파라치 엿보기 — 다른 사람은 대기.
    if (view.peekActive && !view.iAmPeeker) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const Icon(Icons.photo_camera, color: Color(0xFF4A6FA5), size: 26),
          const SizedBox(height: 8),
          Text('📸 ${view.peekerName} 님이 엿보는 중...',
              style: const TextStyle(
                  color: Color(0xFF4A6FA5), fontWeight: FontWeight.w800)),
        ]),
      );
    }
    // 엿보기 지목 후 전원 제출 대기(엿보는 사람).
    if (view.iAmPeeker && !view.peekActive) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('📸 엿보기 — 다른 총잡이 제출을 기다리는 중...',
            style: TextStyle(
                color: Color(0xFF4A6FA5), fontWeight: FontWeight.w800)),
      );
    }

    if (view.phase == OnlinePhase.submitted) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const CircularProgressIndicator(color: CD.sage),
            const SizedBox(height: 10),
            Text('상대를 기다리는 중 (${view.submittedAlive}/${view.aliveCount})',
                style: const TextStyle(color: CD.leather, fontSize: 14)),
          ],
        ),
      );
    }

    final myAmmo = view.me?.ammo ?? 0;
    final myChar = view.me?.char ?? CharId.none;
    // 엿보는 사람의 재선택 단계 — 엿본 결과를 보여준다.
    final peekResult = (view.iAmPeeker && view.peekActive)
        ? '📸 ${view.peekTargetSeat >= 0 && view.peekTargetSeat < view.seats.length ? view.seats[view.peekTargetSeat].name : "상대"}의 행동: ${view.peekedMove?.kind.ko ?? "?"} — 내 행동을 고르세요'
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (peekResult != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(peekResult,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF4A6FA5),
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
            ),
          _turnCountdown(),
          ActionBar(
        myAmmo: myAmmo,
        selected: _selKind,
        selectedTarget: _selTarget,
        targetName: _selTarget >= 0 && _selTarget < view.seats.length
            ? view.seats[_selTarget].name
            : null,
        selectedTarget2: _selTarget2,
        targetName2: _selTarget2 >= 0 && _selTarget2 < view.seats.length
            ? view.seats[_selTarget2].name
            : null,
        myChar: myChar,
        trapAvailable: view.myTrapAvailable,
        smokeLeft: view.mySmokeLeft,
        smokeOn: _smokeOn,
        onSmokeToggle: (v) => setState(() => _smokeOn = v),
        showPeek: myChar == CharId.paparazzi && !view.myPaparazziUsed,
        peekEnabled: true,
        onPeek: () => setState(() {
          Sfx.click();
          _peekSelecting = true;
          _selKind = null;
          _selTarget = -1;
          _selTarget2 = -1;
        }),
        onSelect: (k) => setState(() {
          Sfx.click();
          _selKind = k;
          _selTarget = -1;
          _selTarget2 = -1;
          final opp = [
            for (final s in view.seats)
              if (s.alive && !s.isMe) s.seat
          ];
          // 외길이면 자동 지정.
          if (_isTargetAction(k) && k != ActKind.dualShoot && opp.length == 1) {
            _selTarget = opp.first;
          } else if (k == ActKind.dualShoot && opp.length == 2) {
            _selTarget = opp[0];
            _selTarget2 = opp[1];
          }
        }),
        onConfirm: () {
          Sfx.confirm();
          var m = switch (_selKind!) {
            ActKind.reload => const Move.reload(),
            ActKind.defend => const Move.defend(),
            ActKind.shoot => Move.shoot(_selTarget),
            ActKind.superShoot => Move.superShoot(_selTarget),
            ActKind.trap => const Move.trap(),
            ActKind.roulette => Move.roulette(_selTarget),
            ActKind.dualShoot => Move.dualShoot(_selTarget, _selTarget2),
            ActKind.voodoo => Move.voodoo(_selTarget),
            ActKind.idle => const Move.idle(),
          };
          if (_smokeOn &&
              myChar == CharId.smoker &&
              view.mySmokeLeft > 0 &&
              m.kind != ActKind.trap) {
            m = m.withSmoke(true);
          }
          widget.service.submitMove(widget.code, view.turn, view.mySeat, m);
        },
          ),
        ],
      ),
    );
  }

  /// 남은 시간 카운트다운 바 (10초 이하 빨강).
  Widget _turnCountdown() {
    final low = _secondsLeft <= 10;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer,
              size: 16, color: low ? CD.danger : CD.muted),
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

  Widget _result(RoomView view) {
    final iWon = view.iWon;
    return Container(
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
          Text(view.banner,
              textAlign: TextAlign.center,
              style: posterTitle(26, color: iWon ? CD.rust : CD.danger)),
          const SizedBox(height: 12),
          Text('다시하기 ${view.rematchCount}/${view.presentCount}',
              style: const TextStyle(color: CD.muted)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _leaveAndPop,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CD.leather,
                    side: const BorderSide(color: CD.leather),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('나가기'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: (!view.seated || view.iRequestedRematch)
                      ? null
                      : () => widget.service
                          .requestRematch(widget.code, view.mySeat),
                  style: FilledButton.styleFrom(
                    backgroundColor: CD.rust,
                    disabledBackgroundColor: CD.muted.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: Text(view.iRequestedRematch ? '대기 중...' : '다시하기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _info(String msg, {bool back = false}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(msg, style: posterTitle(20)),
          if (back) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _leaveAndPop,
              style: FilledButton.styleFrom(backgroundColor: CD.rust),
              child: const Text('나가기'),
            ),
          ],
        ],
      ),
    );
  }
}
