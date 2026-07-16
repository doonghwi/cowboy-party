import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/characters.dart';
import '../game/party_logic.dart';
import '../theme.dart';
import 'rank_emblem.dart';
import 'character_portrait.dart';
import 'emo.dart';
import 'tier_frame.dart';

/// A single cowboy at the table: avatar, name, ammo and their last revealed
/// action. Shakes briefly when [hit] flips true. Three sizes via [scale] so the
/// same card works in a 6-seat circle (mini), the opponent ring (compact) and
/// as the spotlighted "me" card (full).
///
/// 2026-07-15 사용자 선택 반영:
/// - 방장 = 카드 전체 금색 톤 + '방장' 칩(C안) — 상단 배너 제거(겹침 원천 차단).
/// - 스킬 카운트 = 초상화 둘레 링 게이지(B안) — 발동 시 금색 플래시+아이콘 팝.
///   텍스트 라벨('치료!' 등)과 좌하단 횟수 배지는 제거.
/// - 휘장 = TierFramed(카드 틀을 벗어나는 화려한 티어 프레임, LoL 시즌 테두리풍).
class SeatCard extends StatelessWidget {
  final String name;
  final int ammo;
  final bool alive;
  final bool isMe;
  final bool joined;
  final bool submitted;
  final bool hit;

  /// 방장 좌석 — 금색 카드 + '방장' 칩(누가 시작 권한자인지).
  final bool isHost;

  /// 대기방 계정 레벨(-1이면 숨김=게임 중엔 총알 표시).
  final int level;

  /// 지난 시즌 휘장 티어(null=없음) — 카드 밖으로 뻗는 티어 프레임.
  final RankTier? rankTier;
  final Move? lastMove;

  /// 그림자: 탄약 수를 '?'로 가린다.
  final bool hideAmmo;

  /// Whether the last move's shot actually left the barrel (for colouring).
  final bool fired;

  /// 0 = mini (circle seat), 1 = compact, 2 = full.
  final int scale;

  /// Tappable target highlight (used by the shoot picker).
  final bool targetable;
  final bool targeted;
  final VoidCallback? onTap;

  /// 캐릭터 배지 + 난입 대기 표시.
  final CharId char;
  final bool late;

  /// 리빌 중 능력 발동 신호 — 링이 금색으로 번쩍이고 아이콘이 팝(텍스트 미표시).
  final String? abilityFx;

  /// 부두 저주(C2): 남은 턴(0=없음)을 좌석에 상시 표시 — 모두에게 보임.
  final int curseTurnsLeft;

  /// 규칙 v2(2026-07-16): 시전자별 저주 목록 [(시전자 좌석, 남은 턴)].
  /// 비어 있으면 구 필드 curseTurnsLeft 단일 배지로 폴백.
  final List<(int, int)> curses;

  /// 내 좌석 번호(부두 아이콘·저주색 매칭용, -1=모름).
  final int seatIndex;

  /// 방장이 닫은 자리(F2) — 자물쇠 아바타.
  final bool blocked;

  /// 유한 능력 **남은 횟수**(abilityUsesLabel) — null이면 링 게이지 숨김.
  final String? abilityUses;

  const SeatCard({
    super.key,
    required this.name,
    required this.ammo,
    required this.alive,
    this.isMe = false,
    this.joined = true,
    this.submitted = false,
    this.hit = false,
    this.isHost = false,
    this.level = -1,
    this.rankTier,
    this.lastMove,
    this.hideAmmo = false,
    this.fired = false,
    this.scale = 2,
    this.targetable = false,
    this.targeted = false,
    this.onTap,
    this.char = CharId.none,
    this.late = false,
    this.abilityFx,
    this.curseTurnsLeft = 0,
    this.curses = const [],
    this.seatIndex = -1,
    this.blocked = false,
    this.abilityUses,
  });

  /// 캐릭터별 유한 능력 총 횟수 — 링 게이지 분모(표시 전용).
  static int _abilityTotal(CharId c) => c == CharId.smoker ? 2 : 1;

  @override
  Widget build(BuildContext context) {
    final mini = scale == 0;
    final compact = scale == 1;
    final avatar = mini ? 34.0 : (compact ? 40.0 : 54.0);
    final width = mini ? 92.0 : (compact ? 120.0 : 150.0);

    // 방장 = 금색 카드(C안). 조준 중엔 조준색이 우선.
    final hostGold = isHost && alive && !targeted;
    final borderColor = targeted
        ? CD.danger
        : !alive
            ? CD.muted.withValues(alpha: 0.5)
            : hostGold
                ? CD.gold
                : (isMe ? CD.rust : CD.leather.withValues(alpha: 0.3));

    // 초상화(+ 스킬 링 게이지).
    Widget portrait = blocked
        ? Icon(Icons.lock,
            size: avatar, color: CD.muted.withValues(alpha: 0.6))
        : (joined && alive && char != CharId.none)
            // 살아있는 참가자는 자기 캐릭터 일러스트로 표시(없으면 아이콘 폴백).
            ? CharacterPortrait(
                id: char.name,
                icon: charDef(char).icon,
                color: charDef(char).color,
                size: avatar,
                showRing: false,
              )
            // 빈자리는 사람, 탈락은 해골 — 생존 상태 가독성 유지.
            : Opacity(
                opacity: alive ? 1 : 0.55,
                child: Emo(
                  !joined ? 'person' : (alive ? 'cowboy' : 'skull'),
                  size: avatar,
                ),
              );
    final showRing = alive &&
        joined &&
        !blocked &&
        char != CharId.none &&
        (abilityUses != null || abilityFx != null);
    if (showRing) {
      final remaining = int.tryParse(abilityUses ?? '') ?? 1;
      final total = math.max(_abilityTotal(char), remaining);
      portrait = _AbilityRing(
        key: ValueKey('ring-$name-$abilityFx-$abilityUses'),
        color: charDef(char).color,
        icon: charDef(char).icon,
        frac: total == 0 ? 0 : remaining / total,
        size: avatar,
        flash: abilityFx != null,
      );
      // 링 안에 초상화를 넣는다.
      portrait = Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          blocked
              ? const SizedBox.shrink()
              : CharacterPortrait(
                  id: char.name,
                  icon: charDef(char).icon,
                  color: charDef(char).color,
                  size: avatar,
                  showRing: false,
                ),
          Positioned(
            left: -3,
            top: -3,
            right: -3,
            bottom: -3,
            child: portrait,
          ),
        ],
      );
    }

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: width,
      padding: EdgeInsets.symmetric(
          horizontal: mini ? 6 : 10, vertical: mini ? 6 : (compact ? 8 : 12)),
      decoration: BoxDecoration(
        color: targeted
            ? CD.danger.withValues(alpha: 0.18)
            : hostGold
                ? const Color(0xFFF1DCA4)
                : isMe
                    ? CD.gold.withValues(alpha: 0.22)
                    : CD.parchment.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(CD.rCard),
        border: Border.all(
          color: borderColor,
          width: (isMe || targeted || hostGold) ? 2.5 : 1.5,
        ),
        // 휘장 발광은 TierFramed 프레임이 담당.
        boxShadow: targetable && !targeted
            ? [BoxShadow(color: CD.danger.withValues(alpha: 0.35), blurRadius: 7)]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              portrait,
              if (submitted && alive)
                Positioned(
                  right: -6,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: CD.sage,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 12, color: Colors.white),
                  ),
                ),
              if (targetable && !targeted)
                Positioned(
                  right: -8,
                  bottom: -6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: CD.danger,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.gps_fixed,
                        size: 13, color: Colors.white),
                  ),
                ),
              if (char != CharId.none && joined)
                Positioned(
                  left: -8,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      // 부두술사는 자기 저주색으로 — 여러 부두를 색으로 구분(v2).
                      color: char == CharId.voodoo && seatIndex >= 0
                          ? curseColorOf(seatIndex)
                          : charDef(char).color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                    child: Icon(charDef(char).icon,
                        size: 11, color: Colors.white),
                  ),
                ),
            ],
          ),
          // C2: 저주 남은 턴 — 코너 배지와 절대 겹치지 않도록 아바타 아래
          // **전용 줄**에 둔다. 규칙 v2: 시전자별 저주가 각자 색 배지로 나란히.
          if (alive && (curses.isNotEmpty || curseTurnsLeft > 0)) ...[
            SizedBox(height: mini ? 3 : 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, cu) in (curses.isNotEmpty
                          ? curses
                          : [(-1, curseTurnsLeft)])
                      .indexed) ...[
                    if (i > 0) const SizedBox(width: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: curseColorOf(cu.$1),
                        borderRadius: BorderRadius.circular(CD.rChip),
                        border: Border.all(color: Colors.white, width: 1.2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('💀', style: TextStyle(fontSize: 9)),
                          const SizedBox(width: 3),
                          Text('저주 ${cu.$2}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          SizedBox(height: mini ? 2 : 4),
          Text(
            joined ? name : '빈자리',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: mini ? 11.5 : (compact ? 13 : 15),
              color: alive ? CD.leather : CD.muted,
            ),
          ),
          // 레벨 줄이 없을 때(게임 중)도 '방장' 칩은 보여야 한다.
          if (isHost && level < 0) ...[
            SizedBox(height: mini ? 2 : 3),
            _hostChip(mini),
          ],
          SizedBox(height: mini ? 2 : 4),
          if (late && !alive)
            const Text('다음 판 참여',
                style: TextStyle(
                    color: CD.sage,
                    fontSize: 11,
                    fontWeight: FontWeight.bold))
          // 빈자리는 총알 줄을 그리지 않는다(대기방 '총알 0' 제보, 2026-07-16).
          else if (alive && !joined)
            const SizedBox.shrink()
          else if (alive)
            _ammoRow(mini)
          else
            const Text('탈락',
                style: TextStyle(
                    color: CD.danger,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          if (lastMove != null && alive) ...[
            SizedBox(height: mini ? 3 : 6),
            _lastMoveRow(mini),
          ],
        ],
      ),
    );

    // 지난 시즌 휘장 — 카드 틀을 벗어나는 화려한 티어 프레임.
    final decorated =
        rankTier == null ? card : TierFramed(tier: rankTier!, child: card);

    final wrapped = onTap == null
        ? decorated
        : GestureDetector(onTap: alive ? onTap : null, child: decorated);

    if (!hit) return wrapped;
    // Quick shake + flash on a fresh hit.
    return TweenAnimationBuilder<double>(
      key: ValueKey('hit-$name-$ammo-${lastMove?.encode()}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, t, child) {
        final dx = (t < 1) ? (8 * (1 - t) * (t * 16 % 2 < 1 ? 1 : -1)) : 0.0;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: wrapped,
    );
  }

  Widget _hostChip(bool mini) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: CD.gold,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text('방장',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: mini ? 9.5 : 11)),
      );

  Widget _ammoRow(bool mini) {
    // 대기방: 총알 대신 계정 레벨(2026-07-13 사용자 결정 — 프로필처럼).
    if (level >= 0) {
      // 레벨 미기록(구 봇 claim 등)은 'Lv.?' 대신 표시 생략(2026-07-16 제보).
      if (level == 0) {
        return isHost ? _hostChip(mini) : const SizedBox.shrink();
      }
      final lvChip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: CD.rust.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text('Lv.$level',
            style: TextStyle(
                color: CD.rust,
                fontWeight: FontWeight.w900,
                fontSize: mini ? 10 : 11.5)),
      );
      if (!isHost) return lvChip;
      // Lv+방장 칩이 좁은 카드(6인방 92px)를 넘치면 통째로 살짝 축소 —
      // 넘침이 내용을 왼쪽으로 쏠려 보이게 하던 버그(2026-07-16 제보).
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [lvChip, const SizedBox(width: 4), _hostChip(mini)],
        ),
      );
    }
    if (hideAmmo) {
      // 그림자 — 탄약 숨김.
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_off,
              size: mini ? 11 : 13, color: CD.muted),
          const SizedBox(width: 3),
          Text('총알 ?',
              style: TextStyle(color: CD.muted, fontSize: mini ? 10 : 11.5)),
        ],
      );
    }
    if (ammo <= 0) {
      return Text('총알 0',
          style: TextStyle(color: CD.muted, fontSize: mini ? 10 : 11.5));
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 2,
      runSpacing: 2,
      children: [
        for (var i = 0; i < ammo; i++)
          Container(
            width: mini ? 6 : 7,
            height: mini ? 9 : 11,
            decoration: BoxDecoration(
              color: CD.gold,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: CD.leather.withValues(alpha: 0.5)),
            ),
          ),
      ],
    );
  }

  Widget _lastMoveRow(bool mini) {
    final m = lastMove!;
    final Color c;
    switch (m.kind) {
      case ActKind.reload:
        c = CD.gold;
        break;
      case ActKind.defend:
        c = CD.sage;
        break;
      case ActKind.shoot:
        c = fired ? CD.danger : CD.muted;
        break;
      case ActKind.superShoot:
        c = fired ? CD.nova : CD.muted;
        break;
      case ActKind.trap:
        c = const Color(0xFF7A3E18);
        break;
      case ActKind.roulette:
        c = const Color(0xFF8E1E1E);
        break;
      case ActKind.dualShoot:
        c = fired ? const Color(0xFFB5642A) : CD.muted;
        break;
      case ActKind.voodoo:
        c = const Color(0xFF5B3A8E);
        break;
      case ActKind.reset:
        c = const Color(0xFF2E5E8E);
        break;
      case ActKind.idle:
        c = CD.muted;
        break;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(actionIcon(m.kind), size: mini ? 14 : 16, color: c),
        const SizedBox(width: 3),
        Text(
          m.kind.ko,
          style: TextStyle(
              fontSize: mini ? 10.5 : 12, color: c, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// 스킬 링 게이지(B안) — 초상화 둘레에 남은 횟수를 원호로, 우상단에 능력
/// 아이콘 배지. [flash]가 켜지면(능력 발동 순간) 링이 금색으로 번쩍이고
/// 아이콘이 팝된다. 표시 전용.
class _AbilityRing extends StatelessWidget {
  const _AbilityRing({
    super.key,
    required this.color,
    required this.icon,
    required this.frac,
    required this.size,
    required this.flash,
  });

  final Color color;
  final IconData icon;
  final double frac; // 남은 비율 0~1
  final double size;
  final bool flash;

  @override
  Widget build(BuildContext context) {
    final badge = size * 0.36;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: flash ? 0.0 : 1.0, end: 1.0),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        // t<1 동안 금색 → 캐릭터색으로 되돌아온다.
        final ringColor = flash
            ? Color.lerp(CD.nova, color, t)!
            : color;
        final pop = flash ? 1.0 + 0.45 * (1 - t) : 1.0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RingPainter(
                  ringColor,
                  frac.clamp(0.0, 1.0),
                  glow: flash ? (1 - t) : 0,
                ),
              ),
            ),
            Positioned(
              top: -badge * 0.25,
              right: -badge * 0.25,
              child: Transform.scale(
                scale: pop,
                child: Container(
                  width: badge,
                  height: badge,
                  decoration: BoxDecoration(
                    color: ringColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.1),
                    boxShadow: flash
                        ? [
                            BoxShadow(
                                color: CD.nova.withValues(alpha: 0.8 * (1 - t)),
                                blurRadius: 10),
                          ]
                        : null,
                  ),
                  child: Icon(icon, size: badge * 0.62, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.color, this.frac, {this.glow = 0});
  final Color color;
  final double frac;
  final double glow; // 발동 플래시 강도 0~1

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 1.2;
    if (glow > 0) {
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..color = color.withValues(alpha: 0.55 * glow)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    }
    // 트랙(연한 전체 원) + 남은 비율 원호.
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..color = color.withValues(alpha: 0.22));
    if (frac > 0) {
      canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          -math.pi / 2,
          2 * math.pi * frac,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round
            ..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.color != color || old.frac != frac || old.glow != glow;
}


/// 좌석별 저주(시전자) 구분색 — 부두술사가 여럿일 때 "누구 저주인지"를
/// 색으로 읽게 한다(규칙 v2, 2026-07-16). 6좌석 팔레트, 시전자 좌석으로 결정.
Color curseColorOf(int casterSeat) {
  const palette = [
    Color(0xFF5B3A8E), // 보라(기존 저주색)
    Color(0xFF1E7A52), // 진초록
    Color(0xFF1F5F9E), // 남파랑
    Color(0xFFB05A1D), // 구리주황
    Color(0xFFA63A6C), // 자주
    Color(0xFF12766E), // 청록
  ];
  if (casterSeat < 0) return palette[0];
  return palette[casterSeat % palette.length];
}
