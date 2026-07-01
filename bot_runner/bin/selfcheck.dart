import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:cowboy_bot_runner/config.dart';
import 'package:cowboy_bot_runner/rtdb.dart';

/// 연결 점검: 실제 RTDB에서 rooms/seasons 를 읽어본다(공개 read, auth 불필요).
/// 러너 배포 전 config·네트워크·REST 경로가 맞는지 빠르게 확인.
Future<void> main() async {
  Config.loadEnv(Platform.environment);
  final rtdb = Rtdb(http.Client());
  print('DB: ${Config.databaseUrl}');

  final rooms = await rtdb.getShallow('rooms');
  print('rooms 최상위 키 ${rooms.length}개: ${rooms.keys.take(10).toList()}');

  final seasons = await rtdb.getShallow('seasons');
  print('seasons 키: ${seasons.keys.toList()}');

  print('✅ REST 읽기 OK — config·네트워크 정상.');
  exit(0);
}
