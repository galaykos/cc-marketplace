// Network-category fixture server (card 07). Serves two pages:
//   /500/    → embeds an asset that always 500s        → hard network failure.
//   /flaky/  → embeds an asset that 503s ONCE then 200s → transient (recovers).
// Ephemeral port by default; prints the base URL on stdout as `LISTENING <url>`
// so a harness run can grab it. Not a dev-server launcher (card 11) — just a
// deterministic origin for the network assert fixtures.

import http from 'node:http';

const hits = new Map();
const page = (body) =>
  `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>net fixture</title></head><body>${body}</body></html>`;

const server = http.createServer((req, res) => {
  const url = (req.url || '/').split('?')[0];

  if (url === '/favicon.ico') { res.writeHead(204); return res.end(); }

  if (url === '/500/' || url === '/500') {
    res.writeHead(200, { 'content-type': 'text/html' });
    return res.end(page('<h1>Report</h1><img src="/asset-500.png" alt="chart">'));
  }
  if (url === '/asset-500.png') {
    res.writeHead(500, { 'content-type': 'text/plain' });
    return res.end('server error');
  }

  if (url === '/flaky/' || url === '/flaky') {
    res.writeHead(200, { 'content-type': 'text/html' });
    return res.end(page('<h1>Report</h1><script src="/asset-flaky.js"></script>'));
  }
  if (url === '/asset-flaky.js') {
    const n = (hits.get(url) || 0) + 1;
    hits.set(url, n);
    if (n === 1) {
      // First hit fails transiently; the network category retries once and recovers.
      res.writeHead(503, { 'content-type': 'text/plain' });
      return res.end('warming up');
    }
    res.writeHead(200, { 'content-type': 'application/javascript' });
    return res.end('window.__flakyOk = true;');
  }

  res.writeHead(404, { 'content-type': 'text/plain' });
  res.end('not found');
});

const port = Number(process.env.PORT || process.argv[2] || 0);
server.listen(port, '127.0.0.1', () => {
  const addr = server.address();
  process.stdout.write(`LISTENING http://127.0.0.1:${addr.port}/\n`);
});
