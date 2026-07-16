// `--init` scaffolding (spec A5). Writes a starter `.visual-check/config.json` (the
// documented shape: threshold, viewports, mask, allowLlmEngine) plus an example
// scenario into the consumer's project. Idempotent: an existing file is kept, never
// clobbered. The harness bin (bin/visual-check.mjs) calls this and announces writes.

import * as fs from 'node:fs';
import * as path from 'node:path';
import { CONFIG_DIR, CONFIG_FILE } from './loader.ts';

export const EXAMPLE_SCENARIO_FILE = 'example.scenario.yaml';

/** Starter config.json — the built-in defaults made explicit so authors can edit them.
 *  Viewports match the card-03 harness defaults (desktop 1280x800, mobile 375x812). */
export const STARTER_CONFIG = {
  threshold: 0.01,
  viewports: [
    { name: 'desktop', width: 1280, height: 800 },
    { name: 'mobile', width: 375, height: 812 },
  ],
  mask: ['#ad', '.timestamp'],
  allowLlmEngine: true,
} as const;

export const EXAMPLE_SCENARIO = `# Example visual-check scenario. Copy + adapt: point 'url' at your page, list the
# steps to drive, and 'match' captures a screenshot keyed <id>__<stepIndex>__<viewport>.
# threshold / viewports / mask are inherited from .visual-check/config.json unless
# overridden here (chain: CLI flag > this file > config.json > default).
id: home
url: http://localhost:3000/
engine: auto
steps:
  - goto: /
    match: { source: baseline, ref: baselines/home.png }
  - expect:
      dom:
        - { selector: "main", state: visible }
      console: clean
      layout: no-overflow
    match: { source: baseline, ref: baselines/home-loaded.png }
`;

export type InitResult = { created: string[]; skipped: string[]; dir: string };

/** Scaffold the starter config + example scenario under `<baseDir>/.visual-check/`.
 *  Returns the paths written (created) and the ones already present (skipped). */
export function initProject(baseDir: string): InitResult {
  const dir = path.join(baseDir, CONFIG_DIR);
  fs.mkdirSync(dir, { recursive: true });
  const created: string[] = [];
  const skipped: string[] = [];
  const write = (name: string, content: string): void => {
    const p = path.join(dir, name);
    if (fs.existsSync(p)) {
      skipped.push(p);
      return;
    }
    fs.writeFileSync(p, content);
    created.push(p);
  };
  write(CONFIG_FILE, JSON.stringify(STARTER_CONFIG, null, 2) + '\n');
  write(EXAMPLE_SCENARIO_FILE, EXAMPLE_SCENARIO);
  return { created, skipped, dir };
}
