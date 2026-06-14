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
  final bool resetAvailable; // 리셋터 '무효', 게임당 1회
  final int smokeLeft; // 스모커 잔여 연막
  final bool smokeOn; // 이번 턴 연막 토글 상태
  final ValueChanged<bool>? onSmokeToggle;

  /// 쌍권총 더블 빵야 두 번째 대상.
  final int selectedTarget2;
  final String? targetName2;

  /// 파파라치 엿보기.
  final bool showPeek; // 파파라치 + 미사용
  final bool peekEnabled; // 오프라인 true (온라인은 준비 중)
  final VoidCallback? onPeek;

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
    this.resetAvailable = false,
    this.smokeLeft = 0,
    this.smokeOn = false,
    this.onSmokeToggle,
    this.selectedTarget2 = -1,
    this.targetName2,
    this.showPeek = false,
    this.peekEnabled = false,
    this.onPeek,
  });

  bool get _pacifist => myChar == CharId.pacifist;
  bool get _canShoot => myAmmo > 0 && !_pacifist;
  bool get _canSuper => myAmmo >= kMaxAmmo && !_pacifist;
  bool get _showTrap => myChar == CharId.hunter;
  bool get _showReset => myChar == CharId.resetter;
  bool get _showSmoke => myChar == CharId.smoker;

  /// 캐릭터 전용 '상시' 액션(있으면 별도 줄에 표시). 파파라치 엿보기는 Stage 4.
  ActKind? get _specialKind {
    switch (myChar) {
      case CharId.roulette:
        return ActKind.roulette;
      case CharId.dualgun:
        return ActKind.dualShoot;
      case CharId.voodoo:
        return ActKind.voodoo;
      default:
        return null;
    }
  }

  bool get _specialEnabled {
    switch (_specialKind) {
      case ActKind.dualShoot:
        return myAmmo >= 2; // 2발 필요
      case ActKind.roulette:
      case ActKind.voodoo:
        return true; // 상시
      default:
        return false;
    }
  }

  bool get _ready {
    final s = selected;
    if (s == null) return false;
    if (s == ActKind.shoot ||
        s == ActKind.superShoot ||
        s == ActKind.roulette ||
        s == ActKind.voodoo) {
      return selectedTarget >= 0;
    }
    if (s == ActKind.dualShoot) {
      return selectedTarget >= 0 && selectedTarget2 >= 0;
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
      case ActKind.roulette:
        return selectedTarget < 0
            ? '운명의 방아쇠 — 상대를 탭! 50:50로 나/상대 중 한 명 사망'
            : '운명의 방아쇠 → ${targetName ?? ""} (상대 방어 시 내가 죽음)';
      case ActKind.dualShoot:
        if (selectedTarget < 0) return '더블 빵야 — 첫 번째 상대를 탭! (총알 2발)';
        if (selectedTarget2 < 0) {
          return '더블 빵야 — 두 번째 상대를 탭! (1: ${targetName ?? ""})';
        }
        return '더블 빵야 → ${targetName ?? ""}, ${targetName2 ?? ""}';
      case ActKind.voodoo:
        return selectedTarget < 0
            ? '저주 — 대상을 탭! $kCurseFuse턴 뒤 사망 (내가 죽으면 풀림)'
            : '저주 → ${targetName ?? ""} ($kCurseFuse턴 뒤 사망)';
      case ActKind.reset:
        return '무효 — 이번 턴 다른 모두의 행동을 없던 일로! (게임당 1번)';
      case ActKind.idle:
        return '가만히 — 아무 행동도 하지 않아요';
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
            if (_showReset) ...[
              const SizedBox(width: 10),
              _opt(ActKind.reset, '무효',
                  resetAvailable ? '모두 무효화' : '사용함', resetAvailable),
            ],
          ],
        ),
        if (showPeek) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPeek,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4A6FA5),
                side: const BorderSide(color: Color(0xFF4A6FA5), width: 2),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.photo_camera, size: 18),
              label: Text(
                  peekEnabled ? '엿보기 — 1명 행동 미리보기 (게임당 1번)' : '엿보기 (온라인 준비 중)',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
        if (_specialKind != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            _opt(
              _specialKind!,
              _specialKind!.ko,
              switch (_specialKind!) {
                ActKind.roulette => '운빵 50:50',
                ActKind.dualShoot =>
                  _specialEnabled ? '2발·두 명' : '총알 2발 필요',
                ActKind.voodoo => '$kCurseFuse턴 뒤 사망',
                _ => '',
              },
              _specialEnabled,
            ),
          ]),
        ],
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
