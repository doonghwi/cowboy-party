# cowboy_party 대규모 업데이트 — 구현 계획 (2026-06-11, 진행 중 체크리스트)

> 이 파일은 작업 세션의 단일 진실 공급원. 항목 완료 시 [x] 갱신. 사용자 결정사항: 캐릭터=코인 해금, 랭킹=시즌제 포인트, 로그인=Google+게스트, 디스코드=버튼 자리만.

## 0. 버그: 게임중 난입 즉시부활 (원인 확정)
- 원인: `OnlineService.computeView`의 생존 컬링(`alive[s] && !present(s)`)이 **현재** presence로 리플레이 전체에 적용됨. 게임 중 빈자리를 새 클라이언트가 차지하면(joinRoom의 started 분기) 그 좌석이 과거 턴부터 생존자로 계산됨.
- 수정: joinRoom에서 `started==true`일 때 player 노드에 `late: true` 기록. computeView 라이브 게임에서 `late` 좌석은 alive=false 고정(관전), reap 대상 제외. 다음 판(startGame이 players를 compact 재작성)에서 late 자연 소멸. resetBoard에도 late 클리어 추가. UI: late인 나에게 "관전 중 — 다음 판부터 참여" 배너. [x] 코드 [x] 테스트

## 1. 캐릭터 8종 (lib/game/characters.dart + party_logic 확장)
- 온라인 동기화 핵심: 능력 확률은 **결정적 시드 RNG**(roomCode+turn+seat 해시) — 모든 클라이언트 동일 결과. characters는 `players/p{s}/char` 에 저장, startGame 시 compact에 포함.
- | id | 이름 | 능력 구현 |
  | sniper | 스나이퍼 | 빵야가 10% 확률로 방어 무시 (시드롤) |
  | speedloader | 스피드로더 | 장전 시 50% 확률 +2발 (시드롤) |
  | duelist | 결투가 | 생존자 2명 시점에 결투가 1명뿐이면 즉시 승리 (둘 다 결투가면 효과 없음) |
  | prepper | 준비자 | 시작 ammo 1 |
  | doctor | 의사 | 게임당 1회 치명타 무효(패시브 자동, 자힐) |
  | hunter | 사냥꾼 | 새 액션 '덫'(게임당 1회, 그 턴 다른 행동 불가): 그 턴 나를 쏜 일반탄 전부 반사(쏜 자 사망). 슈퍼빵야는 관통 |
  | smoker | 스모커 | 토글 '연막'(게임당 2회, 다른 행동과 병행): 그 턴 들어오는 각 공격 50% 회피(슈퍼 포함, 시드롤) |
  | pacifist | 평화주의자 | 빵야/슈퍼 불가. 장전 누적 6회 성공 시 즉시 승리(그 턴 사망하면 무효) |
- Move 인코딩 확장: 연막 비트(+16), 덫=새 kind. 결정 로직은 resolvePartyTurn(순수함수) + 단위테스트.
- 오프라인 모드도 동일 로직, CPU는 랜덤 캐릭터. [x] 정의 [x] resolvePartyTurn [x] 테스트 [x] 온라인 연동(서비스/컴퓨트뷰) [x] 게임 UI(덫/연막 버튼) — 오프라인 캐릭터 적용은 보류(후속)

## 2. 메타: 코인·데일리·해금 (lib/meta/meta_service.dart)
- 로컬 우선(shared_preferences) + 로그인 시 /users/$uid 동기화. 코인 획득: 승리 +30(2인)~+70(6인), 참가 +5, 데일리 출석 7일 사이클(20/20/30/30/40/40/60), 첫 캐릭터 2종 무료(준비자·스나이퍼), 해금 비용 200~500.
- [x] meta_service [x] 보상 지급 연동(온라인 승리) [x] 데일리 UI

## 3. 로그인 (lib/meta/auth_service.dart)
- 웹: signInWithPopup(GoogleAuthProvider). 안드: google_sign_in+credential. 게스트: 익명 auth, 실패 시 로컬 폴백(끊김 없음).
- ⚠️ 콘솔 필요: Authentication > Google·익명 활성화(+안드 SHA1 — CLI `firebase apps:android:sha:create`로 시도). 실패 시 대시보드 개입필요에 기록하고 폴백 모드로 출시.
- [x] auth_service(폴백 포함) [x] UI(프로필/로그인 버튼) — 콘솔 활성화 전이면 폴백 동작 확인 [x] (익명 API 활성화 성공)

## 4. 시즌 랭킹 (/seasons/$sid/$uid {name, pts})
- sid = '2026-06' 월별. 승리 시 +10×(인원-1)pts. 랭킹 탭: 상위 50 + 내 순위 sticky. 로그인 유저만 등록(게스트는 로컬 표시 + 로그인 유도).
- [x] 기록 [x] 랭킹 탭 UI

## 5. 방 목록 로비
- createRoom에 `public`(기본 on), `title`, `hostName` 추가. /rooms 쿼리(createdAt 최근 30, !started, 2h TTL 필터) → 목록 UI(제목/인원/입장). 코드 입장도 유지(비공개방).
- [x] 서비스 [x] UI

## 6. 앱 셸 & 화면 (UX_UI.md 준수)
- 하단 탭: [플레이] [캐릭터] [랭킹] [보상]. 우상단 설정(사운드토글/디스코드버튼자리/크레딧). 코인 잔액 상단 상시.
- 캐릭터 탭: 카드 그리드(초상=Twemoji류 이모지 대형+테두리, 능력 한 줄+수치, 장착/해금 상태, 코인 부족 시 이유 토스트). 광고 배너 placeholder(하단 60px, "AD" 점선 박스, 설정으로 토글 가능한 상수).
- [x] 셸 [x] 캐릭터 탭 [x] 보상 탭 [x] 설정/디스코드 자리 [x] 배너 자리
- 메인 메뉴(홈탭)는 기존 home_screen 콘텐츠 재배치 + 방목록.

## 7. 사운드·디자인
- 사운드: Kenney CC0 다운로드 시도 → 실패 시 Python 합성 고도화(레이어드 총성/장전/코인/승리 팡파레/클릭/덫/연막). CREDITS.md 기록.
- 디자인: 팔레트 고정(사막 노을: #1c1410 bg / #2a201a surface / #e8542f rust / #f2b134 gold / #e8d5a8 sand), 전환 애니메이션, 승리 연출 강화, 탭 햅틱. [x] 사운드 [x] 주스 패스(컨페티·코인플라이·홈 페이드 전환)
- 빈 상태 일러스트·스태거 등장은 후속.

## 8. 유입 요소 후보군 (사용자 선택 대기 문서)
- `GROWTH_CANDIDATES.md` 작성: 스킨, 출석, 시즌패스, 일일미션, 친구초대, 관전공유링크, 푸시, 통계프로필, 업적, 이벤트모드 등 + 각 효과/공수 평가. [x]

## 9. 보안·배포
- cowboy-party DB 규칙 강화(rooms validate, users/seasons 규칙) 배포. [x]
- flutter analyze/test → Android 에뮬 시나리오 → iOS 추가(flutter create --platforms ios .)+시뮬 → 웹/APK 배포 → 대시보드 status.json 갱신 + ntfy. [x] analyze/test [x] Android 에뮬 스모크(메뉴·캐릭터탭·게임진입 스크린샷) [x] iOS 시뮬 부팅 스크린샷 [x] 웹 배포 [x] APK dist [x] 대시보드 [x] ntfy

## 진행 메모 (컨텍스트 복구용)
- 환경: Mac, Flutter 3.44.1, AVD cowboy, iPhone 17 시뮬, firebase CLI 로그인됨(계정에 cowboy 3프로젝트 전부 보임), gh 푸시 가능.
- 중앙 stats DB 규칙 배포 완료(딴 작업과 무관). 대시보드 status.json 체계 가동(작업 끝나면 갱신+푸시).
- 디자인 기존: theme.dart 웨스턴 사막톤, Black Han Sans/Rye 폰트, Twemoji 내장(emo.dart), 사운드 합성 wav 4종(assets/sounds: shot/click/reload/win 추정 — 확인 필요).
