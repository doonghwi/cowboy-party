self.addEventListener('install', function (e) { self.skipWaiting(); });
self.addEventListener('activate', function (e) {
  e.waitUntil((async function () {
    try { if (self.caches && caches.keys) { const ks = await caches.keys(); await Promise.all(ks.map(function (k){ return caches.delete(k); })); } } catch (_) {}
    try { if (self.registration) { await self.registration.unregister(); } } catch (_) {}
    try { const cs = await self.clients.matchAll({ type: 'window' }); cs.forEach(function (c){ c.navigate(c.url); }); } catch (_) {}
  })());
});
