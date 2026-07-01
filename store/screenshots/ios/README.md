# iOS 스크린샷 (App Store Connect)

## 규격 (App Store 필수)
- **`iphone_69/`** — 6.9"(1320×2868). iPhone 17/16 Pro Max. App Store가 이 하나로 더 작은 아이폰까지 자동 축소 허용. **1장 이상 필수.**
- **`ipad_13/`** — iPad 13"(2064×2752). iPad Pro M4/M5. iPad를 지원하므로 **1장 이상 필수.**

## 현재 상태
- ✅ `iphone_69/01_home.png` (1320×2868) — 홈(빠른시작·컴퓨터대결·방만들기·공개방).
- ✅ `ipad_13/01_home.png` (2064×2752) — 홈.
- ⏳ 상점·랭킹·보상·게임플레이 화면 — **아래 절차로 추가 캡처**(탭 이동이 필요해 자동화 세션에서 못 찍음).

> 최소 요건(사이즈별 1장)은 충족. 전환율을 위해 상점/게임플레이 등 3~5장으로 늘리길 권장.

## 재현/추가 캡처 절차
탭 이동이 필요한 화면은 시뮬레이터를 **눈으로 보며** 캡처한다. GUI가 있는 데스크톱 세션에서:

```bash
DEV="iPhone 17 Pro Max"           # iPad는 "iPad Pro 13-inch (M5)"
BID=com.doonghwi.cowboyParty
cd /Users/doonghwi/Documents/dailyapp/cowboy_party

# 1) 시뮬레이터용 앱 빌드(최초 1회) + 설치
flutter build ios --simulator --debug
xcrun simctl boot "$DEV"; open -a Simulator
APP=$(find build/ios -path "*iphonesimulator/Runner.app" -maxdepth 3 | head -1)
xcrun simctl install "$DEV" "$APP"

# 2) 첫 실행(컨테이너 생성) 후 온보딩/닉네임을 건너뛰도록 prefs 시드
xcrun simctl launch "$DEV" "$BID"; sleep 5
xcrun simctl terminate "$DEV" "$BID"; sleep 3
#   ⚠️ 반드시 파일 + cfprefsd 양쪽에 써야 앱이 읽는다(둘 중 하나만 쓰면 무시됨).
CONT=$(xcrun simctl get_app_container "$DEV" "$BID" data)
PLIST="$CONT/Library/Preferences/$BID.plist"
/usr/libexec/PlistBuddy -c 'Set :flutter.nickname 보안관' "$PLIST"
/usr/libexec/PlistBuddy -c 'Set :flutter.nick_set true'  "$PLIST"
/usr/libexec/PlistBuddy -c 'Set :flutter.coins 9999'     "$PLIST"
xcrun simctl spawn booted defaults write "$BID" flutter.nickname -string "보안관"
xcrun simctl spawn booted defaults write "$BID" flutter.nick_set -bool true
xcrun simctl spawn booted defaults write "$BID" flutter.coins -int 9999
xcrun simctl launch "$DEV" "$BID"          # 이제 온보딩 없이 홈이 바로 뜬다

# 3) 시뮬레이터에서 원하는 화면으로 탭 이동한 뒤 캡처(실해상도로 저장):
xcrun simctl io "$DEV" screenshot iphone_69/02_shop.png       # 상점 탭에서
xcrun simctl io "$DEV" screenshot iphone_69/03_ranking.png    # 랭킹 탭에서
xcrun simctl io "$DEV" screenshot iphone_69/04_rewards.png    # 보상 탭에서
xcrun simctl io "$DEV" screenshot iphone_69/05_gameplay.png   # 컴퓨터와 대결 진행 중
```

## 권장 5장 (안드로이드와 동일 구성)
1. 홈(빠른시작) — ✅ 완료
2. 상점(캐릭터 16종)
3. 랭킹
4. 보상(출석)
5. 게임플레이(6인 대결) — "컴퓨터와 대결"로 봇전 시작해 캡처

## 메모
- prefs 시드 키: `flutter.nickname`, `flutter.nick_set`, `flutter.coins`(앱은 SharedPreferences=NSUserDefaults 사용).
- 캡처는 항상 `xcrun simctl io <dev> screenshot`으로. 시뮬레이터 창을 직접 캡처하면 베젤이 섞인다.
- 안드로이드 스크린샷은 `../android/`.
