# 카우보이 파티 — 세션 이어가기 (HANDOFF)

> 새 세션에서 이 파일을 먼저 읽고 이어서 진행. 모든 작업물은 디스크에 있고 main에 커밋됨.
> ⚠️ 아래 좌표 일부는 구 Windows 경로(C:\dev\…) — 현재는 Mac `/Users/doonghwi/Documents/dailyapp/`.

## 2026-07-29(16차) 🎉 구글 플레이 정식 출시 확인 + 웹 배포
- **Play 스토어 공개 확인**(공개 페이지 200, "카우보이") — 1.0.0(빌드 31), 전 국가. 첫 프로덕션 심사 통과.
- 예정대로 **웹 재배포**(deploy_web.sh, 최신 main=빌드 32 상당 코드, 스모크 통과) — 한 달 만의 웹 갱신이라 logicV 게이트·신기능 전부 반영됨.
- 남은 것: **애플 재제출만** — TestFlight 32에서 애플 로그인 에러 전문 확인 → ASC 회신+apple.mp4 첨부 → 빌드 32로 재제출(빌드 선택·제출은 세션이 API로 대행 가능).

## 2026-07-27(15차) 온보딩 개편(로그인→닉네임 순서)·튜토리얼 문구 + 애플 로그인 진단 + 빌드 32
- **온보딩 v2(사용자)**: 이름 입력 칸 제거 — 게스트=랜덤 닉네임 자동(`Meta.assignGuestNickname`, nicknameSet false 유지로 첫 직접 설정 무료), 구글/애플=로그인 후 닉네임 팝업(클라우드 소유 닉네임이면 자동 복원). 에뮬 QA: 게스트 시작 즉시 튜토리얼 팝업 확인.
- **튜토리얼 문구(사용자)**: 권유 팝업 '특훈'→'튜토리얼', '게임 방법 글로 보기' 버튼 제거, 코치 턴1 대사 "저 녀석, 방아쇠에…"(상대 행동 아는 듯) → "이번엔 \"방어\"를 눌러보자…". tutorial_flow_test 단언 동기화.
- **애플 로그인 credential 오류 진단**: ①빌드 31 ipa entitlements 정상(applesignin 포함) ②번들 ID 일치 ③**Firebase Apple 공급자 켜져 있음**(signInWithIdp 프로브가 공급자 통과 후 토큰 파싱 단계 도달 — createAuthUri의 'Code flow not enabled'는 웹 플로우 얘기) → 서버/서명 아님. 남은 후보: 기기 Apple ID 상태(아이패드 iCloud 로그인 필요) 또는 토큰/nonce 이슈. **빌드 32는 에러 상세(code·message)를 그대로 표시** — 한 번 재시도하면 원인 확정 가능. (참고: 빌드 30의 "애플 되네"는 구 코드가 실패해도 다이얼로그를 닫아 성공처럼 보였던 것일 수 있음.)
- **빌드 32 ASC 업로드**. ⚠️ upload_appstore.sh 함정 추가 수정: **flutter build ipa는 export 실패해도 exit 0** → 폴백 트리거를 종료코드가 아닌 ipa 신선도로 변경(스테일 가드가 오업로드 1회 방어함). 안드로이드는 31이 프로덕션 심사 중이라 32 미업로드(심사 리셋 방지) — 공개 후 32+로 동기화.
- 테스트 264·analyze 0. 애플 재제출은 **빌드 32**로(영상은 구글 로그인+삭제 촬영분 그대로 유효).

## 2026-07-27(14차) 🚀 구글 프로덕션 1.0.0(31) 검토 제출 완료
- 사용자가 콘솔에서 전체 국가 선택 → Claude가 제출. ⚠️ 함정: fastlane supply는 `--skip_upload_aab`일 때 `--release_status completed`를 트랙에 반영하지 않음(성공 로그만 찍힘) → **Android Publisher REST로 직접** edits.tracks.update(status=completed)+commit(200 확인). 출시 탭에서 production=completed(31) 검증.
- 구글 검토(수 시간~며칠) 통과 시 자동 공개. 공개 확인되면 웹(deploy_web.sh)도 같은 커밋으로 배포해 버전 맞출 것. 애플은 빌드 31 녹화·회신·재제출 대기.

## 2026-07-27(13차) 사용자 제보 5건 수정 → 빌드 31 양대 업로드 (+릴리스 파이프라인 자가치유)
- **①iOS 구글 로그인 즉사**: GoogleService-Info.plist가 Xcode 번들에 없어(Firebase는 Dart 옵션 초기화라 그 외 기능은 정상) google_sign_in이 clientId를 못 찾던 것 → `AuthService._googleSignIn()`에 **iOS clientId 명시**(URL 스킴은 이미 정상). 재인증 경로도 동일 헬퍼로 통일.
- **②iOS 앱 이름**: CFBundleDisplayName 'Cowboy Party' → **카우보이**(안드로이드는 이미 카우보이).
- **③닉네임 필수화**: 온보딩 빈 닉네임 통과 금지(스낵바 안내) + PopScope로 뒤로가기 차단.
- **④로그인 후 닉네임**: 온보딩 로그인 버튼을 **로그인 먼저** 순서로 변경 → 성공 시 클라우드 표시 이름이 **내 소유 닉네임이면 자동 복원**(`ownsNickname` 신설, mergeFromCloud가 cloudName 노출) → 그래도 없으면 **강제 닉네임 다이얼로그**(_forceNicknameDialog, 닫기 불가).
- **⑤특훈 권유**: "닉네임 미설정이면 다음 실행으로 미룸"이 튜토리얼 실종처럼 보임 → play_tab이 Meta 리스너로 **닉네임 설정 직후 같은 세션에서 권유**. 에뮬 QA로 온보딩→특훈 팝업 즉시 표시 확인.
- **테스트 함정**: daily_missions_test가 월요일(새 패스 시즌)에 터짐 — 지급 등호 단언을 gte로 완화(LESSONS 기록). 테스트 264·analyze 0.
- **빌드 31 업로드**: ASC(아이패드 녹화는 31로!) + Play 프로덕션 draft 교체. Play 제출 시도는 "targeting no countries"로 거절 — **국가 선택(콘솔 1회)만 되면 API로 제출 가능**. ⚠️ iOS 업로드 중 2건 자가치유 패치: Xcode 계정 세션 만료 시 'No Accounts' export 실패 → **upload_appstore.sh에 ASC API 키 클라우드 서명 export 폴백 + 스테일 ipa 업로드 가드**(옛 30 ipa가 올라가 중복 에러났던 사고).
- 참고: 이번 수정분 공지(announcements)는 미포함(빌드 재생성 회피) — 다음 업데이트에 합류.

## 2026-07-27(12차) 🤖 구글 프로덕션 준비 — 빌드 30 draft 업로드 (+아이패드 녹화 OK 답변)
- **프로덕션 액세스 승인 확인**: 사용자 이메일 통보 + Play API 프로덕션 트랙 쓰기 통과로 이중 확인.
- **빌드 30 AAB**(iOS 빌드 30과 같은 커밋 — 계정 삭제 포함) 릴리스 빌드·업로드 키 서명 검증 후 **프로덕션 트랙 초안(draft) 업로드** + 출시 노트(`fastlane/metadata/android/ko-KR/changelogs/30.txt`). draft라 검토·공개 미발동.
- **남은 사용자 콘솔 클릭**: ①프로덕션→국가/지역 추가(1회) ②게시 개요→관리형 게시 ON(애플 승인과 동시 공개용) ③프로덕션 릴리스 "검토를 위해 제출" ④양쪽 승인 후 "변경사항 게시" 클릭(=구글 공개 시점). 동시 배포 정책은 이 관리형 게시로 유지.
- **TestFlight 내부 그룹 '팀 테스트' 생성 + 계정 소유자(ehdgnlans@naver.com) 초대**(ASC API, hasAccessToAllBuilds) — 초대 코드 화면은 그룹/초대가 없어서였음. 빌드 30은 VALID+암호화 선언 완료라 즉시 설치 가능.
- 사용자 질의: 플레이 먼저 공개 가능? → 가능(동시 공개는 선택). 프로덕션 액세스 승인과 별개로 **첫 프로덕션 릴리스는 구글 검토 별도 필요**. 관리형 게시는 동시 공개 원할 때만.
- 참고: 앱스토어 녹화는 **아이패드도 가능**(물리 기기면 됨). 안드로이드에도 계정 삭제 동일 포함(같은 Flutter 코드 — 에뮬 E2E가 안드로이드에서 수행된 것). ⚠️ Play도 계정 삭제 관련 **웹 삭제 링크**를 데이터 보안 양식에서 요구할 수 있음 — 콘솔이 물으면 cowboy.gg에 삭제 안내 페이지 즉시 제작 가능.

## 2026-07-23(11차) 🍎 앱스토어 1.0 반려(5.1.1(v)) → 계정 삭제 구현 + 빌드 30 업로드
- **반려 확인**: 출시 탭 스크립트 갱신 → 1.0(빌드 29) REJECTED(7/17 심사). 사유 = **계정 생성만 있고 계정 삭제 없음**(Guideline 5.1.1(v)). 구글 프로덕션 승격은 아직(액세스 신청 결과는 이메일 — API로 못 봄).
- **계정 삭제 구현**(`lib/meta/account_deletion.dart` + 설정 시트 메뉴, cloudUid 있을 때만 노출): 확인 다이얼로그(삭제 항목 명시) → ①친구 그래프 상호 삭제 ②보낸 요청 회수(로컬 기록 기반) ③friendReqs/presence/invites/users 노드 삭제 ④닉네임 매핑 트랜잭션 해제 ⑤시즌 랭킹은 규칙상 삭제 불가(pts 증가만 허용) → **이름만 '떠난 카우보이'로 익명화**(이번 주+지난 주) ⑥Auth 계정 삭제, requires-recent-login이면 `AuthService.reauthenticate()`(구글/애플 재인증) 후 재시도 ⑦로컬 닉네임 초기화(`Meta.clearNicknameLocal`, 기기 게임 데이터는 유지). 전부 베스트에포트 — 노드 일부 실패해도 계정 삭제는 진행. **RTDB 규칙 변경 없음**(기존 규칙이 상호 삭제·본인 삭제 허용).
- **검증**: 테스트 264(다이얼로그 위젯 2 신규)·analyze 0·**에뮬 E2E로 실계정 삭제**(게스트 doonghw2 → nicknames/presence 소거를 공개 REST로 확인, 실사용자 계정 무사). 스크린샷 3장 자료실.
- **빌드 30**(pubspec+kBuildNo) → `tools/upload_appstore.sh`로 ASC 업로드. **남은 사용자 액션**: TestFlight 빌드 30 설치 → 아이폰 화면 녹화(로그인→계정 삭제 완주) → 반려 메시지 회신(영어 회신문 준비됨)+영상 첨부 → 빌드 30으로 재제출. 가이드 `growth/APP_REVIEW_REPLY_0723.md`(자료실 노출).
- 배포 동결 유지: 안드로이드·웹 배포 없음. iOS 업로드는 심사 재제출용(스토어 공개 아님).

## 2026-07-18(10차) 사용자 제보 2건 — 빠른 시작 쏠림(잔존 건) + 친구 탭 '보낸 요청' (커밋만, 배포 동결)
- **①빠른 시작 랭커 카드 왼쪽 쏠림(v26 ① 잔존 건)**: 원인 = **소인원 방(n<5)의 좌석 슬롯 폭 110px vs SeatCard(mini) 92px** 불일치. 일반 카드는 tight 제약이 이겨 110으로 늘어나 정상인데, **휘장 카드는 TierFramed의 Stack이 제약을 loose로 풀어** 92px 카드가 topStart(왼쪽)로 붙음 → 랭커만 ~9px 쏠림. 6인방(슬롯 92px)은 폭 일치라 v26 수정 후 정상 — 그래서 "빠른 시작에서만 여전히"였음. 수정 = `tier_frame.dart` Stack에 `fit: StackFit.passthrough` 1줄. 진단법: 에뮬 실매칭(신규 계정은 휘장 없어 재현 안 됨) + 위젯 프로브로 n=4+rankTier 지오메트리 측정. 회귀 `test/profile_shift_probe_test.dart`(캡처 도구 겸용, PROFILE_PROBE_DIR).
- **②친구 탭 '보낸 요청(대기중)'**: 서버 규칙상 friendReqs는 받는 쪽만 읽을 수 있어 **보낸 쪽은 로컬 기록**(SharedPreferences `sent_reqs_v1`, FriendService.sentRequests/cancelRequest/pruneSentByFriends). 보내면 즉시 '대기중' 카드, 상대 수락으로 친구가 되면 자동 정리, **취소** 버튼은 상대의 받은 요청함에서도 제거(쓰기 규칙이 보낸 이 허용 — 규칙 변경·배포 불필요). 실패 시(닉네임 없음 등) 기록 안 남음. 테스트 `test/friends_sent_pending_test.dart`(FRIENDS_CAPTURE_DIR 캡처 겸용).
- 검증: 테스트 262·analyze 0·에뮬 QA(빠른 시작 실매칭 4인방 재현, 친구 탭·실패 케이스). 보고서+전/후 스크린샷 자료실 '변경 보고서'(growth/reports/bugfix_0718). 공지 1건 추가. **배포 동결 유지 — 커밋만**, 애플 승인 후 동시 배포에 포함.
- 선택 탭: 장전음 3차(sfx_reload4)는 여전히 사용자 답변 대기 — 처리할 새 답변 없음.

## 2026-07-17(9차) 🍎 iOS 앱스토어 첫 제출(심사 대기) + 릴리스 전자동화 + 크로스플레이 게이트
- **iOS 1.0 심사 제출 완료**(새벽 4시경, 빌드 29). 1회성 설정 전 과정과 함정은 `growth/IOS_RELEASE_AUTOMATION.md`에 정리. 핵심 함정: ①기기 0대면 개발 서명 불가 → **맥을 Designed-for-iPad 빌드로 기기 등록**해 해결 ②iOS AppIcon이 플러터 기본→구식 모자 2연속 오탑재 → 진실 소스는 `store/icon_512.png`(카우보이 얼굴), LESSONS 기록 ③6.5" 스크린샷 규격(1284×2778) 별도 필요.
- **전자동 파이프라인**: ASC API 키(D3TN3JP93R, `~/.appstoreconnect/`, 드라이브 백업) 기반 — `tools/upload_appstore.sh`(빌드+업로드, 검증 완료: 빌드 29를 무클릭 업로드) + `tools/release_ios.sh`(pilot 처리 대기→deliver 새소식·빌드 선택·심사 제출, **첫 실전은 1.0.1**) + **🚦 출시 탭에 App Store 상태 통합**(심사 대기/판매 중/반려 실시간 — cowboy_release_check.py, 대시보드 venv에 pyjwt·cryptography 추가).
- **크로스플레이 데싱크(사용자 제보 후속)**: 과거 웹↔앱 불일치 원인 = 버전 게이트 이전 혼방 + 웹 백그라운드 탭 하트비트 스로틀. iOS↔Android는 같은 logicV(2)+게이트로 안전. 남아 있던 구멍(봇 방 logicV 미기록 → 구버전 혼입) 봉쇄: **러너가 방에 logicV 도장 + 매치메이커가 버전 다른 방 회피**(config kAppLogicVersion=2 — 앱과 동기 유지 필수).
- 메모리: automation-first(반복 작업은 자동화 먼저 제안 — 질책 반영).
- **⚠️ 배포 동결 정책(사용자, 2026-07-17)**: 수정사항은 커밋·검증까지만 하고 배포 홀드 → **애플 1.0 승인 후 양대 스토어+웹 동시 배포**(빌드 번호 동일 유지). 이후에도 동시 배포가 기본, 긴급 핫픽스만 예외(사용자 확인). 메모리 cowboy-release-batching.

## 2026-07-16(8차) 버그 리포트 12+2건 → v26 (⚠️ kLogicVersion 2)
- **⑦저주 규칙 v2(핵심)**: PartyState `curseFuse/curseCaster` → **`curseMatrix[대상][시전자]`**(시전자별 독립 스택, 각 kCurseFuse턴). 같은 시전자 재시전 무효는 계승, 다른 시전자는 같은 대상에 추가 가능. 레거시 생성자 파라미터+`curseFuse/curseCaster` 게터(가장 임박 뷰)로 구 코드·테스트 호환. **kLogicVersion 1→2**, `bot_runner/lib/game/party_logic.dart` 동일 파일 복사(md5 일치 확인 후) — 러너는 logicV 미기록 유지(과도기: 봇 방에서 v25·v26 혼재 가능, 2부두 동시 저주 시에만 이론상 어긋남). 표시: SeatView/TableSeat/SeatCard `curses` 목록 + `curseColorOf(시전좌석)` 팔레트 6색, 부두 아이콘도 자기 색. 회귀 test/curse_stack_v2_test.dart 5건.
- **①랭커 카드 치우침/축소**: 원인 = 6인방 92px 카드에서 Lv+방장 칩 Row가 14px 넘침(RenderFlex) → 내용이 왼쪽 쏠림. FittedBox(scaleDown)로 해결. 위젯 프로브로 재현·검증.
- **⑤결과 화면 유지**: `_overHold`(over 뷰 캐시) — 남들이 먼저 리셋(대기실行)하거나 방이 삭제돼도 내 결과 화면 유지, '대기실로 돌아가기'(_backToLobby)가 상태별 분기(리셋됨→화면만 전환/방 삭제→나가기).
- **③BGM**: 원인 = Bgm.sting()의 일회용 AudioPlayer가 라이프사이클 미추적 → _stings 목록으로 추적, paused에서 정지.
- 기타: ②재촉 TopToast 통일(방장 '재촉을 보냈어요'/비방장 '방장의 재촉!' — 한 줄) ⑥peekSelecting 눌림 표시 ⑧준비 중 캐릭터 변경 잠금+안내 ⑨준비 800ms 디바운스 ⑪초대 시트 inRoomUids='같이 있음' ⑫친선전 방 friendly 플래그→friends/<me>/<f>/{fw,fl} 누적(비친구 가드) ⑬presence에 lv 추가+프로필 시트 정보 3종 ⑭LevelUpOverlay(위젯 신설, 온·오프라인 종료 훅) ⑩cowboy.gg 정상(490게임 누적 확인).

## 2026-07-16(7차) 버그 4건 수정 → v25
- **①나가기 UX**: 뒤로가기/앱바 back → `_confirmLeave()` 확인창(대기방 '방을 나가시겠어요?' / 게임 중 '게임을 나가시겠어요?+탈락 안내', 게임 종료 후엔 즉시). `_leaveAndPop`에 `_leaving` 재진입 가드 — **leave await 지연 중 '방에서 나왔어요' 화면의 나가기를 또 누르면 이중 pop → 검은 화면**이던 버그. '나왔어요' 안내 화면 자체를 제거(좌석 소실 시 조용히 자동 복귀).
- **②휘장 인게임 유실(핵심)**: 앱 코드는 전 경로 정상(위젯 프로브로 검증) — 진범은 **봇 러너 hostStartGame의 players 압축이 lv·rank 필드 누락**. 봇이 방장인 방에서 시작 순간 서버 데이터가 지워져 대기방 복귀 후에도 소실. 러너 압축에 lv·rank 보존 추가 + 봇 claim 3곳에 lv(이름 해시 2..30) 부여, launchctl 재시작. 인계: `_shared/notes/botrunner.md`, 교훈: LESSONS(다중 작성자 스키마 정합).
- **③④ 표시 정리**: SeatCard — level 0은 'Lv.?' 대신 표시 생략, 대기방 빈자리는 level 0을 넘겨 총알/레벨 줄 미표시(주의: 대기방은 TableSeat.joined가 전 좌석 true라 `!joined` 분기로는 못 잡음).
- 에뮬 QA(debug): 확인창 2종·빈자리·봇 Lv(23/19/9/2) 스크린샷 검증, 자료실 게시. 테스트 253·analyze 0(앱·러너). 캐릭터 '한눈에 보기' 3안 시안 → 선택 탭 8번(제보 3번은 시안 검사 규칙 적용).

## 2026-07-16(6차) 에셋 AI 툴 조사 + 켄니 실물 비교 + 에셋 전수 목록 + 출시 절차 안내
- **켄니 파티클 팩(CC0) 확보**: `growth/assets_src/kenney_particles/` 80장(화염·스파크·별·연기·베기 등, 흰색+알파=착색 자유). GitHub 미러(Calinou/kenney-particle-pack)에서 — kenney.nl 직링크는 해시 변경으로 깨짐. **"지금 코드 vs 켄니 합성" 비교 목업**과 텍스처 12장 샘플을 자료실+선택 탭 7번에 게시(`growth/reports/asset_examples/`) — 이펙트류는 AI 툴 없이도 켄니+Claude 편집으로 격상 가능함을 시연.
- **에셋 전수 목록** `growth/ASSET_INVENTORY.md`(사용자 요청): 사용 중 에셋(이미지=캐릭터 16장이 사실상 전부, 나머진 코드 드로잉) + 필요 에셋 우선순위·수량·조달 매핑(★1 이펙트 텍스처=켄니 즉시 가능).
- 선택 탭 7번을 "켄니만(무료)/켄니+Scenario 체험/켄니+Recraft/켄니+Leonardo" 구도로 재편(이펙트는 어차피 켄니).
- **(이어서) 조달 문서 v2**: 켄니 팩 28종 실존 검증(HTTP) 카탈로그 + AI 툴별 기능 매트릭스로 확장. 전수 목록에 보강 7건(카드 그림=Playing Cards, WANTED 소품=Cartography, 이모트=Emotes Pack, 타격음=Impact/Casino Audio 등). ⚠️ kenney.nl은 JS 렌더라 크롤링 불가 — 슬러그 직접 HTTP 검증 방식 사용.
- **Play 프로덕션 신청 ✅접수됨(7/16 13:54, 검토 ~7일 — 이메일 통보)**. Apple Developer 등록은 pending. **Sign in with Apple 확인 결과: 클라이언트는 완비**(sign_in_with_apple 패키지, auth_service.signInWithApple, shell.dart 버튼 2곳, Runner.entitlements 사전 생성, 실패 시 '준비 중' 안내 폴백) — 남은 건 계정 승인 후 설정만: Xcode capability + Firebase Apple 공급자 토글 + (웹은 Services ID 키) + 검증.
- (기록) 신청 버튼은 콘솔 UI 전용(API 미제공, Claude 자동 불가)
- **에셋 툴 조사**(명중 이펙트 퀄리티 지적 후속): `growth/ASSET_TOOL_RESEARCH.md` — Scenario(게임 특화·스타일 학습·무료 체험)/Leonardo(투명 PNG $9)/Recraft(벡터 $10)/VFX 특화 무료툴 비교, 이펙트는 "AI 텍스처+기존 파티클" 하이브리드 추천. 자료실 게시 + **선택 탭 라운드4 7번 문항**(A Scenario 체험 추천). 키 받으면 `~/.zshrc`에 저장 후 생성→후처리→시안 검사 파이프라인은 Claude 담당.
- **출시 안내**: Play=기간 요건 충족, 관건은 테스터 12명 옵트인 수(콘솔 홈 카드 확인). Apple=자동 아님·사람 심사 1~3일, 구글 로그인 있어 **Sign in with Apple 필수 구현** 필요(등록 후 Claude가). todo ① 노트에 상세.
- 자료실 낡은 '사운드 보드 열기' 링크 제거(선택 탭으로 대체됨).

## 2026-07-15(5차) 라운드3 확정 + 라운드4 시안 게시 + SFX 재상정 + 스토어 출시 준비
- **라운드3 확정**: 치장 1차=명중 이펙트+처치 연출(A) / 재화=황금 별 프레스티지형(A, 뽑기상자는 추후 과제로 과금 기틀) / 페이스=주 5개(B). 결투장 스킨은 2차에 **셀레브레이션과 번들 판매**(노트).
- **⚠️ 새 고정 규칙(사용자)**: 디자인 관련 작업은 지시 없어도 **구현 전에 시안 여러 개를 선택 탭으로 검사**받는다(메모리 cowboy-confirm-and-report에도 기록).
- **라운드4 게시(6문항)**: 치장 시안 3장(명중 4안·처치 3안·상점 UI 2안 — 도구 `test/round4_cosmetics_capture_test.dart`, R4_CAPTURE_DIR) + SFX 재상정 3건. SFX 이슈 처리: 쇼다운 '안 들려' 원인=드론 -20dB·심장박동 저음 단발 → 리마스터(`growth/reports/sfx_round3/`), 장전 신작B 수정본(띵 제거·틱 4→2·atempo 0.5), 켄니 CC0 철컥 4종(ogg→wav 변환 — **사파리는 ogg 재생 불가**), 현행 사운드 동봉(장전=reload.wav, **쇼다운 예열·입장은 현행 전용 SFX 없음**).
- **스토어 출시 할 일 추가**: 플레이 프로덕션 액세스 신청(요건: 테스터 12명×14일 연속, 7/1 알파 시작 — 콘솔 홈 카드 확인) + iOS(Apple Developer 등록부터). todo ①에 추가.

## 2026-07-15(4차) 라운드2 처리 → 치장 초안 v2(TFT식) + 라운드3 게시 + 대시보드 탭 확장 2건
- **라운드2 답변 처리**: 휘장=A(현재 반영본 유지, 종결). 스킨 3문항은 노트로 방향 전환 — "캐릭터별 의상 말고 **모든 캐릭터 공용 장착형**(TFT 참고: 맵·타격·처치 연출)" + "**다른 재화 종류** 신설" → `growth/SKIN_UPDATE_DRAFT.md` **v2로 전면 개정**(카테고리 6종 매핑: 결투장/명중/처치/셀레브레이션+이모트·프레임 예약, 재화 3안: 황금 별/은화/보안관 배지, 가격 축 6~20). 1~4번 카테고리는 전부 코드 페인팅이라 이미지 생성 대기 없음·표시 전용(로직버전 그대로).
- **라운드3 6문항 게시**(decisions.json — r1·r2는 decided 아카이브): 치장 1차 카테고리 조합/새 재화 컨셉/획득 페이스 + **SFX 2차 3건**(장전·쇼다운 예열·입장 — 후보 wav를 `growth/reports/sfx_round2/`로 복사, 탭에서 바로 재생). 컨셉 시안 `growth/reports/design_round3/cosmetic_categories.png`(도구: test/round3_cosmetics_capture_test.dart, R3_CAPTURE_DIR).
- **사용자 지시(고정 규칙)**: 앞으로 **사용자 선택이 필요한 모든 것(사운드 포함)은 🗳️ 선택 탭으로** 올린다(사운드 보드 html 대체). 선택 탭에 문항 `audios` 필드 지원 추가(super_dashboard.py).
- **🚦 출시 탭 신설**(사용자 지시): `~/bintage/1_sourcing/0_monitor/cowboy_release_check.py`가 Play Developer API(서비스계정=업로드 키 재사용)로 트랙별 versionCode·상태 조회 → repo pubspec 기대 버전과 비교(✅/⚠️/🛑 헤드라인), 리뷰 5건, 크래시율(Reporting API 미개통이라 안내만 — 공개 후 API만 켜면 자동 표시). 데이터 `~/bintage/data/0_monitor/cowboy_release_status.json`, 대시보드 재생성 시 15분 캐시로 자동 갱신. **v24 alpha completed 확인됨.**
- venv 메모: 대시보드 venv(`1a_crawl/.venv`)에 google-auth 설치함(uv pip).
- **🤖 클로드 탭 신설(사용자 지시, cowboy·bintage 양쪽)**: 이 프로젝트를 위한 클로드가 지금 돌아가는지+무슨 내용인지+세션 목록. `serve.py /api/claude_sessions`가 `~/.claude/projects/*/*.jsonl`을 라이브 스캔(mtime=활동, cwd+첫 요청 키워드로 프로젝트 분류, 워크트리 이동은 꼬리 cwd 반영), 탭은 30초 자동 갱신. 🟢 3분 내 활동 / 🟡 30분 내 / ⚪ 그 외(48시간 창).

## 2026-07-15(3차) 홍보 에셋(가로 16:9·30초 영상) + v24 다듬기
- **스토어 에셋 큐 잔여분 처리**: 가로 16:9 스크린샷 3장(`store/screenshots/wide/`, 합성 스크립트 `tool/make_wide_screenshots.py` — 소스 폰캡처는 `wide_src/`) + **30초 홍보 영상** 세로/가로(`promo/video/promo_30s_*.mp4` — v23·24 실플레이 5클립을 ffmpeg trim+concat, menu.mp3 페이드). 자료실 '홍보 준비물'에 게시. 아이콘 2안·피처그래픽 일러스트판만 사용자 이미지 생성 대기.
- **v24 다듬기 3건**: ①게스트가 온라인 행동 전이면 친구 탭이 '연결 중'에 머묾 → FriendsTab 진입 시 tryAnonymous 보장 ②온보딩 '5000골드'→'코인' ③첫 실행에 온보딩·특훈 팝업 겹침 → 닉네임 미설정이면 특훈 권유를 다음 실행으로.
- **⚠️ 에뮬 QA 함정(LESSONS에도 기록)**: 업로드 키 서명 release APK 사이드로드는 Firebase API 키 안드로이드 제한(SHA 미등록)으로 **익명 인증이 차단** → 방 만들기 전부 실패. 규칙/logicV 문제 아님(웹 키 REST로 검증). 에뮬은 debug 빌드로 QA할 것.

## 2026-07-15(2차) 디자인 라운드1 전면 반영 — v23
- **선택 탭 답변 반영 완료**(cowboy_picks.json → 구현): 방장=금색 카드+칩(seat_card) / 휘장=**TierFramed**(widgets/tier_frame.dart — 카드 틀 밖 모서리 장식·상단 크레스트·숨쉬는 발광, LoL 시즌 테두리풍) / 스킬=초상화 링 게이지(_AbilityRing, abilityUses=남은횟수 문자열 파싱, 발동 시 금빛 플래시 — '치료!' 텍스트·좌하단 배지 제거) / 상점=캐러셀(characters_tab 재작성) / 문구=CharDef에 **quote 필드 신설**(15명 대사) + 대사 칸/능력 칸 분리(상점·페이저) / 튜토리얼=**보안관의 특훈**(OfflineGameScreen(tutorial:true) — 3턴 시나리오 봇, ActionBar allowedKinds 잠금, 코치 말풍선, 완주 시 Meta.grantGuidedTutorialReward 300G, 진입=첫실행 팝업·설정).
- decisions.json 전 문항 status:decided+answer 아카이브. 스킨 업데이트 초안 growth/SKIN_UPDATE_DRAFT.md(사용자 검토 대기).
- 테스트 246(특훈 플로우 자동검증 tutorial_flow_test 포함). 캡처 도구: test/round1_report_capture_test.dart(ROUND1_CAPTURE_DIR).
- ⚠️ 워크트리 릴리스 함정: android/key.properties **없이도 빌드는 성공**(디버그 서명 폴백) — 업로드 전 keytool로 서명 확인할 것. google-services.json·play-service-account.json도 메인에서 복사 필요.

## 2026-07-15 피드백 13건 라운드 — 🗳️ 선택 탭 + v22 직접수정 7건
- **대시보드 🗳️ 선택 탭 신설**(사용자 지시: 자료실 말고 전용 탭): `growth/decisions.json`(6문항)을 `super_dashboard.py tab_cowboy_pick`이 렌더, 클릭 시 `serve.py /api/cowboy_pick`(GET/POST)이 `~/bintage/data/0_monitor/cowboy_picks.json`에 저장. **다음 세션은 이 파일을 읽고 방장표시/휘장/스킬표시/상점/문구스타일/튜토리얼 방식을 구현할 것.** 결정 끝난 문항은 decisions.json에서 status:decided로 아카이브.
- **선택지 시안 4장**: `growth/reports/design_round1/`(host/emblem/seat_skill/shop_options.png). 렌더 도구=`test/design_capture_test.dart`(DESIGN_CAPTURE_DIR). ⚠️ 테스트 캡처 노하우: Pretendard **OTF는 FontLoader에 안 올라감** → GothicA1 TTF를 'Pretendard' 이름으로 로드 / **Material 조상 필수**(없으면 테마 폰트 미적용=두부) / MaterialIcons는 `$FLUTTER_ROOT/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf` FontLoader 로드 / 바텀시트 캡처는 RepaintBoundary를 MaterialApp **바깥**에.
- **v22 직접 수정**: ①친구 하단 탭(`friends_tab.dart`, 셸 5탭 상점·보상·플레이(가운데)·친구·랭킹, 1:1 친선전=비공개 2인방+invite, 최근 함께 플레이=`FriendService.noteRecentPlayers` 로컬 기록) ②정원=capacity-닫힌자리 ⑤**버전 게이트**: `kLogicVersion`(online_service.dart) 방에 기록+불일치 입장 차단 — **게임 규칙 바꾸면 반드시 +1**. 봇 러너는 아직 미기록(과도기 통과) ⑥자랑하기 제거 ⑦대기실 버튼 filled(둥근 직사각형 14) ⑧캐릭터 변경=`char_pager_sheet.dart` 일러스트 페이저 ⑪서브라벨 제거+문구 22건 정리(골드→코인, 호스트→방장, 자힐→치료).
- **디자인 규칙(사용자)**: 로비 컴포넌트는 테두리만 X, **배경색 채운 카드/버튼**으로.
- 테스트 240 통과. 남은 것: 선택 탭 결과 반영, 캐릭터 문구 15명 적용(스타일 선택 후), 튜토리얼 제작, SFX 2차.

## 2026-07-12 승인 확정 + bintage 통합 대시보드 cowboy 탭 + 아트 외주 파이프라인
- **사용자 승인**: 타격감 전체 / 리텐션 A1·A2·A4·A5+B1~B5(**광고 요소 전면 제외** — A3 탈락, 스트릭 복구는 주1회 무료) / 홍보 플랜. 다음 구현: 타격감 1단계 → 리텐션 A.
- **GEMINI_API_KEY**: 수령·검증(200 OK)·`~/.zshrc` 저장. 유료 툴(Recraft·ElevenLabs)은 보류.
- **bintage 슈퍼 대시보드에 프로젝트 선택기**(🧵bintage|🤠cowboy) + cowboy 할일 패널 추가(`~/bintage/1_sourcing/0_monitor/super_dashboard.py`, 데이터=이 repo `growth/todo.json`). ⚠️ bintage repo는 병렬 세션 미커밋 작업물과 섞여 있어 **커밋은 bintage 세션에 위임**(수정분 작업트리에 남김, HTML 재생성·서빙 반영 완료).
- **⚠️ 카우보이 작업 종료 루틴 추가**: `growth/todo.json` 갱신 후 `cd ~/bintage/1_sourcing/0_monitor && /opt/homebrew/bin/python3.12 super_dashboard.py` 1줄 실행(대시보드는 정적 파일이라 재생성해야 반영. 시스템 python3=3.9는 문법 에러남, 반드시 3.12).
- **growth/ART_PIPELINE.md 신설**: "GPT→Godot 아트 외주" 질문 답 — AI API 외주 5단계 파이프라인(스타일가이드→생성(Gemini/GPT/Recraft)→rembg 후처리→배치→에뮬 검증). OpenAI 키는 현재 불필요.

## 2026-07-08 성장 계획 수립 — growth/ 폴더 신설 (리서치 5건 완료, 사용자 선택 대기)
- **growth/**: 타격감(JUICE_PLAN)·리텐션(RETENTION_PLAN)·툴연결(TOOLS_SETUP)·업로드자동화(PLAY_UPLOAD_SETUP)·홍보(PROMO_PLAN) — 하스스톤/Brawl Stars/구스구스덕 등 리서치 기반. **README.md에 사용자 액션 요약.**
- **tools/upload_play.sh**: fastlane supply 래퍼(트랙 기본 alpha). 서비스 계정 JSON(사용자 1회 설정, 가이드 참고)만 오면 즉시 가동 — **밀린 v13(광고ID 제거분) 업로드가 첫 실행 대상**.
- .gitignore에 `**/play-service-account.json` 추가.
- **사용자 대기 항목**: ① Play 서비스계정 설정(15분) ② GEMINI_API_KEY 발급(무료·5분) ③ RETENTION_PLAN 번호 선택(추천 A1~A5) ④ 유료 툴(Recraft·ElevenLabs) 여부.

## 2026-06-30 사운드 개선 — 효과음+BGM+게임흐름 **✅ 웹 라이브 · 안드로이드 v6 빌드(Play 업로드 대기)**
> v6 신규(2026-06-30 후속): ① 메뉴BGM 끊김 수정(웹 `onPlayerComplete` 수동 루프 — audioplayers_web은 ReleaseMode.loop 미동작) + 탭 전환 시 `Bgm.ensure('menu')`. ② 백그라운드 재생 방지(`main.dart` 라이프사이클 옵저버 → `Bgm.onLifecycle`로 paused/hidden 정지·resumed 재개). ③ 컴퓨터전 자동진행 — `offline_game_screen` reveal '계속하기'·관전 '다음 턴 보기' 버튼 제거 → 타이머 자동(`_revealHold` 2.2s/`_spectateHold` 1.1s, 탭하면 즉시 스킵). 봇은 원래 자동. 공지 '🎮 컴퓨터 대결이 더 매끄러워졌어요' 추가. **승리음악은 보류(사용자가 나중에)**.
- **효과음 합성 강화**(`tool/make_sounds.py`): 총성에 협곡 에코(reverb), 팡파레/패배에 잔향+하모닉,
  임팩트(hit/trap/super)에 서브 베이스. 파일명·길이·코드 배선 그대로라 재배선 0. `assets/sounds/*.wav` 12종 재생성.
- **BGM 인프라 신규**(`lib/audio/sfx.dart`의 `Bgm`): 루프 재생 + 페이드아웃→인 전환 + 음소거 공유(`Sfx.setMuted`→`Bgm.applyMute`).
  메뉴=shell, 전투=게임화면 initState, 게임 dispose 시 'menu' 복귀. `main.dart`에 `Bgm.init()`. pubspec에 `assets/music/` 등록.
  **mp3 없으면 무음**(앱 안 깨짐) — 빌드/실행 정상.
- **BGM 실제 배치 완료**(Suno 대신 Pixabay 음원 채택 — Suno 무료티어는 상업 사용 불가): 사용자가 Pixabay에서 2곡 다운로드,
  ffmpeg로 **crossfade-fold 루프 가공**(꼬리 4초를 머리에 접어 무이음 루프) 후 `assets/music/`에 배치.
  - `menu.mp3` ← "Country Music Texas Cowboy Wild West Intro" by Maksym Malko (Pixabay 263183), 본체 [8–62s], 50초 루프.
  - `battle.mp3` ← "Sound of Desert" by Mohamed Hassan (Pixabay 335725), 본체 [1–84s] 끝 페이드 제거, 79초 루프.
  - 둘 다 **Pixabay Content License**(상업·앱 임베드 허용, 출처표기 불필요). 루프 이음새 검증: 시작/끝 음량 1dB 이내·클릭 없음.
- **가이드**: `SOUND_GUIDE.md` — Suno 프롬프트·ffmpeg 루프 가공·라이선스 체크(참고용, 실제는 Pixabay 채택).
- **CREDITS.md**: menu/battle.mp3 출처·라이선스 2행 추가 완료.
- **공지 추가 완료**: `announcements.dart` 최상단 '🎵 배경음악이 깔렸어요'(효과음·BGM·음소거 안내).
- **오디오 튜닝(사용자 확정)**: 볼륨 배경 수준으로 대폭 하향 **menu 0.03 / battle 0.024**(효과음 0.7~1.0 대비). 페이드인 **~2초 ease-in**. 우상단 **스피커 토글 버튼** 추가(설정 시트 '효과음' 스위치와 공유). 전투음악은 셋업화면부터 재생(사용자 요청으로 유지).
- **웹 자동재생 대응**: `main.dart`에서 `kIsWeb`일 때 첫 PointerDown에 `Bgm.kickStart()` → 메뉴 BGM 살림(모바일 무영향).
- **웹 배포 완료**(`deploy_web.sh` → gh-pages, https://doonghwi.github.io/cowboy-party/): 6/17 이후 밀려있던 2주치 업데이트 + 사운드 전부 라이브. 스모크 통과(rendered=true). ⚠️ 웹 배포는 **수동**(Actions 없음) — 코드 바꾸면 `bash deploy_web.sh` 다시 돌려야 함.
- **main 머지+푸시 완료**: origin/main HEAD에 새 아이콘+그래픽+효과음+BGM+공지+오디오튜닝 전부, **version 1.0.0+5**.
- **CREDITS.md**: menu/battle.mp3 출처·라이선스. **공지**: announcements.dart '🎵 배경음악이 깔렸어요'.
- **안드로이드 버전 이력**: v5 업로드됨(비공개테스트 Alpha). **v6 = v5 + 위 게임흐름/BGM 수정** — 빌드·검증 완료, Play 업로드 대기. (구 v4·v5는 후속이라 v6가 최신, v6 올릴 것.)
  - .aab 위치: `build/app/outputs/bundle/release/app-release.aab`(gitignore, 업로드키 서명·versionCode 6·음악 포함). 재빌드는 `flutter build appbundle --release`. worktree 빌드 시 `android/key.properties`+`android/app/google-services.json` 메인에서 복사 필요(시크릿/gitignore).
- **✅ 웹 라이브**: https://doonghwi.github.io/cowboy-party/ (gh-pages, v6 코드 반영본). 재배포는 `bash deploy_web.sh`(수동).
- **남은 항목(선택/후속)**:
  1. **Play Console에 v6 .aab 업로드**.
  2. (보류) **승리 음악** — 사용자가 나중에 Pixabay에서 받아 `assets/music/`에 넣으면 승리(over)화면 1회 재생으로 연동. 후보: "Standing In Light (Winner Fanfare)" by AlexGrohl 등 Pixabay victory/fanfare.
  3. `dashboard-site/status.json` 갱신, `LEGAL_CHECKLIST.md` BGM 항목 체크(CREDITS엔 기록됨).
  4. 오디오/자동진행 튜닝값: 볼륨 `lib/audio/sfx.dart`+화면별 `Bgm.play` volume, 자동진행 `offline_game_screen`의 `_revealHold`/`_spectateHold`.
- worktree `worktree-sound-work`는 main에 모두 머지·푸시됨. 정리 가능.

## 2026-06-15 스토어 출시 준비 (STORE_RELEASE_PREP.md 실행 완료)
세션이 **계정/결제/제출 없이 가능한 모든 것**을 준비함. 상세·남은 사용자 액션은 `STORE_RELEASE_PREP.md` 하단.
- **개인정보처리방침**: cowboy.gg repo `privacy.html`(한/영) 작성·푸시 → https://doonghwi.github.io/cowboy.gg/privacy.html
- **store/ 폴더 신규**: 문안(listing_ko/en), data_safety, ios_release, README, icon_512.png, feature_graphic.png(1024×500), screenshots/android 5장(현재 빌드 캡처).
- **Sign in with Apple 구현**(F1): `sign_in_with_apple`+`crypto` 추가, `auth_service.signInWithApple()`(nonce+Firebase apple.com), 온보딩·설정에 버튼(iOS/macOS/웹만 노출). 공지 1건 추가.
- **Android 출시 서명**(E): `build.gradle.kts` release signingConfig(key.properties 읽기, 없으면 디버그 폴백) + `key.properties.example` + .gitignore(key.properties/*.jks/*.keystore). `flutter build appbundle --release` 통과(app-release.aab 57.5MB).
- 검증: analyze 0 · 74 테스트 통과 · 에뮬에서 현재 빌드 설치·홈/상점/랭킹/보상/6인 게임플레이 스크린샷 확인.
- **남은 사용자 액션**: Play/Apple 계정 등록, 업로드 키스토어 생성, Firebase Apple 공급자 켜기, Xcode Apple capability, iOS 스크린샷, 최종 제출 — STORE_RELEASE_PREP.md "남은 사용자 액션" 참고.

## (이전) 한 줄 요약
앱은 **빌드·검증·배포 완료**되어 라이브로 동작 중. 사용자 피드백 **4건 수정도 2026-06-04 배포 완료(LIVE)**.

## 2026-06-04 (4차) 결투 승자 생존·멘트 2건 배포 완료
- **반응결투 승자 해골 버그**: 마지막 동시 탈락 후 결투에서 이겨도 승자까지 `alive=false`(해골)로 뜸 → `online_service.computeView`의 sdWinner 분기에서 `alive[sdWinner]=true; hit[sdWinner]=false`로 승자 생존 표시. (오프라인은 결투결과가 standalone 카드라 무관.)
- **전원 방어/장전 멘트**: `_turnBanner`가 아무도 안 쐈을 때 항상 "장전과 방어…" → moves·aliveBefore 받아 전원 같은 행동이면 "둘 다/모두 방어!" · "둘 다/모두 장전!", 섞이면 기존. 오프/온 양쪽 적용. 단위테스트 4건 추가(총 23개).
- 웹(48f969c)·APK·대시보드·ntfy 배포. **인게임 결투/멘트는 adb 캔버스탭 한계로 시각검증 못함 → 단위테스트로 커버. 다음 세션 온라인 2클라로 눈 확인 권장.**

## 2026-06-04 (3차) 미세조정 2건 배포 완료
- **중앙 배너 2줄 깨짐 복구**: 4인 가림 수정 때 넣은 `circular_table.dart`의 `maxWidth: w*0.52`가 2·3인에도 적용돼 줄바꿈됨 → `n == 4 ? 0.52 : 0.86`으로. (4인만 좌우 좌석이 정확히 중앙 높이라 좁혀야 함. 5·6인은 좌석이 ±0.5ry라 겹치지 않음.) 에뮬 2인 시작 배너 한 줄 확인.
- **게임 방법 이모티콘 규칙 삭제**: `how_to_play_screen.dart`의 마지막 _Rule(이모티콘) 제거 → 마지막이 반응속도 결투. 에뮬 확인.
- 웹(e7fcc64)·APK v1.0.0·대시보드·ntfy 배포. analyze 0·테스트 20개 통과.

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
