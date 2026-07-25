/* Craft audit — accent/ink-on-surface contrast gate.
   Parses the oklch() token values out of src/index.css, converts to sRGB, and
   computes WCAG 2 relative-luminance ratios for every pairing that matters.

   WCAG 2 is the conformance gate (per craft-layer theming-system/accent-system):
   APCA is not normative and WCAG 3 has not settled a contrast algorithm.

   Run: node scripts/contrast.mjs
*/
import { readFileSync } from 'node:fs'

const css = readFileSync(new URL('../src/index.css', import.meta.url), 'utf8')

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
for (const [mode, sel] of [['light', ':root'], ['dark', '.dark']]) {
  const t = parseBlock(sel)
  console.log(`\n${mode.toUpperCase()}`)
  for (const [name, fg, bg, min] of PAIRS) {
    if (!t[fg] || !t[bg]) { console.log(`  ?  ${name.padEnd(20)} not measured (token missing)`); continue }
    const r = ratio(t[fg], t[bg])
    const ok = r >= min
    if (!ok) failures++
    console.log(`  ${ok ? 'PASS' : 'FAIL'} ${name.padEnd(20)} ${r.toFixed(2)}:1  (needs ${min}:1)`)
  }
}
console.log(`\n${failures === 0 ? 'OK: every pairing clears its WCAG 2 threshold.' : `${failures} pairing(s) FAIL.`}`)
process.exit(failures === 0 ? 0 : 1)
