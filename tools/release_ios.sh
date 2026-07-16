#!/usr/bin/env bash
# iOS 완전 자동 릴리스 — "구글 콘솔에 손 안 대듯" (2026-07-17, 사용자 요청).
#   bash tools/release_ios.sh "이번 버전 새 소식 텍스트"
# 흐름: ipa 빌드 → 업로드 → 애플 처리 대기 → 새 버전 페이지 생성/빌드 선택/
#       새 소식 입력 → 심사 자동 제출(승인 시 자동 출시).
#
# ⚠️ 실행 전 세션이 할 일: pubspec version(+N)·shell.dart kBuildNo 범프 + 커밋.
# ⚠️ 첫 실전은 다음 릴리스(1.0.1) — v1.0은 수동 제출 완료(2026-07-17).
# 인증: ~/.appstoreconnect/asc_api_key.json (드라이브 백업됨).
set -euo pipefail
cd "$(dirname "$0")/.."

WHATS_NEW="${1:-버그 수정 및 안정성 개선}"
API_KEY_JSON="$HOME/.appstoreconnect/asc_api_key.json"
BUNDLE_ID="com.doonghwi.cowboyParty"
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //; s/+.*//')
BUILD=$(grep '^version:' pubspec.yaml | sed 's/.*+//')

[ -f "$API_KEY_JSON" ] || { echo "❌ API 키 없음: $API_KEY_JSON"; exit 1; }
echo "== 릴리스 대상: v$VERSION (빌드 $BUILD) =="

echo "== 1/3 ipa 빌드 =="
flutter build ipa --release
IPA=$(ls build/ios/ipa/*.ipa | head -1)

echo "== 2/3 업로드 + 애플 처리 대기 (pilot) =="
fastlane pilot upload \
  --api_key_path "$API_KEY_JSON" \
  --app_identifier "$BUNDLE_ID" \
  --ipa "$IPA" \
  --skip_submission \
  --distribute_external false

echo "== 3/3 버전 페이지 구성 + 심사 제출 (deliver) =="
mkdir -p /tmp/cowboy_ios_meta/ko
printf '%s' "$WHATS_NEW" > /tmp/cowboy_ios_meta/ko/release_notes.txt
fastlane deliver \
  --api_key_path "$API_KEY_JSON" \
  --app_identifier "$BUNDLE_ID" \
  --app_version "$VERSION" \
  --build_number "$BUILD" \
  --metadata_path /tmp/cowboy_ios_meta \
  --skip_screenshots \
  --skip_binary_upload \
  --force \
  --submit_for_review \
  --automatic_release \
  --precheck_include_in_app_purchases false \
  --submission_information "{\"export_compliance_uses_encryption\": false, \"add_id_info_uses_idfa\": false}"

echo "== 완료 — 심사 제출됨. 진행 상황: 대시보드 🚦 출시 탭 =="
