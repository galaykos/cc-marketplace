// No-`--url` launch entry (card 11). The single call `bin/visual-check.mjs` makes
// when the run has no target URL: detect a launchable dev project, then reuse a
// running server or background-start one, handing back a URL for the existing
// capture flow — and a `stop()` that reaps ONLY a server this run started.
//
// Not launchable → `{ ok:false, reason }` carrying a "provide a --url" message so
// the caller can exit 2 (error), never hang.

import { detectLaunch } from './detect.mjs';
import { reuseOrLaunch } from './server.mjs';

export { detectLaunch } from './detect.mjs';
export {
  allocatePort,
  devCommandFor,
  probe,
  reuseOrLaunch,
  startDevServer,
} from './server.mjs';

/**
 * @param {object} o
 * @param {string} o.projectDir  consumer project root to detect + launch in.
 * @param {string} [o.routePath] path appended to the dev URL (e.g. a route).
 * @param {number} [o.bootTimeoutMs]
 * @param {string[]} [o.spawnCommand] override the derived `npm run dev` (test hook).
 * @returns {Promise<{ ok:boolean, url?:string, started?:boolean, reused?:boolean,
 *   stop?:Function, stopSync?:Function, reason?:string, detection:object }>}
 */
export async function launchTarget(o) {
  const { projectDir, routePath = '', bootTimeoutMs, spawnCommand, reusePort } = o;
  const detection = detectLaunch(projectDir);

  if (!detection.launchable) {
    return {
      ok: false,
      reason: `no --url given and no launchable dev project detected (${detection.reason}) — provide a --url`,
      detection,
    };
  }

  try {
    const handle = await reuseOrLaunch({ projectDir, detection, routePath, bootTimeoutMs, spawnCommand, reusePort });
    return {
      ok: true,
      url: handle.url,
      port: handle.port,
      started: handle.started,
      reused: handle.reused,
      stop: handle.stop,
      stopSync: handle.stopSync,
      output: handle.output,
      detection,
    };
  } catch (err) {
    return {
      ok: false,
      reason: `dev server did not come up: ${err && err.message ? err.message : err} — provide a --url`,
      detection,
    };
  }
}
