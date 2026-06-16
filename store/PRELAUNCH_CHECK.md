# 카우보이 — 제출 전 사전점검 (PRELAUNCH_CHECK)

> deploy 루프 세션이 유지. **✅ = 세션이 자동으로 끝낸 것**, **⏳ = 사용자(사장님)만 할 수 있는 것**.
> 마지막 점검: 2026-06-16 15:42 (KST). 기준 커밋: `37a6a59`.

## 빌드 신선도 (매 사이클 재확인)
- ✅ `flutter analyze` 0 issues (2026-06-16 15:42).
- ✅ `flutter build appbundle --release` 통과 → `build/app/outputs/bundle/release/app-release.aab` (63.3MB, 2026-06-16 15:42 재빌드 — 이펙트 E(전 특수행동 연출 통일)·공지 반영, basis 37a6a59=HEAD).
  - ⚠️ 현재 .aab는 **디버그 서명 폴백**(key.properties 없음). 제출용 서명 .aab는 사용자 키스토어 필요(아래 ⏳).
- ✅ 웹 **완전 동기** — gh-pages `0586945 deploy web` (2026-06-16 15:13:54, 코드세션 배포)이 HEAD 37a6a59(15:13:12) 이후라 최신. https://doonghwi.github.io/cowboy-party/
- ✅ `flutter test` 통과 이력(74 테스트, 직전 코드 세션 기준). 코드 변경 시 재확인.

## 버전 정책
- ✅ `pubspec.yaml version: 1.0.0+1` — 최초 출시값. **출시(업로드)할 때마다 빌드번호 `+N` 증가** 필요.
  - Play: versionCode = 빌드번호, 같은 값 재업로드 불가 → 매 업로드마다 +1.
  - iOS: CFBundleVersion = 빌드번호(Flutter 자동 반영).
  - ⏳ 첫 제출 직전 사용자가 최종 버전 확정(예: `1.0.0+1` 그대로 또는 올림).

## 스토어 등록정보 (문안)
- ✅ `store/listing_ko.md` / `store/listing_en.md` — 이름·짧은설명·긴설명·카테고리·콘텐츠등급 답안.
- ✅ 짧은 설명 Play 80자 이내 / 부제목 App Store 30자 이내 확인.
- ✅ 개인정보처리방침 URL: https://doonghwi.github.io/cowboy.gg/privacy.html (라이브).
- ✅ 지원 이메일: ehdgnlans@gmail.com / 웹데모 URL 기재.

## 그래픽 자산
- ✅ `store/icon_512.png` (512×512) — Play 등록용.
- ✅ `store/feature_graphic.png` (1024×500) — Play 피처 그래픽(`tool/make_feature_graphic.py`로 재현 가능).
- ✅ 앱 아이콘 세트(`flutter_launcher_icons`) — Android 적용됨.

## 스크린샷
- ✅ Android 5장 `store/screenshots/android/` (1080×2400): 홈/상점/랭킹/보상/게임플레이.
  - ⚠️ **재캡처 권장(세션 가능, 사용자 단계 아님)**: 98f1e9a로 상점·좌석에 캐릭터 일러스트 16종이 적용됨 → 기존 02_shop·05_gameplay 스크린샷은 구 아트. 에뮬 AVD `cowboy`로 최신 빌드 재캡처 시 더 좋은 인상. (다음 사이클 또는 디자인 안정화 후 일괄.)
- ⏳ **iOS 스크린샷** — 시뮬레이터 필요. 6.7"(1290×2796) 또는 6.9" 필수, iPad 12.9"(2048×2732) iPad 지원 시 필수. → `store/screenshots/ios/`(현재 비어있음). 규격: `store/ios_release.md`.

## 데이터 안전 / 개인정보 양식
- ✅ `store/data_safety.md` — Play 데이터안전 + Apple App Privacy 답안 초안.
- ✅ 수집 데이터 정의: 닉네임·익명/구글 uid·사용량 카운트·캐릭터 승률. 개인식별정보(이메일본문/주소/전화) 미수집.

## 출시 게이트 (보안/법무)
- ✅ 보안: jks/key.properties 커밋 이력 없음, http:// 평문 없음, 시크릿 스캔 클린, google-services.json 미추적.
- ✅ 법무: CREDITS.md에 비속어목록 출처·폰트 OFL·Twemoji CC-BY·신규 패키지 라이선스(GPL 아님) 기표기.

## iOS 코드 준비
- ✅ Sign in with Apple 구현(`auth_service.signInWithApple()` + 온보딩/설정 버튼, iOS/macOS/웹 노출).
- ✅ Bundle ID `com.doonghwi.cowboyParty`, 절차 문서 `store/ios_release.md`.

---

## ⏳ 사용자(사장님)만 할 수 있는 6단계 — 세션 정지점
> 아래는 계정/결제/비밀키/콘솔 권한이 필요해 **세션이 절대 손대지 않음**. `store/` 자산은 다 준비됨.

1. **개발자 계정 등록** — Google Play($25, 1회) / Apple Developer($99/년).
2. **Android 업로드 키스토어 생성·비밀 보관** — `android/key.properties.example`대로 `keytool` 실행 → `android/key.properties` 작성(커밋 금지) → `flutter build appbundle --release`로 **서명된** .aab 생성.
3. **Firebase 콘솔** — Authentication에서 Apple 공급자 켜기(+Apple Service ID/키) / iOS 앱 등록 후 `GoogleService-Info.plist`를 `ios/Runner/`에 배치(커밋 금지).
4. **Xcode** — Sign in with Apple capability + 서명팀 선택 → `flutter build ipa --release` → App Store Connect 업로드.
5. **iOS 스크린샷** — 시뮬레이터로 규격 캡처(`store/ios_release.md`).
6. **스토어 콘솔 업로드 + 최종 제출** — `store/` 문안·그래픽·스크린샷·데이터안전 답안 입력 후 제출.

## 세션 상태
- 자동화 가능분 **전부 완료**. 위 6개 사용자 단계만 남음 → 세션은 **빌드 신선도 재점검 루프**로 대기.
