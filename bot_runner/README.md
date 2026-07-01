# 카우보이 봇 러너

빠른시작에서 **사람이 혼자 대기하면 봇이 방을 채워** 게임이 성사되게 하는 헤드리스
Dart 서비스. **맥미니에서 상시 실행**한다. 봇은 진짜(익명) 계정으로 참여하고, 이기면
주간 랭킹에도 오른다. (실유저가 늘면 봇을 랭킹에서 뺄 예정 — 아래 "끄기" 참고.)

앱과 **똑같은 규칙엔진·봇 AI**(`lib/game/`, 앱에서 동기화)를 쓰므로 봇의 판단은 사람
클라이언트와 항상 일치한다(버전 스큐 없음).

## 구조
```
bin/runner.dart      메인(무한 루프): 계정 준비 → 매칭 감시
bin/selfcheck.dart   연결 점검(공개 read)
lib/config.dart      프로젝트 상수·튜닝(봇 이름·유예·봇수·주기)
lib/auth.dart        Firebase Auth REST(저장형 익명, 토큰 갱신)
lib/rtdb.dart        RTDB REST(get/put/patch)
lib/game_replay.dart 턴 히스토리 재현(=앱 computeView 축약)
lib/bot_client.dart  봇 1명: 입장·하트비트·턴제출·결투탭·랭킹기록·퇴장
lib/matchmaker.dart  방 감시 → 유예 뒤 봇 2~4명 투입
lib/game/            char_core·party_logic·cpu_ai (앱에서 동기화 — 직접 편집 금지)
tool/sync_core.sh    앱 규칙엔진을 러너로 복사
```

## 설정 (최초 1회)

### 1) 서버용 API 키 만들기 (필수)
google-services.json 의 Android 키는 "Android 앱" 제한이라 서버(REST)에서 차단된다.
러너용 키를 새로 만든다:
1. https://console.cloud.google.com/apis/credentials?project=cowboy-party-doonghwi
2. **사용자 인증 정보 만들기 → API 키**
3. 만든 키 → **애플리케이션 제한사항**: "없음"(간단) 또는 "IP 주소"(맥미니 공인 IP; 더 안전)
4. **API 제한사항**: "키 제한" → **Identity Toolkit API**(+ Token Service API) 만 선택 권장
5. 키 값을 환경변수로:
   ```bash
   export COWBOY_AUTH_API_KEY=AIza...        # 새로 만든 키
   ```
   (또는 `lib/config.dart` 의 authApiKey 기본값 교체)

### 2) 봇 이름 정하기
`lib/config.dart` 의 `botNames` 를 원하는 서부풍 이름으로 교체(개수 = 봇 계정 수).
처음 실행하면 익명 계정이 생성돼 `bot_creds.json`(uid·refreshToken)에 저장된다 →
이후 재실행에도 **같은 봇 이름·uid** 유지(랭킹에서 일관). `bot_creds.json` 은 비밀이니
커밋·공유 금지(이미 .gitignore).

### 3) 실행
```bash
dart pub get
dart run bin/selfcheck.dart      # 연결 확인
dart run bin/runner.dart         # 러너 시작(무한 루프)
```

## 상시 실행 (맥미니 · launchd)
`com.doonghwi.cowboy-bot-runner.plist` 참고. `~/Library/LaunchAgents/` 에 넣고:
```bash
cp com.doonghwi.cowboy-bot-runner.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.doonghwi.cowboy-bot-runner.plist
```
크래시/재부팅 시 자동 재시작. 로그는 plist 의 StandardOut/ErrorPath 참고.
맥미니 **절전(잠자기) 끄기**: 시스템 설정 → 에너지 → "디스플레이 끈 후 잠자기 방지".

## 앱 규칙 바뀌면 (버전 스큐 방지)
앱에서 캐릭터·밸런스·규칙을 바꾸면 **러너도 최신화**해야 봇이 어긋나지 않는다:
```bash
bash tool/sync_core.sh   # 앱 lib/game/*.dart → 러너로 복사
dart test                # 재현 테스트 통과 확인
```
(러너 배포 시 앱도 새로 배포한다 — 규칙은 한 소스=앱에서만 편집.)

## 봇 랭킹 끄기 (실유저 늘면)
`lib/bot_client.dart` 의 `_recordWin` 호출을 막으면(예: 상단 `if (false)` 가드) 봇이
랭킹에 안 오른다. 게임 참여(방 채우기)는 그대로 유지.

## 동작 요약
1. 계정 준비(저장형 익명) → 2. rooms 폴링해 **match:true·미시작·사람 1명 대기** 방 탐색
→ 3. 유예(5초) 뒤 사람끼리 안 잡혔으면 **빈 좌석에 봇 2~4명 투입**
→ 4. 각 봇이 좌석 잡고 하트비트, 턴마다 히스토리 재현→CpuAi로 수 결정→제출(사람같은 지연)
→ 5. 무승부면 결투(showdown)에 실력 기반 반응으로 탭 — 탭 값은 goAt+반응ms(서버시각,
   앱 호스트가 `tap≥goAt`만 유효 처리하므로) → 6. 이기면 주간 랭킹 기록 → 7. 끝나면 퇴장.

봇이 만든 공개방(사회성)은 **호스트 봇이 심판까지 겸한다**: 사람 1명+준비 확인 후 시작,
무승부면 showdown 생성→유효 탭 중 최속 승자 확정(전원 부정출발이면 라운드 재시작),
결과를 몇 초 보여주고 대기실로 리셋. 유령 좌석(id 없는 노드)·하트비트 45초+ 끊긴
좌석은 호스트 봇이 청소한다.

## 알려진 한계 (MVP)
- **매칭(빠른시작) 방**에선 봇은 비-호스트 참여만(사람 호스트의 앱이 시작·결투생성·
  승자확정). 사람이 다 나가면 게임이 멈출 수 있고, 봇은 스톨 타임아웃(30초) 뒤 퇴장.
  (봇이 만든 공개방은 위처럼 봇 호스트가 전부 처리.)
- 파파라치 '엿보기'는 봇이 사용 안 함(일반 플레이).
- 서버시계는 로컬(NTP)로 근사 — 결투 탭 타이밍이 미세하게 다를 수 있음.

## e2e 하니스
- `bin/testgame.dart` — 가짜 사람 호스트가 매칭 방을 파서 봇 채움→풀게임→랭킹 확인.
- `bin/showdowntest.dart` — 무승부 상태 방을 만들어 심판·탭·승자확정 전 과정 검증.
