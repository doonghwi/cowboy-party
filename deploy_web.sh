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

cd build/web
rm -rf .git
git init -q
git checkout -q -b gh-pages
git add -A
git -c user.name=doonghwi -c user.email=ehdgnlans@gmail.com commit -q -m "deploy web"
git push -qf https://github.com/doonghwi/cowboy-party.git gh-pages
echo "✅ 배포 완료 — https://doonghwi.github.io/cowboy-party/"
