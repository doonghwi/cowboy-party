import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'package:cowboy_bot_runner/auth.dart';
import 'package:cowboy_bot_runner/bot_client.dart';
import 'package:cowboy_bot_runner/config.dart';
import 'package:cowboy_bot_runner/game/char_core.dart';
import 'package:cowboy_bot_runner/game/party_logic.dart';
import 'package:cowboy_bot_runner/rtdb.dart';

/// 결투(반응속도 showdown) e2e 하니스: 무승부로 끝난 게임 상태를 라이브 DB에
/// 만들어 놓고, 봇 호스트 심판(hostRefereeGame)이 showdown을 만들고 두 봇이
/// 탭해서 승자가 확정되는지 검증한다.
///
///   COWBOY_AUTH_API_KEY=... dart run bin/showdowntest.dart
Map? _asMap(Object? v) => v is Map ? v : null;

Future<void> main() async {
  Config.loadEnv(Platform.environment);
  final rng = Random();
  final client = http.Client();
  final auth = BotAuth(client);
  final rtdb = Rtdb(client);

  final creds = await auth.ensureAccounts(Config.botNames);
  final b0 = BotClient(rtdb, auth, creds[0], Config.bots[0]);
  final b1 = BotClient(rtdb, auth, creds[1], Config.bots[1]);

  const cs = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final code = 'SD${cs[rng.nextInt(cs.length)]}${cs[rng.nextInt(cs.length)]}';
  final c = CharId.commoner.index;
  final now = DateTime.now().millisecondsSinceEpoch;

  // 무승부 직후의 방: t0 둘 다 장전, t1 서로 사격 → 동시 사망(결투 대기).
  print('결투 테스트 방 $code 생성(무승부 상태)...');
  await rtdb.put('rooms/$code', {
    'host': creds[0].uid,
    'capacity': 6,
    'started': true,
    'public': false,
    'pw': '',
    'match': false,
    'title': '결투 테스트',
    'hostName': creds[0].name,
    'game': 1,
    'seatCount': 2,
    'chars': {'p0': c, 'p1': c},
    'players': {
      'p0': {'id': creds[0].uid, 'name': creds[0].name, 'seen': now, 'char': c},
      'p1': {'id': creds[1].uid, 'name': creds[1].name, 'seen': now, 'char': c},
    },
    'turns': {
      't0': {'p0': 0, 'p1': 0},
      't1': {'p0': Move.shoot(1).encode(), 'p1': Move.shoot(0).encode()},
    },
    'createdAt': now,
  }, auth: await auth.freshIdToken(creds[0]));

  // 두 봇이 결투 참가(탭) + 호스트 봇이 심판.
  await Future.wait([
    b0.playSeatedGame(code, 0),
    b1.playSeatedGame(code, 1),
    b0.hostRefereeGame(code),
  ]).timeout(const Duration(seconds: 30), onTimeout: () {
    print('FAIL: 30초 내에 결투가 안 끝남');
    exit(1);
  });

  final sd = _asMap(await rtdb.get('rooms/$code/showdown'));
  final winner = sd?['winner'];
  final taps = _asMap(sd?['taps']);
  final goAt = sd?['goAt'];
  print('showdown: goAt=$goAt taps=$taps winner=$winner');
  await rtdb.delete('rooms/$code', auth: await auth.freshIdToken(creds[0]));
  if (winner is! int) {
    print('FAIL: 승자 미확정');
    exit(1);
  }
  final tapVals = [for (final v in (taps ?? const {}).values) v as num];
  final validTaps = goAt is num && tapVals.every((t) => t >= goAt);
  print(validTaps
      ? 'PASS: 탭 ${tapVals.length}개 전부 goAt 이후(유효), 승자 좌석 $winner'
      : 'FAIL: goAt 이전 탭 존재(무효 탭 버그)');
  exit(validTaps ? 0 : 1);
}
