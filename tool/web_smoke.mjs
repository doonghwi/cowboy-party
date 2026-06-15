// 웹 빌드 흰 화면 스모크 테스트.
// 헤드리스 크롬으로 URL을 열고 Flutter 뷰가 렌더되는지 확인한다.
// 렌더되면 exit 0, 안 되면(흰 화면) exit 1 → 배포 중단에 사용.
// 사용: node tool/web_smoke.mjs <url> <cdpPort>
const URL = process.argv[2];
const PORT = process.argv[3] || '9222';
if (!URL) { console.error('URL 필요'); process.exit(2); }
const mk = await fetch(`http://localhost:${PORT}/json/new?about:blank`, { method: 'PUT' })
  .catch(() => fetch(`http://localhost:${PORT}/json/new?about:blank`));
const t = await mk.json();
const ws = new WebSocket(t.webSocketDebuggerUrl);
let id = 0; const send = (m, p = {}) => ws.send(JSON.stringify({ id: ++id, method: m, params: p }));
const errs = [];
ws.onmessage = (e) => {
  const m = JSON.parse(e.data);
  if (m.method === 'Runtime.exceptionThrown')
    errs.push(m.params.exceptionDetails.exception?.description || m.params.exceptionDetails.text);
};
await new Promise(res => ws.onopen = res);
send('Runtime.enable'); send('Page.enable');
await new Promise(r => setTimeout(r, 300));
send('Page.navigate', { url: URL });
await new Promise(r => setTimeout(r, 12000));
send('Runtime.evaluate', {
  expression: `!!document.querySelector('flutter-view, flt-glass-pane, flt-scene-host')`,
  returnByValue: true,
});
const rendered = await new Promise(r => {
  ws.addEventListener('message', function h(e) {
    const m = JSON.parse(e.data);
    if (m.id === id) { ws.removeEventListener('message', h); r(m.result?.result?.value); }
  });
});
console.log(`[smoke] rendered=${rendered} exceptions=${errs.length}`);
errs.slice(0, 3).forEach(e => console.log('[smoke] ' + String(e).split('\n')[0]));
process.exit(rendered ? 0 : 1);
