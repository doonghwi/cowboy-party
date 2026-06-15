import 'dart:math';

import 'package:flutter/material.dart';

import '../game/party_logic.dart';
import '../theme.dart';
import 'emo.dart';
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
  final bool superFired;
  final int firedTarget;
  final CharId char;
  final bool late; // 게임 중 난입 — 다음 판부터 참여

  /// 이 턴 능력 발동 표시 (리빌 중 좌석 배지).
  final bool healedFx;
  final bool evadedFx;
  final bool reflectedFx;
  final bool doubleLoadFx;
  final bool piercedFx; // 스나이퍼 관통(D1)
  final bool resetFx; // 리셋터 무효(D4)

  /// 부두 저주(C2): 남은 턴(0=없음)을 좌석에 상시 표시, 만료 사망은 별도 이펙트.
  final int curseTurnsLeft;
  final bool curseKillFx;

  /// 그림자: 탄약/행동을 가린다.
  final bool hideAmmo;
  final bool hideAction;

  /// 방장이 닫은 자리(F2) — 대기실에서 자물쇠 표시.
  final bool blocked;

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
    this.superFired = false,
    this.firedTarget = -1,
    this.char = CharId.none,
    this.late = false,
    this.healedFx = false,
    this.evadedFx = false,
    this.reflectedFx = false,
    this.doubleLoadFx = false,
    this.piercedFx = false,
    this.resetFx = false,
    this.curseTurnsLeft = 0,
    this.curseKillFx = false,
    this.hideAmmo = false,
    this.hideAction = false,
    this.blocked = false,
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

  /// 더블 빵야 두 번째 대상(있으면 함께 하이라이트).
  final int selectedTarget2;
  final ValueChanged<int>? onSeatTap;

  /// 타겟 모드가 아닐 때 좌석을 탭하면 프로필/능력 팝업(G3, 결정④).
  final ValueChanged<int>? onSeatInfo;

  /// Show the tracer lines + revealed moves.
  final bool reveal;

  /// Emoji reactions to float over seats (seat -> emoji asset name).
  final Map<int, String> reactions;

  const CircularTable({
    super.key,
    required this.seats,
    required this.mySeat,
    required this.center,
    this.targetMode = false,
    this.selectedTarget = -1,
    this.selectedTarget2 = -1,
    this.onSeatTap,
    this.onSeatInfo,
    this.reveal = false,
    this.reactions = const {},
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
            // Seat cards.
            for (var s = 0; s < n; s++)
              Positioned(
                left: positions[s].dx - cardW / 2,
                top: positions[s].dy - cardH / 2,
                width: cardW,
                child: SeatCard(
                  name: seats[s].name,
                  ammo: seats[s].ammo,
                  hideAmmo: seats[s].hideAmmo,
                  alive: seats[s].alive,
                  isMe: seats[s].isMe,
                  joined: seats[s].joined,
                  submitted: seats[s].submitted,
                  hit: seats[s].hit,
                  lastMove: (reveal && !seats[s].hideAction)
                      ? seats[s].lastMove
                      : null,
                  fired: seats[s].fired,
                  char: seats[s].char,
                  late: seats[s].late,
                  blocked: seats[s].blocked,
                  curseTurnsLeft: seats[s].curseTurnsLeft,
                  abilityFx: reveal ? _fxLabel(seats[s]) : null,
                  scale: 0,
                  targetable: targetMode && !seats[s].isMe && seats[s].alive,
                  targeted: targetMode &&
                      (selectedTarget == s || selectedTarget2 == s),
                  onTap: targetMode && !seats[s].isMe && seats[s].alive
                      ? () => onSeatTap?.call(s)
                      : (!targetMode && seats[s].joined && onSeatInfo != null
                          ? () => onSeatInfo!.call(s)
                          : null),
                ),
              ),
            // Per-action effects on the reveal: shield ring for defend, a gold
            // "+1" for reload (shots already draw a tracer arrow).
            if (reveal)
              for (var s = 0; s < n; s++)
                ..._effects(s, positions[s], cardW, cardH),
            // Emoji reactions floating over seats. Normally above the card, but
            // flipped below it for top-row seats so it never clips off-screen
            // (the bug at 2 players: the opponent's bubble went above the top).
            for (final entry in reactions.entries)
              if (entry.key >= 0 && entry.key < n)
                Positioned(
                  left: positions[entry.key].dx - 24,
                  top: positions[entry.key].dy - cardH / 2 - 44 < 4
                      ? positions[entry.key].dy + cardH / 2 + 4
                      : positions[entry.key].dy - cardH / 2 - 44,
                  child: IgnorePointer(
                    child: _ReactionBubble(
                      key: ValueKey('rx-${entry.key}-${entry.value}'),
                      emoji: entry.value,
                    ),
                  ),
                ),
            // Center banner — drawn last (on top). Only the 4-seat layout puts
            // cards at the exact vertical centre (left & right), so the banner
            // must stay narrow there to not hide them; every other layout
            // leaves the middle band clear and can show the banner on one
            // comfortable line.
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: w * (n == 4 ? 0.52 : 0.86)),
                child: center,
              ),
            ),
          ],
        );
      },
    );
  }

  /// 이 턴 발동한 능력의 좌석 배지 라벨 (우선순위 1개만).
  static String? _fxLabel(TableSeat s) {
    if (s.curseKillFx) return '저주 사망!';
    if (s.resetFx) return '무효!';
    if (s.reflectedFx) return '덫 반사!';
    if (s.piercedFx) return '관통!';
    if (s.healedFx) return '자힐!';
    if (s.evadedFx) return '회피!';
    if (s.doubleLoadFx) return '+2 장전!';
    return null;
  }

  List<Widget> _effects(int s, Offset pos, double cardW, double cardH) {
    if (seats[s].hideAction) return const []; // 그림자: 행동 이펙트 숨김
    final m = seats[s].lastMove;
    if (m == null || !seats[s].alive) return const [];
    switch (m.kind) {
      case ActKind.defend:
        final ring = cardW + 26;
        return [
          Positioned(
            left: pos.dx - ring / 2,
            top: pos.dy - ring / 2,
            width: ring,
            height: ring,
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                key: ValueKey('def-$s-${m.encode()}'),
                tween: Tween(begin: 0.7, end: 1.0),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutBack,
                builder: (context, v, _) => Transform.scale(
                  scale: v,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: CD.sage, width: 3.5),
                      boxShadow: [
                        BoxShadow(
                            color: CD.sage.withValues(alpha: 0.45),
                            blurRadius: 12)
                      ],
                    ),
                    alignment: Alignment.topCenter,
                    child: Transform.translate(
                      offset: const Offset(0, -11),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration:
                            const BoxDecoration(color: CD.sage, shape: BoxShape.circle),
                        child: const Icon(Icons.shield,
                            size: 15, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ];
      case ActKind.trap:
        final tring = cardW + 26;
        return [
          Positioned(
            left: pos.dx - tring / 2,
            top: pos.dy - tring / 2,
            width: tring,
            height: tring,
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                key: ValueKey('trap-$s-${m.encode()}'),
                tween: Tween(begin: 0.7, end: 1.0),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutBack,
                builder: (context, v, _) => Transform.scale(
                  scale: v,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF7A3E18), width: 3.5),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF7A3E18)
                                .withValues(alpha: 0.45),
                            blurRadius: 12)
                      ],
                    ),
                    alignment: Alignment.topCenter,
                    child: Transform.translate(
                      offset: const Offset(0, -11),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: Color(0xFF7A3E18),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.crisis_alert,
                            size: 15, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ];
      case ActKind.reload:
        return [
          Positioned(
            left: pos.dx - 26,
            top: pos.dy - cardH / 2 - 16,
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                key: ValueKey('rl-$s-${m.encode()}'),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                builder: (context, v, _) => Opacity(
                  opacity: v.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: v,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: CD.gold,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                              color: CD.gold.withValues(alpha: 0.5),
                              blurRadius: 8)
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 14, color: Colors.white),
                          Text('1',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13)),
                          SizedBox(width: 2),
                          Icon(Icons.cached, size: 13, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ];
      case ActKind.shoot:
      case ActKind.superShoot:
      case ActKind.roulette:
      case ActKind.dualShoot:
      case ActKind.voodoo:
      case ActKind.reset:
      case ActKind.idle:
        return const [];
    }
  }
}

/// A reaction emoji that pops in, drifts up and fades out.
class _ReactionBubble extends StatelessWidget {
  final String emoji;
  const _ReactionBubble({super.key, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 2200),
      builder: (context, t, _) {
        // Pop in over the first 12%, hold, then drift up + fade over the last 35%.
        final scale = t < 0.12 ? (t / 0.12) : 1.0;
        final fade = t > 0.65 ? (1 - (t - 0.65) / 0.35) : 1.0;
        final rise = -18.0 * (t > 0.65 ? (t - 0.65) / 0.35 : 0);
        return Transform.translate(
          offset: Offset(0, rise),
          child: Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale.clamp(0.0, 1.0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: CD.parchment.withValues(alpha: 0.95),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 5),
                  ],
                ),
                child: Emo(emoji, size: 38),
              ),
            ),
          ),
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
    // Draw normal shots first, super shots on top so they dominate.
    for (final superPass in [false, true]) {
      for (var s = 0; s < seats.length; s++) {
        if (!seats[s].fired || seats[s].superFired != superPass) continue;
        final t = seats[s].firedTarget;
        if (t < 0 || t >= positions.length) continue;
        final a = positions[s];
        final b = positions[t];
        final dir = (b - a);
        final len = dir.distance;
        if (len < 1) continue;
        final unit = dir / len;
        final start = a + unit * 52;
        final end = b - unit * 52;
        if (superPass) {
          _superBolt(canvas, start, end, unit);
        } else {
          final line = Paint()
            ..color = CD.danger.withValues(alpha: 0.85)
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(start, end, line);
          _arrow(canvas, end, unit, line, 11);
        }
      }
    }
  }

  /// A thick gold-fire bolt with an outer glow and a starburst at the target —
  /// the unmistakable, screen-dominating 슈퍼빵야 hit.
  void _superBolt(Canvas canvas, Offset start, Offset end, Offset unit) {
    final glow = Paint()
      ..color = CD.nova.withValues(alpha: 0.40)
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final core = Paint()
      ..color = CD.nova
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final inner = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, glow);
    canvas.drawLine(start, end, core);
    canvas.drawLine(start, end, inner);
    _arrow(canvas, end, unit, Paint()..color = CD.nova, 18);
    _burst(canvas, end);
  }

  void _burst(Canvas canvas, Offset c) {
    final p = Paint()..color = CD.nova;
    final glow = Paint()
      ..color = CD.nova.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(c, 14, glow);
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4;
      final r = i.isEven ? 13.0 : 5.5;
      final pt = c + Offset(cos(a), sin(a)) * r;
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, p);
    canvas.drawCircle(c, 3, Paint()..color = Colors.white);
  }

  void _arrow(Canvas canvas, Offset tip, Offset unit, Paint paint, double head) {
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
