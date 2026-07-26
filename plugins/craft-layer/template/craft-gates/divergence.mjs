/* Craft audit — the anti-attractor divergence gate.
   ---------------------------------------------------------------------------
   Every other craft judgement except contrast and axe is prose graded by a
   reading agent, so "do not land on the model's default" has been advice. This
   script is the teeth: it reads the shipped token source, the project's run log
   and the run's recorded deck draw, and EXITS NON-ZERO when the build landed on
   the category default or repeated its own last five runs.

   Run from the project root:

       node scripts/divergence.mjs

   MISSING TOKEN SOURCE EXITS NON-ZERO — the deliberate divergence from its
   sibling `contrast.mjs`, which prints `not measured (token missing)` and exits
   0. That precedent is right for a per-pairing check inside a file that was
   found; it is wrong here. A gate whose whole subject is "the build defaulted"
   cannot treat "I could not find the build" as a pass: a silent pass on a
   missing or unparseable file is exactly the failure teeth exist to end. If the
   token source lives somewhere unusual, point `CRAFT_TOKEN_SOURCE` at it.

   Environment:
     CRAFT_TOKEN_SOURCE       explicit path to the CSS holding the tokens
     CLAUDE_PLUGIN_ROOT       craft-layer's root; makes the anti-corpus LIVE
     CRAFT_CONTRACT           explicit path to the persisted offer contract
     CRAFT_DIVERGENCE_RECORD  explicit path to the persisted divergence record

   Exit codes: 0 clean · 1 one or more assertions failed · 2 not measured.
*/
import { readFileSync, existsSync, statSync, readdirSync } from 'node:fs'
import { join, dirname, basename, resolve } from 'node:path'

/* ------------------------------------------------------------- anti-corpus */

/* Embedded fallback ONLY. The registry is refreshed per craft-layer release and
   "never refreshing" is one of its own anti-patterns, so a copy frozen into a
   template would silently freeze the gate at this date. Both the source used and
   its date are printed on every run so a stale snapshot is visible, never
   assumed. */
const SNAPSHOT = {
  date: '2026-07-26',
  familyText: [
    'The neutral geometric/grotesque UI sans that generated pages reach for',
    'first — Inter and Geist by name, and any face chosen because it is what a',
    'starter template shipped with. The two-family serif-display-over-grotesque',
    'pairing reached for as the house move rather than derived.',
  ].join(' '),
}

/* The category-default accent band. Violet/indigo is the hue generated pages
   converged on; it does not age out on the recency window (see the registry's
   category-default note). Angles are read in the token's OWN space — 275-315
   covers indigo-to-violet in oklch and violet-to-purple in hsl/hex, which is
   the same tell either way. */
const DEFAULT_BAND = [275, 315]

function loadAntiCorpus() {
  const root = process.env.CLAUDE_PLUGIN_ROOT
  if (root) {
    const p = join(root, 'skills/creative-direction/references/sameness-fingerprint.md')
    if (existsSync(p)) {
      const text = readFileSync(p, 'utf8')
      const m = text.match(/###\s*Type families[\s\S]*?(?=\n##|\n###|$)/i)
      return {
        source: p,
        kind: 'live registry',
        date: statSync(p).mtime.toISOString().slice(0, 10),
        familyText: m ? m[0] : text,
      }
    }
  }
  return {
    source: 'embedded snapshot (CLAUDE_PLUGIN_ROOT unset or registry missing)',
    kind: 'frozen snapshot',
    date: SNAPSHOT.date,
    familyText: SNAPSHOT.familyText,
  }
}

/* ------------------------------------------------------------ token source */

const TOKEN_CANDIDATES = [
  process.env.CRAFT_TOKEN_SOURCE,
  'src/index.css',
  'src/app.css',
  'app/globals.css',
  'resources/css/app.css',
  'assets/css/main.css',
].filter(Boolean)

function findTokenSource() {
  for (const c of TOKEN_CANDIDATES) {
    const p = resolve(process.cwd(), c)
    if (existsSync(p) && statSync(p).isFile()) return p
  }
  return null
}

/* ------------------------------------------------------------ hue plumbing */

const norm = (h) => ((h % 360) + 360) % 360

const WHEEL = [
  [345, 360, 'red'], [0, 15, 'red'], [15, 45, 'orange'], [45, 70, 'amber'],
  [70, 100, 'lime'], [100, 150, 'green'], [150, 190, 'teal'], [190, 210, 'cyan'],
  [210, 265, 'blue'], [265, 290, 'indigo'], [290, 320, 'violet'], [320, 345, 'magenta'],
]
const hueFamily = (h) => (WHEEL.find(([a, b]) => norm(h) >= a && norm(h) < b) ?? [, , 'unknown'])[2]

const num = (s) => parseFloat(String(s).replace(/deg|%/g, ''))

/** oklch(L C H) / hsl(H S% L%) / #rrggbb -> hue angle, or null when achromatic. */
function toHue(value) {
  const v = value.trim()
  let m = v.match(/^oklch\(\s*([^\s,]+)[\s,]+([^\s,]+)[\s,]+([^\s,)/]+)/i)
  if (m) return num(m[2]) === 0 ? null : norm(num(m[3]))
  m = v.match(/^hsla?\(\s*([^\s,]+)[\s,]+([^\s,]+)[\s,]+([^\s,)/]+)/i)
  if (m) return num(m[2]) === 0 ? null : norm(num(m[1]))
  m = v.match(/^#([0-9a-f]{6})\b/i)
  if (m) {
    const [r, g, b] = [0, 2, 4].map((i) => parseInt(m[1].slice(i, i + 2), 16) / 255)
    const max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min
    if (d === 0) return null
    let h
    if (max === r) h = 60 * (((g - b) / d) % 6)
    else if (max === g) h = 60 * ((b - r) / d + 2)
    else h = 60 * ((r - g) / d + 4)
    return norm(h)
  }
  return null
}

/** Accent-ish custom properties, in declaration order. */
function readAccents(css) {
  const out = []
  for (const m of css.matchAll(/(--[\w-]+)\s*:\s*([^;}]+)/g)) {
    const name = m[1]
    if (!/accent|primary|brand/i.test(name)) continue
    const hue = toHue(m[2])
    if (hue === null) continue
    out.push({ name, value: m[2].trim(), hue, family: hueFamily(hue) })
  }
  return out
}

const SYSTEM_STACK = new Set([
  'system-ui', 'ui-sans-serif', 'ui-serif', 'ui-monospace', 'ui-rounded',
  '-apple-system', 'blinkmacsystemfont', 'segoe ui', 'roboto', 'helvetica neue',
  'helvetica', 'arial', 'noto sans', 'liberation sans', 'apple color emoji',
  'segoe ui emoji', 'segoe ui symbol', 'noto color emoji', 'sans-serif', 'serif',
  'monospace', 'cursive', 'fantasy', 'emoji', 'math', 'fangsong', 'inherit',
  'initial', 'unset', 'menlo', 'monaco', 'consolas', 'courier new', 'cascadia mono',
])

/** Every non-generic family named by font-family: or @font-face in the given CSS. */
function readFamilies(css) {
  const out = new Map()
  for (const m of css.matchAll(/font-family\s*:\s*([^;}]+)/gi)) {
    for (const raw of m[1].split(',')) {
      const name = raw.trim().replace(/^["']|["']$/g, '').trim()
      if (!name || name.startsWith('var(') || name.length < 3) continue
      if (SYSTEM_STACK.has(name.toLowerCase())) continue
      out.set(name.toLowerCase(), name)
    }
  }
  return [...out.values()]
}

/* --------------------------------------------------------------- run log */

const LOG_PATH = '.craft-layer/run-log.md'
const COLUMNS = ['date', 'brief-slug', 'hue-family', 'type-strategy', 'spine', 'signature', 'draw']

/** Last 5 rows of the seven-column log. A malformed log is EMPTY, never fatal. */
function readRunLog(notes) {
  const p = resolve(process.cwd(), LOG_PATH)
  if (!existsSync(p)) return []
  let rows = []
  try {
    const lines = readFileSync(p, 'utf8').split('\n').filter((l) => l.trim().startsWith('|'))
    const cells = (l) => l.trim().replace(/^\||\|$/g, '').split('|').map((c) => c.trim())
    let header = null
    for (const l of lines) {
      const c = cells(l)
      if (c.every((x) => /^:?-{2,}:?$/.test(x))) continue
      if (!header && c.some((x) => /brief-slug/i.test(x))) { header = c.map((x) => x.toLowerCase()); continue }
      if (c.length < COLUMNS.length) continue
      const keys = header ?? COLUMNS
      const row = {}
      keys.forEach((k, i) => { row[k] = c[i] ?? '' })
      rows.push(row)
    }
  } catch (e) {
    notes.push(`run log unreadable (${e.message}) — treated as EMPTY`)
    return []
  }
  if (!rows.length) notes.push(`${LOG_PATH} present but held no parseable rows — treated as EMPTY`)
  return rows.slice(-5)
}

/* ------------------------------------------------- contract + deck record */

const AXES = [
  'composition strategy', 'colour behaviour', 'type role', 'motion role', 'graphic-system class',
]
const AXIS_ALIASES = { 'color behavior': 'colour behaviour', 'colour behavior': 'colour behaviour', 'color behaviour': 'colour behaviour' }

function firstExisting(list) {
  for (const c of list.filter(Boolean)) {
    const p = resolve(process.cwd(), c)
    if (existsSync(p) && statSync(p).isFile()) return p
  }
  return null
}

const contractPath = () => firstExisting([
  process.env.CRAFT_CONTRACT,
  'craft/offer-contract.md',
  'taskmaster-docs/craft/offer-contract.md',
  '.craft-layer/offer-contract.md',
])

const recordPath = () => firstExisting([
  process.env.CRAFT_DIVERGENCE_RECORD,
  'craft/divergence-record.md',
  'taskmaster-docs/craft/divergence-record.md',
  '.craft-layer/divergence-record.md',
])

/** A build echoing an existing brand legitimately repeats itself every run. */
function brandEcho() {
  const p = contractPath()
  if (!p) return null
  for (const line of readFileSync(p, 'utf8').split('\n')) {
    const m = line.match(/brand[ -]?echo\s*[:|]\s*(.*)$/i)
    if (!m) continue
    const v = m[1].replace(/\|/g, ' ').trim()
    if (/^(no|none|n\/a|false|-|—)?$/i.test(v)) continue
    return { path: p, value: v }
  }
  return null
}

/** The five recorded axis options, keyed by lowercase axis name. */
function readDraw() {
  const p = recordPath()
  if (!p) return null
  const draw = {}
  for (const line of readFileSync(p, 'utf8').split('\n')) {
    const m = line.match(/^\s*[-*]?\s*([A-Za-z][A-Za-z \-]*?)\s*:\s*(.+?)\s*$/)
    if (!m) continue
    const axis = AXIS_ALIASES[m[1].toLowerCase()] ?? m[1].toLowerCase()
    if (!AXES.includes(axis)) continue
    draw[axis] = m[2].replace(/[`*]/g, '').trim()
  }
  return Object.keys(draw).length === AXES.length ? { path: p, draw } : null
}

/* --------------------------------------------------------------- waivers */

function readWaivers(notes) {
  const p = resolve(process.cwd(), '.craft-layer/waivers.json')
  if (!existsSync(p)) return []
  try {
    const j = JSON.parse(readFileSync(p, 'utf8'))
    if (!Array.isArray(j)) throw new Error('not an array')
    return j.filter((w) => {
      if (w && typeof w.check === 'string' && String(w.reason ?? '').trim()) return true
      notes.push(`waiver for '${w?.check ?? '?'}' has no reason — IGNORED (a waiver without a reason is a silence)`)
      return false
    })
  } catch (e) {
    notes.push(`waivers.json unparseable (${e.message}) — no waivers applied`)
    return []
  }
}

const waiverFor = (waivers, check, value) => waivers.find((w) =>
  w.check === check && (!String(w.value ?? '').trim() || w.value === '*'
    || String(w.value).toLowerCase() === String(value).toLowerCase()))

/* ------------------------------------------------------------------ run */

const notes = []
const results = []   // { check, state: 'PASS'|'FAIL'|'WAIVED'|'SKIP', detail }
const record = (check, state, detail) => results.push({ check, state, detail })

const anti = loadAntiCorpus()
console.log(`anti-corpus source: ${anti.source}`)
console.log(`anti-corpus kind:   ${anti.kind} · snapshot date ${anti.date}`)

const tokenPath = findTokenSource()
if (!tokenPath) {
  console.log(`\nnot measured: no token source found (tried ${TOKEN_CANDIDATES.join(', ')})`)
  console.log('NOT MEASURED IS A FAILURE HERE. A gate that cannot see the build cannot')
  console.log('clear it — set CRAFT_TOKEN_SOURCE to the CSS holding the tokens.')
  process.exit(2)
}
let css
try {
  css = readFileSync(tokenPath, 'utf8')
} catch (e) {
  console.log(`\nnot measured: token source ${tokenPath} unreadable (${e.message})`)
  process.exit(2)
}
const accents = readAccents(css)
if (!accents.length) {
  console.log(`\nnot measured: ${tokenPath} declares no parseable accent/primary/brand colour`)
  console.log('(oklch(), hsl() and 6-digit hex are understood; an achromatic accent has no hue).')
  console.log('NOT MEASURED IS A FAILURE HERE — see the file header.')
  process.exit(2)
}
console.log(`token source:       ${tokenPath}`)

/* font-family declarations: the token source plus its sibling stylesheets. */
const cssFiles = [tokenPath]
try {
  for (const f of readdirSync(dirname(tokenPath))) {
    if (f.endsWith('.css') && f !== basename(tokenPath)) cssFiles.push(join(dirname(tokenPath), f))
  }
} catch { /* directory unreadable — the token source alone is the scan */ }
const families = [...new Set(cssFiles.flatMap((f) => {
  try { return readFamilies(readFileSync(f, 'utf8')) } catch { return [] }
}))]

const waivers = readWaivers(notes)
const log = readRunLog(notes)
const echo = brandEcho()
const drawn = readDraw()

if (echo) notes.push(`brand-echo row found in ${echo.path} ("${echo.value}") — repeat assertions skipped`)

const settle = (check, failed, value, failDetail, passDetail) => {
  if (!failed) return record(check, 'PASS', passDetail)
  const w = waiverFor(waivers, check, value)
  if (w) return record(check, 'WAIVED', `${failDetail}  [waived: ${w.reason}]`)
  record(check, 'FAIL', failDetail)
}

/* (i) accent hue inside the category-default band ------------------------- */
{
  const hit = accents.find((a) => a.hue >= DEFAULT_BAND[0] && a.hue <= DEFAULT_BAND[1])
  settle('accent-default-band', !!hit, hit ? Math.round(hit.hue) : '',
    hit ? `${hit.name}: ${hit.value} — hue ${hit.hue.toFixed(1)}° (${hit.family}) is inside the `
      + `${DEFAULT_BAND[0]}-${DEFAULT_BAND[1]}° category-default band. Reproduce: `
      + `grep -n '${hit.name}' ${tokenPath}` : '',
    `accents at ${accents.map((a) => `${Math.round(a.hue)}° ${a.family}`).join(', ')} clear the `
      + `${DEFAULT_BAND[0]}-${DEFAULT_BAND[1]}° band`)
}

/* (ii) accent hue repeats one of the last 5 runs -------------------------- */
if (echo) record('hue-repeat', 'SKIP', 'brand-echo contract — echoing a brand palette is a reason to repeat')
else if (!log.length) record('hue-repeat', 'SKIP', `no rows in ${LOG_PATH} — first logged run`)
else {
  const past = log.map((r) => (r['hue-family'] ?? '').toLowerCase()).filter(Boolean)
  const hit = accents.find((a) => past.some((p) =>
    p.split(/[^a-z0-9]+/).filter(Boolean).includes(a.family)
    || (/^\d+$/.test(p.trim()) && Math.abs(norm(Number(p)) - a.hue) <= 15)))
  settle('hue-repeat', !!hit, hit ? hit.family : '',
    hit ? `${hit.name} is ${hit.family} (hue ${hit.hue.toFixed(1)}°), already used in the last 5 runs `
      + `[${past.join(', ')}]. Reproduce: sed -n '1,20p' ${LOG_PATH}` : '',
    `no accent family repeats the last ${log.length} run(s) [${past.join(', ')}]`)
}

/* (iii) a shipped family is an anti-corpus entry -------------------------- */
if (!families.length) record('font-anti-corpus', 'SKIP', `no non-generic font-family declared in ${cssFiles.join(', ')}`)
else {
  const hit = families.find((f) =>
    new RegExp(`(^|[^A-Za-z])${f.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}([^A-Za-z]|$)`, 'i').test(anti.familyText))
  settle('font-anti-corpus', !!hit, hit ?? '',
    hit ? `"${hit}" is an anti-corpus family in the ${anti.kind} (${anti.date}) — the category default, `
      + `not a derived spec. Reproduce: grep -rn "font-family" ${cssFiles.join(' ')}` : '',
    `shipped families [${families.join(', ')}] are not anti-corpus entries`)
}

/* (iv) a shipped family repeats one of the last 5 runs -------------------- */
if (echo) record('font-repeat', 'SKIP', 'brand-echo contract — echoing a brand typeface is a reason to repeat')
else if (!families.length || !log.length) record('font-repeat', 'SKIP', 'no families or no logged runs to compare')
else {
  const past = log.map((r) => r['type-strategy'] ?? '').filter(Boolean)
  const hit = families.find((f) => past.some((p) =>
    new RegExp(`(^|[^A-Za-z])${f.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}([^A-Za-z]|$)`, 'i').test(p)))
  settle('font-repeat', !!hit, hit ?? '',
    hit ? `"${hit}" already appears in the last 5 runs' type column [${past.join(' · ')}]. `
      + `Reproduce: grep -n '${hit}' ${LOG_PATH}` : '',
    `no shipped family repeats the last ${log.length} run(s)`)
}

/* (v) the recorded draw differs on fewer than 3 of 5 axes ----------------- */
if (!drawn) record('draw-repeat', 'SKIP', 'no five-axis draw recorded — the gate had no input (never a failure)')
else if (!log.length) record('draw-repeat', 'SKIP', `no rows in ${LOG_PATH} to compare the draw against`)
else {
  const mine = AXES.map((a) => drawn.draw[a].toLowerCase())
  let worst = null
  for (const row of log) {
    const cell = (row.draw ?? '').split('/').map((s) => s.trim().toLowerCase()).filter(Boolean)
    if (cell.length !== AXES.length) continue
    const differ = mine.filter((v, i) => v !== cell[i]).length
    if (!worst || differ < worst.differ) worst = { differ, cell, date: row.date }
  }
  if (!worst) record('draw-repeat', 'SKIP', `no logged row carries a five-axis draw`)
  else settle('draw-repeat', worst.differ < 3, String(worst.differ),
    `the recorded draw differs from the ${worst.date} run on only ${worst.differ} of 5 axes `
      + `(3 required). This run [${mine.join(' / ')}] vs logged [${worst.cell.join(' / ')}]. `
      + `Reproduce: diff <(grep -iE '^(${AXES.join('|')}):' ${drawn.path}) <(grep -n 'draw' ${LOG_PATH})`,
    `the recorded draw differs from every logged run on at least 3 of 5 axes (worst: ${worst.differ})`)
}

/* ------------------------------------------------------------- report */

console.log('')
for (const r of results) console.log(`  ${r.state.padEnd(6)} ${r.check.padEnd(20)} ${r.detail}`)
if (notes.length) {
  console.log('')
  for (const n of notes) console.log(`  note   ${n}`)
}

const failed = results.filter((r) => r.state === 'FAIL')
console.log('')
console.log(failed.length
  ? `${failed.length} divergence assertion(s) FAILED — the build landed on a default it was told to leave.`
  : 'OK: the build clears every divergence assertion.')
process.exit(failed.length ? 1 : 0)
