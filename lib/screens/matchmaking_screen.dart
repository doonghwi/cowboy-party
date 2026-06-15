import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../meta/meta_service.dart';
import '../online/online_service.dart';
import '../theme.dart';
import '../widgets/desert_background.dart';
import 'online_game_screen.dart';

/// 빠른 시작 매칭(#2). 최대 10초 탐색.
/// - 모이는 중인 매칭 방 있으면 합류, 없으면 새로 판다(방장).
/// - 6명 차면 즉시 시작. 10초 시점에 2~5명이면 시작, 1명뿐이면 "상대 없음".
/// - 매칭 방은 비공개+match라 다른 사람은 보거나 들어올 수 없다.
class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  static const int _searchSeconds = 20;

  final _service = OnlineService();
  String? _code;
  bool _isLeader = false; // 현재 가장 낮은 좌석(시작/취소 결정권)
  bool _failScheduled = false;
  int _mySeat = -1;
  int _joined = 1;
  int _secondsLeft = _searchSeconds;
  bool _navigated = false;
  bool _failed = false;
  String _statusMsg = '매칭 상대를 찾는 중...';

  StreamSubscription<DatabaseEvent>? _sub;
  Timer? _tick;
  Timer? _heartbeat;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  Future<void> _begin() async {
    final name = Meta.I.nickname.isNotEmpty
        ? Meta.I.nickname
        : OnlineService.randomNickname();
    final r = await _service.quickMatch(name, charIndex: Meta.I.equippedIndex);
    if (!mounted) return;
    // host=true(내가 만든 방)면 좌석0이라 첫 리더. 이후 리더는 _onRoom이 좌석으로 판단.
    _isLeader = r.host;
    setState(() => _code = r.code);
    _sub = _service.watch(r.code).listen(_onRoom);
    _heartbeat = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_mySeat >= 0) _service.heartbeat(r.code, _mySeat);
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _onRoom(DatabaseEvent e) {
    if (!mounted || _navigated) return;
    final data = e.snapshot.value;
    if (data is! Map) {
      // 방이 사라짐 — 매칭 무산(방장이 취소했거나).
      _fail('지금은 매칭 상대가 없어요');
      return;
    }
    if (data['started'] == true) {
      _goToGame();
      return;
    }
    // 내 좌석 + 인원 + '리더'(가장 낮은 좌석) 계산.
    // 시작/취소는 리더가 몰아서 결정 — 방장이 나가도 다음 좌석이 이어받아 멈추지 않음.
    final players = (data['players'] is Map) ? data['players'] as Map : const {};
    var joined = 0;
    var lowest = 1 << 30;
    players.forEach((k, v) {
      if (v is Map) {
        final s = OnlineService.seatOf(k.toString());
        if (v['id'] == _service.clientId) _mySeat = s;
        if (s < lowest) lowest = s;
        joined++;
      }
    });
    _isLeader = _mySeat >= 0 && _mySeat == lowest;
    setState(() => _joined = joined.clamp(1, 6));
    // 6명 다 차면 리더가 즉시 시작.
    if (_isLeader && joined >= 6) _start();
  }

  void _onTick() {
    if (!mounted || _navigated || _failed) return;
    setState(() => _secondsLeft = (_secondsLeft - 1).clamp(0, _searchSeconds));
    if (_secondsLeft > 0) return;
    // 10초 종료 — 리더가 결정.
    if (_isLeader) {
      if (_joined >= 2) {
        _start();
      } else {
        _service.cancelMatch(_code!);
        _fail('지금은 매칭 상대가 없어요');
      }
    } else if (!_failScheduled) {
      // 리더가 못 살리면(없어졌으면) 잠시 뒤 실패 처리.
      _failScheduled = true;
      Timer(const Duration(seconds: 4), () {
        if (mounted && !_navigated && !_failed) _fail('매칭이 성사되지 않았어요');
      });
    }
  }

  Future<void> _start() async {
    if (_navigated || _code == null) return;
    await _service.startGame(_code!);
    // started 플래그가 _onRoom으로 돌아오며 _goToGame 호출됨.
  }

  void _goToGame() {
    if (_navigated || _code == null) return;
    _navigated = true;
    _tick?.cancel();
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => OnlineGameScreen(
          service: _service, code: _code!, matchMode: true),
    ));
  }

  void _fail(String msg) {
    if (_failed || _navigated) return;
    setState(() {
      _failed = true;
      _statusMsg = msg;
    });
    _tick?.cancel();
    _heartbeat?.cancel();
  }

  Future<void> _cancelAndPop() async {
    _tick?.cancel();
    _heartbeat?.cancel();
    await _sub?.cancel();
    if (_code != null && _mySeat >= 0 && !_navigated) {
      await _service.leave(_code!, _mySeat);
      // 나만 있던 방이면 정리(다른 사람이 있으면 남겨둬서 그들끼리 잡히게).
      if (_joined <= 1) await _service.cancelMatch(_code!);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _heartbeat?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelAndPop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text('빠른 시작', style: posterTitle(20))),
        body: DesertBackground(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_failed) ...[
                  const CircularProgressIndicator(color: CD.rust),
                  const SizedBox(height: 24),
                  Text('$_secondsLeft',
                      style: posterTitle(48, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(_statusMsg,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('현재 $_joined명',
                      style: TextStyle(color: CD.sand.withValues(alpha: 0.9))),
                ] else ...[
                  const Icon(Icons.search_off, color: Colors.white, size: 56),
                  const SizedBox(height: 14),
                  Text(_statusMsg,
                      textAlign: TextAlign.center,
                      style: posterTitle(20, color: Colors.white)),
                  const SizedBox(height: 6),
                  const Text('같은 시간에 빠른 시작을 누른 사람이 있어야 매칭돼요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: CD.sand, fontSize: 12)),
                ],
                const SizedBox(height: 28),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _failed ? CD.rust : CD.leather,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 13),
                  ),
                  onPressed: _cancelAndPop,
                  child: Text(_failed ? '돌아가기' : '취소',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
