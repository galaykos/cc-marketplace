// A dependency-free, Vite-SHAPED dev server for exercising the real launch
// lifecycle (spawn → ready line → probe → group-kill → reap) without installing
// a `vite` binary. It is NOT vite: it just prints vite's ready-line format and
// serves one HTML page, so startDevServer / reuseOrLaunch can be proven against
// a genuine child process. `--port <n>` (0 = OS-assigned) and an optional
// `--no-ready-line` (to exercise the probe-only fallback) are the only knobs.

import http from 'node:http';

const argv = process.argv.slice(2);
function flag(name, dflt) {
  const i = argv.indexOf(name);
  return i >= 0 && argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[i + 1] : dflt;
}
const port = Number(flag('--port', process.env.PORT || 0));
const emitReady = !argv.includes('--no-ready-line');

const page =
  '<!doctype html><html lang="en"><head><meta charset="utf-8"><title>fake dev</title></head>' +
  '<body><div id="root">fake dev server ready</div></body></html>';

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'content-type': 'text/html' });
  res.end(page);
});

server.listen(port, '127.0.0.1', () => {
  const p = server.address().port;
  if (emitReady) {
    // Mirror Vite's stdout banner so the READY_LINE matcher fires.
    process.stdout.write(`\n  VITE v5.4.0  ready in 120 ms\n\n  ➔  Local:   http://localhost:${p}/\n`);
  } else {
    process.stdout.write(`listening on ${p}\n`);
  }
});

const shutdown = () => server.close(() => process.exit(0));
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
