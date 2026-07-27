#!/usr/bin/env bash
# App Store 자동 업로드 — 안드로이드 upload_play.sh의 iOS 짝(2026-07-17).
#   bash tools/upload_appstore.sh                 # ipa 빌드 + 업로드
#   bash tools/upload_appstore.sh --skip-build    # 기존 build/ios/ipa/*.ipa 업로드만
#
# 인증: App Store Connect API 키(~/.appstoreconnect/private_keys/AuthKey_D3TN3JP93R.p8).
# 키 분실 시 드라이브 백업(dailyapp-secrets-backup/cowboy_party) 또는 ASC에서 재발급.
# ⚠️ 같은 빌드 번호는 재업로드 불가 — pubspec version(+N)과 shell.dart kBuildNo를 먼저 올릴 것.
set -euo pipefail
cd "$(dirname "$0")/.."

API_KEY="D3TN3JP93R"
API_ISSUER="c9d3b6fa-18a5-4e5d-bf82-1c02c7f5e205"
KEY_FILE="$HOME/.appstoreconnect/private_keys/AuthKey_${API_KEY}.p8"

[ -f "$KEY_FILE" ] || { echo "❌ API 키 없음: $KEY_FILE (드라이브 백업에서 복원)"; exit 1; }

if [ "${1:-}" != "--skip-build" ]; then
  echo "== flutter build ipa =="
  # Xcode 계정 세션이 만료되면 export 단계가 'No Accounts'로 실패한다(2026-07-27).
  # 그 경우 아카이브는 살아 있으므로 ASC API 키 클라우드 서명으로 직접 export.
  if ! flutter build ipa --release; then
    echo "== flutter export 실패 → API 키 클라우드 서명 export 폴백 =="
    cat > /tmp/cowboy_export_options.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>signingStyle</key><string>automatic</string>
  <key>teamID</key><string>8ZQLPP4N24</string>
  <key>uploadSymbols</key><true/>
</dict>
</plist>
PLIST
    xcodebuild -exportArchive \
      -archivePath build/ios/archive/Runner.xcarchive \
      -exportPath build/ios/ipa \
      -exportOptionsPlist /tmp/cowboy_export_options.plist \
      -allowProvisioningUpdates \
      -authenticationKeyPath "$KEY_FILE" \
      -authenticationKeyID "$API_KEY" \
      -authenticationKeyIssuerID "$API_ISSUER"
  fi
  # 스테일 ipa 업로드 방지: 방금 만든 아카이브보다 ipa가 오래됐으면 중단
  # (7/27 실제 사고 — 옛 ipa가 올라가 '중복 빌드 번호' 에러).
  if [ build/ios/archive/Runner.xcarchive -nt build/ios/ipa ]; then
    echo "❌ ipa가 아카이브보다 오래됨 — export 실패 의심, 업로드 중단"; exit 1
  fi
fi

IPA=$(ls build/ios/ipa/*.ipa 2>/dev/null | head -1)
[ -n "$IPA" ] || { echo "❌ ipa 없음 — 빌드 실패?"; exit 1; }
echo "== 업로드: $IPA =="
xcrun altool --upload-app --type ios -f "$IPA" \
  --apiKey "$API_KEY" --apiIssuer "$API_ISSUER"
echo "== 완료 — App Store Connect > TestFlight에 처리 후 표시됨(수 분). =="
echo "   버전 페이지에서 새 빌드 선택 → 심사에 추가는 콘솔에서."
