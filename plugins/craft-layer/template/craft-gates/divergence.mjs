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
     CRAFT_BUILD_TASK         explicit path to the persisted build task
     CRAFT_CONTENT_SOURCE     explicit path to the persisted content source

   Exit codes: 0 clean · 1 one or more assertions failed · 2 not measured.
*/
import { readFileSync, existsSync, statSync, readdirSync, realpathSync } from 'node:fs'
import { join, dirname, basename, resolve, relative } from 'node:path'

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

/**
 * How saturated is this colour, on a 0..1 scale comparable across notations? Only used to
 * pick the most chromatic token when no accent is named — precision matters less than
 * ranking the same set the same way every run.
 */
function toChroma(value) {
  const v = value.trim()
  let m = v.match(/^oklch\(\s*([^\s,]+)[\s,]+([^\s,]+)/i)
  if (m) return Math.min(num(m[2]) / 0.37, 1) // 0.37 is about the sRGB chroma ceiling
  m = v.match(/^hsla?\(\s*([^\s,]+)[\s,]+([^\s,]+)/i)
  if (m) return num(m[2]) / 100
  m = v.match(/^#([0-9a-f]{6})\b/i)
  if (m) {
    const [r, g, b] = [0, 2, 4].map((i) => parseInt(m[1].slice(i, i + 2), 16) / 255)
    const max = Math.max(r, g, b), min = Math.min(r, g, b)
    return max === 0 ? 0 : (max - min) / max
  }
  return 0
}

/** Accent-ish custom properties, in declaration order. */
function readAccents(css) {
  const out = []
  const all = []
  for (const m of css.matchAll(/(--[\w-]+)\s*:\s*([^;}]+)/g)) {
    const name = m[1]
    const hue = toHue(m[2])
    if (hue === null) continue
    const entry = { name, value: m[2].trim(), hue, chroma: toChroma(m[2]), family: hueFamily(hue) }
    all.push(entry)
    if (/accent|primary|brand/i.test(name)) out.push(entry)
  }
  if (out.length) return out

  /* NAME-BASED RESOLUTION IS NOT ENOUGH. A build whose colour system is value-driven and
   * hue-flat — one hue, hierarchy from lightness alone — has no accent to name, so it
   * names its tokens by ROLE instead (paper / ink / rule / overlap). Resolving only by
   * name reports such a build `not measured`, which this gate treats as a failure, so a
   * legitimately achromatic design fails by construction and cannot pass however correct
   * it is. That is the same defect shape as failing a brand-echo build for repeating its
   * own brand.
   *
   * Fall back to the most chromatic declared token: whatever hue the system is built on
   * is the hue worth testing against the category defaults, whether or not anyone called
   * it an accent. Reported as a fallback so the resolution is never silent. */
  const chromatic = all.filter((t) => t.chroma > 0)
  if (!chromatic.length) return []
  const pick = chromatic.reduce((a, b) => (b.chroma > a.chroma ? b : a))
  pick.resolvedBy = 'fallback: most chromatic declared token — no accent/primary/brand name found'
  return [pick]
}

const SYSTEM_STACK = new Set([
  'system-ui', 'ui-sans-serif', 'ui-serif', 'ui-monospace', 'ui-rounded',
  '-apple-system', 'blinkmacsystemfont', 'segoe ui', 'roboto', 'helvetica neue',
  'helvetica', 'arial', 'noto sans', 'liberation sans', 'apple color emoji',
  'segoe ui emoji', 'segoe ui symbol', 'noto color emoji', 'sans-serif', 'serif',
  'monospace', 'cursive', 'fantasy', 'emoji', 'math', 'fangsong', 'inherit',
  'initial', 'unset', 'menlo', 'monaco', 'consolas', 'courier new', 'cascadia mono',
])

/** Every non-generic family named by font-family:, a Tailwind v4 `--font-*`
 *  theme variable, or @font-face in the given CSS.
 *
 *  READS THE TWO FORMS IT USED TO MISS. Matching only literal `font-family:`
 *  made this gate blind on the two setups the anti-corpus most wants to catch:
 *  Tailwind v4 declares the stack as `@theme { --font-sans: Inter, … }` and
 *  never emits a `font-family` line at all, and a project that writes
 *  `font-family: var(--font-sans)` hid the family behind an indirection the old
 *  loop skipped by name. Both recorded SKIP — "no non-generic font declared" —
 *  which the terminator then folded into a green. So the plugin's most-quoted
 *  anti-sameness claim had no teeth in exactly the stack it ships guidance for,
 *  and the way to pass the font gate was to never choose a typeface. */
function readFamilies(css) {
  const out = new Map()
  /* Resolve custom-property indirection first, so `font-family: var(--font-sans)`
     is read as whatever --font-sans holds. */
  const vars = new Map([...css.matchAll(/(--[\w-]+)\s*:\s*([^;}]+)/g)]
    .map((m) => [m[1], m[2]]))
  const deref = (s, depth = 0) => depth > 4 ? s
    : s.replace(/var\(\s*(--[\w-]+)\s*(?:,[^)]*)?\)/g,
      (_, k) => vars.has(k) ? deref(vars.get(k), depth + 1) : '')
  const DECL = /(?:font-family|--font-(?:sans|serif|mono|display|heading|body|brand|title))\s*:\s*([^;}]+)/gi
  for (const m of css.matchAll(DECL)) {
    for (const raw of deref(m[1]).split(',')) {
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

/** Last 5 rows of the seven-column log. A malformed log is EMPTY, never fatal.
 *
 * PARTIAL malformation is the case worth being loud about. A wholly-unreadable log
 * already warns, but a log where only SOME rows are hand-edited used to be read
 * partially and silently — the gate then ran against a quietly truncated history
 * while craft.md and the README both promise "treated as EMPTY and warned about".
 * Every dropped row is now counted and reported.
 *
 * Widths: rows are matched against the HEADER's width when a header is present,
 * falling back to COLUMNS. Cells map POSITIONALLY, so a column inserted anywhere
 * but the end of the row shifts every older row's values into the wrong keys —
 * which reads as a PASS on garbage rather than a skip. New columns are
 * append-only, and a row wider than its header is reported rather than trusted. */
function readRunLog(notes) {
  const p = resolve(process.cwd(), LOG_PATH)
  if (!existsSync(p)) return []
  let rows = []
  let narrow = 0
  let wide = 0
  try {
    const lines = readFileSync(p, 'utf8').split('\n').filter((l) => l.trim().startsWith('|'))
    const cells = (l) => l.trim().replace(/^\||\|$/g, '').split('|').map((c) => c.trim())
    let header = null
    for (const l of lines) {
      const c = cells(l)
      if (c.every((x) => /^:?-{2,}:?$/.test(x))) continue
      if (!header && c.some((x) => /brief-slug/i.test(x))) { header = c.map((x) => x.toLowerCase()); continue }
      const keys = header ?? COLUMNS
      if (c.length < keys.length) { narrow++; continue }
      if (c.length > keys.length) wide++
      const row = {}
      keys.forEach((k, i) => { row[k] = c[i] ?? '' })
      rows.push(row)
    }
  } catch (e) {
    notes.push(`run log unreadable (${e.message}) — treated as EMPTY`)
    return []
  }
  if (narrow) {
    notes.push(`${LOG_PATH}: ${narrow} row(s) too narrow to parse — DROPPED, so this run diverges from less history than the log appears to hold`)
  }
  if (wide) {
    notes.push(`${LOG_PATH}: ${wide} row(s) wider than the header — extra cells ignored. If a column was inserted mid-row rather than appended, the values read here are MISALIGNED and the repeat gates below are unreliable`)
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

/* The candidate list per artifact, in precedence order. Held in ONE table because
   the stamp assertion below needs the whole list — the extra candidates are the
   ambiguity it reports — while every other reader wants only the first that
   exists. Env vars are read per call, so a test can set one between runs. */
const ARTIFACT_PATHS = {
  'offer contract': () => [
    process.env.CRAFT_CONTRACT,
    'craft/offer-contract.md',
    'taskmaster-docs/craft/offer-contract.md',
    '.craft-layer/offer-contract.md',
  ],
  'divergence record': () => [
    process.env.CRAFT_DIVERGENCE_RECORD,
    'craft/divergence-record.md',
    'taskmaster-docs/craft/divergence-record.md',
    '.craft-layer/divergence-record.md',
  ],
  'build task': () => [
    process.env.CRAFT_BUILD_TASK,
    'craft/build-task.md',
    'taskmaster-docs/craft/build-task.md',
    '.craft-layer/build-task.md',
  ],
  'content source': () => [
    process.env.CRAFT_CONTENT_SOURCE,
    'craft/content-source.md',
    'taskmaster-docs/craft/content-source.md',
    '.craft-layer/content-source.md',
  ],
}

const contractPath = () => firstExisting(ARTIFACT_PATHS['offer contract']())

const recordPath = () => firstExisting(ARTIFACT_PATHS['divergence record']())

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

/* --------------------------------------------------------- spine register */

/* THE BUYER'S QUESTION, ANSWERED IN AN INTEGRATOR'S VOICE.
 *
 * The offer-spine gate checks each slot is PRESENT. A build once answered all
 * eight — and answered them with `POST /api/task`, a bearer-token scope, a
 * `workspace_id` global scope and a 403 body. Every gate reported green; a human
 * read the page and found API documentation wearing a landing page's clothes.
 *
 * Only the three BUYER slots are graded — plain-what, audience, problem. Method
 * disclosure inside `how it works` and `objection` is where the offer contract
 * ROUTES spec detail, and a limits list is SUPPOSED to be concrete, so a
 * whole-page grep is the blunt version of this check: it fires on correct pages,
 * teaches builders to strip real detail, and gets waived into silence.
 *
 * Scoping it needs a slot -> region mapping, which is why this reads
 * `craft/build-task.md`'s `Spine regions:` line. Mapping, corpus and declared
 * limits: skills/creative-direction/references/register-corpus.md
 *
 * `fixture-register.html` and `fixture-register-clean.html` are the pair that
 * proves this fails for the right reason: same product, same facts, same
 * endpoints and the same limits list — only the register of the three buyer
 * slots differs. The clean one MUST pass; a run that fails it has become the
 * whole-page grep. `fixture-register-falsepos.html` is the third of the set: a
 * correct buyer page whose copy happens to carry `401(k)`, `429 teams` and
 * `Suite 502`, with every buyer anchor on a TEXT-ONLY leaf. It must pass, and it
 * must report all three slots CHECKED rather than unreadable.
 *
 * Point a scratch project at each in turn with a build task carrying, ON ONE LINE
 * AND NEVER WRAPPED (this parser reads the line the key is on and nothing else):
 *
 * Spine regions: plain-what=#hero, audience=#hero, problem=#status-quo, how-it-works=#method, price=#pricing, proof=#proof, objection=#limits, cta=#hero
 */

const REGISTER_SNAPSHOT = {
  date: '2026-07-26',
  rules: [
    ['http-verb', 'g', String.raw`\b(?:GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\s+(?:/|https?://|\{|:)`],
    ['http-verb', 'g', String.raw`\b(?:GET|POST|PUT|PATCH|DELETE)\s+(?:request|call|endpoint)s?\b`],
    ['endpoint-path', 'gi', String.raw`(?:^|[\s"'(\[])/(?:api|v[0-9]+|graphql|rest|oauth|webhooks?)(?:/|\b)`],
    ['endpoint-path', 'g', String.raw`/\{[A-Za-z_]\w*\}`],
    ['endpoint-path', 'g', String.raw`/:[a-z_]\w*\b`],
    ['auth-scheme', 'gi', String.raw`\b(?:bearer token|bearer auth|oauth2?|jwt|json web token|sanctum|api[ -]?key|api[ -]?token|api[ -]?secret|access token|refresh token|client secret|personal access token|hmac|basic auth|token scope|scoped token)\b`],
    ['auth-scheme', 'gi', String.raw`\b(?:ability|scope|scopes|permission):[a-z_-]+`],
    ['status-code', 'gi', String.raw`\b(?:HTTP|status(?: code)?|error(?: code)?|response code|responds? with|returns?|rejects? with|rejected(?: with)?|fails? with|throws?)\s+(?:an?\s+)?[1-5][0-9]{2}\b`],
    ['status-code', 'gi', String.raw`\b(?:401|403|409|418|422|429|451|502|503)\s+(?:unauthori[sz]ed|forbidden|conflict|unprocessable|too many requests|bad gateway|service unavailable|errors?|status|responses?)\b`],
    ['orm-schema', 'gi', String.raw`\b[a-z][a-z0-9]*_id\b`],
    ['orm-schema', 'gi', String.raw`\b(?:foreign key|primary key|global scope|eloquent|active ?record|varchar|nullable|polymorphic|soft[ -]delete|join table|database schema|db migration|schema migration|ORM)\b`],
    ['protocol-limits', 'gi', String.raw`\b(?:rate[ -]limit(?:ed|s|ing)?|requests? per (?:second|minute|hour|day)|req/(?:s|min)|idempotenc\w+|retry-after|webhook payload|exponential backoff|throttl\w+)\b`],
  ],
}

/** The corpus, LIVE from the reference when the plugin root is known. Same
    contract as the anti-corpus above: source and date are printed every run, so a
    frozen snapshot is visible rather than assumed. */
function loadRegisterCorpus() {
  const root = process.env.CLAUDE_PLUGIN_ROOT
  if (root) {
    const p = join(root, 'skills/creative-direction/references/register-corpus.md')
    if (existsSync(p)) {
      try {
        const m = readFileSync(p, 'utf8')
          .match(/<!--\s*register-corpus:start\s*-->([\s\S]*?)<!--\s*register-corpus:end\s*-->/)
        const rules = []
        for (const line of (m ? m[1] : '').split('\n')) {
          const t = line.trim()
          if (!t || t.startsWith('```')) continue
          const parts = t.split(' :: ')
          if (parts.length < 3) continue
          rules.push([parts[0].trim(), parts[1].trim(), parts.slice(2).join(' :: ').trim()])
        }
        if (rules.length) {
          return { source: p, kind: 'live corpus', date: statSync(p).mtime.toISOString().slice(0, 10), rules }
        }
      } catch { /* fall through to the snapshot */ }
    }
  }
  return {
    source: 'embedded snapshot (CLAUDE_PLUGIN_ROOT unset or corpus missing)',
    kind: 'frozen snapshot',
    date: REGISTER_SNAPSHOT.date,
    rules: REGISTER_SNAPSHOT.rules,
  }
}

const buildTaskPath = () => firstExisting(ARTIFACT_PATHS['build task']())

/** `Spine regions: plain-what=#hero, audience=#hero, problem=#status-quo, …` */
function readSpineRegions() {
  const p = buildTaskPath()
  if (!p) return null
  let text
  try { text = readFileSync(p, 'utf8') } catch { return null }
  for (const line of text.split('\n')) {
    /* Accept the bare, list-marker AND heading forms. A build task writes five lines and
       only THIS one is machine-parsed — the other four are read by an agent, so heading
       form works for all of them. A task whose five lines are formatted consistently as
       `## <key>:` therefore had four live lines and one silently dead one, reported as a
       SKIP that reads like "nothing to check". Found on a live run, by nobody's review. */
    const m = line.match(/^\s*#{0,6}\s*[-*]?\s*\**\s*Spine regions\s*\**\s*:\s*(.+?)\s*$/i)
    if (!m) continue
    const declared = m[1].replace(/[`*]/g, '').trim()
    const map = {}
    if (!/^(?:none|unmapped|n\/a|-|—)$/i.test(declared)) {
      for (const pair of declared.split(',')) {
        const mm = pair.trim().match(/^([A-Za-z][A-Za-z-]*)\s*=\s*#?([\w:-]+)$/)
        if (mm) (map[mm[1].toLowerCase()] ??= []).push(mm[2])
      }
    }
    return { path: p, map, declared }
  }
  return null
}

const SRC_EXT = /\.(?:html?|jsx?|tsx?|vue|astro|svelte|mdx)$/i
const SKIP_DIR = /^(?:node_modules|dist|build|out|coverage|vendor|craft|taskmaster-docs)$/i

const rel = (p) => relative(process.cwd(), p) || p

/** Shipped source files, dot-directories and build output excluded. */
function sourceFiles(dir, out = [], budget = { n: 0 }) {
  let entries
  try { entries = readdirSync(dir, { withFileTypes: true }) } catch { return out }
  for (const e of entries) {
    if (budget.n > 3000) return out
    if (e.name.startsWith('.')) continue
    if (e.isDirectory()) { if (!SKIP_DIR.test(e.name)) sourceFiles(join(dir, e.name), out, budget) }
    else if (SRC_EXT.test(e.name)) { budget.n++; out.push(join(dir, e.name)) }
  }
  return out
}

const esc = (s) => String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')

/** The element carrying `id="<anchor>"`, bounded by tag balance on its own tag
    name. Bounding matters more than it looks: without it the region runs to the
    end of the file and swallows the `how it works` section, which is the blunt
    whole-page grep this gate exists to NOT be. */
function regionFor(src, anchor) {
  const a = esc(anchor)
  const m = new RegExp(`\\bid\\s*=\\s*(?:"${a}"|'${a}'|\\{\\s*(?:"${a}"|'${a}'|\`${a}\`)\\s*\\})`).exec(src)
  if (!m) return null
  const lt = src.lastIndexOf('<', m.index)
  if (lt < 0) return null
  const tagM = /^<([A-Za-z][\w.:-]*)/.exec(src.slice(lt, lt + 80))
  if (!tagM) return null
  const tag = tagM[1]
  const gt = src.indexOf('>', m.index)
  if (gt < 0) return null
  if (src[gt - 1] === '/') return { start: gt + 1, end: gt + 1, tag, selfClosing: true }
  const re = new RegExp(`<${esc(tag)}(?=[\\s/>])|</${esc(tag)}\\s*>`, 'g')
  re.lastIndex = gt + 1
  let depth = 1
  let end = src.length
  let mm
  while ((mm = re.exec(src))) {
    if (mm[0][1] === '/') {
      if (--depth === 0) { end = mm.index; break }
    } else {
      const close = src.indexOf('>', mm.index)
      if (close > 0 && src[close - 1] === '/') continue   // self-closing sibling
      depth++
    }
  }
  return { start: gt + 1, end, tag, selfClosing: false }
}

/* `data-*` IS DELIBERATELY ABSENT, and this is the one place this gate reads less
   than the banned-vocabulary gate does. That gate looks for literal terms a human
   chose, so a `data-` string is worth checking. This one greps for the SHAPE of
   code — `\w+_id`, a status number, a route — and `data-testid="task_id"`,
   `data-state`, `data-slot` are made of exactly that shape while being code hooks
   no reader ever sees. Including them would fire on correct pages, which is the
   anti-pattern register-corpus.md names. Stated in its declared limits. */
const COPY_ATTR = /\b(?:alt|title|aria-label|placeholder)\s*=\s*(?:"([^"]*)"|'([^']*)')/g
const COPY_KEY = /\b(?:title|label|heading|headline|eyebrow|kicker|lede|subhead|body|copy|text|description|blurb|caption|question|answer|cta|summary|tagline)\s*:\s*(?:"([^"]*)"|'([^']*)'|`([^`]*)`)/g

/** What a READER sees, approximated from source exactly as the banned-vocabulary
    gate defines rendered content: text between tags, copy attributes, and quoted
    values of copy-bearing keys. CODE IS NOT COPY — an import path, a
    `fetch('/api/…')` argument, a `className` and an `href` never reach this list,
    which is what keeps a hero with a working signup form out of the findings.

    `isCopy` is a PARAMETER with the letter test as its default because the
    emoji-as-icon assertion below needs the opposite blindness fixed: an
    icon-only leaf — `<div>🚀</div>` — holds no letter at all, and that is the
    exact shape an emoji icon ships in. */
function copyChunks(slice, isCopy = (s) => /\p{L}/u.test(s)) {
  const blank = (m) => ' '.repeat(m.length)
  const s = slice
    .replace(/<(script|style)[\s\S]*?<\/\1>/gi, blank)
    .replace(/<!--[\s\S]*?-->/g, blank)
    .replace(/\/\*[\s\S]*?\*\//g, blank)
  const out = []
  let i = s.indexOf('<')
  /* THE LEADING TEXT RUN, before the first child tag — and the whole of a text-only
     leaf, which has no child tag at all. Starting the walk at the first `<` skipped
     both: `<h1 id="plain-what">POST /api/task <span>now</span></h1>` graded only
     "now", and `<h1 id="plain-what">POST /api/task</h1>` produced ZERO chunks and was
     reported as "an element holding no copy" — telling the builder to move the id
     onto the element holding the copy, which is where they had already put it, and
     craft.md step 6 instructs them to.

     WHY THE TEST IS `\p{L}` AND NEVER `[A-Za-z]`. It asks one question — is this run
     TEXT rather than whitespace and punctuation — and Latin is not the only script
     that answers yes. Under `[A-Za-z]` an entire Hebrew, Arabic, Cyrillic, Greek,
     CJK, Thai or Devanagari page has NO copy anywhere: every buyer region reports
     "holding no copy", spine-register degrades to SKIP across the whole spine, and
     the message instructs the builder to move an id that was already right. Worse,
     the regions that DO appear to hold copy are the ones whose slice happens to
     contain a JSX identifier — `{ITEMS.map(({ title, body }) => (` — so the gate
     grades JavaScript and ignores the prose. A Hebrew run found exactly that. */
  if (i !== 0) {
    const head = i < 0 ? s : s.slice(0, i)
    if (isCopy(head)) out.push({ at: 0, text: head.replace(/\{[^{}]*\}/g, ' ') })
  }
  while (i >= 0) {
    const gt = s.indexOf('>', i)
    if (gt < 0) break
    const nextLt = s.indexOf('<', gt + 1)
    const raw = s.slice(gt + 1, nextLt < 0 ? s.length : nextLt)
    if (isCopy(raw)) out.push({ at: gt + 1, text: raw.replace(/\{[^{}]*\}/g, ' ') })
    if (nextLt < 0) break
    i = nextLt
  }
  for (const re of [COPY_ATTR, COPY_KEY]) {
    re.lastIndex = 0
    let m
    while ((m = re.exec(s))) {
      const v = m[1] ?? m[2] ?? m[3] ?? ''
      if (isCopy(v)) out.push({ at: m.index, text: v })
    }
  }
  return out
}

const lineAt = (src, idx) => src.slice(0, Math.max(0, idx)).split('\n').length

const BUYER = { plainwhat: 'plain-what', plainlanguagewhat: 'plain-what', audience: 'audience', problem: 'problem' }
const METHOD = new Set(['howitworks', 'objection'])

/* ------------------------------------------------------- composition shape */

/* THE AXIS NOBODY WAS CHECKING.
 *
 * The deck draws FIVE axes and four of them land somewhere a gate can see:
 * colour behaviour has accent-default-band and hue-repeat, type role has
 * font-anti-corpus and font-repeat, motion role is the craft-reviewer's job,
 * graphic-system class is a `maximal` reach floor. Axis 1 — COMPOSITION
 * STRATEGY — had nothing, and draw-repeat does not close that hole: it grades
 * the recorded draw STRING against the run history, so it proves the words are
 * new and never that the page was built the way they say.
 *
 * The failure that produced this check: a run drew "Placed clusters" — discrete
 * positioned groups on an open canvas instead of a running flow — and shipped
 * `mx-auto max-w-5xl` eleven times in a running flow, which is "Centred spine",
 * a DIFFERENT option on the same axis. Every assertion passed. The one axis with
 * no gate was the one that collapsed, and it collapsed to the shape a model
 * reaches for when nothing argues otherwise: one measure, no exceptions. The
 * reviewer's words for it were "it looks like a blog post".
 *
 * SO THIS MEASURES SHAPE, NOT COMPLIANCE. It deliberately does NOT parse the
 * drawn option and hunt for that option's signature: eight options would need
 * eight signature tables, each one a fresh way to be wrong, and a wrong
 * signature table fails correct pages. It asks the blunter question the failure
 * actually poses — did this page commit to ANY spatial structure at all?
 *
 * Two conditions, and it bites only when BOTH hold, so a build with real
 * structure ANYWHERE clears it:
 *
 *   1. ONE MEASURE — the dominant `mx-auto max-w-*` container accounts for 70%+
 *      of all such containers. A page of full-bleed panels or an asymmetric
 *      split does not read this way; a stacked document does.
 *   2. NO ESCAPES — positioned, spanning and bleeding elements number fewer than
 *      one per two sections. Layered depth, off-axis fields and placed clusters
 *      all REQUIRE these; a running flow uses none.
 *
 * Vertical rhythm is measured and REPORTED but is not a fail condition. On the
 * page that motivated this check the rhythm was the weakest of the three signals
 * (py-12/20/28, three values, 67% dominant) while the page was unmistakably one
 * shape — rhythm variety is cheap and buys no structure, so gating on it would
 * have taught builders to sprinkle padding values.
 *
 * A PAGE WITH NO FIXED MEASURE AT ALL PASSES, and says why: zero `mx-auto
 * max-w-*` containers is the opposite of this failure, not a severe case of it.
 *
 * A CENTRED SPINE IS A LEGITIMATE DRAW AND THIS GATE FAILS IT. That is on
 * purpose, and it is what the waiver lane is for — draw the axis, build the
 * spine, write the waiver with the reason. What must never happen silently is
 * the page that never decided.
 */

const ESCAPE_RE = /\b(?:absolute|sticky|fixed|col-span-\w|row-span-\w|col-start-\w|row-start-\w|inset-|w-screen|clip-path|mix-blend-|grid-area)/g
const CLASS_RE = /class(?:Name)?\s*=\s*(?:"([^"]*)"|'([^']*)'|\{\s*`([^`]*)`\s*\})/g

/* THE PAGE, NOT THE HARNESS. `sourceFiles()` walks everything shipped, which is
   right for the register gate — copy is copy wherever it lives — and wrong here.
   A Playwright spec that ASSERTS on layout quotes every utility this check
   counts, so the first run of this gate scored the test file at 8 escapes and
   PASSED the very page it was written to catch. Tests, stories, scripts and
   config describe the page; they are not it. */
const NOT_THE_PAGE = /(?:^|\/)(?:tests?|__tests__|e2e|spec|specs|stories|scripts|config|mocks?|fixtures?)\//i
const NOT_THE_PAGE_FILE = /\.(?:spec|test|stories|config|d)\.[jt]sx?$/i
const isPage = (p) => !NOT_THE_PAGE.test(rel(p)) && !NOT_THE_PAGE_FILE.test(p)

const MIN_SECTIONS = 5
const MEASURE_DOMINANCE = 0.7

function compositionShape() {
  const all = sourceFiles(process.cwd())
  const files = all.filter(isPage)
  if (!files.length) {
    return record('composition-shape', 'SKIP',
      all.length ? `all ${all.length} source file(s) look like tests/scripts, not page source`
        : 'no shipped source files found to measure')
  }

  const measures = new Map()
  const rhythm = new Map()
  let sections = 0
  let escapes = 0

  for (const f of files) {
    let src
    try { src = readFileSync(f, 'utf8') } catch { continue }
    sections += (src.match(/<section\b/gi) ?? []).length
    for (const m of src.matchAll(CLASS_RE)) {
      const cls = m[1] ?? m[2] ?? m[3] ?? ''
      /* Escapes are counted ONLY inside class strings. Counting them file-wide
         scores the word "absolute" in a prose comment as spatial structure —
         which is how a page carrying one positioned element reported four. */
      escapes += (cls.match(ESCAPE_RE) ?? []).length
      if (/\bmx-auto\b/.test(cls)) {
        const w = /\bmax-w-(\[[^\]\s]+\]|[a-z0-9]+)/.exec(cls)
        if (w) measures.set(w[1], (measures.get(w[1]) ?? 0) + 1)
      }
      /* Only SECTION-scale padding. `py-2` is a button and `py-4` is a nav row;
         counting them reports a rhythm variety the page's structure never had. */
      for (const p of cls.matchAll(/\bpy-(\d+)\b/g)) {
        if (Number(p[1]) >= 10) rhythm.set(p[1], (rhythm.get(p[1]) ?? 0) + 1)
      }
    }
  }

  if (sections < MIN_SECTIONS) {
    return record('composition-shape', 'SKIP',
      `only ${sections} <section> element(s) found (${MIN_SECTIONS} needed) — too little page to have a shape`)
  }

  const total = [...measures.values()].reduce((a, b) => a + b, 0)
  const rhythmDesc = [...rhythm.entries()].sort((a, b) => b[1] - a[1])
    .map(([v, n]) => `py-${v}×${n}`).join(', ') || 'none at section scale'

  if (!total) {
    return record('composition-shape', 'PASS',
      `no fixed \`mx-auto max-w-*\` measure anywhere across ${sections} section(s) — the page commits to `
      + `full-width structure rather than to a document column (rhythm: ${rhythmDesc})`)
  }

  const [topMeasure, topCount] = [...measures.entries()].reduce((a, b) => (b[1] > a[1] ? b : a))
  const share = topCount / total
  const escapeFloor = sections / 2
  const oneMeasure = share >= MEASURE_DOMINANCE
  const noEscapes = escapes < escapeFloor

  const shape = `max-w-${topMeasure} on ${topCount}/${total} containers (${Math.round(share * 100)}%), `
    + `${escapes} escape(s) across ${sections} section(s), rhythm: ${rhythmDesc}`

  settle('composition-shape', oneMeasure && noEscapes, topMeasure,
    `the page never committed to a spatial structure: ${shape}. One measure carries `
      + `${Math.round(share * 100)}% of containers (>=${MEASURE_DOMINANCE * 100}% is "one measure") and there are `
      + `fewer than one positioned/spanning/bleeding element per two sections (<${escapeFloor.toFixed(1)}). `
      + `That is a stacked document, which is what a build lands on when the composition axis is drawn `
      + `and then not built. Read the drawn Axis 1 option in the divergence record and BUILD it — or, if a `
      + `centred spine is the deliberate answer, waive this check with that reason. `
      + `Reproduce: grep -roh 'class[N]*ame="[^"]*mx-auto[^"]*"' . | grep -oE 'max-w-[a-z0-9]+' | sort | uniq -c`,
    `the page carries spatial structure — ${shape}`)
}

/* ---------------------------------------------------- copy-half fingerprint */

/* THE COPY HALF OF THE FINGERPRINT — MECHANICAL SUBSET ONLY.
 *
 * The sameness registry carries a copy register (sameness-fingerprint.md,
 * "Recurring copy register"): the machine-copy lexicon a reader identifies as
 * generated in one line, the way the violet gradient is identified in one
 * glance. Most of that section is register and cadence — the craft-reviewer's
 * territory, agent-graded. Two tells are mechanical, and a check a machine can
 * run is never left to a judgement:
 *
 *   emoji-as-icon — pictographs standing in for the icon system. 🚀 in a
 *       heading means no icon decision was made, and it is the single fastest
 *       visual identifier of a generated page.
 *   copy-register — the multi-word machine-copy phrases. MULTI-WORD ON
 *       PURPOSE: "supercharge your" is a verdict, while "seamless" alone is a
 *       word honest copy is allowed to use — a single-word list fires on
 *       correct pages, which is the anti-pattern register-corpus.md names.
 *
 * Both read the reader-visible copy the spine-register assertion reads
 * (copyChunks), across the whole PAGE rather than a mapped region — a
 * pictograph or a lexicon phrase is a tell wherever it lands. The harness is
 * excluded the way composition-shape excludes it: a spec asserting a phrase is
 * banned QUOTES the phrase, and grading the quote fails the test that guards
 * the page. Both are waivable with a reason, the same lane as every assertion. */

const COPY_LEXICON = {
  /* The mechanical subset of the registry's copy section — refresh the two
     together, at release cadence like the anti-corpus snapshot above. */
  date: '2026-08-11',
  phrases: [
    ['supercharge your', String.raw`\bsupercharge\s+your\b`],
    ['seamlessly integrate', String.raw`\bseamlessly\s+integrat\w*`],
    ['take your * to the next level', String.raw`\btake\s+your\s+[^<>.!?]{0,60}?to\s+the\s+next\s+level\b`],
    ['effortless. powerful.', String.raw`\beffortless\.\s*powerful\.`],
    ['unlock the power', String.raw`\bunlock\s+the\s+power\b`],
    ['game-changing', String.raw`\bgame-chang(?:ing|ers?)\b`],
  ],
}

/* Text-default pictographs prose legitimately carries — the legal marks — plus
   anything the author explicitly rendered text-style with U+FE0E. Keycap
   digits (#️⃣, 3️⃣) never match at all: their base characters carry the Emoji
   property, not Extended_Pictographic, so they need no exclusion row here. */
const TEXT_MARKS = new Set(['©', '®', '™', '℠', '℗'])
const PICTO_RE = /\p{Extended_Pictographic}\uFE0E?/gu
const HAS_PICTO = /\p{Extended_Pictographic}/u

/* A QUOTED VOICE IS NOT THE BUILD'S ICON SYSTEM. An emoji inside a
   <blockquote> or <q> is the customer's own register — testimonial content the
   content-fidelity gate wants reproduced verbatim — so quoted subtrees are
   blanked before extraction. An emoji the BUILD authored into a heading or a
   feature row is the finding. */
const QUOTED_RE = /<(blockquote|q)\b[\s\S]*?<\/\1\s*>/gi

/** Shipped page source with its text, harness excluded, one read for both
    copy-half assertions. */
function pageCopy() {
  const out = []
  for (const f of sourceFiles(process.cwd())) {
    if (!isPage(f)) continue
    let src
    try {
      if (statSync(f).size > 512 * 1024) continue
      src = readFileSync(f, 'utf8')
    } catch { continue }
    out.push({ file: f, src })
  }
  return out
}

function emojiAsIcon(files) {
  if (!files.length) return record('emoji-as-icon', 'SKIP', 'no shipped page source found to hold copy')
  const hits = []
  for (const { file, src } of files) {
    const unquoted = src.replace(QUOTED_RE, (m) => ' '.repeat(m.length))
    for (const c of copyChunks(unquoted, (s) => HAS_PICTO.test(s))) {
      for (const m of c.text.matchAll(PICTO_RE)) {
        if (m[0].endsWith('\uFE0E')) continue   // explicit text presentation
        if (TEXT_MARKS.has(m[0])) continue
        hits.push({ char: m[0], file: rel(file), line: lineAt(src, c.at) })
      }
    }
  }
  const seen = new Set()
  const uniq = hits.filter((h) => {
    const k = `${h.file}|${h.char}`
    if (seen.has(k)) return false
    seen.add(k)
    return true
  })
  const shown = uniq.slice(0, 6).map((h) => `${h.char} at ${h.file}:${h.line}`).join(', ')
  settle('emoji-as-icon', uniq.length > 0, uniq[0]?.char ?? '',
    `pictographs standing in for the icon system — ${shown}${uniq.length > 6 ? ` (+${uniq.length - 6} more)` : ''}. `
      + 'An emoji in a heading or a feature row means no icon decision was made, and it is the fastest '
      + 'visual identifier of a generated page (sameness-fingerprint.md, the vocabulary registry). Choose '
      + 'an icon system — or, when the copy legitimately carries them (a chat product reproducing user '
      + `messages), waive this with that reason. Reproduce: grep -rn ${JSON.stringify(uniq[0]?.char ?? '')} ${uniq[0]?.file ?? ''}`,
    `no pictograph stands in for an icon in reader-visible copy across ${files.length} page file(s) `
      + '(quoted testimonial content and text-style marks excluded by construction)')
}

function copyRegister(files) {
  if (!files.length) return record('copy-register', 'SKIP', 'no shipped page source found to hold copy')
  const compiled = []
  for (const [label, source] of COPY_LEXICON.phrases) {
    try { compiled.push({ label, re: new RegExp(source, 'gi') }) } catch (e) {
      notes.push(`copy lexicon: the '${label}' pattern will not compile (${e.message}) — DROPPED, so that phrase is unchecked`)
    }
  }
  if (!compiled.length) return record('copy-register', 'SKIP', 'the copy lexicon compiled no patterns')
  const hits = []
  for (const { file, src } of files) {
    for (const c of copyChunks(src)) {
      for (const { label, re } of compiled) {
        re.lastIndex = 0
        const m = re.exec(c.text)
        /* A phrase can span a source line break; collapse it or the one-row
           reporting shape gains a literal newline. */
        if (m) hits.push({ label, marker: m[0].trim().replace(/\s+/g, ' '), file: rel(file), line: lineAt(src, c.at) })
      }
    }
  }
  const seen = new Set()
  const uniq = hits.filter((h) => {
    const k = `${h.file}|${h.label}`
    if (seen.has(k)) return false
    seen.add(k)
    return true
  })
  const shown = uniq.slice(0, 6).map((h) => `"${h.marker}" [${h.label}] at ${h.file}:${h.line}`).join('; ')
  settle('copy-register', uniq.length > 0, uniq[0]?.label ?? '',
    `machine-copy lexicon in reader-visible copy — ${shown}${uniq.length > 6 ? ` (+${uniq.length - 6} more)` : ''}. `
      + 'These are the phrases a reader identifies as generated in one line (sameness-fingerprint.md, '
      + '"Recurring copy register") — a build leaning on them has authored nothing. Write copy with the '
      + `product's own nouns in it, or waive this with the reason. Reproduce: grep -rni ${JSON.stringify(uniq[0]?.marker ?? '')} ${uniq[0]?.file ?? ''}`,
    `no multi-word machine-copy phrase from the ${compiled.length}-pattern lexicon (${COPY_LEXICON.date}) appears `
      + `in reader-visible copy across ${files.length} page file(s); single words ("seamless" alone) are not graded by construction`)
}

/* ------------------------------------------------------------------ run */

const notes = []
const results = []   // { check, state: 'PASS'|'FAIL'|'WAIVED'|'SKIP', detail }
const record = (check, state, detail) => results.push({ check, state, detail })

const waivers = readWaivers(notes)

const settle = (check, failed, value, failDetail, passDetail) => {
  if (!failed) return record(check, 'PASS', passDetail)
  const w = waiverFor(waivers, check, value)
  if (w) return record(check, 'WAIVED', `${failDetail}  [waived: ${w.reason}]`)
  record(check, 'FAIL', failDetail)
}

/* The register assertion reads SOURCE + the build task and needs nothing the
   token gate resolves, so it runs FIRST and its verdict survives an exit-2 run.
   A page whose CSS lives somewhere unusual is not a page whose copy is unchecked. */
function spineRegister(corpus) {
  const compiled = []
  for (const [cls, flags, source] of corpus.rules) {
    try { compiled.push({ cls, re: new RegExp(source, flags.includes('g') ? flags : `${flags}g`) }) } catch (e) {
      notes.push(`register corpus: the '${cls}' pattern will not compile (${e.message}) — DROPPED, so that class is unchecked`)
    }
  }
  if (!compiled.length) return record('spine-register', 'SKIP', 'the register corpus compiled no patterns')

  const spine = readSpineRegions()
  if (!spine) {
    return record('spine-register', 'SKIP',
      "no build task carrying a 'Spine regions:' line (tried craft/, taskmaster-docs/craft/, .craft-layer/, "
      + 'CRAFT_BUILD_TASK) — the slot->region mapping is this gate\'s only input, and without it the check '
      + 'degrades to a whole-page grep that fires on a correct objection section. NEVER A PASS.')
  }

  const wanted = []
  const alsoMethod = []
  for (const [slot, anchors] of Object.entries(spine.map)) {
    const k = slot.replace(/[^a-z]/g, '')
    if (!BUYER[k]) continue
    for (const a of anchors) {
      wanted.push({ slot: BUYER[k], anchor: a })
      for (const [s2, a2] of Object.entries(spine.map)) {
        if (METHOD.has(s2.replace(/[^a-z]/g, '')) && a2.includes(a)) alsoMethod.push(`${a} (${BUYER[k]} + ${s2})`)
      }
    }
  }
  if (!wanted.length) {
    return record('spine-register', 'SKIP',
      `${spine.path} maps no buyer slot (plain-what / audience / problem) — declared: "${spine.declared}"`)
  }
  if (alsoMethod.length) {
    notes.push(`spine-register: ${[...new Set(alsoMethod)].join(', ')} answers a buyer slot AND a method slot; `
      + 'graded as a buyer region, because the buyer\'s question is the one that gets displaced')
  }

  const anchors = [...new Set(wanted.map((w) => w.anchor))]
  const found = new Map()
  for (const f of sourceFiles(process.cwd())) {
    if (found.size === anchors.length) break
    let src
    try {
      if (statSync(f).size > 512 * 1024) continue
      src = readFileSync(f, 'utf8')
    } catch { continue }
    for (const anchor of anchors) {
      if (found.has(anchor)) continue
      const region = regionFor(src, anchor)
      if (region) found.set(anchor, { file: f, src, region })
    }
  }

  const hits = []
  const checked = []
  const unreadable = []
  for (const { slot, anchor } of wanted) {
    const f = found.get(anchor)
    if (!f) { unreadable.push(`#${anchor} (${slot}): no element carries that id in the shipped source`); continue }
    const chunks = copyChunks(f.src.slice(f.region.start, f.region.end))
    if (!chunks.length) {
      unreadable.push(`#${anchor} (${slot}): ${rel(f.file)} carries the id on `
        + `${f.region.selfClosing ? 'a self-closing element' : `a <${f.region.tag}> holding no copy`} — move the id onto the element that holds the slot's copy`)
      continue
    }
    checked.push(`#${anchor} (${slot})`)
    for (const c of chunks) {
      for (const { cls, re } of compiled) {
        re.lastIndex = 0
        const m = re.exec(c.text)
        if (m) hits.push({ slot, anchor, cls, marker: m[0].trim(), file: rel(f.file), line: lineAt(f.src, f.region.start + c.at) })
      }
    }
  }
  for (const u of unreadable) notes.push(`spine-register: ${u} — that slot is NOT CHECKED`)

  if (!checked.length) {
    return record('spine-register', 'SKIP',
      `none of the mapped buyer regions [${anchors.map((a) => `#${a}`).join(', ')}] resolved to copy in the shipped source — never a pass`)
  }

  const seen = new Set()
  const uniq = hits.filter((h) => {
    const k = `${h.anchor}|${h.cls}|${h.marker.toLowerCase()}`
    if (seen.has(k)) return false
    seen.add(k)
    return true
  })

  /* A CLEAN RESULT OVER PART OF THE BUYER SLOTS IS NOT A CLEAN RESULT.
     Unreadable slots used to be notes only, so one of three regions resolving was
     enough to PASS with two slots ungraded — a note nobody reads standing in for a
     verdict. A FAIL still stands (a marker found is evidence whatever else was
     missed), but a no-hit run over an incomplete set is SKIP, exactly like every
     other input this gate cannot see. */
  if (!uniq.length && unreadable.length) {
    return record('spine-register', 'SKIP',
      `buyer regions [${checked.join(', ')}] carry no marker, but ${unreadable.length} mapped buyer `
      + `slot(s) could not be read — ${unreadable.join('; ')}. Part of the buyer spine was graded and `
      + 'part of it was not, so this is NOT a pass on the remainder. Fix the mapping or the anchor '
      + 'and re-run.')
  }

  const shown = uniq.slice(0, 6).map((h) =>
    `${h.slot} region #${h.anchor} answers in [${h.cls}] register — "${h.marker}" at ${h.file}:${h.line}`).join('; ')
  settle('spine-register', uniq.length > 0, uniq[0]?.cls ?? '',
    `${shown}${uniq.length > 6 ? ` (+${uniq.length - 6} more)` : ''}. `
      + `The same disclosure is LEGAL in how-it-works and objection, which were not checked; here it is standing `
      + `in for a buyer's answer. Reproduce: grep -n ${JSON.stringify(uniq[0]?.marker ?? '')} ${uniq[0]?.file ?? ''}`,
    `all ${checked.length} mapped buyer region(s) [${checked.join(', ')}] were readable and carry no `
      + `marker from the ${corpus.kind} (${corpus.date}); the other five slots are unchecked by construction`)
}

/* --------------------------------------------------------------- run stamp */

/* FOUR ARTIFACTS, ONE RUN — OR EVERY GATE BELOW IS GRADING SOMEONE ELSE'S BUILD.
 *
 * The craft artifacts live at FIXED names so a later session can find them without
 * being told. That is also what lets a SECOND run in one session land on the first
 * run's files, and it has happened: a previous run's contract sat exactly where the
 * audit globs, and a person caught it rather than a gate. So every artifact opens
 * with an identical `Run: <instant> · <slug> · <project root>` stamp
 * (creative-direction/references/offer-contract.md, Part 8), and this assertion is
 * the scripted half of the tiebreak stated there. Three shapes fail, and each means
 * at least one file was left behind by an earlier run: the artifacts DISAGREE, one
 * is stamped to a project that is not this one, or one carries no stamp while a
 * sibling does. A second candidate path holding a different stamp fails too —
 * precedence picked one, which is not the same as deciding between them.
 *
 * It never guesses a winner. No stamp anywhere is a SKIP that says so, exactly like
 * every other input this gate cannot see. */

const STAMP_LINE = /^\s*[-*]?\s*Run\s*:\s*(.+?)\s*$/i

function readStamp(p) {
  try {
    for (const line of readFileSync(p, 'utf8').split('\n')) {
      const m = line.match(STAMP_LINE)
      if (m) return m[1].replace(/[`*]/g, '').trim()
    }
  } catch { /* unreadable reads as unstamped, and is reported as such */ }
  return null
}

const realish = (p) => { try { return realpathSync(p) } catch { return resolve(p) } }

/** The stamp's third field, when it names a project that is not this one. A
    non-absolute or absent field is not a mismatch — there is nothing to compare. */
function foreignProject(stamp) {
  const declared = stamp.split('·').map((s) => s.trim())[2]
  if (!declared || !declared.startsWith('/')) return null
  const a = realish(declared)
  const b = realish(process.cwd())
  return (a === b || a.startsWith(`${b}/`) || b.startsWith(`${a}/`)) ? null : declared
}

function craftStamp() {
  const rows = []
  for (const [name, list] of Object.entries(ARTIFACT_PATHS)) {
    const paths = []
    for (const c of list().filter(Boolean)) {
      const p = resolve(process.cwd(), c)
      if (paths.includes(p)) continue
      try { if (!existsSync(p) || !statSync(p).isFile()) continue } catch { continue }
      paths.push(p)
    }
    if (paths.length) {
      rows.push({
        name,
        pick: paths[0],
        stamp: readStamp(paths[0]),
        extras: paths.slice(1).map((p) => ({ path: p, stamp: readStamp(p) })),
      })
    }
  }
  if (!rows.length) {
    return record('craft-stamp', 'SKIP', 'no craft artifact resolved — nothing to attribute to a run')
  }

  const shown = rows.map((r) => `${r.name} (${rel(r.pick)}) ${r.stamp ? `"${r.stamp}"` : 'NO STAMP'}`).join('; ')
  const stamped = rows.filter((r) => r.stamp)
  if (!stamped.length) {
    return record('craft-stamp', 'SKIP',
      `no 'Run:' stamp on any resolved artifact — ${shown}. Pre-stamp artifacts all read as one run, so `
      + "a previous run's leftovers at these same fixed paths cannot be told from this run's own. NEVER A PASS.")
  }

  const distinct = [...new Set(stamped.map((r) => r.stamp))]
  const problems = []
  if (distinct.length > 1) {
    problems.push(`the artifacts disagree about which run wrote them — ${distinct.map((s) => `"${s}"`).join(' vs ')}`)
  }
  for (const r of rows) {
    if (!r.stamp) {
      problems.push(`${r.name} ${rel(r.pick)} carries NO stamp while a sibling does, so it cannot be attributed to this run`)
    } else {
      const foreign = foreignProject(r.stamp)
      if (foreign) problems.push(`${r.name} ${rel(r.pick)} is stamped to ${foreign}, which is not ${process.cwd()}`)
    }
    for (const e of r.extras) {
      if (e.stamp !== r.stamp) {
        problems.push(`${r.name} also exists at ${rel(e.path)} carrying `
          + `${e.stamp ? `a different stamp ("${e.stamp}")` : 'no stamp'} — AMBIGUOUS, and path precedence `
          + `picked ${rel(r.pick)} without deciding anything`)
      }
    }
  }

  settle('craft-stamp', problems.length > 0, distinct[0] ?? '',
    `${problems.join('; ')}. At least one artifact was left behind by an earlier run, and every gate that `
      + `reads it is grading this build against another run's decisions. Resolved: ${shown}. Reproduce: `
      + `grep -n '^Run:' ${rows.flatMap((r) => [rel(r.pick), ...r.extras.map((e) => rel(e.path))]).join(' ')}`,
    `${stamped.length} resolved artifact(s) carry one stamp — "${distinct[0]}"`)
}

const anti = loadAntiCorpus()
console.log(`anti-corpus source: ${anti.source}`)
console.log(`anti-corpus kind:   ${anti.kind} · snapshot date ${anti.date}`)

const registerCorpus = loadRegisterCorpus()
console.log(`register corpus:    ${registerCorpus.source}`)
console.log(`register corpus:    ${registerCorpus.kind} · ${registerCorpus.rules.length} patterns · ${registerCorpus.date}`)
spineRegister(registerCorpus)
craftStamp()
/* Reads SOURCE only, so like the register assertion it runs BEFORE the token
   resolution below and its verdict survives an exit-2 run. A page whose CSS
   lives somewhere unusual is not a page whose SHAPE goes unmeasured. */
compositionShape()
/* The copy-half pair reads SOURCE only too, so it also runs ahead of the token
   resolution and its verdicts survive an exit-2 run. One walk feeds both. */
const shippedCopy = pageCopy()
emojiAsIcon(shippedCopy)
copyRegister(shippedCopy)

/** Print what IS measured before a not-measured exit, so the register verdict is
    never swallowed by a missing token source. */
const flushEarly = () => {
  console.log('')
  for (const r of results) console.log(`  ${r.state.padEnd(6)} ${r.check.padEnd(20)} ${r.detail}`)
  for (const n of notes) console.log(`  note   ${n}`)
  if (results.some((r) => r.state === 'FAIL')) {
    console.log('  ^ MEASURED AND FAILED. That finding stands on its own; this run exits 2 only')
    console.log('    because the TOKEN assertions could not run.')
  }
}

const tokenPath = findTokenSource()
if (!tokenPath) {
  console.log(`\nnot measured: no token source found (tried ${TOKEN_CANDIDATES.join(', ')})`)
  console.log('NOT MEASURED IS A FAILURE HERE. A gate that cannot see the build cannot')
  console.log('clear it — set CRAFT_TOKEN_SOURCE to the CSS holding the tokens.')
  flushEarly()
  process.exit(2)
}
let css
try {
  css = readFileSync(tokenPath, 'utf8')
} catch (e) {
  console.log(`\nnot measured: token source ${tokenPath} unreadable (${e.message})`)
  flushEarly()
  process.exit(2)
}
const accents = readAccents(css)
if (!accents.length) {
  console.log(`\nnot measured: ${tokenPath} declares no parseable accent/primary/brand colour`)
  console.log('(oklch(), hsl() and 6-digit hex are understood; an achromatic accent has no hue).')
  console.log('NOT MEASURED IS A FAILURE HERE — see the file header.')
  flushEarly()
  process.exit(2)
}
console.log(`token source:       ${tokenPath}`)
if (accents[0]?.resolvedBy) console.log(`accent resolution:  ${accents[0].resolvedBy} -> ${accents[0].name}`)

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

const echo = brandEcho()
const drawn = readDraw()

/* THE RUN MUST NOT BE COMPARED AGAINST ITSELF.
 *
 * craft.md appends this run's row AFTER the audit, so the first pass sees a log without
 * it. Every pass after that — a re-run, a CI job on a committed project, anyone typing the
 * command twice — sees the row this same build just wrote and fails the build for
 * repeating a hue it never repeated. The gate would be single-use, and worse, it would
 * fail hardest on projects diligent enough to keep their log.
 *
 * The draw is the run's fingerprint. A LAST row whose five-axis draw equals the draw in
 * the current divergence record can only be this run's own record, because the draw is
 * written once per run and excludes what earlier rows used. Drop exactly that row, and say
 * so, so the exclusion is never silent. */
const logAll = readRunLog(notes)
let log = logAll
if (logAll.length) {
  const last = logAll[logAll.length - 1]
  const norm = (s) => String(s ?? '').toLowerCase().replace(/\s+/g, ' ').trim()

  // Draw match is the strongest signal, but a run with no persisted divergence record has
  // no draw to match — and that run would then fail against its own row, which is the
  // whole defect. Fall back to the hue family, which every logged row carries and which
  // the gate has already resolved for this build.
  const drawMatch =
    drawn && norm(last.draw) === norm(AXES.map((a) => drawn.draw[a]).join(' / '))
  const hueMatch =
    accents.length > 0 && norm(last['hue-family'] ?? '').includes(norm(accents[0].family))

  if (drawMatch || hueMatch) {
    log = logAll.slice(0, -1)
    notes.push(
      `last log row is THIS run's own record (matched on ${drawMatch ? 'draw' : 'hue family'})` +
        ' — excluded from the repeat assertions, because a run is not a repeat of itself',
    )
  }
}

if (echo) notes.push(`brand-echo row found in ${echo.path} ("${echo.value}") — repeat assertions skipped`)

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

/* THE ANTI-CORPUS WAS LATIN-ONLY, SO EVERY OTHER SCRIPT HAD NO DEFAULT.
 *
 * The registry names Inter and Geist — the faces a generated page reaches for
 * first. That list is correct and it is entirely Latin, and the matcher below
 * needs the shipped family name to appear IN the registry text, so no wording
 * in a markdown bullet can cover a family-per-script.
 *
 * A Hebrew build shipped "Noto Sans Hebrew Variable" and passed clean. Noto is
 * Google's universal-coverage fallback set: `Noto Sans <script>` is what an
 * unstyled page renders in for that script, what the CLI installs, and what a
 * model names when asked for "a font that supports <script>". It is Inter's
 * exact role in every writing system Latin does not own — the category default,
 * arrived at by not choosing.
 *
 * So the Noto rule lives in CODE rather than in the registry text, and it is a
 * PATTERN over the family name rather than a list, because the list would need
 * one row per script and would be wrong the day a script was missing.
 *
 * This is waivable and often SHOULD be waived: for some scripts the quality
 * alternatives are few or none, and Noto is then a real choice rather than a
 * default. A waiver with that reason is the difference — same as a centred
 * spine in `composition-shape`. What must not pass silently is the build that
 * never looked. */
const NOTO_DEFAULT = /^\s*Noto\s+(?:Sans|Serif|Naskh|Nastaliq|Kufi|Rashi)\b/i

if (!families.length) record('font-anti-corpus', 'SKIP', `no non-generic font-family declared in ${cssFiles.join(', ')}`)
else {
  const listed = families.find((f) =>
    new RegExp(`(^|[^A-Za-z])${f.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}([^A-Za-z]|$)`, 'i').test(anti.familyText))
  const noto = families.find((f) => NOTO_DEFAULT.test(f))
  const hit = listed ?? noto
  settle('font-anti-corpus', !!hit, hit ?? '',
    listed
      ? `"${listed}" is an anti-corpus family in the ${anti.kind} (${anti.date}) — the category default, `
        + `not a derived spec. Reproduce: grep -rn "font-family" ${cssFiles.join(' ')}`
      : `"${noto}" is the per-script category default. Noto is Google's universal-coverage `
        + `fallback set: \`Noto Sans <script>\` is what an unstyled page renders in, what the CLI `
        + `installs, and what gets named when the brief asks for "a font that supports" the `
        + `script — it is Inter's role outside Latin, and it is arrived at by not choosing. `
        + `Pick a face with a real argument behind it, or waive this with the reason (for some `
        + `scripts the alternatives are genuinely few, and that is a decision worth recording). `
        + `Reproduce: grep -rn "font-family" ${cssFiles.join(' ')}`,
    `shipped families [${families.join(', ')}] are not anti-corpus entries and none is a Noto per-script default`)
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
const skipped = results.filter((r) => r.state === 'SKIP')
const graded = results.length - skipped.length
console.log('')

/* COVERAGE BEFORE VERDICT. Every assertion here SKIPs when its input artifact is
   absent, and a build that produced no craft artifacts and declared no typeface
   skips nearly all of them — so the terminator used to print the identical green
   over 1-of-7 graded as over 7-of-7. That is the has-teeth over-claim this repo's
   own convention forbids, printed by the file that calls itself "the teeth": the
   laziest possible build read as "clears every divergence assertion", while a
   build that did the work was the only one that could fail. Coverage is now
   stated on every run, and the clean line says how many assertions it speaks for.
   A SKIP is still not a failure — the gate genuinely cannot grade an input it was
   never given — but it can no longer be silently counted as a pass. */
console.log(`coverage: ${graded}/${results.length} assertion(s) graded`
  + (skipped.length ? `, ${skipped.length} SKIP (${skipped.map((r) => r.check).join(', ')})` : ''))
console.log(failed.length
  ? `${failed.length} divergence assertion(s) FAILED — the build landed on a default it was told to leave.`
  : graded === 0
    ? 'NOT MEASURED: every assertion skipped — this run proves nothing about divergence.'
    : `OK: the build clears the ${graded} divergence assertion(s) that could be graded.`)
process.exit(failed.length ? 1 : 0)
