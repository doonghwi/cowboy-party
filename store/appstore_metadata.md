# App Store Connect — 입력 필드 모음 (복붙용)

> Apple Developer 계정 생긴 뒤 App Store Connect에서 앱 생성 시 그대로 붙여넣는 값.
> 긴 설명 원문은 `listing_en.md`(영문) / `listing_ko.md`(국문). 여기는 **iOS 콘솔 전용 필드**만.
> 글자수 제한을 지킨 확정 문안이다.

## 기본 정보
- **Bundle ID**: `com.doonghwi.cowboyParty`
- **SKU**: `cowboy-party-001` (콘솔 내부용 임의 식별자, 아무거나 가능)
- **Primary Language**: Korean (또는 English — 주 시장에 맞춰)
- **App Name (표시명, ≤30자)**: `카우보이` (영문 현지화: `Cowboy`)
- **Copyright**: `2026 doonghwi`
- **Primary Category**: Games  ·  **Subcategory**: Casual (2차: Board)

## 현지화 필드 — 한국어
- **Subtitle (부제, ≤30자)**: `2~6인 서부 눈치 대결`
- **Promotional Text (≤170자, 심사 없이 수시 변경 가능)**:
  `2~6명이 동시에 장전·방어·발사! 상대의 수를 읽고 마지막까지 살아남으세요. 캐릭터 16종·빠른 매칭·친구 초대. 한 판 몇 분이면 끝!`
- **Keywords (≤100자, 쉼표구분·공백없이)**:
  `서부,카우보이,눈치게임,파티게임,멀티플레이,대결,보드게임,심리전,온라인,캐주얼,친구,총`
- **Description**: `listing_ko.md`의 긴 설명 본문 사용.

## 현지화 필드 — English
- **Subtitle (≤30 chars)**: `Western standoff party game`
- **Promotional Text (≤170 chars)**:
  `2–6 players reload, defend, or shoot at once. Read your rivals and be the last cowboy standing. 16 characters, quick match, invite friends. A round takes minutes!`
- **Keywords (≤100 chars, comma, no spaces)**:
  `western,cowboy,standoff,party,multiplayer,duel,board,mindgame,online,shooting,casual,bluff`
- **Description**: `listing_en.md`의 Full Description 사용.

## 공통 URL / 연락처
- **Support URL (필수)**: `https://doonghwi.github.io/cowboy.gg/`
- **Marketing URL (선택)**: `https://doonghwi.github.io/cowboy-party/`
- **Privacy Policy URL (필수)**: `https://doonghwi.github.io/cowboy.gg/privacy.html`
- **Support email**: `ehdgnlans@gmail.com`

## Age Rating 설문 (App Store, 예상 4+ ~ 9+)
> Apple 콘솔 "Age Rating" 설문. 아래 기준대로 정직하게 답변 → 대략 **9+** (만화적 폭력 경미).
- Cartoon or Fantasy Violence: **Infrequent/Mild** (만화적 총격, 피·고어 없음)
- Realistic Violence / Prolonged Graphic Violence: **None**
- Sexual Content, Nudity, Profanity, Horror, Alcohol/Tobacco/Drugs: **None**
- Simulated Gambling: **None** (코인은 인게임 재화, 현금 환전·실제 베팅 없음)
- Contests / Unrestricted Web Access: **None**
- Medical/Treatment Info: **None**
- Made for Kids (아동용 카테고리): **아니오** (일반 앱, COPPA 아동 카테고리 비대상)

## App Privacy (요약 — 상세 답안은 store/data_safety.md B절)
- 데이터 수집: **예**. 추적(Tracking, ATT): **아니오** → ATT 프롬프트 불필요.
- 수집·연결(Linked) 항목: User ID(uid), Other User Content(닉네임), Product Interaction(플레이 기록).
- 목적: App Functionality (+ 플레이 기록은 Analytics 겸용).
- **PrivacyInfo.xcprivacy** 이미 번들에 포함됨(`ios/Runner/PrivacyInfo.xcprivacy`) → 콘솔 답안과 일치.

## App Review Information (심사팀 전달용 — 중요)
- **Sign in with Apple 사용**: 예 (제3자 로그인 제공하므로 Apple도 제공 — 가이드라인 4.8 충족).
- **데모 계정 불필요**: 로그인 없이 **게스트로 전체 플레이 가능**. 온라인은 "빠른 시작"으로
  봇 포함 즉시 매칭되어 로그인 없이 검증 가능. → Review Notes에 아래 문구 권장:
  > No login required. Tap "Quick Match" to play online instantly (bots fill empty seats).
  > Or play offline vs. computer. Sign in with Apple / Google is optional (for cross-device ranking).
- **In-App Purchase**: 없음(현재). 코인은 플레이로만 획득, 실결제 없음.
- **광고**: 없음.

## 스크린샷 (App Store 규격)
- 6.9"(1320×2868, iPhone 17 Pro Max 등) — **필수**. 준비됨: `store/screenshots/ios/iphone_69/`.
- iPad 13"(2064×2752) — iPad 지원하므로 **필수**. 준비됨: `store/screenshots/ios/ipad_13/`.
- 나머지 규격은 6.9"를 App Store가 자동 다운스케일 허용(원하면 별도 캡처).

## 남은 사장님 액션 (계정 생긴 뒤)
1. App Store Connect에서 앱 생성(위 Bundle ID/SKU).
2. 위 필드 붙여넣기 + 스크린샷 업로드 + Age Rating 설문 + App Privacy 답안.
3. Xcode에서 Sign in with Apple capability 추가·서명팀 선택 → `flutter build ipa` → 업로드(store/ios_release.md).
4. 심사 제출.
