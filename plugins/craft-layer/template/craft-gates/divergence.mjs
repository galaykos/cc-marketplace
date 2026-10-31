// divergence.mjs — craft-layer's anti-attractor gate: exit 1 when the build lands on the category default (hue, family, copy, layout) or repeats its last five runs, 0 clean, 2 not measured, a failure (as in contrast.mjs, a missing token source is never a pass). Run `node ${CLAUDE_PLUGIN_ROOT}/template/craft-gates/divergence.mjs` from the project root.
// Env: CRAFT_TOKEN_SOURCE, CRAFT_CONTRACT, CRAFT_DIVERGENCE_RECORD, CRAFT_BUILD_TASK, CRAFT_CONTENT_SOURCE set each input's path; CLAUDE_PLUGIN_ROOT reads the registries live. Misses: a chosen hue or face told from a default unless `Brand echo:` names it (else waive it with a reason), class lists built in variables or cn(), colours through props, arrangement beyond one measure, copy depth and the voice itself (agent-graded).
// Why, limits, history: rationale/derivations/plugin-craft-layer.md § plugins/craft-layer/template/craft-gates/divergence.mjs
import { readFileSync, existsSync, statSync, readdirSync, realpathSync } from 'node:fs'
import { join, dirname, basename, resolve, relative } from 'node:path'

// Embedded fallback only: the live registry is read when CLAUDE_PLUGIN_ROOT is set, and source and date print every run.
const SNAPSHOT = {
  date: '2026-07-26',
  familyText: [
    'The neutral geometric/grotesque UI sans that generated pages reach for',
    'first — Inter and Geist by name, and any face chosen because it is what a',
    'starter template shipped with. The two-family serif-display-over-grotesque',
    'pairing reached for as the house move rather than derived.',
  ].join(' '),
}

// The violet/indigo band generated pages converge on; it never ages out of the recency window. Read in each token's own colour space.
const DEFAULT_BAND = [275, 315]

/** A corpus's own `verified:` stamp, never its mtime (the date bytes moved, not the date anyone reviewed it); proves only what the file says; an unstamped corpus shows its mtime, labelled so. */
function corpusDate(text, path) {
  const m = text.match(/verified:\s*(\d{4}-\d{2}-\d{2})/i)
  if (m) return m[1]
  return `${statSync(path).mtime.toISOString().slice(0, 10)} (unstamped, mtime)`
}

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
        date: corpusDate(text, p),
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

/** 0..1 saturation comparable across notations; only ranks tokens when no accent is named. */
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

/** oklch() / hsl() / #rrggbb -> { c, h } in OKLCH, one space for every notation unlike toHue; h null when achromatic, null when unparsed. */
function toOklch(value) {
  const v = value.trim()
  let m = v.match(/^oklch\(\s*([^\s,]+)[\s,]+([^\s,]+)[\s,]+([^\s,)/]+)/i)
  if (m) {
    const c = /%$/.test(m[2]) ? num(m[2]) * 0.004 : num(m[2])   // CSS maps 100% chroma to 0.4
    return { c, h: c === 0 ? null : norm(num(m[3])) }
  }
  let rgb = null
  m = v.match(/^#([0-9a-f]{6})\b/i)
  if (m) rgb = [0, 2, 4].map((i) => parseInt(m[1].slice(i, i + 2), 16) / 255)
  m = v.match(/^hsla?\(\s*([^\s,]+)[\s,]+([^\s,]+)[\s,]+([^\s,)/]+)/i)
  if (m) {
    const h = norm(num(m[1])), s = num(m[2]) / 100, l = num(m[3]) / 100
    const k = (n) => (n + h / 30) % 12
    const a = s * Math.min(l, 1 - l)
    rgb = [0, 8, 4].map((n) => l - a * Math.max(-1, Math.min(k(n) - 3, 9 - k(n), 1)))
  }
  if (!rgb) return null
  const [r, g, b] = rgb.map((c) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4))
  const L = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
  const M = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
  const S = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
  const A = 1.9779984951 * L - 2.428592205 * M + 0.4505937099 * S
  const B = 0.0259040371 * L + 0.7827717662 * M - 0.808675766 * S
  const c = Math.hypot(A, B)
  return { c, h: c < 1e-3 ? null : norm((Math.atan2(B, A) * 180) / Math.PI) }
}

const oklchHue = (value) => toOklch(value)?.h ?? null

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

  /* No accent/primary/brand name (a hue-flat system names tokens by role): test the most chromatic token, reported as a fallback. */
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

/** Non-generic families from font-family:, Tailwind v4 `--font-*` theme variables (through var() too) and @font-face. */
function readFamilies(css) {
  const out = new Map()
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

const LOG_PATH = '.craft-layer/run-log.md'
const COLUMNS = ['date', 'brief-slug', 'hue-family', 'type-strategy', 'spine', 'signature', 'draw']

/** Last 5 rows; a malformed log is EMPTY, never fatal, and every dropped row is counted in a note. Cells map by position: add columns at the end only. */
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

// Precedence order per artifact; craft-stamp reads the whole list (an extra candidate is an ambiguity), every other reader the first that exists.
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

const ECHO_COLOUR = /oklch\([^)]*\)|hsla?\([^)]*\)|#[0-9a-f]{6}\b/gi

// Under 0.05 OKLCH chroma an echoed colour is a tinted neutral ink, not an accent.
const ECHO_CHROMA_FLOOR = 0.05

/** A `Brand echo:` value's accent hues (OKLCH) and the text outside parentheses a family must appear in whole-word. Misses 3-digit hex and named colours; "Inter" matches "Inter Display" and "not Inter". */
function echoNames(echo) {
  if (!echo) return null
  const hues = [...echo.value.matchAll(ECHO_COLOUR)].map((m) => toOklch(m[0]))
    .filter((o) => o && o.h !== null && o.c >= ECHO_CHROMA_FLOOR).map((o) => o.h)
  return { path: echo.path, hues, text: echo.value.replace(ECHO_COLOUR, ' ').replace(/\([^()]*\)/g, ' ') }
}

// Takes an OKLCH hue; 15°, the hue-repeat window, because a kept brand ships as a ramp around one hue.
const echoesHue = (names, h) =>
  !!names && h !== null && names.hues.some((e) => Math.min(Math.abs(e - h), 360 - Math.abs(e - h)) <= 15)

const echoesFamily = (names, f) => !!names
  && new RegExp(`(^|[^A-Za-z])${f.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}([^A-Za-z]|$)`, 'i').test(names.text)

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

/* spine-register: only the three buyer slots (plain-what, audience, problem) are graded for integrator register, scoped by the build task's `Spine regions:` line, which must sit on ONE line, never wrapped. Corpus and limits: skills/creative-direction/references/register-corpus.md */

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

/** The register corpus, live from the plugin when CLAUDE_PLUGIN_ROOT is set; source and date print every run. */
function loadRegisterCorpus() {
  const root = process.env.CLAUDE_PLUGIN_ROOT
  if (root) {
    const p = join(root, 'skills/creative-direction/references/register-corpus.md')
    if (existsSync(p)) {
      try {
        const text = readFileSync(p, 'utf8')
        const m = text
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
          return { source: p, kind: 'live corpus', date: corpusDate(text, p), rules }
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
    /* Bare, list-marker and heading (`## Spine regions:`) forms all parse. */
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

/** The element carrying `id="<anchor>"`, bounded by tag balance on its own tag name so the region never runs on into later sections. */
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

/* data-* is deliberately not read: test ids and state hooks are code-shaped (`\w+_id`) but no reader sees them. */
const COPY_ATTR = /\b(?:alt|title|aria-label|placeholder)\s*=\s*(?:"([^"]*)"|'([^']*)')/g
const COPY_KEY = /\b(?:title|label|heading|headline|eyebrow|kicker|lede|subhead|body|copy|text|description|blurb|caption|question|answer|cta|summary|tagline)\s*:\s*(?:"([^"]*)"|'([^']*)'|`([^`]*)`)/g

/** What a reader sees: text between tags, copy attributes, quoted values of copy-bearing keys — never code. `isCopy` defaults to "holds a letter"; emoji-as-icon passes its own. */
function copyChunks(slice, isCopy = (s) => /\p{L}/u.test(s)) {
  const blank = (m) => ' '.repeat(m.length)
  const s = slice
    .replace(/<(script|style)[\s\S]*?<\/\1>/gi, blank)
    .replace(/<!--[\s\S]*?-->/g, blank)
    .replace(/\/\*[\s\S]*?\*\//g, blank)
  const out = []
  let i = s.indexOf('<')
  /* The leading text run counts (a text-only leaf has no child tag); text is `\p{L}`, never `[A-Za-z]`, so non-Latin pages hold copy. */
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

/* composition-shape FAILs only when one `mx-auto max-w-*` measure holds 70%+ of those containers AND positioned/spanning/bleeding escapes number under one per two sections. Rhythm is reported, never failed; no fixed measure passes; a deliberate centred spine is waived with its reason. */

const ESCAPE_RE = /\b(?:absolute|sticky|fixed|col-span-\w|row-span-\w|col-start-\w|row-start-\w|inset-|w-screen|clip-path|mix-blend-|grid-area)/g
const CLASS_RE = /class(?:Name)?\s*=\s*(?:"([^"]*)"|'([^']*)'|\{\s*`([^`]*)`\s*\})/g

/* Tests, stories, scripts and config quote the utilities this counts; they describe the page, they are not it. */
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
      /* Escapes count inside class strings only, so prose saying "absolute" is not structure. */
      escapes += (cls.match(ESCAPE_RE) ?? []).length
      if (/\bmx-auto\b/.test(cls)) {
        const w = /\bmax-w-(\[[^\]\s]+\]|[a-z0-9]+)/.exec(cls)
        if (w) measures.set(w[1], (measures.get(w[1]) ?? 0) + 1)
      }
      /* Section-scale padding only: py-2 is a button, py-4 a nav row. */
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

/* voice-contract: the build task's `Voice:` line must exist and carry a `NEVER "<literal>"` (exit 1); copy-register grades the literals; the voice itself is agent-graded. No build task is a SKIP, never a FAIL. */

const NEVER_RE = /NEVER\s+(?:"([^"]{2,80})"|'([^']{2,80})'|\u201c([^\u201d]{2,80})\u201d)/g

/** `Voice: <person> · <band> · <fragments> · NEVER "x", NEVER "y"` */
function readVoice() {
  const p = buildTaskPath()
  if (!p) return null
  let text
  try { text = readFileSync(p, 'utf8') } catch { return null }
  for (const line of text.split('\n')) {
    /* Same tolerant key shape as `Spine regions:`: bare, list-marker and heading forms. */
    const m = line.match(/^\s*#{0,6}\s*[-*]?\s*\**\s*Voice\s*\**\s*:\s*(.+?)\s*$/i)
    if (!m) continue
    const nevers = []
    NEVER_RE.lastIndex = 0
    let n
    while ((n = NEVER_RE.exec(m[1]))) {
      const lit = (n[1] ?? n[2] ?? n[3]).trim()
      if (lit) nevers.push(lit)
    }
    return { path: p, value: m[1], nevers }
  }
  return { path: p, value: null, nevers: [] }
}

function voiceContract(voice) {
  if (!voice) {
    return record('voice-contract', 'SKIP',
      'no build task resolved (tried craft/, taskmaster-docs/craft/, .craft-layer/, CRAFT_BUILD_TASK) — '
      + 'a build is never failed for not having saved a file. NEVER A PASS.')
  }
  if (voice.value === null) {
    return settle('voice-contract', true, 'absent',
      `${rel(voice.path)} carries no \`Voice:\` line. The concept's editorial voice reached the build as a `
      + 'typographic role and nothing else, so the product-specific half of the copy grade has no input and '
      + 'copy-register falls back to the category lexicon alone. Write the line at step 5, four dimensions '
      + 'separated by `·`: person and address, a sentence-length band in words, what it does with fragments/'
      + 'questions/imperatives, and 2-3 `NEVER "<literal>"` items. Shape and standing: '
      + 'skills/creative-direction/references/voice-contract.md. '
      + `Reproduce: grep -n '^Voice:' ${rel(voice.path)}`,
      '')
  }
  if (!voice.nevers.length) {
    return settle('voice-contract', true, 'no-nevers',
      `${rel(voice.path)}'s \`Voice:\` line carries no \`NEVER "<literal>"\` item, so the line has no `
      + 'machine-readable half and this run grades the voice with prose only. The NEVERs are the one '
      + 'dimension a script can check — two or three exact strings THIS product does not say, taken from '
      + 'the concept rather than from the sameness registry (those are already in the lexicon). '
      + `Reproduce: grep -n '^Voice:' ${rel(voice.path)}`,
      '')
  }
  record('voice-contract', 'PASS',
    `${rel(voice.path)} carries a \`Voice:\` line with ${voice.nevers.length} literal NEVER(s) `
    + `[${voice.nevers.map((v) => JSON.stringify(v)).join(', ')}], graded against shipped copy by copy-register. `
    + 'Whether the person, the sentence band and the fragment rules were honoured is agent-graded — no script counts a sentence.')
}

/* emoji-as-icon and copy-register: the mechanical tells of the copy register, read from reader-visible copy across the whole page, harness excluded. Multi-word phrases only — a single word fires on honest copy. Both waivable. */

/* Frozen fallback for the registry's copy-lexicon block. Rows are `label :: flags :: min :: pattern`; `min` is how many distinct copy chunks must match, for the repetition tells (eyebrow, trailing arrow). */
const COPY_SNAPSHOT = {
  date: '2026-09-22',
  rules: [
    ['supercharge your', 'gi', 1, String.raw`\bsupercharge\s+your\b`],
    ['seamlessly integrate', 'gi', 1, String.raw`\bseamlessly\s+integrat\w*`],
    ['take your * to the next level', 'gi', 1, String.raw`\btake\s+your\s+[^<>.!?]{0,60}?to\s+the\s+next\s+level\b`],
    ['effortless. powerful.', 'gi', 1, String.raw`\beffortless\.\s*powerful\.`],
    ['unlock the power', 'gi', 1, String.raw`\bunlock\s+the\s+power\b`],
    ['game-changing', 'gi', 1, String.raw`\bgame-chang(?:ing|ers?)\b`],
    ['all-caps eyebrow', 'g', 3, String.raw`^\s*[A-Z][A-Z0-9&'\u2019]*(?:\s+[A-Z0-9&'\u2019]+){1,4}\s*$`],
    ['middle-dot meta string', 'g', 1, String.raw`\u00b7[^\u00b7\n]{1,60}\u00b7`],
    ['trailing arrow', 'g', 3, String.raw`[^\u2192\n]{0,40}[^\s\u2192]\s*\u2192\s*$`],
  ],
}

/** The copy lexicon, live from the registry when CLAUDE_PLUGIN_ROOT is set; a row added there is armed here with no code change. */
function loadCopyLexicon() {
  const root = process.env.CLAUDE_PLUGIN_ROOT
  if (root) {
    const p = join(root, 'skills/creative-direction/references/sameness-fingerprint.md')
    if (existsSync(p)) {
      try {
        const text = readFileSync(p, 'utf8')
        const m = text.match(/<!--\s*copy-lexicon:start\s*-->([\s\S]*?)<!--\s*copy-lexicon:end\s*-->/)
        const rules = []
        for (const line of (m ? m[1] : '').split('\n')) {
          const t = line.trim()
          if (!t || t.startsWith('```')) continue
          const parts = t.split(' :: ')
          if (parts.length < 4) continue
          const min = parseInt(parts[2].trim(), 10)
          rules.push([parts[0].trim(), parts[1].trim(), Number.isFinite(min) && min > 0 ? min : 1,
            parts.slice(3).join(' :: ').trim()])
        }
        if (rules.length) {
          return { source: p, kind: 'live registry', date: corpusDate(text, p), rules }
        }
      } catch { /* fall through to the snapshot */ }
    }
  }
  return {
    source: 'embedded snapshot (CLAUDE_PLUGIN_ROOT unset or registry missing)',
    kind: 'frozen snapshot',
    date: COPY_SNAPSHOT.date,
    rules: COPY_SNAPSHOT.rules,
  }
}

/* Legal marks are text-default and U+FE0E opts a pictograph out; keycap digits never match Extended_Pictographic. */
const TEXT_MARKS = new Set(['©', '®', '™', '℠', '℗'])
const PICTO_RE = /\p{Extended_Pictographic}\uFE0E?/gu
const HAS_PICTO = /\p{Extended_Pictographic}/u

/* A quoted subtree (<blockquote>, <q>) is the customer's voice, not the build's icon system, so it is blanked first. */
const QUOTED_RE = /<(blockquote|q)\b[\s\S]*?<\/\1\s*>/gi

/** Shipped page source with its text, harness excluded; one read feeds both copy-half assertions. */
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

const escapeLiteral = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/\s+/g, String.raw`\s+`)

function copyRegister(files, lexicon, voice) {
  if (!files.length) return record('copy-register', 'SKIP', 'no shipped page source found to hold copy')
  /* The run's own NEVERs ride the lexicon as extra rows; whitespace is relaxed so a wrapped literal still matches. */
  const voiceRows = (voice?.nevers ?? []).map((lit) => [`voice NEVER ${JSON.stringify(lit)}`, 'gi', 1, escapeLiteral(lit)])
  const compiled = []
  for (const [label, flags, min, source] of [...lexicon.rules, ...voiceRows]) {
    try { compiled.push({ label, min, re: new RegExp(source, flags.includes('g') ? flags : `${flags}g`) }) } catch (e) {
      notes.push(`copy lexicon: the '${label}' pattern will not compile (${e.message}) — DROPPED, so that phrase is unchecked`)
    }
  }
  if (!compiled.length) return record('copy-register', 'SKIP', 'the copy lexicon compiled no patterns')
  const raw = []
  for (const { file, src } of files) {
    for (const c of copyChunks(src)) {
      for (const { label, min, re } of compiled) {
        re.lastIndex = 0
        const m = re.exec(c.text)
        /* A phrase can span a source line break; collapsed so the report stays one row. */
        if (m) raw.push({ label, min, marker: m[0].trim().replace(/\s+/g, ' '), file: rel(file), line: lineAt(src, c.at) })
      }
    }
  }
  /* A `min` above 1 is a repetition tell: a finding once that many distinct chunks carry it, counted across the whole page set. */
  const seenByLabel = new Map()
  for (const h of raw) seenByLabel.set(h.label, (seenByLabel.get(h.label) ?? 0) + 1)
  const hits = raw.filter((h) => (seenByLabel.get(h.label) ?? 0) >= h.min)
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
      + 'A `voice NEVER` row is a string THIS concept ruled out on the build task\'s `Voice:` line; every other '
      + 'row is one a reader identifies as generated in one line (sameness-fingerprint.md, the copy register and '
      + 'the mechanical chrome rows) — a build leaning on either has authored nothing. Write copy with the '
      + `product's own nouns in it, or waive this with the reason. Reproduce: grep -rni ${JSON.stringify(uniq[0]?.marker ?? '')} ${uniq[0]?.file ?? ''}`,
    `no row of the ${compiled.length}-pattern lexicon (${lexicon.kind}, ${lexicon.date}) fires in reader-visible `
      + `copy across ${files.length} page file(s); single words ("seamless" alone) are not graded by construction, and `
      + `the repetition rows (eyebrow, trailing arrow) need ${Math.max(...compiled.map((c) => c.min))} distinct chunks before they do`)
}

/* utility-palette and utility-font: the category-default hue and family arriving through class strings, next/font imports or Google Fonts links, which accent-default-band and font-anti-corpus (CSS only) never see. Source-only, so they survive an exit-2 run. Misses: class lists built in variables or cn(), colours through props, in-band hex outside DEFAULT_SWATCHES where sRGB and oklch disagree, a Noto face through a class string. */

// indigo/violet/purple are derived from DEFAULT_BAND (500-step oklch hues 277.1/292.7/303.9; blue and fuchsia fall outside): re-derive them if the band moves.
const UTIL_PROP = 'bg|text|border|from|via|to|ring|shadow|decoration|outline|fill|stroke'
const UTIL_FAMILY = 'indigo|violet|purple'
const UTIL_COLOR_RE = new RegExp(`\\b(?:${UTIL_PROP})-(?:${UTIL_FAMILY})-\\d{2,3}\\b`, 'g')
const CLASS_HEX_RE = /\[#([0-9a-fA-F]{6})\]/g
const STYLE_RE = /\bstyle\s*=\s*(?:\{\{([\s\S]*?)\}\}|"([^"]*)"|'([^']*)')/g
const HEX_RE = /#([0-9a-fA-F]{6})\b/g

const inBand = (h) => h !== null && h >= DEFAULT_BAND[0] && h <= DEFAULT_BAND[1]

/* toHue reads hex in sRGB, where these in-band swatches fall below 275° (indigo-500 #6366f1: 238.7° sRGB, 277.1° oklch), so they are named: steps 400/500/600 of the three families. Converting hex to oklch would flip accent-default-band for every existing build. */
const DEFAULT_SWATCHES = new Set([
  '6366f1', '818cf8', '4f46e5',   // indigo 500 / 400 / 600
  '8b5cf6', 'a78bfa', '7c3aed',   // violet
  'a855f7', 'c084fc', '9333ea',   // purple
])
const isDefaultSwatch = (hex) => DEFAULT_SWATCHES.has(String(hex).toLowerCase())
/* The 500-step oklch angles from the derivation note above, so a named utility can meet a Brand echo. */
const UTIL_FAMILY_OKLCH = { indigo: 277.1, violet: 292.7, purple: 303.9 }

function utilityPalette(files, kept) {
  if (!files.length) return record('utility-palette', 'SKIP', 'no shipped page source found to carry class strings')
  const all = []
  let classStrings = 0
  for (const { file, src } of files) {
    for (const m of src.matchAll(CLASS_RE)) {
      const cls = m[1] ?? m[2] ?? m[3] ?? ''
      classStrings++
      const at = lineAt(src, m.index)
      for (const u of cls.matchAll(UTIL_COLOR_RE)) {
        all.push({ how: 'named utility', marker: u[0], file: rel(file), line: at,
          hue: UTIL_FAMILY_OKLCH[u[0].match(new RegExp(`-(${UTIL_FAMILY})-`))[1]] })
      }
      /* A hex in a class string skips the token layer by construction; band-gated, so chart series and third-party marks pass. */
      for (const h of cls.matchAll(CLASS_HEX_RE)) {
        if (isDefaultSwatch(h[1])) {
          all.push({ how: 'default swatch as hex', marker: `#${h[1]}`, file: rel(file), line: at, hue: oklchHue(`#${h[1]}`) })
          continue
        }
        const hue = toHue(`#${h[1]}`)
        if (inBand(hue)) all.push({ how: `arbitrary value, ${hue.toFixed(1)}° ${hueFamily(hue)}, not a token`, marker: h[0], file: rel(file), line: at, hue: oklchHue(`#${h[1]}`) })
      }
    }
    for (const s of src.matchAll(STYLE_RE)) {
      const decl = s[1] ?? s[2] ?? s[3] ?? ''
      const at = lineAt(src, s.index)
      for (const h of decl.matchAll(HEX_RE)) {
        const hue = toHue(`#${h[1]}`)
        if (inBand(hue)) all.push({ how: `inline style, ${hue.toFixed(1)}° ${hueFamily(hue)}, not a token`, marker: `#${h[1]}`, file: rel(file), line: at, hue: oklchHue(`#${h[1]}`) })
      }
    }
  }
  const echoed = [...new Set(all.filter((h) => echoesHue(kept, h.hue)).map((h) => h.marker))]
  const hits = all.filter((h) => !echoed.includes(h.marker))
  if (echoed.length) notes.push(`utility-palette: [${echoed.join(', ')}] echo the kept brand named in ${kept.path} — not a finding`)
  const seen = new Set()
  const uniq = hits.filter((h) => {
    const k = `${h.file}|${h.marker}`
    if (seen.has(k)) return false
    seen.add(k)
    return true
  })
  const shown = uniq.slice(0, 6).map((h) => `${h.marker} [${h.how}] at ${h.file}:${h.line}`).join('; ')
  settle('utility-palette', uniq.length > 0, uniq[0]?.marker ?? '',
    `the category-default hue reaches the page through the utility layer — ${shown}`
      + `${uniq.length > 6 ? ` (+${uniq.length - 6} more)` : ''}. indigo/violet/purple utilities and in-band `
      + `arbitrary hex are the ${DEFAULT_BAND[0]}-${DEFAULT_BAND[1]}° category default (sameness-fingerprint.md, `
      + `"Recent palette hues" and the category-default note) arriving where accent-default-band cannot see it: `
      + `that assertion reads CSS custom properties only, so a cleanly derived accent token NO ELEMENT REFERENCES `
      + `still clears it. Derive the accent and then use it — or, when the brand genuinely is violet or a `
      + `third-party mark owns that hex, waive this with that reason. `
      + `Reproduce: grep -rn ${JSON.stringify(uniq[0]?.marker ?? '')} ${uniq[0]?.file ?? ''}`,
    (echoed.length ? `no indigo/violet/purple utility, default swatch or in-band arbitrary hex but the kept brand's [${echoed.join(', ')}] across `
      : 'no indigo/violet/purple utility, no default swatch and no in-band arbitrary hex across ')
      + `${classStrings} class string(s) in `
      + `${files.length} page file(s); families derived from the ${DEFAULT_BAND[0]}-${DEFAULT_BAND[1]}° band, not listed by taste`)
}

/* Three ways a family reaches a Tailwind/JSX page without the token stylesheet; `_` (Tailwind) and `+` (Google Fonts) stand for spaces. */
const FONT_ARBITRARY_RE = /\bfont-\[\s*['"]?([\w ]+)['"]?\s*\]/g
const NEXT_FONT_RE = /import\s*\{([^}]*)\}\s*from\s*['"]next\/font\/google['"]/g
const GOOGLE_FAMILY_RE = /fonts\.googleapis\.com\/css2\?[^"'`\s>]*/g
const FAMILY_PARAM_RE = /family=([^&:"'`\s>]+)/g

function utilityFont(files, corpus, kept) {
  if (!files.length) return record('utility-font', 'SKIP', 'no shipped page source found to declare a family')
  const found = []
  const add = (name, file, line, how) => {
    const n = name.replace(/[_+]/g, ' ').trim()
    if (n.length < 3 || !/[A-Za-z]/.test(n) || SYSTEM_STACK.has(n.toLowerCase())) return
    found.push({ name: n, file: rel(file), line, how })
  }
  for (const { file, src } of files) {
    for (const m of src.matchAll(CLASS_RE)) {
      const cls = m[1] ?? m[2] ?? m[3] ?? ''
      for (const f of cls.matchAll(FONT_ARBITRARY_RE)) add(f[1], file, lineAt(src, m.index), 'arbitrary font utility')
    }
    for (const m of src.matchAll(NEXT_FONT_RE)) {
      for (const spec of m[1].split(',')) {
        add(spec.trim().split(/\s+as\s+/)[0].trim(), file, lineAt(src, m.index), 'next/font/google import')
      }
    }
    for (const m of src.matchAll(GOOGLE_FAMILY_RE)) {
      for (const f of m[0].matchAll(FAMILY_PARAM_RE)) add(f[1], file, lineAt(src, m.index), 'Google Fonts link')
    }
  }
  if (!found.length) {
    return record('utility-font', 'SKIP',
      'no family named by an arbitrary `font-[…]` utility, a next/font/google import or a fonts.googleapis.com '
      + `link across ${files.length} page file(s) — nothing to grade at the utility layer`)
  }
  const echoed = [...new Set(found.filter((f) => echoesFamily(kept, f.name)).map((f) => f.name))]
  if (echoed.length) notes.push(`utility-font: [${echoed.join(', ')}] echo the kept brand named in ${kept.path} — not a finding`)
  const hits = found.filter((f) => !echoed.includes(f.name)
    && new RegExp(`(^|[^A-Za-z])${esc(f.name)}([^A-Za-z]|$)`, 'i').test(corpus.familyText))
  const seen = new Set()
  const uniq = hits.filter((h) => {
    const k = `${h.file}|${h.name.toLowerCase()}`
    if (seen.has(k)) return false
    seen.add(k)
    return true
  })
  const names = [...new Set(found.map((f) => f.name))]
  const shown = uniq.slice(0, 6).map((h) => `"${h.name}" [${h.how}] at ${h.file}:${h.line}`).join('; ')
  settle('utility-font', uniq.length > 0, uniq[0]?.name ?? '',
    `${shown}${uniq.length > 6 ? ` (+${uniq.length - 6} more)` : ''} — an anti-corpus family in the `
      + `${corpus.kind} (${corpus.date}), the category default rather than a derived spec. It never reaches the `
      + `stylesheet, so font-anti-corpus records "no non-generic font declared" and the type gate has no teeth on `
      + `exactly the stack this plugin ships guidance for. Pick a face with an argument behind it, or waive this `
      + `with the reason. Reproduce: grep -rn ${JSON.stringify(uniq[0]?.name ?? '')} ${uniq[0]?.file ?? ''}`,
    `families reaching the page through the utility layer [${names.join(', ')}] are not anti-corpus entries in the `
      + `${corpus.kind} (${corpus.date})` + (echoed.length ? ` or echo the kept brand (${echoed.join(', ')})` : ''))
}

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

/* Reads source and the build task only, so it runs first and its verdict survives an exit-2 run. */
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

  /* A no-hit run over an incomplete set of buyer slots is a SKIP, not a pass; a found marker still FAILs. */
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

/* craft-stamp: the four artifacts must carry one identical `Run:` stamp (offer-contract.md Part 8). Disagreeing, foreign-project, unstamped-beside-stamped, or a second candidate with another stamp means a leftover from an earlier run. Never guesses a winner; no stamp anywhere is a SKIP. */

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

/** The stamp's third field when it names another project; a non-absolute or absent field is no mismatch. */
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
// Source-only assertions run before the token resolution below, so their verdicts survive an exit-2 run.
compositionShape()
// One walk feeds both copy-half assertions.
const shippedCopy = pageCopy()
emojiAsIcon(shippedCopy)
const copyLexicon = loadCopyLexicon()
console.log(`copy lexicon:       ${copyLexicon.source}`)
console.log(`copy lexicon:       ${copyLexicon.kind} · ${copyLexicon.rules.length} patterns · ${copyLexicon.date}`)
const voice = readVoice()
voiceContract(voice)
copyRegister(shippedCopy, copyLexicon, voice)
const echo = brandEcho()
const kept = echoNames(echo)
utilityPalette(shippedCopy, kept)
utilityFont(shippedCopy, anti, kept)

/** Print what IS measured before a not-measured exit, so no verdict is swallowed by a missing token source. */
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

const drawn = readDraw()

/* A last log row matching this run's draw or its hue family (the no-record fallback, applied always) is this run's own row: excluded with a note, so a re-run never fails as a repeat of itself. */
const logAll = readRunLog(notes)
let log = logAll
if (logAll.length) {
  const last = logAll[logAll.length - 1]
  const norm = (s) => String(s ?? '').toLowerCase().replace(/\s+/g, ' ').trim()

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

{
  const inBand = accents.filter((a) => a.hue >= DEFAULT_BAND[0] && a.hue <= DEFAULT_BAND[1])
  const echoed = inBand.filter((a) => echoesHue(kept, oklchHue(a.value)))
  const hit = inBand.find((a) => !echoed.includes(a))
  const echoedNames = [...new Set(echoed.map((a) => a.name))]
  if (echoed.length) {
    notes.push(`accent-default-band: ${echoedNames.join(', ')} echo the kept brand named in ${echo.path} — not a finding`)
  }
  settle('accent-default-band', !!hit, hit ? Math.round(hit.hue) : '',
    hit ? `${hit.name}: ${hit.value} — hue ${hit.hue.toFixed(1)}° (${hit.family}) is inside the `
      + `${DEFAULT_BAND[0]}-${DEFAULT_BAND[1]}° category-default band. Reproduce: `
      + `grep -n '${hit.name}' ${tokenPath}` : '',
    `accents at ${accents.map((a) => `${Math.round(a.hue)}° ${a.family}`).join(', ')} clear the `
      + `${DEFAULT_BAND[0]}-${DEFAULT_BAND[1]}° band`
      + (echoed.length ? ` or echo the kept brand (${echoedNames.join(', ')})` : ''))
}

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

/* `Noto Sans|Serif <script>` is the per-script category default (what an unstyled page renders in), so it is a pattern in code, not registry rows. Waive it with a reason where a script has few real alternatives. */
const NOTO_DEFAULT = /^\s*Noto\s+(?:Sans|Serif|Naskh|Nastaliq|Kufi|Rashi)\b/i

if (!families.length) record('font-anti-corpus', 'SKIP', `no non-generic font-family declared in ${cssFiles.join(', ')}`)
else {
  const echoed = families.filter((f) => echoesFamily(kept, f))
  const judged = families.filter((f) => !echoed.includes(f))
  if (echoed.length) {
    notes.push(`font-anti-corpus: [${echoed.join(', ')}] echo the kept brand named in ${echo.path} — not a finding`)
  }
  const listed = judged.find((f) =>
    new RegExp(`(^|[^A-Za-z])${f.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}([^A-Za-z]|$)`, 'i').test(anti.familyText))
  const noto = judged.find((f) => NOTO_DEFAULT.test(f))
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
    echoed.length
      ? `[${echoed.join(', ')}] echo the kept brand${judged.length
        ? `; [${judged.join(', ')}] are not anti-corpus entries and none is a Noto per-script default` : ''}`
      : `shipped families [${families.join(', ')}] are not anti-corpus entries and none is a Noto per-script default`)
}

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

/* Coverage prints before the verdict: a SKIP is not a failure, and never counts as a pass. */
console.log(`coverage: ${graded}/${results.length} assertion(s) graded`
  + (skipped.length ? `, ${skipped.length} SKIP (${skipped.map((r) => r.check).join(', ')})` : ''))
console.log(failed.length
  ? `${failed.length} divergence assertion(s) FAILED — the build landed on a default it was told to leave.`
  : graded === 0
    ? 'NOT MEASURED: every assertion skipped — this run proves nothing about divergence.'
    : `OK: the build clears the ${graded} divergence assertion(s) that could be graded.`)
process.exit(failed.length ? 1 : 0)
