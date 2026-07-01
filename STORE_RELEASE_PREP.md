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
- [x] A1 개인정보처리방침 페이지 작성(한/영). 수집 항목(닉네임·uid·사용량·승률), 목적(게임 진행·
      랭킹·밸런스), 보관/삭제, 제3자(Firebase/Google), 문의(ntfy 채널) 명시.
- [x] A2 정적 페이지로 호스팅: `cowboy.gg` repo에 `privacy.html` 추가·푸시(커밋 cc1f5b3).
      → https://doonghwi.github.io/cowboy.gg/privacy.html
- [x] A3 그 URL을 이 문서 하단 "산출물"에 기록.

## B. 스토어 등록정보 (한/영 문안)
- [x] B1 앱 이름(카우보이 / Cowboy), 짧은 설명(80자), 긴 설명(기능·캐릭터·모드).
- [x] B2 카테고리: 게임 > 캐주얼. 태그/키워드(서부, 눈치게임, 파티, 멀티플레이).
- [x] B3 콘텐츠 등급 설문 답안 초안: 만화적 총격(피·고어 없음) → 낮음. 폭력 표현 수위 답변 가이드.
- [x] B4 문안을 `store/listing_ko.md`·`store/listing_en.md`로 저장.

## C. 스크린샷 (규격대로)
- [x] C1 안드로이드 에뮬(AVD `cowboy`)에서 **현재 빌드**로 캡처(1080×2400): 홈(빠른시작 포함)/
      게임플레이(6인)/상점/랭킹/보상 5장 → `store/screenshots/android/`.
- [ ] C2 iOS 시뮬레이터에서 6.7"/6.5"/5.5" + iPad 규격 캡처(App Store는 규격 엄격). **(후속: 시뮬레이터 필요 — store/ios_release.md 규격 참고)**
- [x] C2 iOS 시뮬레이터 캡처 — **6.9"(1320×2868) `ios/iphone_69/01_home.png` + iPad 13"(2064×2752) `ios/ipad_13/01_home.png`**
      (App Store 사이즈별 필수 최소 충족). 상점/랭킹/보상/게임플레이는 탭 이동이 필요해 `store/screenshots/ios/README.md`
      절차로 추가 캡처(자동화 세션은 GUI 탭 불가). iPhone 17 Pro Max / iPad Pro 13" 시뮬레이터 사용.
- [x] C3 `store/screenshots/android/` + `ios/iphone_69`·`ios/ipad_13` 저장 완료.

## D. 그래픽 자산
- [x] D1 앱 아이콘 512×512 → `store/icon_512.png` (원본 1024 launcher icon에서 추출).
- [x] D2 Play 피처 그래픽 1024×500 → `store/feature_graphic.png` (`tool/make_feature_graphic.py`, 재현 가능).

## E. Android 출시 빌드 (서명 + appbundle)
- [x] E1 업로드 키스토어 생성 안내 + `android/key.properties.example` 작성(keytool 명령 포함).
      **키스토어·비밀번호는 사용자가 생성·보관**(세션은 생성 안 함).
- [x] E2 `build.gradle.kts`에 release `signingConfig`(key.properties 읽기) + 없으면 디버그 폴백.
      `key.properties`·`*.jks`·`*.keystore` `.gitignore`에 추가.
- [x] E3 `flutter build appbundle --release` 통과(키 없어 디버그 서명 폴백으로 빌드 검증).
      산출물: `build/app/outputs/bundle/release/app-release.aab`.
- [x] E4 versionCode/versionName 정책: `pubspec.yaml version: 1.0.0+1`, 출시마다 `+빌드번호`↑.
      compile/targetSdk는 Flutter 기본(최신) 따름.

## F. iOS 출시 준비
- [x] F1 ✅ **Sign in with Apple 구현 완료** — `sign_in_with_apple`+`crypto` 추가, `auth_service.signInWithApple()`
      (nonce + Firebase apple.com 공급자), 온보딩·설정에 버튼(iOS/macOS/웹만). analyze 0 / 74 테스트 통과.
      ⚠️ 실제 작동은 Firebase 콘솔 Apple 공급자 + Apple Developer 계정 필요(store/ios_release.md).
- [x] F2 버전/빌드번호·bundle id·아이콘 세트 점검 항목 정리 → store/ios_release.md.
- [x] F3 Xcode 아카이브·업로드 절차 문서화 → store/ios_release.md.
- [x] F4 **개인정보 매니페스트** `ios/Runner/PrivacyInfo.xcprivacy` 생성 + Xcode 타깃 연결(pbxproj) →
      릴리스 빌드 `Runner.app/PrivacyInfo.xcprivacy`로 번들됨 검증. (2024+ App Store 필수)
- [x] F5 **`Runner.entitlements`(applesignin) 사전 생성** — 계정 뒤 Xcode capability 추가 시 자동 연결.
- [x] F6 **`Info.plist ITSAppUsesNonExemptEncryption=false`** — 업로드 시 수출규정 질문 자동 통과(HTTPS만 사용).
- [x] F7 **iOS 릴리스 빌드 검증** `flutter build ios --release --no-codesign` 통과(Runner.app 48MB, 서명만 계정 필요).
- [x] F8 **App Store Connect 입력 필드 문서** `store/appstore_metadata.md`(부제·키워드·프로모션·Age Rating·App Review 노트).

## G. 데이터 안전 / 개인정보 양식 답안
- [x] G1 Play "데이터 안전" 답안 초안 작성.
- [x] G2 Apple "App Privacy" 답안 초안 작성.
- [x] G3 `store/data_safety.md`에 저장.

## H. 출시 게이트
- [x] H1 보안 게이트 통과: jks/key.properties 커밋 이력 없음, http:// 없음, 시크릿 스캔 클린,
      google-services.json 미추적, key.properties .gitignore 확인.
- [x] H2 법무 게이트 통과: CREDITS.md에 비속어 목록 출처(hlog2e/bad_word_list)·피처그래픽 추가,
      폰트 OFL·Twemoji CC-BY 기표기, 신규 패키지(sign_in_with_apple/crypto) GPL 아님.

## 사용자(사장님)만 할 수 있는 것 — 세션은 하지 말고 목록만 정리
- Google Play 개발자 등록($25, 1회), Apple Developer($99/년).
- 업로드 키스토어 생성·**비밀 보관**, Apple 인증서/프로비저닝.
- 스토어 콘솔에 자산 업로드 + 최종 "제출".

## 산출물 (세션이 끝나며 여기에 채움)
- **개인정보처리방침 URL**: https://doonghwi.github.io/cowboy.gg/privacy.html (cowboy.gg repo `privacy.html`, 커밋 cc1f5b3, 푸시됨)
- **appbundle 경로**: `build/app/outputs/bundle/release/app-release.aab` (57.5MB, 디버그 서명 폴백 — 제출용은 업로드 키 필요)
- **store/ 폴더**:
  - 문안: `store/listing_ko.md`, `store/listing_en.md`
  - 데이터안전: `store/data_safety.md` · iOS 절차: `store/ios_release.md` · 안내: `store/README.md`
  - 그래픽: `store/icon_512.png`(512²), `store/feature_graphic.png`(1024×500)
  - 스크린샷: `store/screenshots/android/` 5장(현재 빌드, 1080×2400) / `store/screenshots/ios/`(후속)
- **코드 변경**: Sign in with Apple 구현(auth_service+shell), Android release signingConfig, 공지 1건. analyze 0 / 74 테스트 통과.

## 남은 사용자(사장님) 액션
1. **Google Play 개발자 등록**($25, 1회) / **Apple Developer**($99/년).
2. **Android 업로드 키스토어 생성·비밀 보관**: `android/key.properties.example` 따라 `keytool` 실행 →
   `android/key.properties` 작성(절대 커밋 금지) → `flutter build appbundle --release`로 서명된 .aab 생성.
3. **Firebase 콘솔**: Authentication에서 **Apple 공급자 켜기**(+ Apple Service ID/키). iOS 앱 등록 후
   `GoogleService-Info.plist`를 `ios/Runner/`에 배치(커밋 금지).
4. **Xcode**: Sign in with Apple capability 추가 + 서명팀 선택 → `flutter build ipa --release` → 업로드.
5. **iOS 스크린샷**: 시뮬레이터로 6.7"/6.9" 등 규격 캡처(store/ios_release.md).
6. **스토어 콘솔**: store/ 문안·그래픽·스크린샷·개인정보 답안 업로드 후 **최종 제출**.
