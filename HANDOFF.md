# 카우보이 파티 — 세션 이어가기 (HANDOFF)

> 새 세션에서 이 파일을 먼저 읽고 이어서 진행. 모든 작업물은 디스크에 있고 main에 커밋됨.
> ⚠️ 아래 좌표 일부는 구 Windows 경로(C:\dev\…) — 현재는 Mac `/Users/doonghwi/Documents/dailyapp/`.

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
