// Launch detection (card 11). Decides whether a --url-less run can render the
// consumer's app by launching its own dev server. The rule set is the
// AUTHORITATIVE table from design-preview's real-preview SKILL (a declared
// dependency): reference its patterns, never `npm install` to make detection
// pass, never execute the consumer's config to read it.
//
//   | Vite present    | vite.config.{ts,js,mjs} exists AND `vite` in (dev)deps |
//   | React wired     | @vitejs/plugin-react(-swc) in the config's plugins     |
//   | Dev script      | package.json scripts.dev (or .start) runs vite         |
//   | Component paths  | components.json, tsconfig paths, or src/components/    |
//
// ALL four must hold for `launchable`. Anything failing → the caller falls back
// to "give me a --url" (never a hang). Pure + IO-only-reads: unit-testable.

import * as fs from 'node:fs';
import * as path from 'node:path';

const VITE_CONFIG_NAMES = [
  'vite.config.ts', 'vite.config.js', 'vite.config.mjs',
  'vite.config.cjs', 'vite.config.mts', 'vite.config.cts',
];

function readText(p) {
  try {
    return fs.readFileSync(p, 'utf8');
  } catch {
    return null;
  }
}

function readJson(p) {
  const raw = readText(p);
  if (raw == null) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function existsDir(p) {
  try {
    return fs.statSync(p).isDirectory();
  } catch {
    return false;
  }
}

/** Locate the vite config file, if any. */
function findViteConfig(projectDir) {
  for (const name of VITE_CONFIG_NAMES) {
    const full = path.join(projectDir, name);
    if (fs.existsSync(full)) return full;
  }
  return null;
}

function hasDep(pkg, name) {
  if (!pkg) return false;
  return Boolean(
    (pkg.devDependencies && pkg.devDependencies[name]) ||
      (pkg.dependencies && pkg.dependencies[name]) ||
      (pkg.peerDependencies && pkg.peerDependencies[name]),
  );
}

/** Vite present: a config file AND `vite` declared as a dependency. */
function checkVite(projectDir, pkg) {
  const configFile = findViteConfig(projectDir);
  const dep = hasDep(pkg, 'vite');
  return {
    ok: Boolean(configFile) && dep,
    configFile,
    evidence: configFile
      ? `${path.basename(configFile)}${dep ? ' + vite dependency' : ' but no vite dependency'}`
      : 'no vite.config.{ts,js,mjs}',
  };
}

/** React wired: the react plugin appears in the config text or the deps. */
function checkReact(configFile, pkg) {
  const text = configFile ? readText(configFile) : null;
  const inConfig = text ? /@vitejs\/plugin-react(-swc)?/.test(text) : false;
  const inDeps = hasDep(pkg, '@vitejs/plugin-react') || hasDep(pkg, '@vitejs/plugin-react-swc');
  return {
    ok: inConfig || inDeps,
    evidence: inConfig
      ? '@vitejs/plugin-react in config'
      : inDeps
        ? '@vitejs/plugin-react in dependencies'
        : 'no @vitejs/plugin-react',
  };
}

/** Dev script: scripts.dev (preferred) or scripts.start whose body runs vite. */
function checkDevScript(pkg) {
  const scripts = (pkg && pkg.scripts) || {};
  for (const name of ['dev', 'start']) {
    const body = scripts[name];
    if (typeof body === 'string' && /\bvite\b/.test(body)) {
      return { ok: true, name, body, evidence: `scripts.${name}: ${body}` };
    }
  }
  return { ok: false, name: null, body: null, evidence: 'no scripts.dev/start running vite' };
}

/** Component paths: components.json, tsconfig paths, or a src/components/ dir. */
function checkComponentPaths(projectDir) {
  if (fs.existsSync(path.join(projectDir, 'components.json'))) {
    return { ok: true, evidence: 'components.json aliases' };
  }
  for (const tsc of ['tsconfig.json', 'tsconfig.app.json']) {
    const cfg = readJson(path.join(projectDir, tsc));
    if (cfg && cfg.compilerOptions && cfg.compilerOptions.paths) {
      return { ok: true, evidence: `${tsc} compilerOptions.paths` };
    }
  }
  if (existsDir(path.join(projectDir, 'src', 'components'))) {
    return { ok: true, evidence: 'src/components/' };
  }
  return { ok: false, evidence: 'no components.json / tsconfig paths / src/components/' };
}

/**
 * Parse the reuse port: an explicit `--port <n>` in the dev script wins, else
 * `server.port` in the vite config text, else Vite's default 5173. This is the
 * port a *foreign* already-running dev server is probed on before launching.
 */
function detectPort(devBody, configFile) {
  if (devBody) {
    const m = /--port(?:[=\s]+)(\d{2,5})/.exec(devBody);
    if (m) return Number(m[1]);
  }
  const text = configFile ? readText(configFile) : null;
  if (text) {
    const m = /server\s*:\s*\{[^}]*\bport\s*:\s*(\d{2,5})/s.exec(text);
    if (m) return Number(m[1]);
  }
  return 5173;
}

/**
 * Inspect `projectDir` against the real-preview detection table.
 * Returns `{ launchable, checks, devScript, port, reason }`.
 */
export function detectLaunch(projectDir) {
  const dir = path.resolve(projectDir);
  const pkg = readJson(path.join(dir, 'package.json'));

  const vite = checkVite(dir, pkg);
  const react = checkReact(vite.configFile, pkg);
  const devScript = checkDevScript(pkg);
  const componentPaths = checkComponentPaths(dir);

  const checks = { vite, react, devScript, componentPaths };
  const launchable = vite.ok && react.ok && devScript.ok && componentPaths.ok;
  const failed = Object.entries(checks)
    .filter(([, c]) => !c.ok)
    .map(([k, c]) => `${k}: ${c.evidence}`);

  return {
    launchable,
    checks,
    devScript: devScript.ok ? { name: devScript.name, body: devScript.body } : null,
    port: detectPort(devScript.body, vite.configFile),
    reason: launchable ? 'vite dev project' : `not launchable — ${failed.join('; ')}`,
  };
}
