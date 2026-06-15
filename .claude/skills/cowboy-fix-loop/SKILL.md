---
name: cowboy-fix-loop
description: 카우보이(cowboy_party) 버그를 BUGS.md 큐에서 하나씩 꺼내 재현→수정→검증(analyze+test)→배포→보고까지 자동으로 도는 루프. 사용자가 QA로 버그를 쌓아두면 이 루프가 처리한다.
---

# cowboy-fix-loop — 카우보이 버그 수정 루프

Steinberger의 `maintainer-orchestrator`를 이 프로젝트에 맞춘 버전. "버그를 일일이
프롬프트하지 말고 버그를 잡는 루프를 설계하라"의 실물. 한 번 깨어날 때 큐에서 **가장
높은 우선순위 버그 1개**를 끝까지(배포까지) 처리하고 보고한다.

## 작업 디렉토리
`/Users/doonghwi/Documents/dailyapp/cowboy_party`

## 한 사이클 (버그 1개)
1. **고르기**: `cowboy-bug-triage`로 BUGS.md 정렬 → 맨 위 `[ ]` 항목을 `[~]`로.
   큐가 비었으면 "처리할 버그 없음" 보고하고 종료.
2. **재현·원인**: 재현 단계로 해당 화면/로직 파일을 grep으로 찾고 근본 원인을 특정.
   규칙/판정 버그는 **항상 `lib/game/party_logic.dart` 한 곳**에서 본다.
3. **수정**: 최소 변경으로 고친다. 결정성 규칙 준수(랜덤은 `seededRoll`만, enum은
   append-only, RTDB orderByChild엔 `.indexOn`). 주변 코드 스타일을 따른다.
4. **검증(필수 게이트)**:
   - `flutter analyze` → 0 이슈
   - `flutter test` → 전부 통과 (규칙 수정이면 `test/characters_test.dart`에 케이스 추가)
   - 가능하면 위젯 테스트로 회귀 고정(에뮬 탭은 캔버스라 불안정 — 단위/위젯 우선)
5. **문서**: 바뀐 게 사용자에게 보이면 `lib/meta/announcements.dart`에 한 줄,
   설계가 바뀌면 `ARCHITECTURE.md` 갱신, 새 함정은 `_make-new-app/LESSONS.md`.
6. **커밋·배포**: 작성자 `doonghwi <ehdgnlans@gmail.com>`, Co-Authored-By 금지.
   - 커밋 → `git push origin main`(pre-push 시크릿 스캔 통과)
   - 웹: **`bash deploy_web.sh`** (빌드 + 자가소멸 SW 덮어쓰기 + gh-pages force push).
     ⚠️ 수동 배포 시 반드시 `build/web/flutter_service_worker.js`를 자가소멸 SW로 덮어쓸 것
     — 빈 SW를 두면 옛 PWA가 흰 화면이 된다.
   - APK: `JAVA_HOME=/opt/homebrew/opt/openjdk@17 flutter build apk --release`
     → `dist/cowboy-party.apk`
   - RTDB 규칙 바꿨으면 `firebase deploy --only database --project cowboy-party-doonghwi`
7. **마감**: BUGS.md 항목 `[x]` + 한 줄 결과, `HANDOFF.md` 갱신. 다음 사이클로(또는 종료).

## 멈춤 조건
- 큐가 비었다 / 사용자 결정이 필요한 항목(밸런스 방향, 외부 가입 등)에 닿으면 보고 후 중단.
- 같은 버그가 3사이클 연속 안 잡히면 근본 문제로 보고.

## 어떻게 돌리나
- 수동: 이 스킬을 호출하면 한 사이클(버그 1개)을 처리한다.
- 반복: omc `/loop`(또는 ralph)로 "BUGS.md가 빌 때까지 cowboy-fix-loop" 형태로 감쌀 수 있다.
- 큐 채우기: 사용자가 QA로 찾은 버그를 BUGS.md에 적거나 ntfy 제보를 붙여넣는다.

## 이 루프 구조를 또 쓸 수 있는 곳
- **밸런스 패치 루프**: cowboy.gg 승률(/charstats)을 읽어 편차 큰 캐릭터를 party_logic에서 조정.
- **신규 캐릭터 추가 루프**: ARCHITECTURE의 "캐릭터 수정 루프 체크리스트"를 자동 순회.
- **출시 전 회귀 스윕**: analyze+test+에뮬 스모크를 화면별로 한 바퀴.
