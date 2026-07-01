import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:cowboy_bot_runner/auth.dart';
import 'package:cowboy_bot_runner/bot_client.dart';
import 'package:cowboy_bot_runner/bot_pool.dart';
import 'package:cowboy_bot_runner/config.dart';
import 'package:cowboy_bot_runner/matchmaker.dart';
import 'package:cowboy_bot_runner/room_janitor.dart';
import 'package:cowboy_bot_runner/rtdb.dart';
import 'package:cowboy_bot_runner/social_sim.dart';

Future<void> main(List<String> args) async {
  Config.loadEnv(Platform.environment);

  print('=== 카우보이 봇 러너 ===');
  print('프로젝트: ${Config.projectId}');
  print('봇 이름(${Config.botNames.length}): ${Config.botNames.join(", ")}');

  if (Config.authApiKey == 'REPLACE_WITH_SERVER_API_KEY') {
    stderr.writeln('''
[설정 필요] 서버용 Firebase API 키가 없습니다.
  Cloud Console에서 애플리케이션 제한 없는(또는 맥미니 IP 제한) API 키를 만들고
  (Identity Toolkit API 허용), 환경변수로 주입하세요:
    export COWBOY_AUTH_API_KEY=AIza...
  또는 lib/config.dart 의 authApiKey 기본값을 교체하세요.
''');
    exit(1);
  }

  final client = http.Client();
  final auth = BotAuth(client);
  final rtdb = Rtdb(client);

  print('봇 계정 준비 중(저장형 익명)...');
  final BotPool pool;
  final BotClient janitorBot;
  try {
    final creds = await auth.ensureAccounts(Config.botNames);
    final clients = [
      for (var i = 0; i < creds.length; i++)
        BotClient(rtdb, auth, creds[i], Config.bots[i])
    ];
    pool = BotPool(clients);
    janitorBot = clients.first;
    print('계정 준비 완료: ${creds.map((c) => "${c.name}(${c.uid.substring(0, 6)}…)").join(", ")}');
  } catch (e) {
    stderr.writeln('계정 준비 실패: $e');
    exit(1);
  }

  // 빠른시작 채우기 + 공개방 사회성 + 죽은 방 청소를 같은 봇 풀로 동시에 돌린다.
  final mm = Matchmaker(rtdb, pool);
  final social = SocialSim(rtdb, pool);
  final janitor = RoomJanitor(rtdb, janitorBot);
  await Future.wait([mm.run(), social.run(), janitor.run()]);
}
