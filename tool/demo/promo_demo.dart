// 홍보 클립용 연출 데모(일회성) — DRAW! 슬램 · 승리 셀레브레이션 · 명중 연출.
// 빌드: flutter build apk --debug -t tool/demo/promo_demo.dart
// 고정 타임라인이라 녹화 후 구간만 잘라 GIF로 쓴다.
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:cowboy_party/theme.dart';
import 'package:cowboy_party/widgets/celebration.dart';
import 'package:cowboy_party/widgets/hit_burst.dart';
import 'package:cowboy_party/widgets/juice3.dart';
import 'package:cowboy_party/widgets/reaction_panel.dart';

void main() => runApp(const _App());

class _App extends StatelessWidget {
  const _App();
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Pretendard'),
        home: const _Stage(),
      );
}

class _Stage extends StatefulWidget {
  const _Stage();
  @override
  State<_Stage> createState() => _StageState();
}

enum _Scene { blank, drawPrep, drawGo, victory, hit }

class _StageState extends State<_Stage> {
  _Scene _scene = _Scene.blank;
  int _key = 0;

  @override
  void initState() {
    super.initState();
    _cycle();
    // OS 스플래시가 첫 사이클을 가리므로 무한 반복 — 녹화는 2번째 사이클을 쓴다.
    Timer.periodic(const Duration(milliseconds: 12400), (_) => _cycle());
  }

  void _cycle() {
    void at(int ms, _Scene s) => Timer(Duration(milliseconds: ms), () {
          if (mounted) setState(() { _scene = s; _key++; });
        });
    at(800, _Scene.drawPrep);
    at(2600, _Scene.drawGo); // DRAW! 슬램
    at(4600, _Scene.blank);
    at(5000, _Scene.victory); // 콘페티 + 승리 카드
    at(8200, _Scene.blank);
    at(8600, _Scene.hit); // 명중 연출 종합(파티클+숫자팝+모자)
    at(11600, _Scene.blank);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final c = Offset(size.width / 2, size.height * 0.42);
    switch (_scene) {
      case _Scene.drawPrep:
      case _Scene.drawGo:
        return Scaffold(
          body: ReactionPanel(
            stage: _scene == _Scene.drawPrep
                ? ReactionStage.prep
                : ReactionStage.go,
            opponents: const ['거스'],
            onTap: () {},
          ),
        );
      case _Scene.victory:
        return Scaffold(
          backgroundColor: const Color(0xFF2E6E5A),
          body: Stack(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 26),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: CD.parchment,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: CD.gold, width: 3),
                  ),
                  child: Text('승리! 최후의 1인',
                      style: posterTitle(28, color: CD.rust)),
                ),
              ),
              Positioned.fill(child: Celebration(key: ValueKey('v$_key'))),
            ],
          ),
        );
      case _Scene.hit:
        return Scaffold(
          backgroundColor: const Color(0xFF2E6E5A),
          body: Stack(
            children: [
              Positioned(
                left: c.dx - 46,
                top: c.dy - 58,
                child: Container(
                  width: 92,
                  height: 116,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B4A2F),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD9B36B), width: 2),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🤠', style: TextStyle(fontSize: 46)),
                ),
              ),
              Positioned.fill(
                  child: HitBurst(
                      key: ValueKey('hb$_key'), center: c, seed: 3)),
              Positioned.fill(
                  child: DamagePop(
                      key: ValueKey('dp$_key'),
                      center: c,
                      delay: const Duration(milliseconds: 60))),
              Positioned.fill(
                  child: DeathHatRoll(
                      key: ValueKey('hat$_key'),
                      center: c.translate(0, -24),
                      seed: 2,
                      delay: const Duration(milliseconds: 120))),
            ],
          ),
        );
      case _Scene.blank:
        return const Scaffold(backgroundColor: Color(0xFF2E6E5A));
    }
  }
}
