# iOS 출시 준비 메모

> 실제 업로드/서명은 **Apple Developer Program($99/년) 계정**이 있어야 가능(사장님 몫).
> 아래는 그 전까지 세션이 준비해 둔 코드/설정과, 계정 생긴 뒤 따라 할 절차.

## 기본 정보
- Bundle ID: `com.doonghwi.cowboyParty`
- 표시 이름: 카우보이
- 버전/빌드: `pubspec.yaml`의 `version: x.y.z+build` 가 `CFBundleShortVersionString`/`CFBundleVersion`에 반영됨(Flutter가 자동).

## ✅ 세션이 끝낸 것 (코드)
- **Sign in with Apple 구현 완료** — `lib/meta/auth_service.dart` `signInWithApple()`
  (nonce 처리 + Firebase `apple.com` 공급자), 온보딩 다이얼로그 + 설정 계정칸에 'Apple로 로그인' 버튼.
  iOS/macOS/웹에서만 노출(`AuthService.showAppleButton`).
- 패키지 추가: `sign_in_with_apple`, `crypto`.

## ⏳ 계정 생긴 뒤 해야 할 것 (사장님 + Xcode)
### 1) Apple Developer / Firebase 콘솔
- [ ] Apple Developer에서 App ID(`com.doonghwi.cowboyParty`)에 **Sign In with Apple** capability 활성화.
- [ ] (Service ID/키) Firebase 콘솔 → Authentication → Sign-in method → **Apple** 공급자 켜기.
      웹에서도 쓰려면 Apple Service ID + 도메인/리디렉션 등록.
- [ ] Firebase iOS 앱 등록 → `GoogleService-Info.plist` 받아 `ios/Runner/`에 넣기
      (**커밋 금지** — .gitignore에 이미 차단됨).

### 2) Xcode 설정
- [ ] Runner 타깃 → Signing & Capabilities → 팀 선택, **+ Capability → Sign in with Apple** 추가
      (Runner.entitlements에 `com.apple.developer.applesignin` 생성됨).
- [ ] (구글 로그인용) `Info.plist`의 `CFBundleURLTypes`에 역DNS 클라이언트 ID 스킴이 들어있는지 확인.
- [ ] 아이콘 세트(`ios/Runner/Assets.xcassets/AppIcon.appiconset`) 채워졌는지 확인
      — `flutter_launcher_icons`가 생성. 비어 있으면 `dart run flutter_launcher_icons` 재실행.

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
- 6.7"(1290×2796) 또는 6.9" — **필수**. 6.5"(1242×2688), 5.5"(1242×2208)는 권장.
- iPad 12.9"(2048×2732) — iPad 지원 표시 시 필수.
- `store/screenshots/ios/` 에 시뮬레이터로 캡처(`_make-new-app/TESTING.md` 참고).
