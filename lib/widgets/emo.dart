import 'package:flutter/widgets.dart';

import '../game/party_logic.dart';

/// A colour emoji rendered from a bundled Twemoji PNG. Looks like a native
/// emoji but ships inside the app, so it appears instantly with no web flash.
class Emo extends StatelessWidget {
  final String name;
  final double size;
  const Emo(this.name, {super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/emoji/$name.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// Emoji asset name for each action kind.
String actionEmoji(ActKind a) {
  switch (a) {
    case ActKind.reload:
      return 'reload';
    case ActKind.defend:
      return 'shield';
    case ActKind.shoot:
      return 'bang';
    case ActKind.superShoot:
      return 'bang';
  }
}
