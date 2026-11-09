#!/usr/bin/env node
// system-render.mjs — tokens from a page AFTER its JavaScript ran: loads a URL or HTML file in the project's Playwright Chromium, reads the computed colours, font families and sizes, spacing and radii of every visible element, clusters them and writes DTCG JSON in tokens.json's shape. --samples re-clusters a saved --dump-samples file with no browser.
// Misses: names are the values (color.1f2937), never roles; one viewport, the light scheme and the first screen's DOM (no hover, focus, dark mode or other route); gradients, shadows, images and canvas; a colour outside rgb()/oklch()/color(srgb) is kept as written, unclustered.
// Why, limits, history: rationale/derivations/plugin-design-kit.md § plugins/design-kit/scripts/system-render.mjs
import { readFileSync, writeFileSync } from 'node:fs'
import { launchChromium, targetUrl, Missing } from './chromium.mjs'

const USAGE = `usage: system-render.mjs <url|file.html> [--out FILE|-] [--dump-samples FILE] [--viewport 1440x900]
                         [--settle 500] [--max-elements 4000] [--project DIR] [--browser PATH]
       system-render.mjs --samples FILE [--out FILE|-]
  clustering: --near 8 (RGB distance merged into one colour) --min-uses 2 (rarer values are dropped)
  exit: 0 tokens written · 1 no value survived (nothing visible, or all under --min-uses) · 2 usage or unreadable input
        3 NOT MEASURED: Playwright, or a Chromium it can launch, is missing (nothing is installed)
        4 NOT MEASURED: the page did not load`

const GENERIC = new Set(['serif', 'sans-serif', 'monospace', 'cursive', 'fantasy', 'system-ui', 'ui-sans-serif', 'ui-serif',
  'ui-monospace', 'ui-rounded', 'emoji', 'math', 'fangsong', '-apple-system', 'blinkmacsystemfont', 'inherit', 'initial'])

function fail(code, msg) {
  console.error(`system-render: ${msg}`)
  process.exit(code)
}

function parseArgs(argv) {
  const o = { out: '-', viewport: [1440, 900], settle: 500, maxElements: 4000, near: 8, minUses: 2, project: process.cwd() }
  const need = (flag, v) => { if (v === undefined || (v.startsWith('--') && v !== '-')) fail(2, `${flag} needs a value\n${USAGE}`); return v }
  const num = (flag, v, min) => {
    const n = Number(need(flag, v))
    if (!Number.isFinite(n) || n < min) fail(2, `${flag} needs a number >= ${min}, got ${v}\n${USAGE}`)
    return n
  }
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]
    if (a === '-h' || a === '--help') { console.log(USAGE); process.exit(0) }
    else if (a === '--out') o.out = need(a, argv[++i])
    else if (a === '--samples') o.samples = need(a, argv[++i])
    else if (a === '--dump-samples') o.dump = need(a, argv[++i])
    else if (a === '--project') o.project = need(a, argv[++i])
    else if (a === '--browser') o.browser = need(a, argv[++i])
    else if (a === '--settle') o.settle = num(a, argv[++i], 0)
    else if (a === '--max-elements') o.maxElements = num(a, argv[++i], 1)
    else if (a === '--near') o.near = num(a, argv[++i], 0)
    else if (a === '--min-uses') o.minUses = num(a, argv[++i], 1)
    else if (a === '--viewport') {
      const m = /^(\d+)x(\d+)$/.exec(need(a, argv[++i]))
      if (!m) fail(2, `--viewport needs WxH, got ${argv[i]}\n${USAGE}`)
      o.viewport = [Number(m[1]), Number(m[2])]
    } else if (a.startsWith('-') && a !== '-') fail(2, `unknown flag ${a}\n${USAGE}`)
    else if (o.target) fail(2, `one target only (got ${o.target} and ${a})\n${USAGE}`)
    else o.target = a
  }
  if (!o.target && !o.samples) fail(2, `needs a URL, an HTML file or --samples FILE\n${USAGE}`)
  if (o.target && o.samples) fail(2, '--samples replaces the page: pass one or the other')
  return o
}

function collect(max) {
  const out = { elements: 0, samples: [] }
  const desc = (el) => {
    const cls = typeof el.className === 'string' ? el.className.trim().split(/\s+/).filter(Boolean).slice(0, 2) : []
    return (el.tagName.toLowerCase() + (el.id ? '#' + el.id : '') + cls.map((c) => '.' + c).join('')).replace(/[^\w#.-]/g, '').slice(0, 60)
  }
  const skip = new Set(['SCRIPT', 'STYLE', 'NOSCRIPT', 'TEMPLATE', 'HEAD', 'META', 'LINK', 'BR', 'TITLE'])
  const els = document.body ? [document.body, ...document.body.querySelectorAll('*')] : []
  for (const el of els) {
    if (out.elements >= max) break
    if (skip.has(el.tagName)) continue
    const cs = getComputedStyle(el)
    if (cs.display === 'none' || cs.visibility !== 'visible' || Number(cs.opacity) === 0) continue
    const r = el.getBoundingClientRect()
    if (r.width <= 0 || r.height <= 0) continue
    out.elements++
    const d = desc(el)
    const push = (kind, value) => out.samples.push([kind, value, d])
    if ([...el.childNodes].some((n) => n.nodeType === 3 && n.textContent.trim())) {
      push('text', cs.color); push('family', cs.fontFamily); push('size', cs.fontSize)
    }
    push('background', cs.backgroundColor)
    for (const s of ['Top', 'Right', 'Bottom', 'Left']) {
      if (cs[`border${s}Style`] !== 'none' && parseFloat(cs[`border${s}Width`]) > 0) push('border', cs[`border${s}Color`])
    }
    for (const p of ['marginTop', 'marginRight', 'marginBottom', 'marginLeft', 'paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft']) push('spacing', cs[p])
    if (/flex|grid/.test(cs.display)) { push('spacing', cs.rowGap); push('spacing', cs.columnGap) }
    for (const c of ['TopLeft', 'TopRight', 'BottomRight', 'BottomLeft']) push('radius', cs[`border${c}Radius`])
  }
  return out
}

function oklchToRgb(L, C, H) {
  const a = C * Math.cos((H * Math.PI) / 180); const b = C * Math.sin((H * Math.PI) / 180)
  const l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
  const m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
  const s = (L - 0.0894841775 * a - 1.291485548 * b) ** 3
  const lin = [4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s, -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s]
  return lin.map((c) => { c = Math.min(1, Math.max(0, c)); return Math.round(255 * (c > 0.0031308 ? 1.055 * c ** (1 / 2.4) - 0.055 : 12.92 * c)) })
}

const num = (s) => (s.endsWith('%') ? parseFloat(s) / 100 : parseFloat(s))

function parseColor(raw) {
  const v = String(raw || '').trim().toLowerCase()
  if (!v || v === 'transparent') return null
  let rgb = null; let alpha = 1
  let m = /^rgba?\(\s*([\d.]+)[\s,]+([\d.]+)[\s,]+([\d.]+)(?:\s*[,/]\s*([\d.]+%?))?\s*\)$/.exec(v)
  if (m) { rgb = [m[1], m[2], m[3]].map((x) => Math.round(Math.min(255, Number(x)))); if (m[4]) alpha = num(m[4]) }
  if (!rgb && (m = /^oklch\(\s*([\d.]+%?)\s+([\d.]+)\s+([\d.]+)(?:deg)?(?:\s*\/\s*([\d.]+%?))?\s*\)$/.exec(v))) {
    rgb = oklchToRgb(num(m[1]) > 1 ? num(m[1]) / 100 : num(m[1]), Number(m[2]), Number(m[3])); if (m[4]) alpha = num(m[4])
  }
  if (!rgb && (m = /^color\(srgb\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)(?:\s*\/\s*([\d.]+%?))?\s*\)$/.exec(v))) {
    rgb = [m[1], m[2], m[3]].map((x) => Math.round(Math.min(1, Number(x)) * 255)); if (m[4]) alpha = num(m[4])
  }
  if (alpha === 0) return null
  if (!rgb) return { raw: v, key: v.replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') }
  const a = Math.round(alpha * 100) / 100
  const hex = rgb.map((c) => c.toString(16).padStart(2, '0')).join('')
  return a >= 1 ? { rgb, a: 1, key: hex, value: '#' + hex } : { rgb, a, key: `${hex}-a${Math.round(a * 100)}`, value: `rgba(${rgb.join(', ')}, ${a})` }
}

function dim(raw) {
  const v = String(raw || '').trim().split(/\s+/)[0]
  let m = /^(-?[\d.]+)px$/.exec(v)
  if (m) {
    const n = Math.round(Number(m[1]) * 2) / 2
    return n > 0 ? { key: `${String(n).replace('.', '_')}px`, value: `${n}px` } : null
  }
  if ((m = /^([\d.]+)%$/.exec(v)) && Number(m[1]) > 0) return { key: `${m[1].replace('.', '_')}pct`, value: `${m[1]}%` }
  return null
}

function firstFamily(raw) {
  const f = String(raw || '').split(',')[0].trim().replace(/^["']|["']$/g, '').trim()
  return f && !GENERIC.has(f.toLowerCase()) ? f : null
}

function cluster(dump, o, label) {
  const groups = { color: new Map(), family: new Map(), size: new Map(), spacing: new Map(), radius: new Map() }
  const add = (map, key, value, role, el, extra) => {
    const e = map.get(key) || { key, value, uses: 0, roles: new Set(), els: [], ...extra }
    e.uses++
    if (role) e.roles.add(role)
    if (e.els.length < 3 && !e.els.includes(el)) e.els.push(el)
    map.set(key, e)
  }
  for (const [kind, raw, el] of dump.samples || []) {
    if (kind === 'text' || kind === 'background' || kind === 'border') {
      const c = parseColor(raw)
      if (c) add(groups.color, c.key, c.value || c.raw, kind, el, { rgb: c.rgb, a: c.a })
    } else if (kind === 'family') {
      const f = firstFamily(raw)
      if (f) add(groups.family, f.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, ''), f, null, el)
    } else if (groups[kind]) {
      const d = dim(raw)
      if (d) add(groups[kind], d.key, d.value, null, el)
    }
  }
  const byUse = (a, b) => b.uses - a.uses || (a.key < b.key ? -1 : a.key > b.key ? 1 : 0)
  const merged = []
  for (const c of [...groups.color.values()].sort(byUse)) {
    const near = c.rgb && merged.find((m) => m.rgb && m.a === c.a && Math.hypot(...m.rgb.map((x, i) => x - c.rgb[i])) <= o.near)
    if (!near) { merged.push({ ...c, roles: new Set(c.roles), els: [...c.els], members: 1 }); continue }
    near.uses += c.uses; near.members++
    for (const r of c.roles) near.roles.add(r)
    for (const e of c.els) if (near.els.length < 3 && !near.els.includes(e)) near.els.push(e)
  }
  const out = {}
  let count = 0
  const put = (path, name, type, e, more) => {
    let cur = out
    for (const g of path) cur = cur[g] ??= {}
    cur[name] = { $type: type, $value: e.value, $extensions: { 'design-kit': { uses: e.uses, ...more, sources: e.els.map((x) => `rendered ${label} ${x}`) } } }
    count++
  }
  const keep = (list) => list.filter((e) => e.uses >= o.minUses).sort(byUse)
  for (const e of keep(merged)) put(['color'], e.key, 'color', e, { roles: [...e.roles].sort(), ...(e.members > 1 ? { merged: e.members } : {}) })
  for (const e of keep([...groups.family.values()])) put(['typography', 'family'], e.key, 'fontFamily', e)
  for (const e of keep([...groups.size.values()])) put(['typography', 'size'], e.key, 'dimension', e)
  for (const e of keep([...groups.spacing.values()])) put(['spacing'], e.key, 'dimension', e)
  for (const e of keep([...groups.radius.values()])) put(['radius'], e.key, 'dimension', e)
  out.$extensions = { 'design-kit': { rendered: { source: label, elements: dump.elements ?? null, viewport: dump.viewport ?? null } } }
  return { tokens: out, count }
}

async function render(o) {
  let url
  try { url = targetUrl(o.target) } catch (e) { fail(2, e.message) }
  let launched
  try { launched = await launchChromium({ project: o.project, browser: o.browser }) } catch (e) {
    if (e instanceof Missing) fail(3, `NOT MEASURED — ${e.message}`)
    throw e
  }
  const { browser } = launched
  try {
    const ctx = await browser.newContext({ viewport: { width: o.viewport[0], height: o.viewport[1] }, colorScheme: 'light' })
    const page = await ctx.newPage()
    try {
      await page.goto(url, { waitUntil: 'load', timeout: 30000 })
    } catch (e) {
      fail(4, `NOT MEASURED — the page did not load: ${String(e.message).split('\n')[0]}`)
    }
    await page.evaluate(() => document.fonts && document.fonts.ready)
    if (o.settle) await page.waitForTimeout(o.settle)
    const dump = await page.evaluate(collect, o.maxElements)
    return { ...dump, viewport: `${o.viewport[0]}x${o.viewport[1]}`, label: o.target }
  } finally {
    await browser.close().catch(() => {})
  }
}

const o = parseArgs(process.argv.slice(2))
let dump
if (o.samples) {
  try { dump = JSON.parse(readFileSync(o.samples, 'utf8')) } catch (e) { fail(2, `${o.samples}: ${e.message}`) }
  if (!dump || !Array.isArray(dump.samples)) fail(2, `${o.samples}: not a --dump-samples file (no "samples" array)`)
} else {
  dump = await render(o).catch((e) => fail(4, `NOT MEASURED — ${String(e && e.message).split('\n')[0]}`))
  if (o.dump) writeFileSync(o.dump, JSON.stringify(dump) + '\n')
}
const { tokens, count } = cluster(dump, o, dump.label || o.samples)
if (!count) fail(1, `no value survived from ${dump.elements ?? 0} visible element(s) at --min-uses ${o.minUses} — nothing written`)
const text = JSON.stringify(tokens, null, 2) + '\n'
if (o.out === '-') process.stdout.write(text)
else { writeFileSync(o.out, text); console.error(`system-render: ${count} tokens from ${dump.elements ?? '?'} visible element(s) → ${o.out}`) }
