// 친구 탭 '보낸 요청(대기중)' 카드 — 로컬 기록 렌더 검증(2026-07-18 사용자 요청).
// FRIENDS_CAPTURE_DIR 지정 시 보고용 PNG도 저장.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cowboy_party/online/friend_service.dart';
import 'package:cowboy_party/screens/friends_tab.dart';
import 'package:cowboy_party/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFonts() async {
  Future<ByteData> bd(String p) async {
    final bytes = await File(p).readAsBytes();
    return ByteData.view(bytes.buffer);
  }

  final pret = FontLoader('Pretendard')
    ..addFont(bd('assets/fonts/GothicA1-Regular.ttf'))
    ..addFont(bd('assets/fonts/GothicA1-Bold.ttf'))
    ..addFont(bd('assets/fonts/GothicA1-Black.ttf'));
  await pret.load();
  final bhs = FontLoader('BlackHanSans')
    ..addFont(bd('assets/fonts/BlackHanSans-Regular.ttf'));
  await bhs.load();
  final root =
      Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter';
  final iconsPath =
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  if (File(iconsPath).existsSync()) {
    final icons = FontLoader('MaterialIcons')..addFont(bd(iconsPath));
    await icons.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Platform.environment['FRIENDS_CAPTURE_DIR'];

  testWidgets('보낸 요청이 로컬 기록에서 대기중으로 표시된다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'sent_reqs_v1': jsonEncode([
        {'uid': 'u1', 'name': '보노보노', 'at': 1},
        {'uid': 'u2', 'name': '카우보이22', 'at': 2},
      ]),
    });
    // 서비스 계층 확인: 로컬 기록을 읽고, forget이 지운다.
    final list = await FriendService.I.sentRequests();
    expect(list.map((s) => s.name), ['보노보노', '카우보이22']);
    await FriendService.I.forgetSent('u2');
    expect((await FriendService.I.sentRequests()).length, 1);
    await FriendService.I.pruneSentByFriends(['u1']);
    expect(await FriendService.I.sentRequests(), isEmpty);

    // 화면: 대기중 카드가 두 명을 보여준다.
    SharedPreferences.setMockInitialValues({
      'sent_reqs_v1': jsonEncode([
        {'uid': 'u1', 'name': '보노보노', 'at': 1},
        {'uid': 'u2', 'name': '카우보이22', 'at': 2},
      ]),
    });
    await tester.runAsync(_loadFonts);
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildCowboyTheme(),
      home: const Scaffold(
        body: RepaintBoundary(key: Key('shot'), child: FriendsTab()),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('📤 보낸 요청'), findsOneWidget);
    expect(find.text('보노보노'), findsOneWidget);
    expect(find.text('카우보이22'), findsOneWidget);
    expect(find.text('대기중'), findsNWidgets(2));
    expect(find.text('취소'), findsNWidgets(2));

    if (out != null) {
      Directory(out).createSync(recursive: true);
      final boundary = tester
          .renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
      await tester.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: 2);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/friends_sent_pending.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    // 취소 탭 → 목록에서 사라진다(원격 제거는 Firebase 없음 → 무시됨).
    await tester.tap(find.text('취소').first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('대기중'), findsOneWidget);
  });
}
