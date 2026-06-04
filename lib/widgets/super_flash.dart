import 'package:flutter/material.dart';

import '../theme.dart';

/// One-shot "슈 퍼 빵 야" skill flash: thick, spaced poster letters in an
/// intense yellow with a scorched-red outline and amber glow, played the moment
/// a 슈퍼빵야 fires. A quick pop-and-shake, a brief hold, then a fade.
///
/// Purely decorative (wrapped in [IgnorePointer]); render it inside a [Stack]
/// with a unique [Key] so it replays each time a super shot lands.
class SuperBbangyaFlash extends StatefulWidget {
  const SuperBbangyaFlash({super.key});

  @override
  State<SuperBbangyaFlash> createState() => _SuperBbangyaFlashState();
}

class _SuperBbangyaFlashState extends State<SuperBbangyaFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Intense, slightly-orange yellow over a dark scorched-red outline — a
  // deliberate "skill activated" pop rather than the softer table palette.
  static const _yellow = Color(0xFFFFD21A);
  static const _outline = Color(0xFF7A1408);
  static const _ember = Color(0xFFFF7A00);
  static const _text = '슈 퍼 빵 야';

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final pop = t < 0.22 ? Curves.easeOutBack.transform(t / 0.22) : 1.0;
          final out = t > 0.7 ? (t - 0.7) / 0.3 : 0.0; // 0..1 over the exit
          final fade = (1 - out).clamp(0.0, 1.0);
          final scale = 0.55 + 0.45 * pop + out * 0.18;
          final shake = t < 0.45 ? (0.45 - t) / 0.45 * 6 : 0.0;
          return Opacity(
            opacity: fade,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.95,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: Transform.translate(
                offset: Offset(shake, 0),
                child: Transform.scale(
                  scale: scale,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bolt,
                            size: 58,
                            color: _yellow,
                            shadows: [
                              Shadow(color: CD.nova, blurRadius: 22),
                              Shadow(color: _ember, blurRadius: 10),
                            ],
                          ),
                          _glyphs(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _glyphs() {
    final stroke = TextStyle(
      fontFamily: 'BlackHanSans',
      fontSize: 60,
      letterSpacing: 4,
      height: 1.0,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11
        ..strokeJoin = StrokeJoin.round
        ..color = _outline,
    );
    const fill = TextStyle(
      fontFamily: 'BlackHanSans',
      fontSize: 60,
      letterSpacing: 4,
      height: 1.0,
      color: _yellow,
      shadows: [
        Shadow(color: CD.nova, blurRadius: 26),
        Shadow(color: _ember, blurRadius: 12),
      ],
    );
    return Stack(
      children: [
        Text(_text, style: stroke),
        const Text(_text, style: fill),
      ],
    );
  }
}
