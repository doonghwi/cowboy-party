import 'package:flutter/material.dart';

import '../game/party_logic.dart';
import '../theme.dart';
import 'emo.dart';

/// A single cowboy at the table: avatar, name, ammo and their last revealed
/// action. Shakes briefly when [hit] flips true. Three sizes via [scale] so the
/// same card works in a 6-seat circle (mini), the opponent ring (compact) and
/// as the spotlighted "me" card (full).
class SeatCard extends StatelessWidget {
  final String name;
  final int ammo;
  final bool alive;
  final bool isMe;
  final bool joined;
  final bool submitted;
  final bool hit;
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

  /// 리빌 중 능력 발동 라벨 ('자힐!' 등). null이면 표시 안 함.
  final String? abilityFx;

  /// 부두 저주(C2): 남은 턴(0=없음)을 좌석에 상시 표시 — 모두에게 보임.
  final int curseTurnsLeft;

  /// 방장이 닫은 자리(F2) — 자물쇠 아바타.
  final bool blocked;

  const SeatCard({
    super.key,
    required this.name,
    required this.ammo,
    required this.alive,
    this.isMe = false,
    this.joined = true,
    this.submitted = false,
    this.hit = false,
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
    this.blocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final mini = scale == 0;
    final compact = scale == 1;
    final avatar = mini ? 34.0 : (compact ? 40.0 : 54.0);
    final width = mini ? 92.0 : (compact ? 120.0 : 150.0);

    final borderColor = targeted
        ? CD.danger
        : !alive
            ? CD.muted.withValues(alpha: 0.5)
            : (isMe ? CD.rust : CD.leather.withValues(alpha: 0.3));

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: width,
      padding: EdgeInsets.symmetric(
          horizontal: mini ? 6 : 10, vertical: mini ? 6 : (compact ? 8 : 12)),
      decoration: BoxDecoration(
        color: targeted
            ? CD.danger.withValues(alpha: 0.18)
            : isMe
                ? CD.gold.withValues(alpha: 0.22)
                : CD.parchment.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(mini ? 13 : 16),
        border: Border.all(
          color: borderColor,
          width: (isMe || targeted) ? 2.5 : 1.5,
        ),
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
              blocked
                  ? Icon(Icons.lock,
                      size: avatar, color: CD.muted.withValues(alpha: 0.6))
                  : Opacity(
                      opacity: alive ? 1 : 0.55,
                      child: Emo(
                        !joined ? 'person' : (alive ? 'cowboy' : 'skull'),
                        size: avatar,
                      ),
                    ),
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
                      color: charDef(char).color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                    child: Icon(charDef(char).icon,
                        size: 11, color: Colors.white),
                  ),
                ),
              // C2: 저주 남은 턴 — 모두에게 보이는 해골 카운트다운.
              if (curseTurnsLeft > 0 && alive)
                Positioned(
                  right: -10,
                  bottom: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B3A8E),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('💀',
                            style: TextStyle(fontSize: 9)),
                        const SizedBox(width: 2),
                        Text('$curseTurnsLeft',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
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
          SizedBox(height: mini ? 2 : 4),
          if (abilityFx != null) ...[
            const SizedBox(height: 2),
            TweenAnimationBuilder<double>(
              key: ValueKey('fx-$name-$abilityFx'),
              tween: Tween(begin: 0.6, end: 1.0),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              builder: (context, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: charDef(char).color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(abilityFx!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900)),
              ),
            ),
          ],
          if (late && !alive)
            const Text('다음 판 참여',
                style: TextStyle(
                    color: CD.sage,
                    fontSize: 11,
                    fontWeight: FontWeight.bold))
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

    final wrapped = onTap == null
        ? card
        : GestureDetector(onTap: alive ? onTap : null, child: card);

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

  Widget _ammoRow(bool mini) {
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
