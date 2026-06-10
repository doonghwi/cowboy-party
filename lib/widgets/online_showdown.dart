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
  bool _tapped = false;
  bool _creating = false;
  Timer? _flip;
  Timer? _arb;

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
    _arb?.cancel();
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
      _arb?.cancel();
      _signal = false;
      _tapped = false;
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

    if (widget.isHost && sd['winner'] == null) {
      _hostArbitrate(sd, goAt, round);
    }
  }

  /// Host decides the round: the earliest valid tap wins. If everyone jumped
  /// the gun, re-run. A short settle timer covers the case where one player
  /// tapped and another simply hasn't yet.
  void _hostArbitrate(Map sd, int goAt, int round) {
    final fsMap = sd['falseStart'];
    final tapsMap = sd['taps'];
    bool isFalse(int s) => fsMap is Map && fsMap['p$s'] == true;
    int? tapOf(int s) =>
        tapsMap is Map ? _i(tapsMap['p$s']) : null;

    final valid = <int, int>{}; // seat -> tap time (>= goAt)
    for (final s in widget.participants) {
      final t = tapOf(s);
      if (t != null && t >= goAt && !isFalse(s)) valid[s] = t;
    }
    final accounted = widget.participants.every((s) {
      final t = tapOf(s);
      return isFalse(s) || (t != null && t >= goAt);
    });

    void award() {
      if (valid.isEmpty || _creating) return;
      var best = valid.keys.first;
      valid.forEach((s, t) {
        if (t < valid[best]!) best = s;
      });
      _creating = true;
      widget.service
          .setShowdownWinner(widget.code, best)
          .whenComplete(() => _creating = false);
    }

    if (valid.isNotEmpty && accounted) {
      award();
      return;
    }
    if (valid.isNotEmpty) {
      // Someone reacted; give stragglers a brief window then award.
      _arb ??= Timer(const Duration(milliseconds: 700), () {
        _arb = null;
        if (mounted) award();
      });
      return;
    }
    // Nobody valid yet. If everyone already false-started, re-run.
    final allFalse = widget.participants.isNotEmpty &&
        widget.participants.every(isFalse);
    if (allFalse && !_creating) {
      _creating = true;
      widget.service
          .newShowdownRound(widget.code, round + 1, _newGoAt())
          .whenComplete(() => _creating = false);
    }
  }

  void _onTap() {
    if (!_amIn || _false) return;
    if (!_signal) {
      setState(() => _false = true);
      widget.service.recordFalseStart(widget.code, widget.mySeat);
    } else if (!_tapped) {
      _tapped = true;
      widget.service.recordTap(widget.code, widget.mySeat, _serverNow);
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
