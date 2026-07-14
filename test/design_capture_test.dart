// 디자인 라운드1 선택지 캡처(일회성 도구) — DESIGN_CAPTURE_DIR 지정 시에만 동작.
// 대시보드 '상의 필요'에 올릴 후보 이미지를 렌더한다: 방장 표시 3안, 휘장 3안,
// 좌석 스킬표시 3안, 상점 레이아웃 3안. 번들 한글 폰트(Pretendard/BlackHanSans)를
// FontLoader로 로드해 테스트 환경에서도 한글이 두부(□)로 깨지지 않는다.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cowboy_party/game/characters.dart';
import 'package:cowboy_party/theme.dart';
import 'package:cowboy_party/widgets/character_portrait.dart';
import 'package:cowboy_party/widgets/rank_emblem.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFonts() async {
  Future<ByteData> bd(String p) async {
    final bytes = await File(p).readAsBytes();
    return ByteData.view(bytes.buffer);
  }

  // Pretendard(OTF/CFF)는 테스트 렌더러에서 안 올라와 두부가 된다 —
  // 같은 한글 커버리지의 GothicA1(TTF)을 Pretendard 이름으로 대신 로드.
  final pret = FontLoader('Pretendard')
    ..addFont(bd('assets/fonts/GothicA1-Regular.ttf'))
    ..addFont(bd('assets/fonts/GothicA1-Bold.ttf'))
    ..addFont(bd('assets/fonts/GothicA1-Black.ttf'));
  await pret.load();
  final bhs = FontLoader('BlackHanSans')
    ..addFont(bd('assets/fonts/BlackHanSans-Regular.ttf'));
  await bhs.load();
  // Material 아이콘 폰트 — 테스트 기본 환경엔 없어서 별·배지가 □로 나온다.
  final root = Platform.environment['FLUTTER_ROOT'] ??
      '/opt/homebrew/share/flutter';
  final iconsPath =
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  if (File(iconsPath).existsSync()) {
    final icons = FontLoader('MaterialIcons')..addFont(bd(iconsPath));
    await icons.load();
  }
}

Future<void> _shot(
  WidgetTester tester,
  Widget scene,
  Size size,
  String dir,
  String file, {
  List<String> precache = const [],
}) async {
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildCowboyTheme(),
    // Material 조상이 있어야 DefaultTextStyle이 테마 폰트(Pretendard)를 탄다 —
    // 없으면 테스트 환경에서 한글이 두부(□)로 렌더된다.
    home: Material(
      type: MaterialType.transparency,
      child: RepaintBoundary(key: const Key('shot'), child: scene),
    ),
  ));
  if (precache.isNotEmpty) {
    final ctx = tester.element(find.byKey(const Key('shot')));
    await tester.runAsync(() async {
      for (final id in precache) {
        await precacheImage(AssetImage('assets/characters/$id.png'), ctx);
      }
    });
  }
  await tester.pump(const Duration(milliseconds: 250));
  final boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
  await tester.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$file').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

// ── 공용 프레임: 어두운 석양 배경 + 제목 + 옵션 행 ──
Widget _frame(String title, List<Widget> options) => Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [CD.skyTop, CD.duneNear],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: posterTitle(19, color: Colors.white)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final o in options) ...[
                Expanded(child: o),
                if (o != options.last) const SizedBox(width: 14),
              ],
            ],
          ),
        ],
      ),
    );

Widget _opt(String label, String caption, Widget child) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13)),
        ),
        const SizedBox(height: 12),
        child,
        const SizedBox(height: 12),
        Text(caption,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 10.5,
                height: 1.35)),
      ],
    );

// ── 대기방 좌석 카드 목업(SeatCard 시각 재현 + 변형 포인트만 교체) ──
class _SeatMock extends StatelessWidget {
  final String name;
  final CharDef def;
  final int level;
  final String host; // none | strip | star | goldcard
  final String emblem; // none | inline | border | ring
  final RankTier? tier;

  const _SeatMock({
    required this.name,
    required this.def,
    this.level = 12,
    this.host = 'none',
    this.emblem = 'none',
    this.tier,
  });

  @override
  Widget build(BuildContext context) {
    final gold = host == 'goldcard';
    final t = tier;

    Widget portrait = CharacterPortrait(
        id: def.id.name, icon: def.icon, color: def.color, size: 54);
    if (emblem == 'ring' && t != null) {
      portrait = Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: tierColor(t), width: 2.4),
              boxShadow: [
                BoxShadow(
                    color: tierColor(t).withValues(alpha: 0.6), blurRadius: 8),
              ],
            ),
            child: portrait,
          ),
          Positioned(
            bottom: -4,
            left: 0,
            right: 0,
            child: Center(child: RankEmblem(tier: t, size: 15)),
          ),
        ],
      );
    }

    final card = Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: gold
            ? const Color(0xFFF3DFAE)
            : CD.parchment.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(CD.rCard),
        border: emblem == 'border' && t != null
            ? null // 그라데이션 테두리는 바깥 래퍼가 그린다.
            : Border.all(
                color: gold ? CD.gold : CD.leather.withValues(alpha: 0.3),
                width: gold ? 2.5 : 1.5,
              ),
        boxShadow: emblem == 'ring' && t != null
            ? null
            : t != null
                ? [
                    BoxShadow(
                        color: tierColor(t).withValues(alpha: 0.5),
                        blurRadius: 9,
                        spreadRadius: 1),
                  ]
                : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (host == 'strip') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: CD.gold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 11, color: Colors.white),
                  SizedBox(width: 3),
                  Text('방장',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Stack(
            clipBehavior: Clip.none,
            children: [
              portrait,
              // 캐릭터 배지(좌상단) — 방장 표시와 겹치지 않음을 보여주는 용도.
              Positioned(
                left: -8,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: def.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                  child: Icon(def.icon, size: 11, color: Colors.white),
                ),
              ),
              if (emblem == 'border' && t != null)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Icon(Icons.diamond, size: 15, color: tierColor(t)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (host == 'star') ...[
                const Icon(Icons.star, size: 14, color: CD.gold),
                const SizedBox(width: 2),
              ],
              Flexible(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: CD.leather)),
              ),
              if (emblem == 'inline' && t != null) ...[
                const SizedBox(width: 4),
                RankEmblem(tier: t, size: 14),
              ],
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: CD.rust.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text('Lv.$level',
                    style: const TextStyle(
                        color: CD.rust,
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5)),
              ),
              if (host == 'goldcard') ...[
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: CD.gold,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Text('방장',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11)),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (emblem == 'border' && t != null) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tierColor(t), tierAccent(t), tierColor(t)],
          ),
          borderRadius: BorderRadius.circular(CD.rCard + 2),
          boxShadow: [
            BoxShadow(
                color: tierColor(t).withValues(alpha: 0.45), blurRadius: 8),
          ],
        ),
        padding: const EdgeInsets.all(2.2),
        child: card,
      );
    }
    return card;
  }
}

// ── 게임 중 좌석 카드 목업(스킬 카운트/이펙트 표시 3안) ──
class _RingGaugePainter extends CustomPainter {
  _RingGaugePainter(this.color, this.frac);
  final Color color;
  final double frac; // 남은 비율

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 1.5;
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = color.withValues(alpha: 0.22));
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * frac,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = color);
  }

  @override
  bool shouldRepaint(covariant _RingGaugePainter old) =>
      old.frac != frac || old.color != color;
}

class _SkillMock extends StatelessWidget {
  final String name;
  final CharDef def;
  final String variant; // tray | ring | side
  final bool activated; // 발동 순간 연출 강조
  final double width;

  const _SkillMock({
    required this.name,
    required this.def,
    required this.variant,
    this.activated = false,
    this.width = 96,
  });

  Widget _pip(bool filled, {double size = 7}) => Container(
        width: size,
        height: size,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? Colors.white : Colors.white.withValues(alpha: 0.25),
          border: Border.all(color: Colors.white70, width: 0.8),
        ),
      );

  @override
  Widget build(BuildContext context) {
    Widget portrait = CharacterPortrait(
        id: def.id.name, icon: def.icon, color: def.color, size: 42);
    if (variant == 'ring') {
      portrait = Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            child: portrait,
          ),
          Positioned.fill(
            child: CustomPaint(
                painter: _RingGaugePainter(
                    activated ? CD.nova : def.color, 0.5)),
          ),
          Positioned(
            top: -5,
            right: -5,
            child: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                color: def.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
                boxShadow: activated
                    ? [
                        BoxShadow(
                            color: CD.nova.withValues(alpha: 0.9),
                            blurRadius: 8)
                      ]
                    : null,
              ),
              child: Icon(def.icon, size: 10, color: Colors.white),
            ),
          ),
        ],
      );
    }

    final inner = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        portrait,
        const SizedBox(height: 4),
        Text(name,
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: CD.leather)),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 2; i++)
              Container(
                width: 6,
                height: 9,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: CD.gold,
                  borderRadius: BorderRadius.circular(2),
                  border:
                      Border.all(color: CD.leather.withValues(alpha: 0.5)),
                ),
              ),
          ],
        ),
        if (variant == 'tray') ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: activated ? def.color : CD.leather.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(7),
              boxShadow: activated
                  ? [
                      BoxShadow(
                          color: def.color.withValues(alpha: 0.8),
                          blurRadius: 9)
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(def.icon, size: 11, color: Colors.white),
                const SizedBox(width: 4),
                _pip(true),
                _pip(false),
                if (activated) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.auto_awesome,
                      size: 10, color: Colors.white),
                ],
              ],
            ),
          ),
        ],
      ],
    );

    final card = Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
      decoration: BoxDecoration(
        color: CD.parchment.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(CD.rCard),
        border: Border.all(
            color: activated
                ? def.color
                : CD.leather.withValues(alpha: 0.3),
            width: activated ? 2.2 : 1.5),
        boxShadow: activated
            ? [
                BoxShadow(
                    color: def.color.withValues(alpha: 0.55), blurRadius: 12)
              ]
            : null,
      ),
      child: inner,
    );

    if (variant != 'side') return card;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          decoration: BoxDecoration(
            color: activated ? def.color : CD.leather.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(7),
            boxShadow: activated
                ? [
                    BoxShadow(
                        color: def.color.withValues(alpha: 0.8), blurRadius: 8)
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(def.icon, size: 10, color: Colors.white),
              const SizedBox(height: 3),
              _pip(true, size: 6),
              const SizedBox(height: 2),
              _pip(false, size: 6),
            ],
          ),
        ),
        const SizedBox(width: 3),
        card,
      ],
    );
  }
}

// ── 상점 레이아웃 목업 3안 ──
Widget _phone(Widget child) => Container(
      width: 236,
      height: 430,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: CD.sand,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.4), width: 2),
      ),
      child: child,
    );

Widget _priceChip(int cost) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: CD.leather,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on, size: 11, color: CD.gold),
          const SizedBox(width: 3),
          Text(cost == 0 ? '기본' : '$cost',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );

Widget _shopCarousel() {
  final def = kCharacters[2]; // 스나이퍼
  return _phone(Column(
    children: [
      const SizedBox(height: 10),
      Text('상점', style: posterTitle(16)),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chevron_left, size: 26, color: CD.muted),
          Container(
            width: 168,
            height: 210,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: def.color, width: 2),
              color: def.color.withValues(alpha: 0.12),
            ),
            child: Image.asset('assets/characters/${def.id.name}.png',
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) =>
                    Icon(def.icon, size: 80, color: def.color)),
          ),
          const Icon(Icons.chevron_right, size: 26, color: CD.rust),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 7; i++)
            Container(
              width: i == 2 ? 8 : 5,
              height: i == 2 ? 8 : 5,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == 2 ? CD.rust : CD.muted.withValues(alpha: 0.5),
              ),
            ),
        ],
      ),
      const SizedBox(height: 6),
      Text(def.name, style: posterTitle(18)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: CD.parchment,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: def.color.withValues(alpha: 0.4)),
          ),
          child: Text(def.ability,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, height: 1.4)),
        ),
      ),
      const SizedBox(height: 4),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            decoration: BoxDecoration(
              color: CD.leather,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on, size: 13, color: CD.gold),
                const SizedBox(width: 4),
                Text('${def.cost}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: CD.sage,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('체험',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12)),
          ),
        ],
      ),
    ],
  ));
}

Widget _shopGridTiered() {
  Widget mini(CharDef def) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: CD.parchment,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: def.color.withValues(alpha: 0.6),
              width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CharacterPortrait(
                id: def.id.name, icon: def.icon, color: def.color, size: 40),
            const SizedBox(height: 4),
            Text(def.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 10.5)),
            const SizedBox(height: 3),
            _priceChip(def.cost),
          ],
        ),
      );
  Widget header(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Row(
          children: [
            Flexible(
              child: Text(t,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
                      color: CD.leather)),
            ),
            const SizedBox(width: 6),
            Expanded(
                child: Container(
                    height: 1.4, color: CD.leather.withValues(alpha: 0.25))),
          ],
        ),
      );
  Widget row2(CharDef a, CharDef b) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Row(children: [
          Expanded(child: mini(a)),
          const SizedBox(width: 8),
          Expanded(child: mini(b)),
        ]),
      );
  return _phone(Column(
    children: [
      const SizedBox(height: 10),
      Text('상점', style: posterTitle(16)),
      header('견습 · ~2,000'),
      row2(kCharacters[1], kCharacters[2]),
      header('사냥꾼 · ~5,000'),
      row2(kCharacters[4], kCharacters[6]),
      header('전설 · 5,500~'),
      row2(kCharacters[10], kCharacters[14]),
    ],
  ));
}

Widget _shopSplit() {
  final sel = kCharacters[4]; // 의사
  Widget rowItem(CharDef def, {bool selected = false}) => Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? def.color.withValues(alpha: 0.2) : CD.parchment,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected
                  ? def.color
                  : CD.leather.withValues(alpha: 0.2),
              width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            CharacterPortrait(
                id: def.id.name, icon: def.icon, color: def.color, size: 26),
            const SizedBox(width: 5),
            Expanded(
              child: Text(def.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 10)),
            ),
          ],
        ),
      );
  return _phone(Column(
    children: [
      const SizedBox(height: 10),
      Text('상점', style: posterTitle(16)),
      const SizedBox(height: 6),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 84,
                child: Column(
                  children: [
                    for (final (i, def) in kCharacters.take(8).indexed)
                      rowItem(def, selected: i == 4),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: CD.parchment,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: sel.color, width: 2),
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 120,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: sel.color.withValues(alpha: 0.12),
                        ),
                        child: Image.asset(
                            'assets/characters/${sel.id.name}.png',
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Icon(sel.icon,
                                size: 60, color: sel.color)),
                      ),
                      const SizedBox(height: 6),
                      Text(sel.name, style: posterTitle(15)),
                      const SizedBox(height: 4),
                      Text(sel.ability,
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(fontSize: 9, height: 1.4)),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 6),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: CD.leather,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('${sel.cost}',
                                  style: const TextStyle(
                                      color: CD.gold,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 6),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: CD.sage,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('체험',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  ));
}

void main() {
  final out = Platform.environment['DESIGN_CAPTURE_DIR'];

  setUpAll(() async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    await _loadFonts();
  });

  testWidgets('방장 표시 3안', (tester) async {
    if (out == null) return;
    final defs = [charDef(CharId.sniper), charDef(CharId.doctor),
        charDef(CharId.dualgun)];
    await _shot(
      tester,
      _frame('방장 표시 — 어떤 방식이 좋으세요?', [
        _opt('A안 · 카드 상단 띠', '카드 안 맨 위에 금색 띠 —\n무엇과도 겹치지 않음',
            Center(child: _SeatMock(name: '카우보이A', def: defs[0], host: 'strip'))),
        _opt('B안 · 이름 옆 별', '이름 앞 금색 별만 —\n가장 미니멀',
            Center(child: _SeatMock(name: '카우보이A', def: defs[1], host: 'star'))),
        _opt('C안 · 금색 카드', '카드 전체 금색 톤 + 방장 칩 —\n한눈에 구분',
            Center(child: _SeatMock(name: '카우보이A', def: defs[2], host: 'goldcard'))),
      ]),
      const Size(620, 330),
      out,
      'host_options.png',
      precache: ['sniper', 'doctor', 'dualgun'],
    );
  });

  testWidgets('휘장 배치 3안', (tester) async {
    if (out == null) return;
    final defs = [charDef(CharId.sniper), charDef(CharId.doctor),
        charDef(CharId.dualgun)];
    await _shot(
      tester,
      _frame('지난 시즌 휘장 — 어디에 달까요? (예: 1등 챌린저)', [
        _opt('A안 · 이름 옆 미니 휘장', '이름 오른쪽에 작은 크레스트 —\n레이아웃 안 밀림',
            Center(child: _SeatMock(name: '카우보이A', def: defs[0],
                emblem: 'inline', tier: RankTier.challenger))),
        _opt('B안 · 티어 테두리', '카드 테두리를 티어색 그라데이션 +\n우상단 보석',
            Center(child: _SeatMock(name: '카우보이A', def: defs[1],
                emblem: 'border', tier: RankTier.challenger))),
        _opt('C안 · 초상화 링', '아바타에 티어색 링 + 링 아래 크레스트 —\n프로필처럼',
            Center(child: _SeatMock(name: '카우보이A', def: defs[2],
                emblem: 'ring', tier: RankTier.challenger))),
      ]),
      const Size(620, 340),
      out,
      'emblem_options.png',
      precache: ['sniper', 'doctor', 'dualgun'],
    );
  });

  testWidgets('좌석 스킬 표시 3안', (tester) async {
    if (out == null) return;
    final doc = charDef(CharId.doctor);
    final smk = charDef(CharId.smoker);
    Widget pair(String variant) {
      final w = variant == 'side' ? 84.0 : 96.0;
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkillMock(name: '평상시', def: smk, variant: variant, width: w),
          const SizedBox(width: 6),
          _SkillMock(name: '발동!', def: doc, variant: variant,
              activated: true, width: w),
        ],
      );
    }
    await _shot(
      tester,
      _frame('게임 중 스킬 카운트·발동 연출 — 좌/우: 평상시/발동 순간', [
        _opt('A안 · 하단 트레이', '카드 아래 고정 줄에 스킬 아이콘+핍(●○) —\n발동 시 트레이가 빛나며 아이콘 팝',
            pair('tray')),
        _opt('B안 · 초상화 링 게이지', '아바타 둘레 링이 남은 횟수 게이지 —\n발동 시 링이 금색 플래시',
            pair('ring')),
        _opt('C안 · 옆 핍 기둥', '카드 왼쪽에 세로 핍 기둥 —\n카드 안은 그대로, 발동 시 기둥 점화',
            pair('side')),
      ]),
      const Size(790, 340),
      out,
      'seat_skill_options.png',
      precache: ['doctor', 'smoker'],
    );
  });

  testWidgets('상점 레이아웃 3안', (tester) async {
    if (out == null) return;
    await _shot(
      tester,
      _frame('캐릭터 상점 레이아웃 — 15명을 어떻게 보여줄까요?', [
        _opt('A안 · 캐러셀', '큰 일러스트 1명씩 좌우 스와이프 —\n캐릭터가 주인공, 탐색은 느림',
            Center(child: _shopCarousel())),
        _opt('B안 · 가격대 섹션 그리드', '견습/사냥꾼/전설 섹션으로 묶은 2열 —\n목표(다음 해금)가 명확',
            Center(child: _shopGridTiered())),
        _opt('C안 · 리스트+상세', '왼쪽 전체 목록, 오른쪽 상세 —\n비교·탐색이 가장 빠름',
            Center(child: _shopSplit())),
      ]),
      const Size(880, 620),
      out,
      'shop_options.png',
      precache: [
        'sniper', 'doctor', 'commoner', 'prepper', 'speedloader',
        'hunter', 'shadow', 'voodoo', 'smoker', 'resetter', 'duelist',
      ],
    );
  });
}
