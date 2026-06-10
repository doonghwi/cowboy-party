import 'package:flutter/material.dart';

import '../game/party_logic.dart';
import '../theme.dart';

/// The bottom action panel: pick one of 장전 / 방어 / 빵야, then lock it in.
///
/// Shooting needs a target, chosen by tapping a cowboy in the circle above —
/// so this bar only owns the action choice and the confirm button. The parent
/// screen flips the table into "target mode" while [selected] is [ActKind.shoot]
/// and feeds back the picked [targetName].
class ActionBar extends StatelessWidget {
  final int myAmmo;
  final ActKind? selected;
  final int selectedTarget;
  final String? targetName;
  final ValueChanged<ActKind> onSelect;
  final VoidCallback onConfirm;

  /// 캐릭터 능력 (기본값 = 능력 없음 — 오프라인 등 기존 경로 무변경).
  final CharId myChar;
  final bool trapAvailable; // 사냥꾼, 게임당 1회
  final int smokeLeft; // 스모커 잔여 연막
  final bool smokeOn; // 이번 턴 연막 토글 상태
  final ValueChanged<bool>? onSmokeToggle;

  const ActionBar({
    super.key,
    required this.myAmmo,
    required this.selected,
    required this.selectedTarget,
    required this.targetName,
    required this.onSelect,
    required this.onConfirm,
    this.myChar = CharId.none,
    this.trapAvailable = false,
    this.smokeLeft = 0,
    this.smokeOn = false,
    this.onSmokeToggle,
  });

  bool get _pacifist => myChar == CharId.pacifist;
  bool get _canShoot => myAmmo > 0 && !_pacifist;
  bool get _canSuper => myAmmo >= kMaxAmmo && !_pacifist;
  bool get _showTrap => myChar == CharId.hunter;
  bool get _showSmoke => myChar == CharId.smoker;

  bool get _ready {
    if (selected == null) return false;
    if (selected == ActKind.shoot || selected == ActKind.superShoot) {
      return selectedTarget >= 0;
    }
    return true;
  }

  String get _hint {
    if (selected == null) {
      if (_pacifist) return '평화주의자 — 장전 6번을 채우면 승리! (빵야 불가)';
      if (_canSuper) return '총알 가득! 슈퍼빵야로 방어를 뚫을 수 있어요';
      return myAmmo > 0 ? '행동을 골라요' : '총알이 없어요 — 먼저 장전!';
    }
    switch (selected!) {
      case ActKind.reload:
        return myChar == CharId.speedloader
            ? '장전 — 50% 확률로 총알 +2!'
            : '장전 — 총알 +1';
      case ActKind.defend:
        return '방어 — 이번 턴 모든 공격을 막아요';
      case ActKind.shoot:
        return selectedTarget < 0
            ? '빵야 — 위 원에서 쏠 상대를 탭하세요'
            : '빵야 → ${targetName ?? ""}';
      case ActKind.superShoot:
        return selectedTarget < 0
            ? '⚡슈퍼빵야 — 처치할 상대를 탭! (방어 무시·5발 소비)'
            : '⚡슈퍼빵야 → ${targetName ?? ""} 확정 처치!';
      case ActKind.trap:
        return '덫 — 이번 턴 나를 쏜 일반탄을 전부 반사! (게임당 1번)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showSmoke && smokeLeft > 0) ...[
          GestureDetector(
            onTap: () => onSmokeToggle?.call(!smokeOn),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: smokeOn
                    ? const Color(0xFF6B7A8F)
                    : CD.parchment.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF6B7A8F), width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud,
                      size: 16,
                      color: smokeOn ? Colors.white : const Color(0xFF6B7A8F)),
                  const SizedBox(width: 6),
                  Text(
                    smokeOn
                        ? '연막 켜짐 — 이번 턴 50% 회피 (남은 $smokeLeft번)'
                        : '연막 쓰기 (남은 $smokeLeft번, 행동과 함께)',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: smokeOn ? Colors.white : CD.leather),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            if (_canSuper)
              _opt(ActKind.superShoot, '슈퍼빵야', '5발·확정', true)
            else
              _opt(ActKind.reload, '장전',
                  myChar == CharId.speedloader ? '+1~2 총알' : '+1 총알', true),
            const SizedBox(width: 10),
            _opt(ActKind.defend, '방어', '다 막음', true),
            const SizedBox(width: 10),
            _opt(ActKind.shoot, '빵야',
                _pacifist ? '사용 불가' : (_canShoot ? '한 명 저격' : '총알 필요'),
                _canShoot),
            if (_showTrap) ...[
              const SizedBox(width: 10),
              _opt(ActKind.trap, '덫',
                  trapAvailable ? '일반탄 반사' : '사용함', trapAvailable),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _hint,
          textAlign: TextAlign.center,
          style: const TextStyle(color: CD.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _ready ? onConfirm : null,
            style: FilledButton.styleFrom(
              backgroundColor: CD.rust,
              disabledBackgroundColor: CD.muted.withValues(alpha: 0.35),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.gavel, size: 20),
            label: Text(
              _ready ? '결정!' : '행동 선택',
              style: posterTitle(18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _opt(ActKind kind, String label, String sub, bool enabled) {
    final c = CD.actionColor(kind);
    final isSel = selected == kind;
    return Expanded(
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: GestureDetector(
          onTap: enabled ? () => onSelect(kind) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              color: isSel ? c : CD.parchment,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c, width: 2),
              boxShadow: isSel
                  ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 8)]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(actionIcon(kind),
                    size: 28, color: isSel ? Colors.white : c),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: isSel ? Colors.white : CD.leather)),
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.5,
                        color: isSel
                            ? Colors.white.withValues(alpha: 0.9)
                            : CD.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
