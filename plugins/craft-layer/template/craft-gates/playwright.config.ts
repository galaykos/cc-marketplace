/* craft-layer — the config that makes `gates.spec.ts` RUNNABLE FROM THE PLUGIN.
 * ---------------------------------------------------------------------------
 * WHAT IT CATCHES. Playwright has no `--spec <file>` flag: a bare
 * `npx playwright test` in a crafted project scans THAT project's testDir, finds
 * no craft gate, and exits 0 having run nothing — the failure mode `commands/audit.md`
 * step 4 calls "a gate never run", reported as green. Pointing `--config` at this
 * file makes the directory holding the spec the testDir, so the suite that runs is
 * the plugin's, at the plugin's version, with no copy to go stale.
 *
 * WHAT IT DOES NOT DO. It cannot supply the dependencies, and it cannot find
 * them either. Node resolves `@playwright/test` and `@axe-core/playwright` by
 * walking up from THIS FILE — inside the installed plugin, which has no
 * `node_modules` — so both this config and the spec beside it die with
 * MODULE_NOT_FOUND unless the caller exports `NODE_PATH=<project>/node_modules`.
 * That is why `commands/audit.md` step 4 carries it; measured 2026-09-22, the
 * invocation without it never reaches a single test. It also proves nothing
 * about WHICH build answers at BASE_URL — that is `CRAFT_EXPECT_TITLE`'s job,
 * inside the spec.
 *
 * Two paths, resolved against different roots on purpose:
 *  - `testDir` is relative, and Playwright resolves config paths against the
 *    CONFIG's directory — so `.` is this directory and the spec beside it is the
 *    whole suite, wherever the plugin is installed.
 *  - `outputDir` is pinned under the PROJECT's cwd. The default, `test-results/`
 *    beside the config, would have the gate writing into the installed plugin —
 *    the tree audit.md step 4 treats as read-only. The spec's own screenshots
 *    already go to `<cwd>/.craft-layer/shots`, where audit.md step 5 looks.
 */
import { defineConfig } from '@playwright/test'
import { resolve } from 'node:path'

export default defineConfig({
  testDir: '.',
  testMatch: /gates\.spec\.ts$/,
  outputDir: resolve(process.cwd(), '.craft-layer/test-results'),
  reporter: [['list']],
})
