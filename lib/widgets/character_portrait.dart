import 'package:flutter/material.dart';

import '../theme.dart';

/// Renders a character's illustration from `assets/characters/<id>.png`, falling
/// back to the character's themed Material [icon] in a tinted medallion when the
/// PNG is missing or still decoding. Ported from cowboy_redesign — adapted to
/// cowboy_party's icon-based identity (no per-character emoji here).
///
/// Presentation only: callers pass `id` = `CharId.name`, plus the character's
/// `icon`/`color` for the placeholder. Never reads game state.
class CharacterPortrait extends StatelessWidget {
  const CharacterPortrait({
    super.key,
    required this.id,
    required this.icon,
    required this.color,
    this.size = 56,
    this.showRing = true,
    this.dim = false,
  });

  final String id;
  final IconData icon;
  final Color color;
  final double size;
  final bool showRing;

  /// Locked/unowned look — desaturates via a translucent veil.
  final bool dim;

  // The illustrations are chest-up bust portraits, so the face sits in the
  // upper-middle of the square. Zoom in and bias upward so the FACE fills the
  // circular avatar instead of the chest. Tuned by screenshot in the redesign.
  static const double _zoom = 1.85;
  static const Alignment _faceAlign = Alignment(0, -0.58);

  @override
  Widget build(BuildContext context) {
    final ring = showRing
        ? Border.all(color: color.withValues(alpha: 0.55), width: 1.6)
        : null;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.14), CD.parchment],
        ),
        border: ring,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          OverflowBox(
            maxWidth: size * _zoom,
            maxHeight: size * _zoom,
            alignment: _faceAlign,
            child: Image.asset(
              'assets/characters/$id.png',
              fit: BoxFit.cover,
              width: size * _zoom,
              height: size * _zoom,
              // PNG missing → graceful icon placeholder (un-zoomed).
              errorBuilder: (context, error, stack) =>
                  _Placeholder(icon: icon, color: color, size: size),
              // Avoid a flash of nothing while decoding.
              frameBuilder: (context, child, frame, wasSync) {
                if (wasSync || frame != null) return child;
                return _Placeholder(icon: icon, color: color, size: size);
              },
            ),
          ),
          if (dim)
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CD.leather.withValues(alpha: 0.35),
              ),
            ),
        ],
      ),
    );
  }
}

/// Large hero illustration for the shop detail view — shows head + torso (not
/// the tight face-crop of [CharacterPortrait]), on a char-tinted backdrop with
/// a parchment scrim at the bottom for text legibility. Icon fallback when the
/// PNG is missing. Presentation only.
class CharacterHero extends StatelessWidget {
  const CharacterHero({
    super.key,
    required this.id,
    required this.icon,
    required this.color,
    this.height = 230,
  });

  final String id;
  final IconData icon;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.30),
              color.withValues(alpha: 0.10),
              CD.parchment,
            ],
            stops: const [0, 0.7, 1],
          ),
        ),
        child: Image.asset(
          'assets/characters/$id.png',
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.15),
          errorBuilder: (context, error, stack) =>
              Center(child: Icon(icon, color: color, size: height * 0.42)),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.color, required this.size});
  final IconData icon;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}
