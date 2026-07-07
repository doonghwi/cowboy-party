#!/usr/bin/env bash
# Play 콘솔 AAB 업로드 자동화 (fastlane supply 래퍼)
# 사전조건: growth/PLAY_UPLOAD_SETUP.md의 1회 설정(서비스 계정 JSON + fastlane 설치)
# 사용: bash tools/upload_play.sh [--aab <경로>] [--track alpha] [--validate]
set -euo pipefail

cd "$(dirname "$0")/.."
AAB="build/app/outputs/bundle/release/app-release.aab"
TRACK="alpha"
EXTRA=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --aab) AAB="$2"; shift 2;;
    --track) TRACK="$2"; shift 2;;
    --validate) EXTRA+=(--validate_only true); shift;;
    *) echo "unknown arg: $1"; exit 1;;
  esac
done

KEY="android/play-service-account.json"
[[ -f "$KEY" ]] || { echo "서비스 계정 키 없음: $KEY — growth/PLAY_UPLOAD_SETUP.md 설정 먼저"; exit 1; }
[[ -f "$AAB" ]] || { echo "AAB 없음: $AAB — flutter build appbundle --release 먼저"; exit 1; }
command -v fastlane >/dev/null || { echo "fastlane 미설치 — brew install fastlane"; exit 1; }

echo "== 업로드: $AAB → track=$TRACK =="
fastlane supply \
  --aab "$AAB" \
  --track "$TRACK" \
  --json_key "$KEY" \
  --package_name com.doonghwi.cowboy_party \
  --skip_upload_metadata --skip_upload_images --skip_upload_screenshots \
  --release_status completed \
  "${EXTRA[@]}"
echo "== 완료 — 심사 자동 제출됨(관리형 게시 ON이면 콘솔에서 게시 클릭 필요) =="
