import 'package:flutter/material.dart';

import 'game/party_logic.dart';

/// Spaghetti-western / wanted-poster palette. Deliberate, committed direction:
/// warm parchment & leather with a dusty-sunset rust accent, plus a distinct
/// colour per action so the three choices read instantly.
class CD {
  static const sand = Color(0xFFE8D5A8);
  static const parchment = Color(0xFFF5EAD0);
  static const leather = Color(0xFF3B2412);
  static const ink = Color(0xFF241A12);
  static const muted = Color(0xFF7A6748);

  static const rust = Color(0xFFC8541E); // primary accent / sunset
  static const danger = Color(0xFF9E2B25); // shoot / hit
  static const sage = Color(0xFF2E6E5A); // defend
  static const gold = Color(0xFFD9A441); // reload
  static const nova = Color(0xFFF2A93B); // 슈퍼빵야 (gold-fire)

  // Dusk sky tones for the painted background.
  static const skyTop = Color(0xFF3A2A55);
  static const skyMid = Color(0xFFC8541E);
  static const skyLow = Color(0xFFF2B25C);
  static const duneFar = Color(0xFFB9712E);
  static const duneNear = Color(0xFF7A3E18);

  /// Colour for each action kind.
  static Color actionColor(ActKind a) {
    switch (a) {
      case ActKind.reload:
        return gold;
      case ActKind.defend:
        return sage;
      case ActKind.shoot:
        return danger;
      case ActKind.superShoot:
        return nova;
    }
  }
}

/// A bundled Material icon per action — no emoji, so nothing flashes on web.
IconData actionIcon(ActKind a) {
  switch (a) {
    case ActKind.reload:
      return Icons.cached;
    case ActKind.defend:
      return Icons.shield;
    case ActKind.shoot:
      return Icons.local_fire_department;
    case ActKind.superShoot:
      return Icons.bolt;
  }
}

ThemeData buildCowboyTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: CD.rust,
    scaffoldBackgroundColor: CD.sand,
    brightness: Brightness.light,
    // Bundled Korean body font — full Hangul, no runtime download.
    fontFamily: 'GothicA1',
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: CD.ink,
      displayColor: CD.leather,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: CD.leather,
      centerTitle: true,
    ),
  );
}

/// Heavy poster-style Korean title (Black Han Sans, bundled, full Hangul).
TextStyle posterTitle(double size, {Color? color}) => TextStyle(
      fontFamily: 'BlackHanSans',
      fontSize: size,
      letterSpacing: 1,
      color: color ?? CD.leather,
      height: 1.08,
    );

/// Bundled western display font (Rye) for Latin taglines / numbers only.
TextStyle westernLatin(double size, {Color? color, double spacing = 1}) =>
    TextStyle(
      fontFamily: 'Rye',
      fontSize: size,
      letterSpacing: spacing,
      color: color ?? CD.rust,
    );
