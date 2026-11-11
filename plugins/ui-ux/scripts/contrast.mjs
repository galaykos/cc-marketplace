/* contrast.mjs — craft-layer's contrast gate: WCAG 2 ratios (the conformance gate; APCA is not normative) for the ink, accent, status, focus, border and chart pairings of the colour tokens in the project's token CSS: oklch(), hex, rgb(), hsl() and bare `H S% L%` values, under every `:root`/`html` rule (light) and every `.dark`, `[data-theme=dark]`, `[data-mode=dark]` or `prefers-color-scheme: dark` rule (dark, inheriting light). A translucent colour is composited over its surface first. Run from the project root: `node ${CLAUDE_PLUGIN_ROOT}/template/craft-gates/contrast.mjs`; CRAFT_TOKEN_SOURCE names the file. Exit 1 a pairing fails, 2 not measured — a failure: gates.spec.ts turns axe's color-contrast off for this file.
   Misses: a token whose value is var(), color-mix() or a named colour (printed as not measured, never a pass), tokens declared in `@theme`, colours a page paints without a token, pairings outside PAIRS; a build with no dark rule gets no dark verdict. A role reads the first theming-system or shadcn name present (ROLE_ALIASES).
# TWIN: plugins/craft-layer/template/craft-gates/contrast.mjs is an identical copy save this line. craft-layer owns the original; ui-ux ships this copy because craft-layer NEEDS ui-ux and not the reverse, so a ui-ux install without craft-layer would reach no contrast checker at all. Invoke it here as ${CLAUDE_PLUGIN_ROOT}/scripts/contrast.mjs.
   Why, limits, history: rationale/derivations/plugin-craft-layer.md § plugins/craft-layer/template/craft-gates/contrast.mjs */
import { readFileSync, existsSync } from 'node:fs'
import { resolve } from 'node:path'

const TOKEN_CANDIDATES = [
  process.env.CRAFT_TOKEN_SOURCE,
  'src/index.css',
  'src/app.css',
  'app/globals.css',
  'src/app/globals.css',
  'styles/globals.css',
  'src/styles/globals.css',
  'resources/css/app.css',
  'assets/css/main.css',
].filter(Boolean)

// The token source resolves from process.cwd(), never import.meta.url (that read the plugin's own CSS).
const cssPath = TOKEN_CANDIDATES.map((c) => resolve(process.cwd(), c)).find((p) => existsSync(p))
if (!cssPath) {
  console.error(`not measured: no token source found under ${process.cwd()}`)
  console.error(`(tried ${TOKEN_CANDIDATES.join(', ')}) — set CRAFT_TOKEN_SOURCE to the CSS holding the tokens.`)
  console.error('NOT MEASURED IS A FAILURE HERE: a gate that cannot see the build cannot clear it.')
  process.exit(2)
}
console.log(`token source:       ${cssPath}`)
const css = readFileSync(cssPath, 'utf8').replace(/\/\*[\s\S]*?\*\//g, '')

/* Every rule with its selector and the at-rules around it: a bare text search for `.dark` lands on `@custom-variant dark (&:is(.dark *))`, which stock shadcn puts above the theme. */
function ruleBlocks() {
  const out = [], stack = []
  let start = 0
  for (let j = 0; j < css.length; j++) {
    const ch = css[j]
    if (ch === ';') start = j + 1
    else if (ch === '{') { stack.push({ prelude: css.slice(start, j).trim(), parents: stack.map((b) => b.prelude), open: j }); start = j + 1 }
    else if (ch === '}') { const b = stack.pop(); if (b) { b.body = css.slice(b.open + 1, j); out.push(b) } start = j + 1 }
  }
  return out.sort((a, b) => a.open - b.open)
}
const selectors = (b) => b.prelude.split(',').map((x) => x.trim())
const underDarkMedia = (b) => b.parents.some((p) => /prefers-color-scheme\s*:\s*dark/i.test(p))
const isRoot = (b) => selectors(b).some((x) => x === ':root' || x === 'html')
const DARK_SELECTOR = /^(:root|html)?(\.dark|\[data-(theme|mode)=["']?dark["']?\])$/
const isLight = (b) => isRoot(b) && !underDarkMedia(b)
const isDark = (b) => selectors(b).some((x) => DARK_SELECTOR.test(x)) || (isRoot(b) && underDarkMedia(b))

const f = (x) => (x <= 0.0031308 ? 12.92 * x : 1.055 * Math.pow(x, 1 / 2.4) - 0.055)
const clamp01 = (x) => Math.min(1, Math.max(0, x))

function oklchToLinearRGB([L, C, H]) {
  const h = (H * Math.PI) / 180
  const a = C * Math.cos(h), b = C * Math.sin(h)
  const l_ = L + 0.3963377774 * a + 0.2158037573 * b
  const m_ = L - 0.1055613458 * a - 0.0638541728 * b
  const s_ = L - 0.0894841775 * a - 1.291485548 * b
  const l = l_ ** 3, m = m_ ** 3, s = s_ ** 3
  return [
    clamp01(+4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
    clamp01(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
    clamp01(-0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s),
  ]
}

function hslToRGB(h, s, l) {
  const k = (n) => (n + h / 30) % 12
  const a = s * Math.min(l, 1 - l)
  const ch = (n) => l - a * Math.max(-1, Math.min(k(n) - 3, 9 - k(n), 1))
  return [ch(0), ch(8), ch(4)]
}

const num = (x, full = 1) => (x === 'none' ? 0 : x.endsWith('%') ? (parseFloat(x) / 100) * full : parseFloat(x))
const hue = (x) => (x === 'none' ? 0
  : x.endsWith('turn') ? parseFloat(x) * 360
  : x.endsWith('grad') ? parseFloat(x) * 0.9
  : x.endsWith('rad') ? (parseFloat(x) * 180) / Math.PI
  : parseFloat(x))

/* A token value as gamma sRGB 0..1 plus alpha, or null when it is not a colour this file reads. */
function parseColor(raw) {
  const v = raw.trim().toLowerCase().replace(/\s*!important$/, '')
  let rgb, a = 1
  const hex = v.match(/^#([0-9a-f]{3,4}|[0-9a-f]{6}|[0-9a-f]{8})$/)
  const fn = v.match(/^(oklch|hsla?|rgba?)\(([^()]*)\)$/)
  const triplet = v.match(/^[\d.]+(deg)?\s+[\d.]+%\s+[\d.]+%(\s*\/\s*[\d.]+%?)?$/)
  if (hex) {
    const h = hex[1].length <= 4 ? [...hex[1]].map((c) => c + c).join('') : hex[1]
    rgb = [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16) / 255)
    if (h.length === 8) a = parseInt(h.slice(6, 8), 16) / 255
  } else if (fn || triplet) {
    const kind = fn ? fn[1].replace(/a$/, '') : 'hsl'
    const [main, alpha] = (fn ? fn[2] : v).split('/').map((x) => x.trim())
    const p = main.split(/[\s,]+/).filter(Boolean)
    if (p.length < 3) return null
    a = alpha ? num(alpha) : p[3] ? num(p[3]) : 1
    if (kind === 'oklch') rgb = oklchToLinearRGB([num(p[0]), num(p[1], 0.4), hue(p[2])]).map(f)
    else if (kind === 'hsl') rgb = hslToRGB(((hue(p[0]) % 360) + 360) % 360, num(p[1]), num(p[2]))
    else rgb = p.slice(0, 3).map((x) => (x.endsWith('%') ? num(x) : parseFloat(x) / 255))
  } else return null
  return [...rgb, a].every(Number.isFinite) ? { rgb: rgb.map(clamp01), a: clamp01(a) } : null
}

/* Later rules win, as in the cascade; a value this file cannot read is kept as null so its role reports "not measured". */
function tokens(match) {
  const out = {}
  let found = false
  for (const b of ruleBlocks()) {
    if (!match(b)) continue
    found = true
    for (const m of b.body.matchAll(/(--[\w-]+)\s*:\s*([^;{}]+)/g)) out[m[1]] = parseColor(m[2])
  }
  return found ? out : null
}

const over = (top, under) => ({ rgb: top.rgb.map((c, i) => c * top.a + under.rgb[i] * (1 - top.a)), a: 1 })
// Round to 8-bit sRGB so the number matches what a browser paints.
const lum = ({ rgb }) => {
  const lin = (c) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4)
  const [r, g, b] = rgb.map((v) => lin(Math.round(v * 255) / 255))
  return 0.2126 * r + 0.7152 * g + 0.0722 * b
}
const ratio = (a, b) => {
  const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p)
  return (x + 0.05) / (y + 0.05)
}

const PAIRS = [
  ['body text',            '--ink-1',           '--surface-base',    4.5],
  ['secondary text',       '--ink-2',           '--surface-base',    4.5],
  ['tertiary text',        '--ink-3',           '--surface-base',    4.5],
  ['body on raised',       '--ink-1',           '--surface-raised',  4.5],
  ['tertiary on raised',   '--ink-3',           '--surface-raised',  4.5],
  ['accent text',          '--accent-text',     '--surface-base',    4.5],
  ['accent text/raised',   '--accent-text',     '--surface-raised',  4.5],
  ['accent text/sunken',   '--accent-text',     '--surface-sunken',  4.5],
  ['button label',         '--accent-on',       '--accent-fill',     4.5],
  ['status good',          '--status-good',     '--surface-raised',  4.5],
  ['status warn',          '--status-warn',     '--surface-raised',  4.5],
  ['status serious',       '--status-serious',  '--surface-raised',  4.5],
  ['status critical',      '--status-critical', '--surface-raised',  4.5],
  ['display accent MARK',  '--accent-display',  '--surface-base',    3.0],
  ['focus ring',           '--focus-ring',      '--surface-base',    3.0],
  ['control border',       '--control-border',  '--surface-base',    3.0],
  ['control border/raised','--control-border',  '--surface-raised',  3.0],
  ['chart 1',              '--chart-1',         '--surface-raised',  3.0],
  ['chart 2',              '--chart-2',         '--surface-raised',  3.0],
  ['chart 3',              '--chart-3',         '--surface-raised',  3.0],
  ['chart 4',              '--chart-4',         '--surface-raised',  3.0],
  ['chart 5',              '--chart-5',         '--surface-raised',  3.0],
]

let failures = 0
/* Each role resolves to the first name present, so one table grades the theming-system and shadcn vocabularies; an unresolved role is not measured, never a pass. */
const ROLE_ALIASES = {
  '--ink-1':           ['--ink-1', '--ink-primary', '--foreground', '--card-foreground'],
  '--ink-2':           ['--ink-2', '--ink-secondary', '--muted-foreground', '--foreground'],
  '--ink-3':           ['--ink-3', '--ink-tertiary', '--muted-foreground'],
  '--surface-base':    ['--surface-base', '--background'],
  '--surface-raised':  ['--surface-raised', '--card', '--popover', '--background'],
  '--surface-sunken':  ['--surface-sunken', '--muted', '--secondary', '--background'],
  '--accent-fill':     ['--accent-fill', '--primary'],
  '--accent-on':       ['--accent-on', '--primary-foreground'],
  '--accent-text':     ['--accent-text', '--primary'],
  '--accent-display':  ['--accent-display', '--primary'],
  '--focus-ring':      ['--focus-ring', '--ring'],
  '--control-border':  ['--control-border', '--input', '--border'],
  '--status-critical': ['--status-critical', '--destructive'],
}
const pick = (t, role) => {
  for (const k of (ROLE_ALIASES[role] ?? [role])) if (k in t) return [t[k], k]
  return [undefined, null]
}

let measured = 0, modes = 0
const light = tokens(isLight)
const dark = tokens(isDark)
for (const [mode, t] of [['light', light], ['dark', dark && { ...light, ...dark }]]) {
  console.log(`\n${mode.toUpperCase()}`)
  if (!t) {
    console.log(mode === 'dark'
      ? '  ?  not measured: no .dark, [data-theme=dark], [data-mode=dark] or prefers-color-scheme: dark rule in the token source'
      : '  ?  not measured: no :root or html rule in the token source')
    continue
  }
  modes++
  for (const [name, fgRole, bgRole, min] of PAIRS) {
    let [fg, fgName] = pick(t, fgRole)
    let [bg, bgName] = pick(t, bgRole)
    const skip = (why) => console.log(`  ?  ${name.padEnd(20)} not measured (${why})`)
    if (fg === undefined || bg === undefined) { skip(`no token for ${fg === undefined ? fgRole : bgRole}`); continue }
    if (!fg || !bg) { skip(`${!fg ? fgName : bgName} is not a colour value this gate reads`); continue }
    if (bg.a < 1) {
      const [base, baseName] = pick(t, '--surface-base')
      if (!base || base.a < 1 || baseName === bgName) { skip(`${bgName} is translucent and nothing opaque sits under it`); continue }
      bg = over(bg, base)
    }
    if (fg.a < 1) fg = over(fg, bg)
    measured++
    const r = ratio(fg, bg)
    const ok = r >= min
    if (!ok) failures++
    const via = (fgName !== fgRole || bgName !== bgRole) ? `  [${fgName} on ${bgName}]` : ''
    console.log(`  ${ok ? 'PASS' : 'FAIL'} ${name.padEnd(20)} ${r.toFixed(2)}:1  (needs ${min}:1)${via}`)
  }
}

console.log(`\ncoverage: ${measured}/${PAIRS.length * 2} pairing(s) measured across ${modes} of 2 theme(s)`)
/* Zero measured is not a pass: gates.spec.ts turns axe's color-contrast off because this file is the gate of record. */
if (measured === 0) {
  console.error('\nnot measured: no pairing resolved a token in this build.')
  console.error(`(looked for ${Object.keys(ROLE_ALIASES).length} roles under both the theming-system and shadcn vocabularies)`)
  console.error('NOT MEASURED IS A FAILURE HERE: gates.spec.ts disables axe\'s color-contrast rule')
  console.error('because this file is the gate of record. If neither runs, nothing checks contrast.')
  process.exit(2)
}
console.log(failures === 0
  ? `OK: all ${measured} measured pairing(s) clear their WCAG 2 threshold.`
  : `${failures} pairing(s) FAIL.`)
process.exit(failures === 0 ? 0 : 1)
