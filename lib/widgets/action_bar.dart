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

  // ── 특수행동 UI 규칙(2틀): ───────────────────────────────────────────────
  // 1) parallel(스모커 연막·파파라치 엿보기): 기본 행동 줄 **위**에 얇게 둔다.
  // 2) turnSlot(덫·무효·저주·운빵·더블): 장전/방어/빵야와 같은 한 턴을 쓰므로
  //    기본 3칸을 줄이고 **4번째 칸**으로 둔다.
  // 패시브/기본형은 장전·방어·빵야만. 새 로직 없이는 이 틀을 벗어나지 않는다.
  bool get _showSmoke => myChar == CharId.smoker;
  bool get _showPeek => showPeek; // 파파라치 — parallel 위치(위)

  /// 한 턴 소모형 특수행동(4번째 칸). 없으면 null.
  ActKind? get _turnSlotKind {
    switch (myChar) {
      case CharId.hunter:
        return ActKind.trap;
      case CharId.resetter:
        return ActKind.reset;
      case CharId.voodoo:
        return ActKind.voodoo;
      case CharId.roulette:
        return ActKind.roulette;
      case CharId.dualgun:
        return ActKind.dualShoot;
      default:
        return null;
    }
  }

  bool get _turnSlotEnabled {
    switch (_turnSlotKind) {
      case ActKind.trap:
        return trapAvailable;
      case ActKind.reset:
        return resetAvailable;
      case ActKind.dualShoot:
        return myAmmo >= 2;
      case ActKind.voodoo:
      case ActKind.roulette:
        return true;
      default:
        return false;
    }
  }

  String get _turnSlotLabel {
    switch (_turnSlotKind) {
      case ActKind.trap:
        return '덫';
      case ActKind.reset:
        return '무효';
      case ActKind.voodoo:
        return '저주';
      case ActKind.roulette:
        return '운빵';
      case ActKind.dualShoot:
        return '더블';
      default:
        return '';
    }
  }

  String get _turnSlotSub {
    switch (_turnSlotKind) {
      case ActKind.trap:
        return trapAvailable ? '일반탄 반사' : '사용함';
      case ActKind.reset:
        return resetAvailable ? '모두 무효화' : '사용함';
      case ActKind.voodoo:
        return '$kCurseFuse턴 뒤';
      case ActKind.roulette:
        return '50:50';
      case ActKind.dualShoot:
        return _turnSlotEnabled ? '2발·두명' : '2발 필요';
      default:
        return '';
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
            ? '운명의 방아쇠 — 상대를 탭! 50:50로 나/상대에게 총알'
            : '운명의 방아쇠 → ${targetName ?? ""} (상대 향하면 방어로 막힘·덫 반사)';
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
        // ── parallel 슬롯(위): 스모커 연막 토글 / 파파라치 엿보기 버튼 ──
        if (_showSmoke && smokeLeft > 0) ...[
          _parallelBar(
            on: smokeOn,
            color: const Color(0xFF6B7A8F),
            icon: Icons.cloud,
            label: smokeOn
                ? '연막 켜짐 — 이번 턴 50% 회피 (남은 $smokeLeft번)'
                : '연막 쓰기 (남은 $smokeLeft번, 행동과 함께)',
            onTap: () => onSmokeToggle?.call(!smokeOn),
          ),
          const SizedBox(height: 8),
        ] else if (_showPeek) ...[
          _parallelBar(
            on: false,
            color: const Color(0xFF4A6FA5),
            icon: Icons.photo_camera,
            label: peekEnabled
                ? '엿보기 — 한 명 행동 미리보기 (게임당 1번)'
                : '엿보기 (준비 중)',
            onTap: peekEnabled ? onPeek : null,
          ),
          const SizedBox(height: 8),
        ],
        // ── 기본 3칸(+ turnSlot 4번째) ──
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
            if (_turnSlotKind != null) ...[
              const SizedBox(width: 10),
              _opt(_turnSlotKind!, _turnSlotLabel, _turnSlotSub,
                  _turnSlotEnabled),
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

  /// parallel 슬롯(위) — 행동과 병행하는 토글/버튼(연막·엿보기) 공통 모양.
  Widget _parallelBar({
    required bool on,
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: on ? color : CD.parchment.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: on ? Colors.white : color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: on ? Colors.white : CD.leather)),
            ),
          ],
        ),
      ),
    );
  }
}
