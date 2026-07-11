// 파티클 비교 데모 — 타격감 1단계 선택용 (앱 코드와 무관한 임시 엔트리).
// 빌드: flutter build apk --debug -t tool/demo/particle_demo.dart
// 고정 스케줄: A(자작) 1.0s·3.5s, B(newton) 6.0s·8.5s 폭발.
// 좌상단 흰 점 = 버스트 진행 중 마커(녹화 구간 추출용).
import 'dart:async';

import 'package:flutter/material.dart' hide Velocity;
import 'package:newton_particles/newton_particles.dart';

import 'package:cowboy_party/widgets/hit_burst.dart';

void main() => runApp(const _DemoApp());

class _DemoApp extends StatelessWidget {
  const _DemoApp();
  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _DemoStage(),
      );
}

class _DemoStage extends StatefulWidget {
  const _DemoStage();
  @override
  State<_DemoStage> createState() => _DemoStageState();
}

class _DemoStageState extends State<_DemoStage> {
  String _label = '준비…';
  final List<Widget> _bursts = [];
  bool _newton = false;
  bool _marker = false;
  int _key = 0;

  @override
  void initState() {
    super.initState();
    _label = '왼쪽 탭 = A(자작) · 오른쪽 탭 = B(newton)';
  }

  void _fire(bool newton) {
    setState(() {
      _marker = true;
      if (newton) {
        _label = 'B. newton_particles';
        _bursts.clear();
        _newton = false;
      } else {
        _label = 'A. 자작 파티클 (CustomPainter)';
        _newton = false;
        _bursts
          ..clear()
          ..add(HitBurst(
              key: ValueKey(_key++), center: _target(context), seed: _key * 3));
      }
    });
    if (newton) {
      // 마운트 순간 폭발하므로 한 프레임 끄고 다시 켠다.
      Timer(const Duration(milliseconds: 40), () {
        if (mounted) setState(() { _newton = true; _key++; });
      });
    }
    Timer(const Duration(milliseconds: 900),
        () { if (mounted) setState(() => _marker = false); });
  }

  Offset _target(BuildContext context) {
    final s = MediaQuery.of(context).size;
    return Offset(s.width * 0.5, s.height * 0.48);
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.of(context).size;
    final target = _target(context);
    return Scaffold(
      backgroundColor: const Color(0xFF2E6E5A),
      body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _fire(d.globalPosition.dx > s.width / 2),
          child: Stack(
        children: [
          Positioned(
            left: target.dx - 44,
            top: target.dy - 56,
            child: Container(
              width: 88,
              height: 112,
              decoration: BoxDecoration(
                color: const Color(0xFF6B4A2F),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD9B36B), width: 2),
              ),
              alignment: Alignment.center,
              child: const Text('🤠', style: TextStyle(fontSize: 44)),
            ),
          ),
          ..._bursts,
          if (_newton)
            Positioned.fill(
              child: IgnorePointer(
                child: Newton(
                  key: ValueKey('newton$_key'),
                  effectConfigurations: [
                    PhysicsEffectConfiguration(
                      physicsProperties: PhysicsProperties(
                        gravity: Gravity.earthGravity,
                        angle: const NumRange.between(0, 360),
                        velocity: NumRange.between(
                            Velocity.custom(180), Velocity.custom(300)),
                        solidEdges: SolidEdges.none,
                      ),
                      visualProperties: const VisualProperties(
                        beginScale: NumRange.single(1.6),
                        endScale: NumRange.between(0.2, 0.4),
                        fadeOutThreshold: NumRange.between(0.55, 0.75),
                        scaleCurve: Curves.easeOut,
                        fadeOutCurve: Curves.easeIn,
                      ),
                      emissionProperties: EmissionProperties(
                        particleCount: 32,
                        particlesPerEmit: 32,
                        emitDuration: const Duration(milliseconds: 1),
                        origin:
                            Offset(target.dx / s.width, target.dy / s.height),
                        particleLifespan: const DurationRange.between(
                          Duration(milliseconds: 650),
                          Duration(milliseconds: 950),
                        ),
                      ),
                      particleConfiguration: const ParticleConfiguration(
                        shape: CircleShape(),
                        size: Size(9, 9),
                        color: LinearInterpolationParticleColor(colors: [
                          Colors.white,
                          Color(0xFFFF8A3D),
                          Color(0xFFE0B34C),
                          Color(0xFFB3261E),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // 버스트 마커(녹화 구간 탐지용).
          if (_marker)
            Positioned(
              left: 16,
              top: 120,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
              ),
            ),
          Positioned(
            top: 56,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      )),
    );
  }
}
