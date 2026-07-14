// 휘장 보고서용 프레임 캡처(일회성 도구) — EMBLEM_CAPTURE_DIR 지정 시에만 동작.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cowboy_party/widgets/rank_emblem.dart';
import 'package:cowboy_party/widgets/seat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final out = Platform.environment['EMBLEM_CAPTURE_DIR'];

  testWidgets('휘장 3티어 + 좌석 카드 적용 모습 캡처', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    await tester.binding.setSurfaceSize(const Size(430, 340));
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        child: Container(
          color: const Color(0xFF2E6E5A),
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (tier, lv) in [
                (RankTier.challenger, 21),
                (RankTier.master, 14),
                (RankTier.diamond, 9),
              ])
                SizedBox(
                  width: 110,
                  child: SeatCard(
                      name: switch (tier) {
                        RankTier.challenger => '지난시즌 1등',
                        RankTier.master => '2~3등',
                        RankTier.diamond => '4~10등',
                      },
                      ammo: 0,
                      alive: true,
                      level: lv,
                      rankTier: tier),
                ),
            ],
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    final boundary = tester
        .renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
    late final ui.Image img;
    await tester.runAsync(() async {
      img = await boundary.toImage(pixelRatio: 2);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/rank_emblems.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
