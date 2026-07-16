// Dev-server lifecycle (card 11) — the reuse-don't-kill doctrine from
// design-preview's real-preview SKILL, made executable:
//
//   - A dev server already up on the project's port? REUSE it (probe, no restart).
//     NEVER kill or restart a server this run did not start.
//   - Otherwise background-start the dev script on a RUN-UNIQUE free port
//     (concurrency-safe: two runs never fight over one port), wait for the ready
//     line OR a live probe, hand back the URL, and on stop kill ONLY that child.
//   - A lock file records {pid, port} so a crashed run's leftovers are reap-able.
//
// The command to spawn is injectable so the lifecycle can be exercised with a
// dependency-free Vite-shaped stand-in when a real `vite` binary is unavailable.

import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import * as fs from 'node:fs';
import * as http from 'node:http';
import * as https from 'node:https';
import * as net from 'node:net';
import * as path from 'node:path';

const DEFAULT_BOOT_TIMEOUT_MS = 30_000;
const STOP_GRACE_MS = 4_000;
// A Vite (or Vite-shaped) ready line: "➜  Local:   http://localhost:5173/".
const READY_LINE = /(Local:\s*)(https?:\/\/\S+)|ready in\s|localhost:\d+/i;

/** Resolve to a free ephemeral port the OS hands out (run-unique by construction). */
export function allocatePort() {
  return new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.on('error', reject);
    srv.listen(0, '127.0.0.1', () => {
      const { port } = srv.address();
      srv.close(() => resolve(port));
    });
  });
}

/** True when an HTTP(S) GET to `url` gets ANY response (server is up). */
export function probe(url, { timeoutMs = 1500 } = {}) {
  return new Promise((resolve) => {
    let u;
    try {
      u = new URL(url);
    } catch {
      return resolve(false);
    }
    const lib = u.protocol === 'https:' ? https : http;
    const req = lib.get(u, { timeout: timeoutMs }, (res) => {
      res.resume(); // drain
      resolve(true);
    });
    req.on('timeout', () => {
      req.destroy();
      resolve(false);
    });
    req.on('error', () => resolve(false));
  });
}

/** The production dev command: `npm run <script> -- --port <p> --strictPort`. */
export function devCommandFor(detection, port) {
  const script = (detection.devScript && detection.devScript.name) || 'dev';
  return ['npm', 'run', script, '--', '--port', String(port), '--strictPort'];
}

function lockDir(projectDir) {
  return path.join(projectDir, '.visual-check', 'launch');
}

function writeLock(projectDir, info) {
  const dir = lockDir(projectDir);
  fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, `${process.pid}-${randomUUID()}.lock`);
  fs.writeFileSync(file, JSON.stringify({ ...info, at: Date.now() }) + '\n');
  return file;
}

function removeLock(file) {
  if (!file) return;
  try {
    fs.rmSync(file, { force: true });
  } catch {
    /* best-effort */
  }
}

/** True while the process (group leader) is still alive. */
function alive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

/**
 * Spawn a dev command in the background and resolve once it is ready (ready line
 * seen OR a live probe of `url` succeeds), whichever comes first. Rejects if the
 * child exits first or the boot budget elapses (stopping the child either way).
 * Returns a handle: `{ pid, url, port, started:true, stop(), stopSync(), output() }`.
 */
export function startDevServer(o) {
  const {
    command,
    cwd,
    url,
    port,
    projectDir = cwd,
    bootTimeoutMs = DEFAULT_BOOT_TIMEOUT_MS,
    env,
  } = o;

  return new Promise((resolve, reject) => {
    const [cmd, ...args] = command;
    // detached: the child leads its own process group so a single group-signal
    // reaps npm AND its `vite` grandchild — no orphaned node left behind.
    const child = spawn(cmd, args, {
      cwd,
      env: { ...process.env, ...env },
      detached: true,
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let out = '';
    let settled = false;
    let stopped = false;
    let lockFile = null;
    let probeTimer = null;
    let bootTimer = null;

    const capture = (buf) => {
      out += buf.toString();
      if (!settled && READY_LINE.test(out)) succeed();
    };
    child.stdout.on('data', capture);
    child.stderr.on('data', capture);

    const cleanupWaiters = () => {
      if (probeTimer) clearInterval(probeTimer);
      if (bootTimer) clearTimeout(bootTimer);
      probeTimer = bootTimer = null;
    };

    const stopSync = () => {
      if (stopped) return;
      stopped = true;
      cleanupWaiters();
      try {
        process.kill(-child.pid, 'SIGKILL'); // whole group
      } catch {
        try {
          child.kill('SIGKILL');
        } catch {
          /* already gone */
        }
      }
      removeLock(lockFile);
    };

    const stop = async () => {
      if (stopped) return;
      stopped = true;
      cleanupWaiters();
      const pid = child.pid;
      try {
        process.kill(-pid, 'SIGTERM'); // ask the group to leave
      } catch {
        /* already gone */
      }
      const gone = await waitForExit(child, pid, STOP_GRACE_MS);
      if (!gone) {
        try {
          process.kill(-pid, 'SIGKILL');
        } catch {
          /* raced */
        }
        await waitForExit(child, pid, 1000);
      }
      removeLock(lockFile);
    };

    const handle = () => ({
      pid: child.pid,
      url,
      port,
      started: true,
      reused: false,
      stop,
      stopSync,
      output: () => out,
    });

    function succeed() {
      if (settled) return;
      settled = true;
      cleanupWaiters();
      lockFile = writeLock(projectDir, { pid: child.pid, port, url });
      resolve(handle());
    }

    child.on('error', (err) => {
      if (settled) return;
      settled = true;
      cleanupWaiters();
      reject(new Error(`could not spawn dev server (${command.join(' ')}): ${err.message}`));
    });

    child.on('exit', (code, signal) => {
      if (settled) return;
      settled = true;
      cleanupWaiters();
      reject(new Error(`dev server exited before ready (code=${code} signal=${signal})\n${out.slice(-400)}`));
    });

    // Probe fallback: some servers do not print a recognizable ready line.
    if (url) {
      probeTimer = setInterval(async () => {
        if (settled) return;
        if (await probe(url, { timeoutMs: 800 })) succeed();
      }, 300);
    }

    bootTimer = setTimeout(() => {
      if (settled) return;
      settled = true;
      cleanupWaiters();
      stopSync();
      reject(new Error(`dev server not ready within ${bootTimeoutMs}ms\n${out.slice(-400)}`));
    }, bootTimeoutMs);
  });
}

function waitForExit(child, pid, ms) {
  return new Promise((resolve) => {
    if (!alive(pid)) return resolve(true);
    let done = false;
    const finish = (v) => {
      if (done) return;
      done = true;
      resolve(v);
    };
    child.once('exit', () => finish(true));
    const t = setInterval(() => {
      if (!alive(pid)) {
        clearInterval(t);
        finish(true);
      }
    }, 100);
    setTimeout(() => {
      clearInterval(t);
      finish(!alive(pid));
    }, ms);
  });
}

/** A no-op handle for a reused (foreign) server — stop() must NEVER kill it. */
function reusedHandle(url, port) {
  return {
    pid: null,
    url,
    port,
    started: false,
    reused: true,
    stop: async () => {},
    stopSync: () => {},
    output: () => '',
  };
}

function joinUrl(port, routePath) {
  const base = `http://localhost:${port}/`;
  const rel = String(routePath || '').replace(/^\//, '');
  return rel ? base + rel : base;
}

/**
 * Reuse-or-launch. Probe the project's dev port first; if a server answers,
 * REUSE it (started:false — stop() is a no-op). Otherwise launch on a run-unique
 * free port and return a handle whose stop() reaps ONLY the child this run spawned.
 * `spawnCommand` overrides the derived `npm run dev` (used to inject a stand-in).
 */
export async function reuseOrLaunch(o) {
  const {
    projectDir,
    detection,
    routePath = '',
    bootTimeoutMs = DEFAULT_BOOT_TIMEOUT_MS,
    spawnCommand = null,
    reusePort = detection && detection.port,
  } = o;

  const port = reusePort || 5173;
  if (await probe(joinUrl(port, ''), { timeoutMs: 1200 })) {
    return reusedHandle(joinUrl(port, routePath), port);
  }

  const freePort = await allocatePort();
  const command =
    typeof spawnCommand === 'function'
      ? spawnCommand(freePort)
      : spawnCommand || devCommandFor(detection, freePort);
  const url = joinUrl(freePort, routePath);
  return startDevServer({
    command,
    cwd: projectDir,
    projectDir,
    url,
    port: freePort,
    bootTimeoutMs,
  });
}
