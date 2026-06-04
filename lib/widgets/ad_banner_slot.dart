import 'package:flutter/material.dart';

import '../theme.dart';

/// A reserved, currently-empty banner-ad slot (standard 320x50-ish mobile
/// banner footprint). It just holds the space at the bottom of a screen so the
/// layout already accounts for an ad; drop a real ad widget in [child] later
/// (e.g. an AdMob `AdWidget`) without shifting anything else.
class AdBannerSlot extends StatelessWidget {
  /// The actual ad view, once wired up. While null the slot stays empty.
  final Widget? child;

  /// Reserve the space even when there's no ad yet. Set false to collapse.
  final bool reserveWhenEmpty;

  const AdBannerSlot({super.key, this.child, this.reserveWhenEmpty = true});

  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    if (child == null && !reserveWhenEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: CD.leather.withValues(alpha: 0.06),
        border: Border(
          top: BorderSide(color: CD.leather.withValues(alpha: 0.12)),
        ),
      ),
      child: child ??
          Text(
            '광고',
            style: TextStyle(
              color: CD.muted.withValues(alpha: 0.5),
              fontSize: 11,
              letterSpacing: 2,
            ),
          ),
    );
  }
}
