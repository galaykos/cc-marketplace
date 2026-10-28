/* contrast.mjs — craft-layer's contrast gate: WCAG 2 ratios (the conformance gate; APCA is not normative) for the ink, accent, status, focus, border and chart pairings of the oklch() tokens under :root and .dark in the project's token CSS. Run from the project root: `node ${CLAUDE_PLUGIN_ROOT}/template/craft-gates/contrast.mjs`; CRAFT_TOKEN_SOURCE names the file. Exit 1 a pairing fails, 2 not measured — a failure: gates.spec.ts turns axe's color-contrast off for this file.
   Misses: hex, hsl and HSL-triplet tokens (only oklch() is parsed), any :root or .dark block after the first, pairings outside PAIRS. A role reads the first theming-system or shadcn name present (ROLE_ALIASES).
   Why, limits, history: rationale/derivations/plugin-craft-layer.md § plugins/craft-layer/template/craft-gates/contrast.mjs */
import { readFileSync, existsSync } from 'node:fs'
import { resolve } from 'node:path'

const TOKEN_CANDIDATES = [
  process.env.CRAFT_TOKEN_SOURCE,
  'src/index.css',
  'src/app.css',
  'app/globals.css',
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
const css = readFileSync(cssPath, 'utf8')

function parseBlock(selector) {
  const i = css.indexOf(selector)
  const open = css.indexOf('{', i)
  let depth = 0, end = open
  for (let j = open; j < css.length; j++) {
    if (css[j] === '{') depth++
    else if (css[j] === '}') { depth--; if (!depth) { end = j; break } }
  }
  const body = css.slice(open, end)
  const out = {}
  for (const m of body.matchAll(/(--[\w-]+):\s*oklch\(([^)]+)\)/g)) {
    const [L, C, H] = m[2].trim().split(/\s+/).map(Number)
    out[m[1]] = [L, C, H]
  }
  return out
}

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

// Round-trip through 8-bit sRGB so the number matches what a browser paints.
const lum = (oklch) => {
  const [r, g, b] = oklchToLinearRGB(oklch).map((v) => Math.round(f(v) * 255) / 255)
  const lin = (c) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4)
  return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
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
  '--control-border':  ['--control-border', '--border', '--input'],
  '--status-critical': ['--status-critical', '--destructive'],
}
const pick = (t, role) => {
  for (const k of (ROLE_ALIASES[role] ?? [role])) if (t[k]) return [t[k], k]
  return [null, null]
}

let measured = 0
for (const [mode, sel] of [['light', ':root'], ['dark', '.dark']]) {
  const t = parseBlock(sel)
  console.log(`\n${mode.toUpperCase()}`)
  for (const [name, fgRole, bgRole, min] of PAIRS) {
    const [fg, fgName] = pick(t, fgRole)
    const [bg, bgName] = pick(t, bgRole)
    if (!fg || !bg) {
      console.log(`  ?  ${name.padEnd(20)} not measured (no token for ${!fg ? fgRole : bgRole})`)
      continue
    }
    measured++
    const r = ratio(fg, bg)
    const ok = r >= min
    if (!ok) failures++
    const via = (fgName !== fgRole || bgName !== bgRole) ? `  [${fgName} on ${bgName}]` : ''
    console.log(`  ${ok ? 'PASS' : 'FAIL'} ${name.padEnd(20)} ${r.toFixed(2)}:1  (needs ${min}:1)${via}`)
  }
}

console.log(`\ncoverage: ${measured}/${PAIRS.length * 2} pairing(s) measured`)
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
