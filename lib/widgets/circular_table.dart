import 'dart:math';

import 'package:flutter/material.dart';

import '../game/party_logic.dart';
import '../theme.dart';
import 'seat_card.dart';

/// Neutral, render-ready seat data so both the offline and online screens can
/// drive the circular table without sharing a state class.
class TableSeat {
  final String name;
  final int ammo;
  final bool alive;
  final bool isMe;
  final bool joined;
  final bool submitted;
  final bool hit;
  final Move? lastMove;
  final bool fired;
  final int firedTarget;

  const TableSeat({
    required this.name,
    required this.ammo,
    required this.alive,
    this.isMe = false,
    this.joined = true,
    this.submitted = false,
    this.hit = false,
    this.lastMove,
    this.fired = false,
    this.firedTarget = -1,
  });
}

/// Lays the cowboys out in a circle (my seat anchored at the bottom) with a
/// banner in the middle. During the reveal it draws danger-coloured tracer
/// lines from each shooter to whoever they fired at.
class CircularTable extends StatelessWidget {
  final List<TableSeat> seats;
  final int mySeat;
  final Widget center;

  /// When true, alive non-me seats become tappable targets.
  final bool targetMode;
  final int selectedTarget;
  final ValueChanged<int>? onSeatTap;

  /// Show the tracer lines + revealed moves.
  final bool reveal;

  const CircularTable({
    super.key,
    required this.seats,
    required this.mySeat,
    required this.center,
    this.targetMode = false,
    this.selectedTarget = -1,
    this.onSeatTap,
    this.reveal = false,
  });

  @override
  Widget build(BuildContext context) {
    final n = seats.length;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final cardW = n >= 5 ? 92.0 : 110.0;
        final cardH = 96.0;
        // Ellipse radii leave room for the cards at the edges.
        final rx = (w / 2) - cardW / 2 - 6;
        final ry = (h / 2) - cardH / 2 - 6;
        final cx = w / 2;
        final cy = h / 2;

        Offset posOf(int seat) {
          final rel = ((seat - mySeat) % n + n) % n;
          final angle = pi / 2 + rel * (2 * pi / n); // mySeat at bottom
          return Offset(cx + rx * cos(angle), cy + ry * sin(angle));
        }

        final positions = [for (var s = 0; s < n; s++) posOf(s)];

        return Stack(
          children: [
            // Tracer lines behind the cards.
            if (reveal)
              Positioned.fill(
                child: CustomPaint(
                  painter: _TracerPainter(seats: seats, positions: positions),
                ),
              ),
            // Center banner.
            Align(alignment: Alignment.center, child: center),
            // Seat cards.
            for (var s = 0; s < n; s++)
              Positioned(
                left: positions[s].dx - cardW / 2,
                top: positions[s].dy - cardH / 2,
                width: cardW,
                child: SeatCard(
                  name: seats[s].name,
                  ammo: seats[s].ammo,
                  alive: seats[s].alive,
                  isMe: seats[s].isMe,
                  joined: seats[s].joined,
                  submitted: seats[s].submitted,
                  hit: seats[s].hit,
                  lastMove: reveal ? seats[s].lastMove : null,
                  fired: seats[s].fired,
                  scale: 0,
                  targetable: targetMode && !seats[s].isMe && seats[s].alive,
                  targeted: targetMode && selectedTarget == s,
                  onTap: targetMode && !seats[s].isMe && seats[s].alive
                      ? () => onSeatTap?.call(s)
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TracerPainter extends CustomPainter {
  final List<TableSeat> seats;
  final List<Offset> positions;
  _TracerPainter({required this.seats, required this.positions});

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = CD.danger.withValues(alpha: 0.85)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var s = 0; s < seats.length; s++) {
      if (!seats[s].fired) continue;
      final t = seats[s].firedTarget;
      if (t < 0 || t >= positions.length) continue;
      final a = positions[s];
      final b = positions[t];
      // Shorten both ends so the line sits between the cards, not under them.
      final dir = (b - a);
      final len = dir.distance;
      if (len < 1) continue;
      final unit = dir / len;
      final start = a + unit * 52;
      final end = b - unit * 52;
      canvas.drawLine(start, end, line);
      _arrow(canvas, end, unit, line);
    }
  }

  void _arrow(Canvas canvas, Offset tip, Offset unit, Paint paint) {
    const head = 11.0;
    final back = tip - unit * head;
    final normal = Offset(-unit.dy, unit.dx);
    final p1 = back + normal * (head * 0.6);
    final p2 = back - normal * (head * 0.6);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(path, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _TracerPainter old) => true;
}
