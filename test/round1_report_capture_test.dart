// 디자인 라운드1 반영 결과 보고서 캡처(일회성 도구) — ROUND1_CAPTURE_DIR 지정 시.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cowboy_party/game/characters.dart';
import 'package:cowboy_party/screens/characters_tab.dart';
import 'package:cowboy_party/screens/offline_game_screen.dart';
import 'package:cowboy_party/theme.dart';
import 'package:cowboy_party/widgets/rank_emblem.dart';
import 'package:cowboy_party/widgets/seat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
  final root = Platform.environment['FLUTTER_ROOT'] ??
      '/opt/homebrew/share/flutter';
  final iconsPath =
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  if (File(iconsPath).existsSync()) {
    final icons = FontLoader('MaterialIcons')..addFont(bd(iconsPath));
    await icons.load();
  }
}

Future<void> _save(
    WidgetTester tester, Key key, String dir, String file) async {
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$file').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  final out = Platform.environment['ROUND1_CAPTURE_DIR'];

  setUpAll(() async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    await _loadFonts();
  });

  testWidgets('좌석 카드 신규 3종(방장 금카드·티어 프레임·링 게이지)', (tester) async {
    if (out == null) return;
    await tester.binding.setSurfaceSize(const Size(600, 320));
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildCowboyTheme(),
      home: Material(
        type: MaterialType.transparency,
        child: RepaintBoundary(
          key: const Key('shot'),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [CD.skyTop, CD.duneNear],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 34, 24, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SizedBox(
                  width: 150,
                  child: SeatCard(
                      name: '방장님',
                      ammo: 0,
                      alive: true,
                      isHost: true,
                      level: 12,
                      char: CharId.dualgun),
                ),
                SizedBox(
                  width: 150,
                  child: SeatCard(
                      name: '지난시즌 1등',
                      ammo: 0,
                      alive: true,
                      level: 21,
                      rankTier: RankTier.challenger,
                      char: CharId.sniper),
                ),
                SizedBox(
                  width: 150,
                  child: SeatCard(
                      name: '의사(발동!)',
                      ammo: 2,
                      alive: true,
                      char: CharId.doctor,
                      abilityUses: '1',
                      abilityFx: '치료!'),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await _save(tester, const Key('shot'), out, 'seatcards_new.png');
  });

  testWidgets('상점 캐러셀(A안) + 대사/능력 두 칸(C안)', (tester) async {
    if (out == null) return;
    await tester.binding.setSurfaceSize(const Size(420, 740));
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildCowboyTheme(),
      home: Material(
        type: MaterialType.transparency,
        child: RepaintBoundary(
          key: const Key('shop'),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [CD.skyMid, CD.duneNear],
              ),
            ),
            child: const SafeArea(child: CharactersTab()),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await _save(tester, const Key('shop'), out, 'shop_carousel.png');
  });

  testWidgets('보안관의 특훈 — 코치 말풍선+버튼 잠금', (tester) async {
    if (out == null) return;
    // 게임 화면은 BGM을 켠다 — 테스트 환경엔 오디오 플러그인이 없어
    // 비동기 MissingPluginException이 새므로 그것만 무시(캡처 전용 테스트).
    final prevOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is MissingPluginException) return;
      prevOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = prevOnError);
    await tester.binding.setSurfaceSize(const Size(420, 780));
    await tester.pumpWidget(RepaintBoundary(
      key: const Key('tuto'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildCowboyTheme(),
        home: const OfflineGameScreen(tutorial: true),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _save(tester, const Key('tuto'), out, 'tutorial_coach.png');
    // 화면 dispose가 BGM 페이드 타이머를 새로 만든다 — 테스트 안에서 먼저
    // 내리고(fade 시작) 가짜 시계를 흘려 소진시킨다.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
  });
}
