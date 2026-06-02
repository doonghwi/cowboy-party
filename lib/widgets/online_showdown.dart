import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../online/online_service.dart';
import 'reaction_panel.dart';

/// The online reaction showdown that breaks a final simultaneous wipe.
///
/// All clients render this off the shared `showdown` RTDB node: the host sets a
/// server-clock "go" time, every participant sees "준비..." flip to "카우보이!
/// 지금 탭!" at the same instant, and the first valid tap wins. Tapping before
/// the signal is a false start (=패배). If everyone jumps the gun the host
/// re-runs the round.
class OnlineShowdown extends StatefulWidget {
  final OnlineService service;
  final String code;
  final int drawTurn;
  final List<int> participants;
  final int mySeat;
  final Map<int, String> seatNames;
  final Map? sdRaw; // rooms/{code}/showdown
  final int serverOffset; // ms (server = local + offset)
  final bool isHost;

  const OnlineShowdown({
    super.key,
    required this.service,
    required this.code,
    required this.drawTurn,
    required this.participants,
    required this.mySeat,
    required this.seatNames,
    required this.sdRaw,
    required this.serverOffset,
    required this.isHost,
  });

  @override
  State<OnlineShowdown> createState() => _OnlineShowdownState();
}

class _OnlineShowdownState extends State<OnlineShowdown> {
  final _rand = Random();
  String? _roundKey;
  bool _signal = false;
  bool _false = false;
  bool _creating = false;
  Timer? _flip;

  bool get _amIn =>
      widget.mySeat >= 0 && widget.participants.contains(widget.mySeat);

  int get _serverNow =>
      DateTime.now().millisecondsSinceEpoch + widget.serverOffset;

  int _newGoAt() => _serverNow + 800 + 500 + _rand.nextInt(900); // lead + 0.5~1.4s

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant OnlineShowdown old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _flip?.cancel();
    super.dispose();
  }

  int? _i(Object? v) => v is num ? v.toInt() : null;

  void _sync() {
    final sd = widget.sdRaw;
    final matches = sd != null && _i(sd['turn']) == widget.drawTurn;

    // Host opens the showdown if it isn't set up for this draw yet.
    if (!matches) {
      if (widget.isHost && !_creating) {
        _creating = true;
        widget.service
            .createShowdown(
                widget.code, widget.drawTurn, widget.participants, _newGoAt())
            .whenComplete(() => _creating = false);
      }
      return;
    }

    final round = _i(sd['round']) ?? 0;
    final goAt = _i(sd['goAt']) ?? _serverNow + 1000;
    final fs = sd['falseStart'];
    final iFalseServer =
        fs is Map && fs['p${widget.mySeat}'] == true;
    final key = '${widget.drawTurn}-$round';

    if (key != _roundKey) {
      _roundKey = key;
      _flip?.cancel();
      _signal = false;
      _false = iFalseServer;
      final fireLocal = goAt - widget.serverOffset;
      final delay = fireLocal - DateTime.now().millisecondsSinceEpoch;
      if (delay <= 0) {
        _signal = true;
      } else {
        _flip = Timer(Duration(milliseconds: delay), () {
          if (mounted) setState(() => _signal = true);
        });
      }
    } else if (iFalseServer && !_false) {
      _false = true;
    }

    // If everyone jumped the gun, the host re-runs with a fresh signal.
    if (widget.isHost && sd['winner'] == null) {
      final allFalse = widget.participants.isNotEmpty &&
          widget.participants.every((s) {
            final m = sd['falseStart'];
            return m is Map && m['p$s'] == true;
          });
      if (allFalse && !_creating) {
        _creating = true;
        widget.service
            .newShowdownRound(widget.code, round + 1, _newGoAt())
            .whenComplete(() => _creating = false);
      }
    }
  }

  void _onTap() {
    if (!_amIn || _false) return;
    if (!_signal) {
      setState(() => _false = true);
      widget.service.recordFalseStart(widget.code, widget.mySeat);
    } else {
      widget.service.tryWinShowdown(widget.code, widget.mySeat);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = !_amIn
        ? ReactionStage.spectate
        : _false
            ? ReactionStage.falseStart
            : _signal
                ? ReactionStage.go
                : ReactionStage.prep;
    final others = widget.participants
        .where((s) => s != widget.mySeat)
        .map((s) => widget.seatNames[s] ?? '카우보이')
        .toList();
    return ReactionPanel(
      stage: stage,
      opponents: others,
      onTap: _onTap,
    );
  }
}
