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
  flutter build ipa --release
fi

IPA=$(ls build/ios/ipa/*.ipa 2>/dev/null | head -1)
[ -n "$IPA" ] || { echo "❌ ipa 없음 — 빌드 실패?"; exit 1; }
echo "== 업로드: $IPA =="
xcrun altool --upload-app --type ios -f "$IPA" \
  --apiKey "$API_KEY" --apiIssuer "$API_ISSUER"
echo "== 완료 — App Store Connect > TestFlight에 처리 후 표시됨(수 분). =="
echo "   버전 페이지에서 새 빌드 선택 → 심사에 추가는 콘솔에서."
