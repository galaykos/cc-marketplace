/* axe-run.mjs — renders a URL or local HTML file in Chromium through the project's own Playwright or puppeteer, runs axe-core's WCAG 2.x A/AA rules, prints one line per failing element (or --json); installs nothing.
   Exit 0 no violation, 1 violations, 2 usage, 3 a piece missing from the project (named on stderr), 4 the page, a main-frame script or stylesheet, or axe failed. Misses what axe cannot test (keyboard flow, screen-reader output, meaning), iframe content (counted, not tested), states absent at load, dark mode.
   Why, limits, history: rationale/derivations/plugin-ui-ux.md § plugins/ui-ux/scripts/axe-run.mjs */
import { createRequire } from 'node:module'
import { existsSync, statSync } from 'node:fs'
import { resolve, join } from 'node:path'
import { pathToFileURL, fileURLToPath } from 'node:url'

const USAGE = 'usage: [AXE_RUN_CHROMIUM=<chrome binary>] node axe-run.mjs [--json] <http(s)://url | file://url | path/to/page.html>   (run from the project root)'
const TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa']
const NAV_TIMEOUT_MS = 30000

const usage = (why) => { console.error(`axe-run: ${why}\n${USAGE}`); process.exit(2) }
const fail = (why) => { console.error(`axe-run: ${why}`); process.exit(4) }
class Stop extends Error {}

let json = false
let target = null
for (const a of process.argv.slice(2)) {
  if (a === '--json') json = true
  else if (a === '-h' || a === '--help') { console.log(USAGE); process.exit(0) }
  else if (a.startsWith('-')) usage(`unknown option ${a}`)
  else if (target !== null) usage('one target only')
  else target = a
}
if (!target) usage('no target given')

let url
if (/^[a-z][a-z0-9+.-]+:/i.test(target)) {
  let u
  try { u = new URL(target) } catch { usage(`not a URL: ${target}`) }
  if (u.protocol === 'file:') {
    let p
    try { p = fileURLToPath(u) } catch { usage(`not a local file URL: ${target} (file:///abs/path.html, or a path without file://)`) }
    if (!existsSync(p) || !statSync(p).isFile()) usage(`no such file: ${p}`)
  } else if (u.protocol !== 'http:' && u.protocol !== 'https:') usage(`unsupported scheme ${u.protocol} (give http://, https://, file:// or a path)`)
  url = u.href
} else {
  const p = resolve(process.cwd(), target)
  if (!existsSync(p) || !statSync(p).isFile()) usage(`no such file: ${p}`)
  url = pathToFileURL(p).href
}

const req = createRequire(join(process.cwd(), 'noop.js'))
const load = (r, id) => { try { return r(id) } catch { return null } }
const versionOf = (r, id) => { try { return r(`${id}/package.json`).version } catch { return '?' } }

let driver = null
for (const id of ['playwright', '@playwright/test', 'playwright-core', 'puppeteer']) {
  const m = load(req, id)
  const mod = m && (m.chromium || m.launch ? m : m.default)
  if (mod && (mod.chromium?.launch || mod.launch)) { driver = { id, mod, version: versionOf(req, id) }; break }
}

let axeSource = null
let axeFrom = null
for (const id of ['axe-core', '@axe-core/playwright', '@axe-core/puppeteer']) {
  let r = req
  if (id !== 'axe-core') {
    try { r = createRequire(req.resolve(id)) } catch { continue }
  }
  const m = load(r, 'axe-core')
  if (typeof m?.source === 'string' && m.source) { axeSource = m.source; axeFrom = id; break }
}

const missing = []
if (!driver) missing.push(`missing: browser driver — none of playwright, @playwright/test, playwright-core, puppeteer resolves from ${process.cwd()}`)
if (!axeSource) missing.push(`missing: axe-core — none of axe-core, @axe-core/playwright, @axe-core/puppeteer resolves from ${process.cwd()}`)
if (missing.length) {
  for (const m of missing) console.error(m)
  console.error('axe-run: not run; nothing was installed.')
  process.exit(3)
}

// Selectors carry page-authored ids and attributes: one line each, capped, printed quoted as data.
const clean = (s) => {
  const t = String(s).replace(/[\u0000-\u001f\u007f\u2028\u2029]/g, ' ')
  return t.length > 200 ? `${t.slice(0, 199)}…` : t
}
const selector = (t) => clean((Array.isArray(t) ? t : [t]).map((x) => (Array.isArray(x) ? x.join(' >>> ') : x)).join(' | '))
// The page can rewrite window.axe, so every axe field prints bare only in its known shape, else JSON-quoted.
const shape = (s, re) => (re.test(s) ? s : JSON.stringify(s))
const RULE_ID = /^[a-z0-9]+(-[a-z0-9]+)*$/
const IMPACT = /^(minor|moderate|serious|critical|unknown)$/
const HTTPS = /^https:\/\/[!#-[\]-~]+$/
const VERSION = /^\d+\.\d+\.\d+([-+][0-9A-Za-z.-]+)?$/
const WCAG_TAG = /^wcag\d+a*$/

const watchdog = setTimeout(() => fail(`timed out after ${(NAV_TIMEOUT_MS * 3) / 1000} s`), NAV_TIMEOUT_MS * 3)
watchdog.unref()

const pw = Boolean(driver.mod.chromium)
const exe = process.env.AXE_RUN_CHROMIUM || ''
const launchOpts = exe ? { headless: true, executablePath: exe } : { headless: true }
let browser
try {
  browser = pw ? await driver.mod.chromium.launch(launchOpts) : await driver.mod.launch(launchOpts)
} catch (e) {
  console.error(`missing: Chromium — ${driver.id} ${driver.version} could not launch ${exe ? `AXE_RUN_CHROMIUM=${exe}` : 'its own'}: ${clean(String(e?.message ?? e).split('\n')[0])}`)
  if (!exe) console.error('axe-run: AXE_RUN_CHROMIUM may name a Chrome or Chromium binary already on this machine.')
  console.error('axe-run: not run; nothing was installed.')
  process.exit(3)
}

let result
try {
  const page = pw ? await browser.newPage({ viewport: { width: 1280, height: 800 } }) : await browser.newPage()
  if (!pw) await page.setViewport({ width: 1280, height: 800 })
  page.on('dialog', (d) => { d.dismiss().catch(() => {}) })
  const broken = []
  const asset = (q) => { try { return q.frame() === page.mainFrame() && ['script', 'stylesheet'].includes(q.resourceType()) } catch { return false } }
  page.on('requestfailed', (q) => { if (asset(q)) broken.push(`${q.resourceType()} ${JSON.stringify(clean(q.url()))} ${clean(q.failure()?.errorText ?? 'failed')}`) })
  page.on('response', (r) => { if (r.status() >= 400 && asset(r.request())) broken.push(`${r.request().resourceType()} ${JSON.stringify(clean(r.request().url()))} HTTP ${r.status()}`) })
  let resp
  try {
    resp = await page.goto(url, { waitUntil: 'load', timeout: NAV_TIMEOUT_MS })
  } catch (e) {
    throw new Stop(`page did not load: ${JSON.stringify(clean(String(e?.message ?? e).split('\n')[0]))}`)
  }
  if (resp && resp.status() >= 400) throw new Stop(`page answered HTTP ${resp.status()}`)
  if (broken.length) throw new Stop(`${broken.length} script/stylesheet request(s) failed, so this is not the page as built (built output needs a server, e.g. vite preview):\n${broken.slice(0, 5).map((b) => `  failed: ${b}`).join('\n')}`)
  await page.evaluate(axeSource)
  result = await page.evaluate(async (tags) => {
    const r = await window.axe.run(document, { runOnly: { type: 'tag', values: tags }, resultTypes: ['violations'], iframes: false })
    return {
      axe: window.axe.version,
      violations: r.violations.map((v) => ({ id: v.id, impact: v.impact, tags: v.tags, help: v.help, helpUrl: v.helpUrl, targets: v.nodes.map((n) => n.target) })),
      incomplete: r.incomplete.map((v) => v.id),
    }
  }, TAGS)
  result.framesSkipped = page.frames().length - 1
} catch (e) {
  await browser.close().catch(() => {})
  fail(e instanceof Stop ? e.message : `the page or axe threw: ${JSON.stringify(clean(String(e?.message ?? e).split('\n')[0]))}`)
}
await browser.close().catch(() => {})

const violations = result.violations.map((v) => ({
  id: clean(v.id), impact: clean(v.impact ?? 'unknown'), tags: [].concat(v.tags ?? []).filter((t) => WCAG_TAG.test(t)),
  help: clean(v.help), helpUrl: clean(v.helpUrl), targets: v.targets.map(selector),
}))
const elements = violations.reduce((n, v) => n + v.targets.length, 0)

if (json) {
  console.log(JSON.stringify({
    url, driver: `${driver.id}@${driver.version}`, axe: clean(result.axe), axeFrom, tags: TAGS,
    violations, incomplete: result.incomplete.map(clean), framesSkipped: result.framesSkipped,
  }, null, 2))
} else {
  console.log(`rendered: ${url} (${driver.id} ${driver.version}, axe-core ${shape(clean(result.axe), VERSION)} via ${axeFrom})`)
  for (const v of violations) {
    for (const t of v.targets) console.log(`${shape(v.id, RULE_ID)}  ${shape(v.impact, IMPACT)}  ${v.tags.join(',') || '-'}  ${JSON.stringify(t)}  ${shape(v.helpUrl, HTTPS)}`)
  }
  if (result.incomplete.length) console.log(`incomplete (check by hand): ${result.incomplete.map((x) => shape(clean(x), RULE_ID)).join(', ')}`)
  if (result.framesSkipped) console.log(`${result.framesSkipped} iframe(s) not tested: axe ran in the top frame only.`)
  console.log(violations.length
    ? `${elements} failing element(s) across ${violations.length} rule(s).`
    : 'OK: axe found no WCAG 2.x A/AA violation on this render.')
}
process.exitCode = violations.length ? 1 : 0
