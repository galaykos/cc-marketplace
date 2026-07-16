import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';
import { detectLaunch } from './detect.mjs';
import {
  allocatePort,
  devCommandFor,
  probe,
  reuseOrLaunch,
  startDevServer,
} from './server.mjs';
import { launchTarget } from './index.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const FIX = path.join(here, '__fixtures__');
const VITE_APP = path.join(FIX, 'vite-app');
const BARE = path.join(FIX, 'bare');
const FAKE = path.join(FIX, 'fake-dev-server.mjs');
const BOOT = 8000;

// A run-unique temp dir so lock files never touch the repo tree.
function tmpProject(): string {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'vc-launch-'));
}
const isAlive = (pid: number): boolean => {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
};

// ---- Detection (design-preview table) --------------------------------------

test('detectLaunch: a real Vite+React fixture is launchable with all four signals', () => {
  const d = detectLaunch(VITE_APP);
  assert.equal(d.launchable, true, d.reason);
  assert.equal(d.checks.vite.ok, true);
  assert.equal(d.checks.react.ok, true);
  assert.equal(d.checks.devScript.ok, true);
  assert.equal(d.checks.componentPaths.ok, true);
  assert.equal(d.devScript?.name, 'dev');
  assert.equal(d.port, 5173);
});

test('detectLaunch: a bare dir (no vite, no dev script) is NOT launchable', () => {
  const d = detectLaunch(BARE);
  assert.equal(d.launchable, false);
  assert.match(d.reason, /not launchable/);
  assert.equal(d.checks.vite.ok, false);
  assert.equal(d.checks.devScript.ok, false);
});

test('detectLaunch: vite present but no dev script → not launchable (all-four rule)', () => {
  const dir = tmpProject();
  fs.writeFileSync(path.join(dir, 'vite.config.ts'), "import react from '@vitejs/plugin-react';\nexport default { plugins: [react()] };\n");
  fs.writeFileSync(path.join(dir, 'package.json'), JSON.stringify({ devDependencies: { vite: '^5', '@vitejs/plugin-react': '^4' }, scripts: { build: 'vite build' } }));
  fs.mkdirSync(path.join(dir, 'src', 'components'), { recursive: true });
  const d = detectLaunch(dir);
  assert.equal(d.checks.vite.ok, true);
  assert.equal(d.checks.devScript.ok, false, 'no scripts.dev/start running vite');
  assert.equal(d.launchable, false);
});

test('detectPort: an explicit --port in the dev script overrides the 5173 default', () => {
  const dir = tmpProject();
  fs.writeFileSync(path.join(dir, 'vite.config.ts'), "import react from '@vitejs/plugin-react';\nexport default { plugins: [react()] };\n");
  fs.writeFileSync(path.join(dir, 'package.json'), JSON.stringify({ devDependencies: { vite: '^5', '@vitejs/plugin-react': '^4' }, scripts: { dev: 'vite --port 4000' } }));
  fs.mkdirSync(path.join(dir, 'src', 'components'), { recursive: true });
  assert.equal(detectLaunch(dir).port, 4000);
});

test('devCommandFor builds `npm run <script> -- --port <p> --strictPort` (production launch)', () => {
  const cmd = devCommandFor({ devScript: { name: 'dev' } }, 4321);
  assert.deepEqual(cmd, ['npm', 'run', 'dev', '--', '--port', '4321', '--strictPort']);
});

// ---- Concurrency: run-unique ports -----------------------------------------

test('allocatePort hands out distinct free ports while one is held (concurrency-safe)', async () => {
  const p1 = await allocatePort();
  const p2 = await allocatePort();
  assert.ok(p1 > 0 && p2 > 0);
  // Not guaranteed distinct in general, but the OS won't hand out a bound port:
  // hold p1 open and confirm the next allocation avoids it.
  const net = await import('node:net');
  const held = net.createServer().listen(p1, '127.0.0.1');
  await new Promise((r) => held.once('listening', r));
  const p3 = await allocatePort();
  assert.notEqual(p3, p1, 'a held port is never re-handed');
  held.close();
});

// ---- Cold start: launch → serve → reap (real child process) ----------------

test('cold start: startDevServer spawns, waits for the ready line, serves, then stop() reaps it', async () => {
  const dir = tmpProject();
  const port = await allocatePort();
  const handle = await startDevServer({
    command: ['node', FAKE, '--port', String(port)],
    cwd: dir,
    projectDir: dir,
    url: `http://localhost:${port}/`,
    port,
    bootTimeoutMs: BOOT,
  });
  assert.equal(handle.started, true);
  assert.ok(handle.pid && handle.pid > 0);
  assert.equal(isAlive(handle.pid), true, 'child running after ready');
  assert.equal(await probe(handle.url), true, 'server answers HTTP');
  // A lock file records the launched pid/port for crash recovery.
  const locks = fs.readdirSync(path.join(dir, '.visual-check', 'launch'));
  assert.ok(locks.some((f) => f.endsWith('.lock')), 'lock file written');

  const pid = handle.pid;
  await handle.stop();
  assert.equal(isAlive(pid), false, 'process is gone afterward');
  assert.equal(await probe(handle.url), false, 'server no longer answers');
});

test('probe-only fallback: a server with no recognizable ready line still resolves via probe', async () => {
  const dir = tmpProject();
  const port = await allocatePort();
  const handle = await startDevServer({
    command: ['node', FAKE, '--port', String(port), '--no-ready-line'],
    cwd: dir,
    projectDir: dir,
    url: `http://localhost:${port}/`,
    port,
    bootTimeoutMs: BOOT,
  });
  const pid = handle.pid;
  assert.equal(await probe(handle.url), true);
  await handle.stop();
  assert.equal(isAlive(pid), false);
});

// ---- Warm reuse: a foreign server is reused and NOT stopped -----------------

test('warm reuse: an already-running dev server is reused, and stop() NEVER kills it', async () => {
  const dir = tmpProject();
  const port = await allocatePort();
  // Stand in for the user's own already-running dev server.
  const foreign = await startDevServer({
    command: ['node', FAKE, '--port', String(port)],
    cwd: dir,
    projectDir: dir,
    url: `http://localhost:${port}/`,
    port,
    bootTimeoutMs: BOOT,
  });

  const result = await reuseOrLaunch({
    projectDir: dir,
    detection: { launchable: true, port, devScript: { name: 'dev' } },
    routePath: 'sub/page',
  });
  assert.equal(result.started, false, 'reused, not launched');
  assert.equal(result.reused, true);
  assert.equal(result.pid, null, 'no child owned by this run');
  assert.equal(result.url, `http://localhost:${port}/sub/page`);

  await result.stop(); // must be a no-op
  assert.equal(isAlive(foreign.pid), true, 'foreign server still alive after reuse stop');
  assert.equal(await probe(`http://localhost:${port}/`), true);

  await foreign.stop(); // cleanup: only the run that started it reaps it
  assert.equal(isAlive(foreign.pid), false);
});

test('cold launch via reuseOrLaunch: free port probed, launched on a run-unique port, reaped on stop', async () => {
  const dir = tmpProject();
  const freeDefault = await allocatePort(); // nothing listens here → probe fails → launch
  const handle = await reuseOrLaunch({
    projectDir: dir,
    detection: { launchable: true, port: freeDefault, devScript: { name: 'dev' } },
    reusePort: freeDefault,
    spawnCommand: (p: number) => ['node', FAKE, '--port', String(p)],
    bootTimeoutMs: BOOT,
  });
  assert.equal(handle.started, true, 'launched because nothing was reusable');
  assert.notEqual(handle.port, freeDefault, 'ran on its own run-unique port, not the probed default');
  const pid = handle.pid;
  assert.equal(await probe(handle.url), true);
  await handle.stop();
  assert.equal(isAlive(pid), false, 'no orphaned node after cold launch');
});

// ---- Bare dir: no --url, not detectable → provide-a-url (caller exits 2) ----

test('launchTarget on a bare dir returns ok:false with a "provide a --url" reason', async () => {
  const r = await launchTarget({ projectDir: BARE });
  assert.equal(r.ok, false);
  assert.match(r.reason ?? '', /provide a --url/i);
  assert.equal(r.detection.launchable, false);
});

test('launchTarget on a launchable project reuses/launches and hands back a URL', async () => {
  const dir = tmpProject();
  const freeDefault = await allocatePort();
  const r = await launchTarget({
    projectDir: VITE_APP,
    reusePort: freeDefault,
    spawnCommand: (p: number) => ['node', FAKE, '--port', String(p)],
    bootTimeoutMs: BOOT,
  });
  assert.equal(r.ok, true, r.reason);
  assert.equal(r.started, true);
  assert.match(r.url ?? '', /^http:\/\/localhost:\d+\//);
  const pid = (r as { port?: number }).port;
  assert.ok(pid);
  assert.equal(await probe(r.url as string), true);
  await r.stop?.();
  assert.equal(await probe(r.url as string), false, 'self-started server reaped');
  void dir;
});
