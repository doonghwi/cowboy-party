import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'package:cowboy_bot_runner/auth.dart';
import 'package:cowboy_bot_runner/config.dart';
import 'package:cowboy_bot_runner/game/char_core.dart';
import 'package:cowboy_bot_runner/game/party_logic.dart';
import 'package:cowboy_bot_runner/game_replay.dart';
import 'package:cowboy_bot_runner/rtdb.dart';

/// e2e 검증 하니스: 사람 대신 **테스트 호스트**가 매칭 방을 만들고(→러너가 봇으로
/// 채움) 게임을 시작한 뒤 좌석0으로 장전만 하며 봇들이 끝까지 두는지 지켜본다.
///
/// 사용법(러너를 먼저 background로 띄운 상태에서):
///   COWBOY_AUTH_API_KEY=... COWBOY_BOT_CREDS=test_host_creds.json \
///     dart run bin/testgame.dart
int? _asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
Map? _asMap(Object? v) => v is Map ? v : null;

Future<void> main() async {
  Config.loadEnv(Platform.environment);
  final rng = Random();
  final client = http.Client();
  final auth = BotAuth(client);
  final rtdb = Rtdb(client);

  final cred = (await auth.ensureAccounts(['테스트호스트'])).first;
  final uid = cred.uid;
  Future<String> tok() => auth.freshIdToken(cred);

  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final code =
      List.generate(4, (_) => chars[rng.nextInt(chars.length)]).join();
  print('테스트 방 $code 생성(match, 좌석0=테스트호스트)...');

  await rtdb.put('rooms/$code', {
    'host': uid,
    'capacity': 6,
    'started': false,
    'public': false,
    'pw': '',
    'match': true,
    'title': '테스트 결투장',
    'hostName': '테스트호스트',
    'game': 0,
    'players': {
      'p0': {
        'id': uid,
        'name': '테스트호스트',
        'seen': Rtdb.serverTimestamp,
        'char': CharId.commoner.index,
      }
    },
    'createdAt': Rtdb.serverTimestamp,
  }, auth: await tok());

  // 봇이 붙을 때까지 대기(하트비트하며 최대 20초).
  print('봇 입장 대기...');
  var joined = 1;
  for (var i = 0; i < 40; i++) {
    await rtdb.put('rooms/$code/players/p0/seen', Rtdb.serverTimestamp,
        auth: await tok());
    final players = _asMap(await rtdb.get('rooms/$code/players')) ?? const {};
    joined = players.length;
    if (joined >= 3 && i >= 8) break; // 봇 2명+ 모이면 시작(유예5초 지난 뒤)
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  if (joined < 2) {
    print('봇이 안 붙었어요(러너 실행 중인지 확인). 방 정리 후 종료.');
    await rtdb.delete('rooms/$code', auth: await tok());
    exit(1);
  }

  // startGame: 좌석 압축 + chars 스냅샷 + started.
  print('$joined명 모임 → 게임 시작');
  final players = _asMap(await rtdb.get('rooms/$code/players')) ?? const {};
  final entries = <MapEntry<int, Map>>[];
  players.forEach((k, v) {
    final m = _asMap(v);
    if (m != null) entries.add(MapEntry(int.parse('$k'.substring(1)), m));
  });
  entries.sort((a, b) => a.key.compareTo(b.key));
  final compact = <String, Object?>{};
  final charsMap = <String, Object?>{};
  for (var i = 0; i < entries.length; i++) {
    final ci = _asInt(entries[i].value['char']) ?? 0;
    compact['p$i'] = {
      'id': entries[i].value['id'],
      'name': entries[i].value['name'],
      'seen': Rtdb.serverTimestamp,
      'char': ci,
    };
    charsMap['p$i'] = ci;
  }
  await rtdb.patch('rooms/$code', {
    'players': compact,
    'chars': charsMap,
    'seatCount': entries.length,
    'started': true,
    'game': 1,
    'turns': null,
  }, auth: await tok());

  // 좌석0(호스트)은 장전만 하며 봇들이 두는 걸 지켜본다.
  print('진행 관전(호스트는 장전만)...');
  var lastTurn = -1;
  for (var i = 0; i < 200; i++) {
    final data = _asMap(await rtdb.get('rooms/$code'));
    if (data == null) break;
    final r = replay(data, code);
    if (r.over) {
      if (r.status == GameStatus.won) {
        final names = _asMap(data['players']);
        final wname = _asMap(names?['p${r.winner}'])?['name'] ?? '?';
        print('🏆 승자: 좌석 ${r.winner} ($wname)');
      } else {
        print('결과: ${r.status.name} (결투/무승부)');
      }
      break;
    }
    if (r.currentTurn != lastTurn) {
      lastTurn = r.currentTurn;
      print('  턴 ${r.currentTurn}: 생존 ${r.alive.asMap().entries.where((e) => e.value).map((e) => e.key).toList()} 탄약 ${r.ammo}');
    }
    if (r.awaits(0)) {
      await rtdb.put('rooms/$code/turns/t${r.currentTurn}/p0',
          const Move.reload().encode(),
          auth: await tok());
      await rtdb.put('rooms/$code/players/p0/seen', Rtdb.serverTimestamp,
          auth: await tok());
    }
    await Future<void>.delayed(const Duration(milliseconds: 800));
  }

  // 랭킹 확인.
  final sid = _weeklySeasonId();
  final season = _asMap(await rtdb.get('seasons/$sid'));
  print('이번 주 랭킹($sid): ${season?.entries.map((e) => "${_asMap(e.value)?['name']}:${_asMap(e.value)?['pts']}").toList()}');

  await rtdb.delete('rooms/$code', auth: await tok());
  print('테스트 방 정리 완료.');
  exit(0);
}

String _weeklySeasonId() {
  final n = DateTime.now();
  final d = DateTime(n.year, n.month, n.day);
  final m = d.subtract(Duration(days: d.weekday - 1));
  String two(int x) => x.toString().padLeft(2, '0');
  return '${m.year}-${two(m.month)}-${two(m.day)}';
}
