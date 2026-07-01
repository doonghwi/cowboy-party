#!/usr/bin/env bash
# 앱의 순수 게임 로직(Flutter 의존 0)을 러너로 복사한다.
# **편집은 항상 앱(cowboy_party/lib/game/)에서만** — 러너 쪽은 생성물이다.
# 앱 룰엔진을 바꾸면 이 스크립트를 다시 돌려 러너를 최신화한다(버전 스큐 방지).
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$HERE/../lib/game"
DST="$HERE/lib/game"
mkdir -p "$DST"
for f in char_core.dart party_logic.dart cpu_ai.dart; do
  cp "$SRC/$f" "$DST/$f"
  echo "synced $f"
done
echo "완료. (편집은 앱에서, 러너는 재동기화)"
