# 카우보이 파티 — 세션 이어가기 (HANDOFF)

> 새 세션에서 이 파일을 먼저 읽고 이어서 진행. 모든 작업물은 디스크에 있고 main에 커밋됨(커밋 423ed86 기준).

## 한 줄 요약
앱은 **빌드·검증·배포 완료**되어 라이브로 동작 중. 사용자 피드백 **4건 수정도 2026-06-04 배포 완료(LIVE)**.
→ 남은 할 일 없음. 새 피드백이 오면 아래 "배포 절차" 그대로 반복.

## 2026-06-04 (2차) 피드백 3건 배포 완료
- **① 상대 퇴장 표시**: 상대가 나가면 닉이 사라져(`names[s]→null`) "카우보이 승리!"로 깨지던 문제 → `leave(name:)`가 `quit/pX`에 닉을 저장(보존), `computeView`의 `quit/quitName/leftName` 헬퍼로 퇴장 두 경로(드롭 중도퇴장·정상승리후 승자퇴장) 모두 **"OOO 님이 나갔어요"** 표시. 단위테스트 2건 추가(`online_service_test.dart`).
- **② 슈퍼빵야 이펙트**: `lib/widgets/super_flash.dart`(SuperBbangyaFlash) — 노란 "슈 퍼 빵 야" 외곽선/글로우/팝&셰이크 1회 오버레이. 오프라인은 `_resolve`에서 `out.superFired.any()`, 온라인은 `_handleReveal`(라이브 턴 + 게임종료 over 케이스 `_superFlashedOver` 가드)에서 트리거. 위젯 스모크 테스트 추가.
- **③ 게임 방법 보강**: `how_to_play_screen.dart` 슈퍼빵야 규칙 명확화 + 이펙트 안내.
- 검증: analyze 0 · 테스트 20개 통과 · 게임방법 화면 에뮬 시각확인. 웹(462b972)·APK v1.0.0·대시보드·ntfy 배포. **단 인게임 슈퍼빵야 플래시/온라인 퇴장 배너는 adb 캔버스탭 한계로 실제 게임 시각검증 못함 → 다음 세션 눈으로 확인 권장**(슈퍼빵야: 봇전 6발 모아 발동 / 퇴장배너: 온라인 2클라 후 한쪽 나가기).

## 2026-06-04 배포 완료 기록
- analyze 0 · 테스트 17개 통과 · 웹 재빌드(PowerShell `--base-href=/cowboy-party/`) → gh-pages 푸시(6897aad).
- APK v1.0.0 재업로드(clobber, 51MB). 대시보드 `cowboy-party.html`에 4건 수정행+작업로그 추가 후 푸시(513df9d). ntfy 알림 전송.
- 에뮬 검증: 설치·실행·홈/컴퓨터전 셋업/2인 게임보드 렌더 정상 확인. **단, 인게임 조작(자동조준·4인 배너) 직접 검증은 못함** — `adb input tap`이 Flutter 게임 캔버스 surface에 등록 안 됨(메뉴 화면은 정상). 다음 세션에서 손으로 또는 다른 입력 주입 방식 필요.

## 좌표
- 폴더: `C:\dev\dailyapp\cowboy_party`
- repo: github.com/doonghwi/cowboy-party (main=소스, gh-pages=웹). git author **doonghwi <ehdgnlans@gmail.com>**, Co-Authored-By 금지.
- 웹: https://doonghwi.github.io/cowboy-party/  · APK: releases/tag/v1.0.0
- Firebase: `cowboy-party-doonghwi`, RTDB asia-southeast1
- 대시보드: `C:\dev\dailyapp\dashboard-site`(repo doonghwi/dailyapp-dashboard, main→Pages). 빌드로그=`cowboy-party.html`. 사용량/현황 desc는 중앙 RTDB `cowboy-duel-doonghwi` 의 `dailyapp_stats/cowboy_party`.
- 에뮬: AVD cowboy(emulator-5554), `adb`로 설치/스크린샷. **주의: 이번 대화는 이미지 누적 한도로 스크린샷 read 불가였음 → 새 세션은 가능. 디바이스 좌표 1080x2400 기준.**

## 지금 "배포만 남은" 4건 (모두 코드 완료, analyze 0)
1. **반응속도 결투 점수 오기록** → 승자 판정을 "네트워크 먼저"(transaction race)에서 **"탭 서버시각 가장 빠른 사람"**(host 중재)로 변경.
   - `online_service.dart`: `recordTap`, `setShowdownWinner` 추가(기존 `tryWinShowdown` 대체), `newShowdownRound`가 `taps`도 초기화.
   - `widgets/online_showdown.dart`: `_onTap`이 valid면 `recordTap(_serverNow)`, host는 `_hostArbitrate()`로 valid 탭 중 최소시각 award(+700ms settle 타이머, 전원 부정출발이면 재시작).
   - 점수: `online_game_screen._maybeReset(view, scored)`가 승리 즉시 `recordScore(winnerSeat)` (이미 반영). showdown.winner는 computeView가 won으로 override.
2. **상대 1명이면 빵야 자동조준**(카우보이 듀얼처럼) → 양 화면 `onSelect`에서 살아있는 상대가 1명이면 `_selTarget` 자동 설정(오프라인/온라인 모두 적용).
3. **빵야 후 결정 안눌러지다 팅김(1회)** → 자동조준으로 "타겟 미선택 시 결정 비활성" 상태를 줄여 완화. (재현 로그 없어 근본원인 미확정 — 새 세션에서 logcat 주시)
4. **4인일 때 중앙 문구 가림** → `circular_table.dart`에서 center 배너를 Stack **맨 위(z-order 최상단)** 로 옮기고 `maxWidth: w*0.52`로 제한.

## 배포 절차(그대로 복붙)
```
# 1) analyze + test
cd C:/dev/dailyapp/cowboy_party && flutter analyze && flutter test
# 2) 웹 빌드는 반드시 PowerShell로(Git Bash는 --base-href 앞 / 가 경로변환됨)
#    PowerShell: flutter build web --release --pwa-strategy=none --base-href=/cowboy-party/
# 3) gh-pages 배포(orphan worktree)
git worktree add --force -B gh-pages /tmp/cp_gh
cd /tmp/cp_gh && git rm -rf . ; cp -r C:/dev/dailyapp/cowboy_party/build/web/. . && touch .nojekyll
git add -A && git -c user.name=doonghwi -c user.email=ehdgnlans@gmail.com commit -q -m "Deploy: feedback fixes" && git push -f origin gh-pages
cd C:/dev/dailyapp/cowboy_party && git worktree remove --force /tmp/cp_gh
# 4) APK + release
flutter build apk --release   # (PowerShell 권장)
cp build/app/outputs/flutter-apk/app-release.apk C:/dev/dailyapp/cowboy-party-v1.apk
gh release upload v1.0.0 C:/dev/dailyapp/cowboy-party-v1.apk --repo doonghwi/cowboy-party --clobber
# 5) 대시보드 빌드로그(cowboy-party.html)에 4건 행 추가 + 상태 LIVE, push (메모리 규칙: 기능마다 빌드로그 기록)
# 6) ntfy: curl -H "Content-Type: text/plain; charset=utf-8" -T <utf8파일> https://ntfy.sh/app-making-doonghwi
```

## 배포 후 검증(새 세션은 스크린샷 가능)
- 에뮬 설치 후: 봇전 6발→슈퍼빵야 화살표, 장전/방어 이펙트, 이모티콘, 2인 자동조준, 4인 중앙문구 안가림 확인.
- 온라인 점수: REST로 2번째 플레이어 시뮬레이션(`rooms/{code}/players/p1`, `turns/tN/p1`) 후 무승부→결투→탭, 점수가 **이긴 사람**에게 가는지 확인.

## 핵심 교훈/주의(이미 메모리에도 있음)
- 온라인 퇴장은 onDisconnect 하드제거 금지 → **하트비트(4s)+14s 유예**(이미 적용). 좌석 stale 시 host가 `quit` 기록.
- 사용량은 중앙 `dailyapp_stats`에 **increment만**, opens 덮어쓰기 금지.
- 게임로직은 오프라인/온라인 공용(`party_logic.resolveTurn`). Move 인코딩 0=장전·1=방어·2+=빵야·8+=슈퍼빵야.
