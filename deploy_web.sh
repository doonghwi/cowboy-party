#!/usr/bin/env bash
# 카우보이 웹 배포 — gh-pages.
# 중요: --pwa-strategy=none 은 빈 flutter_service_worker.js 를 남기는데,
# 예전에 설치된 PWA의 옛 SW가 캐시를 붙들어 "흰 화면"을 만든다.
# 그래서 배포 때마다 자가소멸 SW로 덮어써 옛 SW를 정리한다.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17}"
flutter build web --release --base-href "/cowboy-party/" --pwa-strategy=none

# 자가소멸 service worker로 교체(옛 SW 정리 → 흰 화면 방지).
cat > build/web/flutter_service_worker.js <<'SW'
self.addEventListener('install', function (e) { self.skipWaiting(); });
self.addEventListener('activate', function (e) {
  e.waitUntil((async function () {
    try { if (self.caches && caches.keys) { const ks = await caches.keys(); await Promise.all(ks.map(function (k){ return caches.delete(k); })); } } catch (_) {}
    try { if (self.registration) { await self.registration.unregister(); } } catch (_) {}
    try { const cs = await self.clients.matchAll({ type: 'window' }); cs.forEach(function (c){ c.navigate(c.url); }); } catch (_) {}
  })());
});
SW

# --- 흰 화면 스모크 테스트(배포 전) ---
# 빌드한 웹을 헤드리스 크롬으로 띄워 Flutter 뷰가 렌더되는지 확인.
# 안 뜨면(흰 화면) 배포를 중단한다 — 흰 화면 회귀가 사용자에게 안 나가게.
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
if [ -x "$CHROME" ] && command -v node >/dev/null 2>&1; then
  # 이전 실행이 남긴 좀비 정리(포트 충돌 방지).
  pkill -f "remote-debugging-port=9251" 2>/dev/null || true
  pkill -f "http.server 8769" 2>/dev/null || true
  sleep 1
  SMOKE_DIR="$(mktemp -d)"
  ln -s "$ROOT/build/web" "$SMOKE_DIR/cowboy-party"
  python3 -m http.server 8769 --directory "$SMOKE_DIR" >/dev/null 2>&1 &
  SRV_PID=$!
  "$CHROME" --headless=new --remote-debugging-port=9251 --disable-gpu \
    --no-first-run --user-data-dir="$SMOKE_DIR/cdp" about:blank >/dev/null 2>&1 &
  CHROME_PID=$!
  sleep 5
  set +e
  node "$ROOT/tool/web_smoke.mjs" "http://localhost:8769/cowboy-party/" 9251
  SMOKE=$?
  set -e
  kill "$CHROME_PID" "$SRV_PID" 2>/dev/null || true
  pkill -f "remote-debugging-port=9251" 2>/dev/null || true
  sleep 1
  rm -rf "$SMOKE_DIR" 2>/dev/null || true
  if [ "$SMOKE" -ne 0 ]; then
    echo "❌ 스모크 실패: 빌드가 흰 화면입니다. 배포 중단."
    exit 1
  fi
  echo "✅ 스모크 통과(렌더 확인)"
else
  echo "⚠️  크롬/노드 없음 — 스모크 건너뜀(흰 화면 자동검증 불가)"
fi

cd build/web
rm -rf .git
git init -q
git checkout -q -b gh-pages
git add -A
git -c user.name=doonghwi -c user.email=ehdgnlans@gmail.com commit -q -m "deploy web"
git push -qf https://github.com/doonghwi/cowboy-party.git gh-pages
echo "✅ 배포 완료 — https://doonghwi.github.io/cowboy-party/"
