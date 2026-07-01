import 'game/party_logic.dart';

/// 방 데이터의 턴 히스토리를 **클라이언트와 동일하게 재현**해서 현재 상태를
/// 만든다. seed=`{code}#{gameNo}` 와 resolvePartyTurn 이 앱과 같으므로(동기화된
/// 순수 파일) 봇의 계산은 사람 클라이언트와 항상 일치한다.
///
/// 표시(배너·이펙트·정체공개)는 봇에 불필요하므로 뺐다 — **게임 상태 + 내 차례**만.
class ReplayResult {
  final int n;
  final String seed;
  final List<CharId> chars; // effective(??? 변환 후)
  final List<int> ammo;
  final List<bool> alive;
  final PartyState pstate;
  final List<Move?> lastMoves; // 직전 턴 수(반격용)
  final int currentTurn; // 프런티어(미완료) 턴. 게임 끝났으면 -1.
  final List<bool> submitted; // 현재 턴에 각 좌석이 제출했는지
  final GameStatus status;
  final int? winner;
  final int drawTurn; // 무승부(결투)가 난 턴. 무승부 아니면 -1.
  final List<int> drawParticipants; // 결투 참가자(그 턴 시작 시 생존자).

  ReplayResult({
    required this.n,
    required this.seed,
    required this.chars,
    required this.ammo,
    required this.alive,
    required this.pstate,
    required this.lastMoves,
    required this.currentTurn,
    required this.submitted,
    required this.status,
    required this.winner,
    this.drawTurn = -1,
    this.drawParticipants = const [],
  });

  bool get over => currentTurn < 0;

  /// 좌석 [seat]가 살아있고 현재 턴에 아직 제출 안 했는가(=봇이 둘 차례).
  bool awaits(int seat) =>
      !over && seat < n && alive[seat] && !submitted[seat];
}

int? _asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
Map? _asMap(Object? v) => v is Map ? v : null;

/// [data] = rooms/{code} 스냅샷 맵. [seedKey] = 방 코드.
ReplayResult replay(Map data, String seedKey) {
  final gameNo = _asInt(data['game']) ?? 0;
  final charsMap = _asMap(data['chars']) ?? const {};
  final turnsMap = _asMap(data['turns']) ?? const {};
  var n = _asInt(data['seatCount']) ?? charsMap.length;
  if (n < kMinSeats) n = charsMap.length;
  final seed = '$seedKey#$gameNo';

  CharId charAt(int s) => charFromIndex(_asInt(charsMap['p$s']));
  final chars = <CharId>[
    for (var s = 0; s < n; s++) effectiveChar(charAt(s), seed, s)
  ];

  var ammo = <int>[for (var s = 0; s < n; s++) startAmmoFor(chars[s])];
  var alive = List<bool>.filled(n, true);
  var pstate = PartyState.initial(chars);
  var lastMoves = List<Move?>.filled(n, null);

  for (var t = 0; t < 1000; t++) {
    final turn = _asMap(turnsMap['t$t']);
    final submitted = List<bool>.filled(n, false);
    final moves = List<Move>.filled(n, Move.empty);
    var all = true;
    for (var s = 0; s < n; s++) {
      if (!alive[s]) continue;
      final raw = turn == null ? null : _asInt(turn['p$s']);
      if (raw == null) {
        all = false;
      } else {
        submitted[s] = true;
        moves[s] = Move.decode(raw);
      }
    }
    if (!all) {
      return ReplayResult(
        n: n,
        seed: seed,
        chars: chars,
        ammo: ammo,
        alive: alive,
        pstate: pstate,
        lastMoves: lastMoves,
        currentTurn: t,
        submitted: submitted,
        status: GameStatus.ongoing,
        winner: null,
      );
    }
    final aliveBefore = alive;
    final out = resolvePartyTurn(
      moves: moves,
      ammoBefore: ammo,
      aliveBefore: alive,
      chars: chars,
      state: pstate,
      seed: seed,
      turn: t,
    );
    ammo = out.ammoAfter;
    alive = out.aliveAfter;
    pstate = out.stateAfter!;
    lastMoves = List<Move?>.from(moves);
    if (out.status != GameStatus.ongoing) {
      // 무승부(전원 동시 탈락) 처리 — 앱 computeView 와 동일하게:
      // 결투 승자(showdown.winner)가 이미 있으면 그 사람 승리, 결투가가 참가자 중
      // 정확히 1명이면 자동 승리, 아니면 반응속도 결투 대기(draw + 참가자 목록).
      var status = out.status;
      var winner = out.winner;
      var drawTurn = -1;
      var drawParts = const <int>[];
      if (status == GameStatus.draw) {
        final parts = [
          for (var s = 0; s < n; s++)
            if (aliveBefore[s]) s
        ];
        final sd = _asMap(data['showdown']);
        final sdWinner = (sd != null && _asInt(sd['turn']) == t)
            ? _asInt(sd['winner'])
            : null;
        final dWin = duelistShowdownWinner(chars, parts);
        if (sdWinner != null) {
          status = GameStatus.won;
          winner = sdWinner;
        } else if (dWin != null) {
          status = GameStatus.won;
          winner = dWin;
        } else {
          drawTurn = t;
          drawParts = parts;
        }
      }
      return ReplayResult(
        n: n,
        seed: seed,
        chars: chars,
        ammo: ammo,
        alive: alive,
        pstate: pstate,
        lastMoves: lastMoves,
        currentTurn: -1,
        submitted: List<bool>.filled(n, true),
        status: status,
        winner: winner,
        drawTurn: drawTurn,
        drawParticipants: drawParts,
      );
    }
  }
  // 안전 상한(정상 게임은 여기 도달 안 함).
  return ReplayResult(
    n: n,
    seed: seed,
    chars: chars,
    ammo: ammo,
    alive: alive,
    pstate: pstate,
    lastMoves: lastMoves,
    currentTurn: -1,
    submitted: List<bool>.filled(n, true),
    status: GameStatus.draw,
    winner: null,
  );
}
