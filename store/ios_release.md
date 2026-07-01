# iOS 출시 준비 메모

> 실제 업로드/서명은 **Apple Developer Program($99/년) 계정**이 있어야 가능(사장님 몫).
> 아래는 그 전까지 세션이 준비해 둔 코드/설정과, 계정 생긴 뒤 따라 할 절차.

## 기본 정보
- Bundle ID: `com.doonghwi.cowboyParty`
- 표시 이름: 카우보이
- 버전/빌드: `pubspec.yaml`의 `version: x.y.z+build` 가 `CFBundleShortVersionString`/`CFBundleVersion`에 반영됨(Flutter가 자동).

## ✅ 세션이 끝낸 것 (계정 없이 가능한 전부)
- **Sign in with Apple 구현 완료** — `lib/meta/auth_service.dart` `signInWithApple()`
  (nonce 처리 + Firebase `apple.com` 공급자), 온보딩 다이얼로그 + 설정 계정칸에 'Apple로 로그인' 버튼.
  iOS/macOS/웹에서만 노출(`AuthService.showAppleButton`). 패키지 `sign_in_with_apple`, `crypto`.
- **개인정보 매니페스트 `ios/Runner/PrivacyInfo.xcprivacy` 생성 + Xcode 타깃 연결 완료** (2024+ 필수).
  수집 데이터(User ID/닉네임/플레이기록, 모두 Linked·추적 없음) + 필요사유 API(UserDefaults CA92.1·
  파일타임스탬프 C617.1·부팅시각 35F9.1) 선언. `store/data_safety.md`와 일치. **빌드 시 `Runner.app`
  최상위에 번들됨 검증 완료**(`flutter build ios --release --no-codesign` exit 0).
- **`Runner.entitlements` 사전 생성** — `com.apple.developer.applesignin`(Default). 계정 생긴 뒤
  Xcode에서 capability 추가하면 `CODE_SIGN_ENTITLEMENTS`가 이 파일을 자동 연결.
- **`Info.plist`에 `ITSAppUsesNonExemptEncryption=false`** 추가 — 표준 HTTPS만 사용하므로
  업로드마다 뜨는 수출규정(Export Compliance) 질문을 자동 통과.
- **iOS 릴리스 빌드 검증** — `flutter build ios --release --no-codesign` 통과(Runner.app 48MB).
  서명/업로드만 계정 필요, 컴파일·pod·매니페스트 번들은 모두 정상.
- **App Store Connect 입력 필드 문서** — `store/appstore_metadata.md`(부제·키워드·프로모션텍스트·
  Age Rating 답안·App Review 노트 등 콘솔 복붙용).
- **iOS 스크린샷** — `store/screenshots/ios/iphone_69/`(6.9", 1320×2868), `ipad_13/`(2064×2752).
  시뮬레이터(iPhone 17 Pro Max / iPad Pro 13") 캡처.

## ⏳ 계정 생긴 뒤 해야 할 것 (사장님 + Xcode)
### 1) Apple Developer / Firebase 콘솔
- [ ] Apple Developer에서 App ID(`com.doonghwi.cowboyParty`)에 **Sign In with Apple** capability 활성화.
- [ ] (Service ID/키) Firebase 콘솔 → Authentication → Sign-in method → **Apple** 공급자 켜기.
      웹에서도 쓰려면 Apple Service ID + 도메인/리디렉션 등록.
- [ ] Firebase iOS 앱 등록 → `GoogleService-Info.plist` 받아 `ios/Runner/`에 넣기
      (**커밋 금지** — .gitignore에 이미 차단됨).

### 2) Xcode 설정
- [ ] Runner 타깃 → Signing & Capabilities → 팀 선택, **+ Capability → Sign in with Apple** 추가.
      → Xcode가 `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements`를 자동 설정(파일은 이미 생성됨).
- [x] (구글 로그인용) `Info.plist`의 `CFBundleURLTypes`에 역DNS 클라이언트 ID 스킴 존재 확인 완료.
- [x] 아이콘 세트(`AppIcon.appiconset`) 채워짐 확인(20~1024pt 전 사이즈 존재).
- [x] `PrivacyInfo.xcprivacy`가 Runner 타깃 "Copy Bundle Resources"에 연결됨(pbxproj 반영, 빌드 번들 확인).

### 3) 아카이브 & 업로드
```bash
cd ios && pod install && cd ..
flutter build ipa --release
# 산출물: build/ios/ipa/*.ipa  (또는 Xcode Organizer로 Archive)
# Xcode → Window → Organizer → Distribute App → App Store Connect 업로드
# 또는: xcrun altool / Transporter 앱으로 .ipa 업로드
```
- [ ] App Store Connect에서 앱 생성 → 스크린샷/설명(store/listing_*.md)·개인정보(store/data_safety.md) 입력 → 심사 제출.

## 스크린샷 규격(App Store, 필수)
- **6.9"(1320×2868, iPhone 17/16 Pro Max)** — 필수. App Store가 이 하나로 작은 아이폰까지 자동 축소 허용.
  준비됨: `store/screenshots/ios/iphone_69/`.
- **iPad 13"(2064×2752, iPad Pro M4/M5)** — iPad 지원 표시하므로 필수. 준비됨: `store/screenshots/ios/ipad_13/`.
- 다시 캡처하려면: 시뮬레이터 부팅 후 `xcrun simctl io <udid> screenshot out.png` (실해상도로 저장됨).
