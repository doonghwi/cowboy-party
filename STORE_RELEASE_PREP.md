# 카우보이 — 스토어 출시 준비 지시서 (다른 세션 전용)

> **이 파일을 읽은 세션이 할 일**: 아래 체크리스트를 위에서부터 끝까지 실제로 수행한다.
> Play 스토어 + App Store 제출에 필요한 것 중 **사용자 계정/결제/제출이 필요 없는 모든 것**을
> 미리 만들어 둔다. 각 항목 `[ ]`→`[x]`. 코드 변경은 `flutter analyze`(0)+`flutter test` 통과 후
> 커밋·푸시(작성자 `doonghwi <ehdgnlans@gmail.com>`, Co-Authored-By 금지). 끝나면 HANDOFF.md 갱신.

## 0. 컨텍스트 (먼저 읽기)
- 작업 디렉토리: `/Users/doonghwi/Documents/dailyapp/cowboy_party`
- 앱: "카우보이" — 2~6인 동시 행동 서부 눈치 대결. 온라인(Firebase RTDB)+오프라인(봇).
- Android applicationId/namespace: `com.doonghwi.cowboy_party`
- iOS bundle id: `com.doonghwi.cowboyParty`
- 현재 버전: `pubspec.yaml` `version: 1.0.0+1` (출시마다 `+빌드번호` 증가).
- Firebase project: `cowboy-party-doonghwi`. 웹: https://doonghwi.github.io/cowboy-party/
- 수집 데이터: **닉네임(사용자 지정)·익명/구글 uid·사용량 카운트·캐릭터 승률**. 개인정보(이메일
  본문/주소/전화)는 **수집 안 함**. 제보는 ntfy로 익명 식별자만.
- 설계/구조: `ARCHITECTURE.md`, 보안/법무 게이트: `_make-new-app/SECURITY_CHECKLIST.md`,
  `_make-new-app/LEGAL_CHECKLIST.md`.

## A. 개인정보처리방침 (필수 — URL 있어야 등록 가능)
- [ ] A1 개인정보처리방침 페이지 작성(한/영). 수집 항목(닉네임·uid·사용량·승률), 목적(게임 진행·
      랭킹·밸런스), 보관/삭제, 제3자(Firebase/Google), 문의(ntfy 채널) 명시.
- [ ] A2 정적 페이지로 호스팅: `cowboy.gg` repo에 `privacy.html`(또는 dashboard-site)로 추가하고
      gh-pages URL 확보. (예: https://doonghwi.github.io/cowboy.gg/privacy.html)
- [ ] A3 그 URL을 이 문서 하단 "산출물"에 기록.

## B. 스토어 등록정보 (한/영 문안)
- [ ] B1 앱 이름(카우보이 / Cowboy), 짧은 설명(80자), 긴 설명(기능·캐릭터·모드).
- [ ] B2 카테고리: 게임 > 캐주얼. 태그/키워드(서부, 눈치게임, 파티, 멀티플레이).
- [ ] B3 콘텐츠 등급 설문 답안 초안: 만화적 총격(피·고어 없음) → 낮음. 폭력 표현 수위 답변 가이드.
- [ ] B4 문안을 `store/listing_ko.md`·`store/listing_en.md`로 저장.

## C. 스크린샷 (규격대로)
- [ ] C1 안드로이드 에뮬(AVD `cowboy`)에서 주요 화면 캡처: 홈/게임플레이/상점/랭킹/빠른시작.
      `_make-new-app/TESTING.md`의 adb+sips 절차 사용. 폰 규격(최소 2장, 16:9 또는 9:16).
- [ ] C2 iOS 시뮬레이터에서 6.7"/6.5"/5.5" + iPad 규격 캡처(App Store는 규격 엄격).
- [ ] C3 `store/screenshots/android/`·`store/screenshots/ios/`에 저장.

## D. 그래픽 자산
- [ ] D1 앱 아이콘 512×512(이미 launcher icon 있음 — 추출/확인).
- [ ] D2 Play 피처 그래픽 1024×500 제작 → `store/feature_graphic.png`.

## E. Android 출시 빌드 (서명 + appbundle)
- [ ] E1 업로드 키스토어 생성 안내 문서 작성(`keytool` 명령). **키스토어 파일·비밀번호는
      사용자가 생성·보관** — 세션은 생성하지 말고 `android/key.properties.example`만 만든다.
- [ ] E2 `android/app/build.gradle.kts`에 release `signingConfig`(key.properties 읽기) 추가.
      `key.properties`는 `.gitignore`에 추가(시크릿).
- [ ] E3 `flutter build appbundle --release` 가 통과하도록 설정(키 없으면 디버그서명으로라도 빌드 확인).
      산출물 `build/app/outputs/bundle/release/app-release.aab` 경로 기록.
- [ ] E4 targetSdk/compileSdk 최신, versionCode/versionName 정책 메모.

## F. iOS 출시 준비
- [ ] F1 ⚠️ **Sign in with Apple 구현 필요** — Apple은 제3자 로그인(구글)을 제공하면 Apple 로그인도
      필수. `sign_in_with_apple` 패키지 + Firebase Apple 공급자 + 버튼 추가(auth_service에). (코드 작업)
- [ ] F2 버전/빌드번호, bundle id 확인, 아이콘 세트(Assets.xcassets) 확인.
- [ ] F3 Xcode 아카이브 절차 문서화(실제 업로드는 Apple 계정 필요 — 사용자 몫).

## G. 데이터 안전 / 개인정보 양식 답안
- [ ] G1 Play "데이터 안전" 답안 초안: 수집=닉네임·식별자·사용량, 공유 없음, 암호화 전송, 삭제 요청 경로.
- [ ] G2 Apple "App Privacy" 답안 초안(동일 내용).
- [ ] G3 `store/data_safety.md`에 저장.

## H. 출시 게이트
- [ ] H1 `_make-new-app/SECURITY_CHECKLIST.md` 통과(키 노출/규칙/시크릿 스캔).
- [ ] H2 `_make-new-app/LEGAL_CHECKLIST.md` 통과(라이선스: 비속어 목록 출처 표기, 폰트/에셋 라이선스).

## 사용자(사장님)만 할 수 있는 것 — 세션은 하지 말고 목록만 정리
- Google Play 개발자 등록($25, 1회), Apple Developer($99/년).
- 업로드 키스토어 생성·**비밀 보관**, Apple 인증서/프로비저닝.
- 스토어 콘솔에 자산 업로드 + 최종 "제출".

## 산출물 (세션이 끝나며 여기에 채움)
- 개인정보처리방침 URL:
- appbundle 경로:
- store/ 폴더(문안·스크린샷·데이터안전):
- 남은 사용자 액션:
