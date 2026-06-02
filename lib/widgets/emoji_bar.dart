import 'package:flutter/material.dart';

import '../theme.dart';
import 'emo.dart';

/// The four in-game reactions players can fling over their seat.
const List<String> kReactionEmojis = ['laugh', 'cool', 'angry', 'cry'];

/// A compact, tap-to-expand emoji reaction button. Collapsed it's a small round
/// button; tapping it fans out the four emojis. Picking one fires [onPick] and
/// collapses again — sits as a corner overlay so it never blocks the table.
class EmojiBar extends StatefulWidget {
  final ValueChanged<String> onPick;
  const EmojiBar({super.key, required this.onPick});

  @override
  State<EmojiBar> createState() => _EmojiBarState();
}

class _EmojiBarState extends State<EmojiBar> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: _open
              ? Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: CD.parchment.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: CD.leather.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 8),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final e in kReactionEmojis)
                        GestureDetector(
                          onTap: () {
                            widget.onPick(e);
                            setState(() => _open = false);
                          },
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            child: Emo(e, size: 30),
                          ),
                        ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _open ? CD.leather : CD.rust,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22), blurRadius: 6),
              ],
            ),
            child: Icon(_open ? Icons.close : Icons.add_reaction,
                color: Colors.white, size: 24),
          ),
        ),
      ],
    );
  }
}
