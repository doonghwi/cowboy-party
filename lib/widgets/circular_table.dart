import 'dart:math';

import 'package:flutter/material.dart';

import '../game/party_logic.dart';
import '../theme.dart';
import 'effects.dart';
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
  final int firedTarget2; // 더블 빵야 두 번째 대상(-1 없음)
  final CharId char;
  final bool late; // 게임 중 난입 — 다음 판부터 참여

  /// 이 턴 능력 발동 표시 (리빌 중 좌석 배지).
  final bool healedFx;
  final bool evadedFx;

  /// 이 턴 연막을 켰는가(=횟수 차감). 회피 성공(evadedFx)과 별개 — 안 맞아도 true.
  /// SmokePuff 트리거용. evadedFx는 "회피!" 텍스트용으로 유지.
  final bool smoked;
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

  /// 유한 능력 사용량 '사용/총'(#11) — null이면 표시 안 함. 모두에게 보임.
  final String? abilityUses;

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
    this.firedTarget2 = -1,
    this.char = CharId.none,
    this.late = false,
    this.healedFx = false,
    this.evadedFx = false,
    this.smoked = false,
    this.reflectedFx = false,
    this.doubleLoadFx = false,
    this.piercedFx = false,
    this.resetFx = false,
    this.curseTurnsLeft = 0,
    this.curseKillFx = false,
    this.hideAmmo = false,
    this.hideAction = false,
    this.blocked = false,
    this.abilityUses,
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
            // Animated bullet tracers behind the cards (muzzle flash, travelling
            // core, hit/blocked/missed impact). Keyed per turn so it replays.
            if (reveal)
              Positioned.fill(
                child: ShotsLayer(
                  key: ValueKey('shots-${_turnSig()}'),
                  shots: _shots(positions),
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
                  abilityUses: seats[s].abilityUses,
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
            // SMOKE (스모커 연막): purely additive puff over a seat that RAISED
            // smoke this turn (charge consumed) — shows whether or not an attack
            // was actually dodged. Driven by `smoked`, not `evadedFx`, so the
            // screen appears even when the smoker isn't shot. ("회피!" 텍스트는 evaded.)
            if (reveal)
              for (var s = 0; s < n; s++)
                if (seats[s].smoked &&
                    seats[s].alive &&
                    !seats[s].hideAction)
                  Positioned.fill(
                    child: SmokePuff(
                      key: ValueKey('smoke-$s-${seats[s].lastMove?.encode()}'),
                      center: positions[s],
                      seed: s + 1,
                    ),
                  ),
            // Per-character ability flourishes (all driven by existing reveal
            // flags — purely additive, no game state read).
            if (reveal)
              for (var s = 0; s < n; s++)
                if (seats[s].healedFx && seats[s].alive && !seats[s].hideAction)
                  Positioned.fill(
                    child: HealSparkle(
                      key: ValueKey('heal-$s-${seats[s].lastMove?.encode()}'),
                      center: positions[s],
                      seed: s + 1,
                    ),
                  ),
            if (reveal)
              for (var s = 0; s < n; s++)
                if (seats[s].resetFx && !seats[s].hideAction)
                  Positioned.fill(
                    child: ResetRipple(
                      key: ValueKey('reset-$s-${seats[s].lastMove?.encode()}'),
                      center: positions[s],
                      radius: cardW / 2 + 16,
                    ),
                  ),
            // 부두 저주: 저주 걸린 좌석에 상시 오라, 만료 사망 시 데스 버스트.
            if (reveal)
              for (var s = 0; s < n; s++)
                if ((seats[s].curseTurnsLeft > 0 || seats[s].curseKillFx) &&
                    !seats[s].hideAction)
                  Positioned.fill(
                    child: CurseAura(
                      key: ValueKey('curse-$s-${seats[s].curseTurnsLeft}-'
                          '${seats[s].curseKillFx}-${seats[s].lastMove?.encode()}'),
                      center: positions[s],
                      radius: cardW / 2 + 14,
                      death: seats[s].curseKillFx,
                      seed: s + 1,
                    ),
                  ),
            // 러시안룰렛: 발동 좌석에 리볼버 실린더 스핀(미싱 이펙트 보강).
            if (reveal)
              for (var s = 0; s < n; s++)
                if (seats[s].lastMove?.kind == ActKind.roulette &&
                    seats[s].alive &&
                    !seats[s].hideAction)
                  Positioned.fill(
                    child: RouletteSpin(
                      key: ValueKey('roul-$s-${seats[s].lastMove?.encode()}'),
                      center: positions[s],
                      radius: cardW / 2 - 8,
                    ),
                  ),
            // 부두 저주를 거는 순간: 시전자→대상 떨리는 테더 + 착탄 링.
            if (reveal)
              for (var s = 0; s < n; s++)
                if (seats[s].lastMove?.kind == ActKind.voodoo &&
                    !seats[s].hideAction &&
                    (seats[s].lastMove?.target ?? -1) >= 0 &&
                    (seats[s].lastMove?.target ?? -1) < n)
                  Positioned.fill(
                    child: CurseBolt(
                      key: ValueKey('cbolt-$s-${seats[s].lastMove?.encode()}'),
                      from: positions[s],
                      to: positions[seats[s].lastMove!.target],
                    ),
                  ),
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

  /// A signature of this turn's moves so the tracer layer re-animates each turn.
  String _turnSig() => seats.map((s) => s.lastMove?.encode() ?? '-').join('|');

  /// Build the animated shot list from the seat flags (presentation only).
  List<ShotSpec> _shots(List<Offset> positions) {
    final out = <ShotSpec>[];
    for (var s = 0; s < seats.length; s++) {
      if (!seats[s].fired) continue;
      final superShot = seats[s].superFired;
      // 더블 빵야는 두 대상 모두에 탄을 그린다(슈퍼는 단일 대상).
      final targets = <int>[
        seats[s].firedTarget,
        if (!superShot) seats[s].firedTarget2,
      ];
      for (final t in targets) {
        if (t < 0 || t >= positions.length) continue;
        out.add(ShotSpec(
          from: positions[s],
          to: positions[t],
          isSuper: superShot,
          result: _shotResult(t),
          pierce: seats[s].piercedFx,
        ));
      }
    }
    return out;
  }

  /// Derive a shot's impact from the *target* seat's existing reveal flags.
  ShotResult _shotResult(int t) {
    final tg = seats[t];
    if (tg.hit) return ShotResult.hit;
    if (tg.lastMove?.kind == ActKind.defend ||
        tg.evadedFx ||
        tg.smoked ||
        tg.reflectedFx) {
      return ShotResult.blocked;
    }
    return ShotResult.missed;
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
          // Expanding shockwave under the shield for a sense of impact.
          Positioned.fill(
            child: ShieldPulse(
              key: ValueKey('defp-$s-${m.encode()}'),
              center: pos,
              radius: ring / 2,
            ),
          ),
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
          // Gold cartridge ticks fly up into the seat — more for a double load.
          Positioned.fill(
            child: ReloadBurst(
              key: ValueKey('rlb-$s-${m.encode()}'),
              center: pos,
              count: seats[s].doubleLoadFx ? 6 : 3,
            ),
          ),
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

