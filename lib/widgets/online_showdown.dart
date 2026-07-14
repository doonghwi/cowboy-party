import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../audio/sfx.dart';

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
  int _myTapMs = 0; // 워치독 재기록용
  bool _creating = false;
  Timer? _flip;
  Timer? _arb;
  // 시간 기반 자가치유 틱 — 스냅샷이 안 와도(쓰기 유실·정적 상태) 진행되게.
  // "둘 다 부정출발이면 안 넘어간다" 제보(2026-07-13)의 핵심 수정.
  Timer? _tick;

  /// 신호 후 이 시간까지 응답(탭/부정출발) 없는 참가자는 이탈로 간주하고
  /// 라운드를 진행한다 — 한 명의 기록 유실/이탈로 전원이 멈추지 않게.
  static const int kNoShowMs = 8000;

  bool get _amIn =>
      widget.mySeat >= 0 && widget.participants.contains(widget.mySeat);

  int get _serverNow =>
      DateTime.now().millisecondsSinceEpoch + widget.serverOffset;

  int _newGoAt() => _serverNow + 800 + 500 + _rand.nextInt(900); // lead + 0.5~1.4s

  @override
  void initState() {
    super.initState();
    // 2단계: 쇼다운 전용 트랙(Smoking Gun).
    Bgm.play('showdown', volume: 0.26);
    _sync();
    _tick = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted) _watchdog();
    });
  }

  @override
  void didUpdateWidget(covariant OnlineShowdown old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    Bgm.play('battle', volume: 0.22); // 쇼다운 트랙 종료
    _flip?.cancel();
    _arb?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  /// 매 틱: ① 신호 시간이 지났는데 로컬이 prep이면 강제 전환(타이머 누락/오프셋
  /// 흔들림 방어 — "빨간 DRAW가 안 뜨더라" 제보) ② 내 기록이 서버에 안 보이면
  /// 재기록 ③ 방장이면 시간 기반 심판 재실행(무응답 타임아웃 포함).
  void _watchdog() {
    final sd = widget.sdRaw;
    if (sd == null || _i(sd['turn']) != widget.drawTurn) return;
    final goAt = _i(sd['goAt']) ?? 0;
    if (!_signal && !_false && goAt > 0 && _serverNow >= goAt) {
      setState(() => _signal = true);
    }
    // 내 상태 재기록(쓰기 유실 자가치유).
    final fs = sd['falseStart'];
    if (_false && !(fs is Map && fs['p${widget.mySeat}'] == true)) {
      widget.service.recordFalseStart(widget.code, widget.mySeat);
    }
    final taps = sd['taps'];
    if (_tapped &&
        _myTapMs > 0 &&
        !(taps is Map && taps['p${widget.mySeat}'] != null)) {
      widget.service.recordTap(widget.code, widget.mySeat, _myTapMs);
    }
    if (widget.isHost && sd['winner'] == null) {
      _hostArbitrate(sd, _i(sd['goAt']) ?? _serverNow, _i(sd['round']) ?? 0);
    }
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
  /// tapped and another simply hasn't yet. 신호 후 [kNoShowMs]가 지나면
  /// 무응답 참가자는 이탈로 간주하고 진행한다(전원 멈춤 방지).
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
    final timedOut = _serverNow > goAt + kNoShowMs;
    if (valid.isNotEmpty) {
      if (timedOut) {
        award(); // 무응답자는 그만 기다린다
        return;
      }
      // Someone reacted; give stragglers a brief window then award.
      _arb ??= Timer(const Duration(milliseconds: 700), () {
        _arb = null;
        if (mounted) award();
      });
      return;
    }
    // Nobody valid yet. 전원 부정출발이면 즉시, 아니면 타임아웃 후 재라운드
    // (응답 없는 좌석의 기록 유실/이탈로 전원이 멈추던 버그의 탈출구).
    final allFalse = widget.participants.isNotEmpty &&
        widget.participants.every(isFalse);
    if ((allFalse || timedOut) && !_creating) {
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
      _myTapMs = _serverNow;
      widget.service.recordTap(widget.code, widget.mySeat, _myTapMs);
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
