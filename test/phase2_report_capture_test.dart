// 피드백 13건 반영 보고서용 프레임 캡처(일회성 도구) — REPORT_CAPTURE_DIR 지정 시.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cowboy_party/game/characters.dart';
import 'package:cowboy_party/game/party_logic.dart';
import 'package:cowboy_party/theme.dart';
import 'package:cowboy_party/widgets/action_bar.dart';
import 'package:cowboy_party/widgets/char_pager_sheet.dart';
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

Future<void> _save(WidgetTester tester, Key key, String dir, String file) async {
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$file').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  final out = Platform.environment['REPORT_CAPTURE_DIR'];

  setUpAll(() async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    await _loadFonts();
  });

  testWidgets('액션바 — 서브 설명 제거 후 모습', (tester) async {
    if (out == null) return;
    await tester.binding.setSurfaceSize(const Size(420, 260));
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildCowboyTheme(),
      home: Material(
        type: MaterialType.transparency,
        child: RepaintBoundary(
          key: const Key('shot'),
          child: Container(
            color: CD.sand,
            padding: const EdgeInsets.all(16),
            child: ActionBar(
              myAmmo: 2,
              selected: ActKind.reload,
              selectedTarget: -1,
              targetName: null,
              onSelect: (_) {},
              onConfirm: () {},
              myChar: CharId.hunter,
              trapAvailable: true,
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 250));
    await _save(tester, const Key('shot'), out, 'actionbar_clean.png');
  });

  testWidgets('캐릭터 변경 페이저 시트', (tester) async {
    if (out == null) return;
    await tester.binding.setSurfaceSize(const Size(420, 760));
    final owned = kCharacters.take(6).toList();
    // 바텀시트는 Navigator 오버레이에 그려지므로 경계를 앱 바깥에 둔다.
    await tester.pumpWidget(RepaintBoundary(
      key: const Key('screen'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildCowboyTheme(),
        home: Scaffold(
          backgroundColor: CD.sand,
          body: Builder(
            builder: (ctx) => Center(
              child: FilledButton(
                onPressed: () => showCharPagerSheet(ctx,
                    chars: owned,
                    current: CharId.sniper,
                    onPick: (_) {}),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await _save(tester, const Key('screen'), out, 'char_pager_sheet.png');
  });
}
