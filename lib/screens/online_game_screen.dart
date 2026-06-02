import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/party_logic.dart';
import '../online/online_service.dart';
import '../theme.dart';
import '../widgets/action_bar.dart';
import '../widgets/circular_table.dart';
import '../widgets/desert_background.dart';
import '../widgets/online_showdown.dart';

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

  // Pending action for the current turn.
  int _pendingTurn = -1;
  ActKind? _selKind;
  int _selTarget = -1;

  // Mid-game reveal: briefly show who shot whom before the next turn's picker.
  int _shownTurn = 0;
  bool _revealing = false;
  Timer? _revealTimer;

  // Server clock skew for the reaction showdown.
  int _serverOffset = 0;
  StreamSubscription<DatabaseEvent>? _offsetSub;

  @override
  void initState() {
    super.initState();
    _offsetSub = widget.service.serverOffsetRef().onValue.listen((e) {
      final v = e.snapshot.value;
      if (v is num && mounted) setState(() => _serverOffset = v.toInt());
    });
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _offsetSub?.cancel();
    // Backstop leave (onDisconnect handles hard disconnects).
    if (_presenceSeat >= 0) widget.service.leave(widget.code, _presenceSeat);
    super.dispose();
  }

  Future<void> _leaveAndPop() async {
    final seat = _presenceSeat;
    _presenceSeat = -1;
    if (seat >= 0) await widget.service.leave(widget.code, seat);
    if (mounted) Navigator.of(context).pop();
  }

  void _updatePresence(int mySeat) {
    if (mySeat >= 0 && mySeat != _presenceSeat) {
      final old = _presenceSeat;
      if (old >= 0) widget.service.clearPresence(widget.code, old);
      _presenceSeat = mySeat;
      widget.service.markPresence(widget.code, mySeat);
    }
  }

  void _handleReveal(RoomView view) {
    if (view.phase == OnlinePhase.waiting) {
      _shownTurn = 0;
      return;
    }
    if (view.phase == OnlinePhase.over) return;
    // A rematch resets the turn counter — re-sync so reveals work next game.
    if (view.turn < _shownTurn) _shownTurn = view.turn;
    if (view.turn > _shownTurn) {
      final hadAction =
          view.seats.any((s) => s.fired) || view.seats.any((s) => s.hitThisTurn);
      _shownTurn = view.turn;
      if (hadAction) {
        _revealing = true;
        _revealTimer?.cancel();
        _revealTimer = Timer(const Duration(milliseconds: 2600), () {
          if (mounted) setState(() => _revealing = false);
        });
      }
    }
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
                final view =
                    OnlineService.computeView(data, widget.service.clientId);
                _updatePresence(view.mySeat);
                _handleReveal(view);
                _maybeReset(view);
                if (view.phase == OnlinePhase.waiting) return _waiting(view);
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

  void _maybeReset(RoomView view) {
    if (view.phase == OnlinePhase.over &&
        view.status == GameStatus.won &&
        view.isHost &&
        view.presentCount >= kMinSeats &&
        view.rematchCount >= view.presentCount &&
        !_resetting) {
      _resetting = true;
      widget.service.recordWinAndReset(widget.code, view.winnerSeat);
    }
    if (view.phase != OnlinePhase.over) _resetting = false;
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
            firedTarget: sv.firedTarget,
          ),
      ];

  Widget _table(RoomView view) {
    final reveal = view.phase == OnlinePhase.over || _revealing;
    final choosing =
        view.phase == OnlinePhase.choosing && view.seated && !_revealing;
    if (choosing) _resetPendingFor(view.turn);
    final targetMode = choosing && _selKind == ActKind.shoot;
    return Column(
      children: [
        const SizedBox(height: 6),
        _scoreStrip(view),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: CircularTable(
              seats: _seatsOf(view, reveal),
              mySeat: view.mySeat < 0 ? 0 : view.mySeat,
              reveal: reveal,
              targetMode: targetMode,
              selectedTarget: _selTarget,
              onSeatTap: (s) => setState(() => _selTarget = s),
              center: _centerBanner(view.banner),
            ),
          ),
        ),
        _bottom(view),
        const SizedBox(height: 10),
      ],
    );
  }

  void _resetPendingFor(int turn) {
    if (_pendingTurn != turn) {
      _pendingTurn = turn;
      _selKind = null;
      _selTarget = -1;
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

    if (!view.seated || (view.me != null && !view.me!.alive)) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('탈락! 관전 중...',
            style: TextStyle(
                color: CD.danger, fontSize: 16, fontWeight: FontWeight.bold)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ActionBar(
        myAmmo: myAmmo,
        selected: _selKind,
        selectedTarget: _selTarget,
        targetName: _selTarget >= 0 && _selTarget < view.seats.length
            ? view.seats[_selTarget].name
            : null,
        onSelect: (k) => setState(() {
          _selKind = k;
          if (k != ActKind.shoot) _selTarget = -1;
        }),
        onConfirm: () {
          final m = switch (_selKind!) {
            ActKind.reload => const Move.reload(),
            ActKind.defend => const Move.defend(),
            ActKind.shoot => Move.shoot(_selTarget),
          };
          widget.service.submitMove(widget.code, view.turn, view.mySeat, m);
        },
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
