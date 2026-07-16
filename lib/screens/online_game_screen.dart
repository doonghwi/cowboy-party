import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../audio/juice_sfx.dart';
import '../audio/sfx.dart';
import '../game/characters.dart';
import '../game/party_logic.dart';
import '../meta/analytics.dart';
import '../meta/meta_service.dart';
import '../meta/char_stats.dart';
import '../meta/season_service.dart';
import '../online/friend_service.dart';
import 'friends_sheet.dart';
import '../online/online_service.dart';
import '../theme.dart';
import '../widgets/char_pager_sheet.dart';
import '../widgets/action_bar.dart';
import '../widgets/celebration.dart';
import '../widgets/circular_table.dart';
import '../widgets/seat_profile.dart';
import '../widgets/desert_background.dart';
import '../widgets/emoji_bar.dart';
import '../widgets/juice.dart';
import '../widgets/juice3.dart';
import '../widgets/online_showdown.dart';
import '../widgets/super_flash.dart';
import '../widgets/top_toast.dart';

class OnlineGameScreen extends StatefulWidget {
  final OnlineService service;
  final String code;

  /// 매칭(#2)으로 들어온 방: 게임 끝나면 '다시하기' 없이 '나가기'만.
  final bool matchMode;

  const OnlineGameScreen({
    super.key,
    required this.service,
    required this.code,
    this.matchMode = false,
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

  // 타격감(W2) + 지표(game_start 1회 로깅).
  final _juice = JuiceController();
  bool _loggedStart = false;

  // Server clock skew (for both staleness and the reaction showdown).
  int _serverOffset = 0;
  StreamSubscription<DatabaseEvent>? _offsetSub;
  Timer? _heartbeat;

  // 레디 독촉(크아식): 마지막으로 본 nudge 시각(0=아직 기준 미설정).
  int _seenNudgeAt = -1;
  int _nudgeKey = 0; // 준비 버튼 흔들림 트리거

  // 제출 자가치유 워치독: 내가 이 턴에 제출한 행동을 기억해 뒀다가
  // 뷰에 반영이 안 되면(쓰기 유실) 다시 쓴다.
  // 3단계 탄흔 영속 — (좌석, 시드).
  final List<(int, int)> _bulletHoles = [];
  int _holeSeed = 0;
  int _submittedTurn = -1;
  Move? _submittedMoveObj;
  int _resubmits = 0;
  int _lastResubmitMs = 0;
  Timer? _staleTick;

  // Emoji reactions floating over seats.
  final Map<int, String> _reactions = {};
  final Map<int, Timer> _rxTimers = {};
  final Map<int, int> _seenReactTs = {};

  @override
  void initState() {
    super.initState();
    Bgm.play('battle', volume: 0.22); // 전투 배경음(07-12 3배 상향)
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
    Bgm.play('menu', volume: 0.06); // 메뉴로 복귀 → 메뉴 배경음
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

  bool _leaving = false; // 이중 pop(검은 화면) 방지 가드
  OnlinePhase _phaseNow = OnlinePhase.waiting;

  Future<void> _leaveAndPop() async {
    if (_leaving) return; // 연타/스트림 경합으로 두 번 pop되던 버그(2026-07-16)
    _leaving = true;
    final seat = _presenceSeat;
    final started = _startedNow;
    _presenceSeat = -1;
    if (seat >= 0) {
      await widget.service
          .leave(widget.code, seat, started: started, name: _myName);
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// 뒤로가기 = 확인부터. 대기방/게임 중 문구를 나눠 묻고,
  /// 게임이 끝난 화면에서는 묻지 않고 바로 나간다(2026-07-16 사용자 제안).
  void _confirmLeave() {
    if (_leaving) return;
    if (_phaseNow == OnlinePhase.over || !_startedNow && _presenceSeat < 0) {
      _leaveAndPop();
      return;
    }
    final inGame = _startedNow;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CD.parchment,
        title: Text(inGame ? '게임을 나가시겠어요?' : '방을 나가시겠어요?'),
        content: inGame ? const Text('나가면 이번 판은 탈락으로 처리돼요.') : null,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('계속하기')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CD.danger),
            onPressed: () {
              Navigator.pop(ctx);
              _leaveAndPop();
            },
            child: const Text('나가기',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _track(RoomView view) {
    _presenceSeat = view.mySeat;
    _startedNow = view.started;
    _phaseNow = view.phase;
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
          if (view.iWon) {
            // 승리: 배경음을 걷어내고 Cowboy Sting만(사용자 결정 — win.wav 제거).
            Bgm.stop();
            Bgm.sting('sting');
          } else {
            Sfx.lose();
          }
        }
        // 마지막 한 방(리빌 창 없이 바로 종료)에도 손맛을 준다.
        _playRevealJuice(view, view.seats.any((s) => s.superFired));
      }
      return;
    }
    _superFlashedOver = false; // re-arm for the next game's finale
    _endSoundPlayed = false;
    if (view.phase == OnlinePhase.waiting) {
      _shownTurn = 0;
      _loggedStart = false; // 다음 판 game_start 재로깅용
      _bulletHoles.clear(); // 새 판 — 탄흔 리셋
      return;
    }
    if (!_loggedStart) {
      _loggedStart = true;
      Ana.log('game_start', {'mode': 'online', 'players': view.seatCount});
    }
    // A rematch resets the turn counter — re-sync so reveals work next game.
    if (view.turn < _shownTurn) _shownTurn = view.turn;
    if (view.turn > _shownTurn) {
      final hadAction =
          view.seats.any((s) => s.fired) || view.seats.any((s) => s.hitThisTurn);
      final hadSuper = view.seats.any((s) => s.superFired);
      _shownTurn = view.turn;
      _playRevealSound(view, hadSuper);
      _playRevealJuice(view, hadSuper);
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

  /// 하스스톤식 타격감(W2): 결과에 맞춰 화면 흔들림·햅틱. 내 피해가 최우선.
  void _playRevealJuice(RoomView view, bool hadSuper) {
    final me = view.mySeat >= 0 && view.mySeat < view.seats.length
        ? view.seats[view.mySeat]
        : null;
    // 3단계: 피격 좌석 탄흔(상한 50).
    for (final s in view.seats) {
      if (s.hitThisTurn) _bulletHoles.add((s.seat, _holeSeed++));
    }
    if (_bulletHoles.length > kMaxBulletHoles) {
      _bulletHoles.removeRange(0, _bulletHoles.length - kMaxBulletHoles);
    }
    if (me?.hitThisTurn == true) {
      _juice.hurt();
      HapticFeedback.mediumImpact(); // 피격=medium(사망·승리만 heavy)
    } else if (hadSuper) {
      _juice.shake(12);
      HapticFeedback.heavyImpact();
    } else if (view.seats.any((s) => s.hitThisTurn)) {
      _juice.shake(6);
      HapticFeedback.mediumImpact();
    } else if (view.seats.any((s) => s.fired)) {
      _juice.shake(2.5); // 발사됐지만 전부 방어/빗나감 — 잔진동만
      HapticFeedback.lightImpact();
    }
    // 히트스톱(1단계) / 킬 슬로모(3단계): 게임이 끝나는 리빌이면 슬로모.
    if (view.seats.any((s) => s.hitThisTurn)) {
      final mine = me?.hitThisTurn == true;
      final endsGame = view.phase == OnlinePhase.over ||
          view.status == GameStatus.won;
      Timer(
          const Duration(milliseconds: 430),
          () => endsGame
              ? JuiceController.slowMo()
              : JuiceController.hitStop(ms: mine ? 80 : 50));
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
      JuiceSfx.shot();
      if (seats.any((s) => s.hitThisTurn)) {
        // 타격음은 탄환 코어 도착(~450ms)에 맞춘다(넉백·히트스톱과 동기).
        Timer(const Duration(milliseconds: 440), JuiceSfx.hit);
      } else if (seats.any((s) => s.evadedFx)) {
        Timer(const Duration(milliseconds: 130), () => Sfx.play('smoke'));
      } else {
        Timer(const Duration(milliseconds: 130), () => Sfx.play('shield'));
      }
    } else if (seats.any((s) => s.healedFx)) {
      Sfx.play('shield');
    } else if (seats.any((s) => s.hitThisTurn)) {
      // 총성 없는 죽음(저주·운명의 방아쇠 반사 등).
      JuiceSfx.hit();
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
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _confirmLeave,
          ),
          title: Text('대결방', style: posterTitle(20)),
          actions: [
            IconButton(
              tooltip: '초대 링크 공유',
              icon: const Icon(Icons.share, size: 20),
              onPressed: _shareInvite,
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
                _handleNudge(data, view);
                _ensureSubmitDelivered(view);
                _maybeReset(view, data['scored'] == true);
                _maybeReward(view);
                _manageTurnTimer(view);
                _maybePeekUnblock(view);
                if (view.iShouldClaimHost) widget.service.ensureHost(widget.code);
                if (view.iWasKicked) {
                  return _info('방장이 방에서 내보냈어요.', back: true);
                }
                if (view.phase == OnlinePhase.waiting) {
                  if (view.mySeat < 0) {
                    // 내 좌석이 이미 사라짐 — 안내 화면·나가기 버튼 없이
                    // 조용히 이전 화면으로(이중 pop 검은 화면 제보, 2026-07-16).
                    if (!_leaving) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _leaveAndPop();
                      });
                    }
                    return const Center(
                        child: CircularProgressIndicator(color: CD.rust));
                  }
                  return _waiting(view, data);
                }
                if (view.iAmOut) {
                  return _info('연결이 끊겨서 방에서 나오게 됐어요.\n초대 링크로 다시 들어올 수 있어요.',
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

  // F2: 방장 좌석 관리 — 빈 자리 열기/닫기, 들어온 사람 추방. (크레이지아케이드식)
  void _hostSeatAction(RoomView view, int s) {
    if (s == view.mySeat) return; // 방장 자신
    if (s >= view.seats.length) return;
    final sv = view.seats[s];
    if (sv.joined) {
      // 추방 확인.
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: CD.parchment,
          title: const Text('내보내기'),
          content: Text('${sv.name} 님을 방에서 내보낼까요? 다시 들어올 수 없어요.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: CD.danger),
              onPressed: () {
                Navigator.pop(ctx);
                widget.service.kickSeat(widget.code, s);
              },
              child: const Text('내보내기',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
      return;
    }
    // 빈 자리: 닫기/열기 토글. 열린 자리가 2개 미만이 되지 않게.
    final openCount = view.seats.where((x) => !x.blocked).length;
    if (!sv.blocked && openCount <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('최소 2자리는 열려 있어야 해요'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    Sfx.click();
    widget.service.setSeatBlocked(widget.code, s, !sv.blocked);
  }

  // F1: 대기실에서 내 캐릭터 변경(보유한 캐릭터 중에서). 시작 전만.
  // #8(2026-07-15): 아이콘 그리드 → 일러스트 페이저(능력 설명 포함).
  void _changeCharInRoom(int mySeat) {
    final owned = [for (final d in kCharacters) if (Meta.I.isUnlocked(d.id)) d];
    showCharPagerSheet(
      context,
      chars: owned,
      current: Meta.I.equipped,
      onPick: (d) {
        Sfx.confirm();
        Meta.I.equip(d.id);
        widget.service.setRoomChar(widget.code, mySeat, d.id.index);
      },
    );
  }

  // F4: 네이티브 공유 시트(카톡 등). 실패 시 링크 복사로 폴백.
  Future<void> _shareInvite() async {
    final link = OnlineService.inviteLink(widget.code);
    final text = '카우보이 한 판 하자!\n$link';
    try {
      await Share.share(text, subject: '카우보이 초대');
    } catch (_) {
      Clipboard.setData(ClipboardData(text: link));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('초대 링크를 복사했어요 — 카톡 등에 붙여넣어 초대해 보세요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
    Ana.log('game_end',
        {'mode': 'online', 'players': players, 'won': iWon ? 1 : 0});
    final coins = iWon ? Meta.I.grantWin(players) : Meta.I.grantPlay();
    if (iWon) SeasonService.I.recordWin(players);
    // #12 승률 트래커: 내 캐릭터의 승/패 1건 기록(밸런스용).
    if (view.mySeat >= 0 && view.mySeat < view.seats.length) {
      CharStats.I.record(view.seats[view.mySeat].char, won: iWon);
    }
    // #1 친구 탭 추천용: 같이 플레이한 닉네임 기록(로컬, 베스트에포트).
    FriendService.I.noteRecentPlayers([
      for (final s in view.seats)
        if (s.seat != view.mySeat && s.name.isNotEmpty) s.name,
    ]);
    // #9 데일리 미션 진행 + 달성 보상.
    final rew = Meta.I.noteGamePlayed(won: iWon);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TopToast.show(
        context,
        message: !rew.isEmpty
            ? '${iWon ? "승리" : "참가"} +$coins · 보상 ${rew.lines.length}개 +${rew.coinsGained} 코인!'
            : (iWon ? '승리 보상 +$coins 코인!' : '참가 보상 +$coins 코인'),
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

  Widget _waiting(RoomView view, Map data) {
    // 준비 상태(방장 제외 전원 준비해야 시작). 방장 = 참여 좌석 중 가장 낮은 좌석.
    // 빠른시작(match) 방은 봇이 준비를 안 누르므로 게이트 제외(항상 시작 가능).
    final isMatch = data['match'] == true;
    final present = [for (final s in view.seats) if (s.joined) s.seat];
    // 방장 좌석은 서비스의 승계 규칙(입장 오래된 순)을 그대로 쓴다 —
    // "최저 좌석=방장" 파생은 신규 입장자가 방장으로 보이던 버그의 원인.
    final hostSeat = view.hostSeat >= 0
        ? view.hostSeat
        : (present.isEmpty ? 0 : present.reduce((a, b) => a < b ? a : b));
    final nonHost = present.where((s) => s != hostSeat).toList();
    // 준비 판정은 computeView(좌석+주인 id 매칭) 것을 그대로 쓴다 —
    // 좌석 재사용·하트비트 순단으로 준비가 풀리던 버그 수정(2026-07-12 제보).
    final readyCount = nonHost.where(view.readySeats.contains).length;
    final needReady = !isMatch;
    final allReady =
        !needReady || (nonHost.isNotEmpty && readyCount == nonHost.length);
    final iAmReady = view.iAmReady;
    return Column(
      children: [
        const SizedBox(height: 12),
        Text('대기실', style: posterTitle(18)),
        const SizedBox(height: 4),
        const Text('친구를 초대하고, 모두 준비되면 시작할 수 있어요',
            style: TextStyle(color: CD.muted)),
        const SizedBox(height: 8),
        // 대기실 버튼은 준비 버튼과 같은 채운 배경+둥근 직사각형(#7).
        // 초대 링크 공유 버튼은 제거 — 우상단 공유 아이콘이 같은 역할.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            FilledButton.icon(
              onPressed: () => showFriendsSheet(context,
                  onInvite: (uid) =>
                      FriendService.I.invite(uid, widget.code)),
              style: FilledButton.styleFrom(
                backgroundColor: CD.gold,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.group_add, size: 18),
              label: const Text('친구 초대',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            // F1: 시작 전 대기실에서 캐릭터 변경.
            FilledButton.icon(
              onPressed: view.mySeat < 0
                  ? null
                  : () => _changeCharInRoom(view.mySeat),
              style: FilledButton.styleFrom(
                backgroundColor: CD.sage,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.face_retouching_natural, size: 18),
              label: const Text('캐릭터 변경',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        if (view.isHost)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('방장은 빈 자리를 탭해 닫거나 열고, 들어온 사람을 탭해 내보낼 수 있어요',
                textAlign: TextAlign.center,
                style: TextStyle(color: CD.muted, fontSize: 11.5)),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: CircularTable(
              seats: _seatsOf(view, false,
                  // 방장은 준비 개념이 없으므로 항상 준비한 것으로 표시.
                  readyOf: needReady
                      ? (seat) =>
                          seat == hostSeat || view.readySeats.contains(seat)
                      : null,
                  hostSeat: hostSeat),
              mySeat: view.mySeat < 0 ? 0 : view.mySeat,
              onSeatInfo:
                  view.isHost ? (s) => _hostSeatAction(view, s) : null,
              center: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: CD.leather.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 방장이 닫은 자리는 정원에서 뺀다(#2).
                    Text(
                        '${view.joinedCount} / ${view.capacity - view.seats.where((s) => s.blocked).length}',
                        style: posterTitle(22, color: Colors.white)),
                    if (needReady && nonHost.isNotEmpty)
                      Text('준비 ${readyCount + 1}/${present.length}',
                          style: TextStyle(
                              color: readyCount == nonHost.length
                                  ? CD.sage
                                  : CD.parchment,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800)),
                  ],
                ),
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
                    // 2명 이상이면 누를 수 있고, 준비 안 된 사람 있으면 안내만 뜬다.
                    onPressed:
                        view.canStart ? () => _hostStart(allReady) : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: allReady ? CD.rust : CD.leather,
                      disabledBackgroundColor: CD.muted.withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                        !view.canStart
                            ? '2명 이상 모이면 시작'
                            : allReady
                                ? '시작! (${view.joinedCount}명)'
                                : '준비 대기 (${readyCount + 1}/${present.length})',
                        style: posterTitle(18, color: Colors.white)),
                  ),
                )
              : !needReady
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text('방장이 시작하기를 기다리는 중...',
                          style: TextStyle(
                              color: CD.leather, fontWeight: FontWeight.w700)),
                    )
                  : TweenAnimationBuilder<double>(
                      // 방장의 레디 독촉이 오면(_nudgeKey 증가) 버튼이 좌우로 떨린다.
                      key: ValueKey('nudge-$_nudgeKey'),
                      tween: Tween(begin: _nudgeKey == 0 ? 1.0 : 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 500),
                      builder: (context, tv, child) => Transform.translate(
                        offset: Offset(
                            math.sin(tv * math.pi * 6) * 6 * (1 - tv), 0),
                        child: child,
                      ),
                      child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: view.mySeat < 0
                            ? null
                            : () => widget.service
                                .setReady(widget.code, view.mySeat, !iAmReady),
                        style: FilledButton.styleFrom(
                          backgroundColor: iAmReady ? CD.sage : CD.leather,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: Icon(iAmReady
                            ? Icons.check_circle
                            : Icons.check_circle_outline),
                        label: Text(iAmReady ? '준비 완료 (탭해서 해제)' : '준비하기',
                            style: posterTitle(18, color: Colors.white)),
                      ),
                    ),
                    ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  /// 방장 시작 버튼: 전원 준비돼야 시작, 아니면 대기실 전원에게 레디 독촉 신호.
  void _hostStart(bool allReady) {
    if (allReady) {
      widget.service.startGame(widget.code);
    } else {
      widget.service.nudgeReady(widget.code); // 미준비자 화면이 울린다
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('아직 준비하지 않은 사람이 있어요. 모두 "준비"를 누르면 시작할 수 있어요.'),
        duration: Duration(seconds: 2),
      ));
    }
  }

  // ---- Table -------------------------------------------------------------

  /// [readyOf]가 주어지면(대기실) 제출 ✓ 배지 자리를 "준비 완료" 표시로 쓴다
  /// — 다른 사람이 준비했는지 모두가 볼 수 있게(2026-07-12 사용자 요청).
  List<TableSeat> _seatsOf(RoomView view, bool reveal,
          {bool Function(int seat)? readyOf, int hostSeat = -1}) =>
      [
        for (final sv in view.seats)
          TableSeat(
            isHostSeat: sv.seat == hostSeat,
            // 대기방(readyOf != null)에서만 레벨 노출, 휘장은 게임 중에도.
            // 빈자리는 level 0 → SeatCard가 총알/레벨 줄을 아예 생략(2026-07-16).
            level: readyOf != null ? (sv.joined ? sv.level : 0) : -1,
            rank: sv.rank,
            name: view.started && !sv.joined ? '나감' : sv.name,
            ammo: sv.ammo,
            alive: sv.alive,
            isMe: sv.isMe,
            joined: sv.joined || !view.started,
            submitted: readyOf != null
                ? (sv.joined && readyOf(sv.seat))
                : (sv.submittedThisTurn && view.phase != OnlinePhase.over),
            hit: sv.hitThisTurn && reveal,
            lastMove: sv.lastMove,
            fired: sv.fired,
            superFired: sv.superFired,
            firedTarget: sv.firedTarget,
            firedTarget2: sv.firedTarget2,
            char: sv.char,
            late: sv.late,
            healedFx: sv.healedFx,
            evadedFx: sv.evadedFx,
            smoked: sv.smokedFx,
            reflectedFx: sv.reflectedFx,
            doubleLoadFx: sv.doubleLoadFx,
            piercedFx: sv.piercedFx,
            resetFx: sv.resetFx,
            rouletteSelfFx: sv.rouletteSelfFx,
            blocked: sv.blocked,
            abilityUses: sv.abilityUses,
            curseTurnsLeft: sv.curseTurnsLeft,
            curseKillFx: sv.curseKillFx,
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
            child: JuiceLayer(
              controller: _juice,
              child: Stack(
              children: [
                CircularTable(
                  seats: _seatsOf(view, reveal),
                  mySeat: view.mySeat < 0 ? 0 : view.mySeat,
                  reveal: reveal,
                  bulletHoles: _bulletHoles,
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
                  onSeatInfo: (s) {
                    if (s < view.seats.length) {
                      final sv = view.seats[s];
                      showSeatProfile(context,
                          name: sv.name, char: sv.char, score: sv.score);
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
                // 승리 셀레브레이션(2단계): 내가 이긴 순간 금색 콘페티.
                if (view.phase == OnlinePhase.over && view.iWon)
                  const Positioned.fill(
                    child: Celebration(key: ValueKey('celebrate')),
                  ),
              ],
              ),
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
            _submittedTurn = turn;
            _submittedMoveObj = const Move.idle();
            _resubmits = 0;
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

  /// 방장의 레디 독촉 신호 처리 — 미준비 본인에게 토스트+햅틱+버튼 흔들림.
  void _handleNudge(Map data, RoomView view) {
    final n = data['nudge'];
    final at = (n is Map) ? (n['at'] is int ? n['at'] as int : null) : null;
    if (at == null) return;
    if (_seenNudgeAt < 0) {
      _seenNudgeAt = at; // 입장 시점의 과거 신호는 무시(기준만 잡음)
      return;
    }
    if (at <= _seenNudgeAt) return;
    _seenNudgeAt = at;
    if (view.phase != OnlinePhase.waiting || view.isHost) return;
    if (view.iAmReady) return;
    HapticFeedback.mediumImpact();
    _nudgeKey++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
      TopToast.show(context, message: '🔔 방장이 시작하려고 해요 — 준비를 눌러주세요!');
    });
  }

  /// 제출 워치독: 제출했다고 믿는 턴이 뷰에 미제출로 남아 있으면 재제출(2초 간격,
  /// 최대 4회). 연결 순단으로 쓰기가 유실돼 게임이 영영 안 넘어가던 버그의 자가치유.
  void _ensureSubmitDelivered(RoomView view) {
    if (_submittedTurn < 0 || _submittedMoveObj == null) return;
    if (view.phase != OnlinePhase.choosing || view.turn != _submittedTurn) {
      if (view.turn != _submittedTurn) {
        _submittedTurn = -1; // 턴이 넘어갔으면 임무 완료
        _submittedMoveObj = null;
        _resubmits = 0;
      }
      return;
    }
    if (view.me?.submittedThisTurn == true) return; // 정상 반영됨
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_resubmits >= 4 || now - _lastResubmitMs < 2000) return;
    _resubmits++;
    _lastResubmitMs = now;
    widget.service.submitMove(
        widget.code, _submittedTurn, view.mySeat, _submittedMoveObj!);
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
        resetAvailable: view.myResetAvailable,
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
            ActKind.reset => const Move.reset(),
            ActKind.idle => const Move.idle(),
          };
          if (_smokeOn &&
              myChar == CharId.smoker &&
              view.mySmokeLeft > 0 &&
              m.kind != ActKind.trap) {
            m = m.withSmoke(true);
          }
          _submittedTurn = view.turn; // 워치독: 유실 시 재제출용 기억
          _submittedMoveObj = m;
          _resubmits = 0;
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
          // 매칭 방(#2)은 다시하기 없이 나가기만.
          if (widget.matchMode)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _leaveAndPop,
                style: FilledButton.styleFrom(
                  backgroundColor: CD.rust,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text('나가기'),
              ),
            )
          else ...[
            // 결과 카드 안내는 1줄(#6). 게임 끝나면 대기실로.
            const Text('대기실에서 캐릭터를 바꾸고 다시 시작할 수 있어요',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: CD.muted, fontSize: 12)),
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
                  flex: 2,
                  child: FilledButton(
                    onPressed: () =>
                        widget.service.resetBoard(widget.code, toLobby: true),
                    style: FilledButton.styleFrom(
                      backgroundColor: CD.rust,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('대기실로 돌아가기'),
                  ),
                ),
              ],
            ),
          ],
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
