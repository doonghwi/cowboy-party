// 파티클 비교 프레임 캡처 — 사용자 선택 보드용 (일회성 도구 테스트).
// 실행: flutter test test/particle_capture_test.dart
// PARTICLE_CAPTURE_DIR 환경변수(--dart-define 아님, Platform.environment)로
// 출력 폴더를 받는다. 미설정이면 스킵(일반 CI/test 실행을 오염시키지 않게).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Velocity;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newton_particles/newton_particles.dart';

import 'package:cowboy_party/widgets/hit_burst.dart';

const _size = 430.0;

Widget _stage(Widget effect) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      child: Container(
        width: _size,
        height: _size,
        color: const Color(0xFF2E6E5A),
        child: Stack(
          children: [
            Positioned(
              left: _size / 2 - 44,
              top: _size / 2 - 56,
              child: Container(
                width: 88,
                height: 112,
                decoration: BoxDecoration(
                  color: const Color(0xFF6B4A2F),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: const Color(0xFFD9B36B), width: 2),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                      color: Color(0xFFE9B44C), shape: BoxShape.circle),
                ),
              ),
            ),
            effect,
          ],
        ),
      ),
    ),
  );
}

Future<void> _capture(WidgetTester tester, String dir, Widget effect,
    {int frames = 30}) async {
  Directory(dir).createSync(recursive: true);
  await tester.binding.setSurfaceSize(const Size(_size, _size));
  await tester.pumpWidget(_stage(effect));
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 40)); // 25fps
    final boundary = tester
        .renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
    late final ui.Image img;
    await tester.runAsync(() async {
      img = await boundary.toImage();
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$dir/f_${i.toString().padLeft(2, '0')}.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }
}

void main() {
  final out = Platform.environment['PARTICLE_CAPTURE_DIR'];

  testWidgets('capture A: HitBurst', (tester) async {
    if (out == null) return;
    await _capture(
        tester, '$out/frames_a',
        const HitBurst(center: Offset(_size / 2, _size / 2), seed: 7));
  });

  testWidgets('capture B: newton explosion', (tester) async {
    if (out == null) return;
    await _capture(
      tester,
      '$out/frames_b',
      Positioned.fill(
        child: Newton(
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
                origin: const Offset(0.5, 0.5),
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
    );
  });
}
