#!/usr/bin/env node
// motion-check.mjs — records a page or element animation through the project's Playwright Chromium on a stepped fake clock (PNG frames with --frames) and checks it against the motion skill: animated layout properties, CSS durations outside --min-ms..--max-ms, blur above --max-blur, motion left under prefers-reduced-motion: reduce. --static reads the HTML and its local CSS and scripts with no browser.
// Misses: JS-driven motion gets only the layout and reduced-motion rules (an inline style counts after 3 changes); a custom property feeding a transform; motion started by hover, click or a scroll beyond --selector's; seam, overflow, empty-beat and rest stay the model's (capture-export.md). --static: no cascade, no remote CSS, a transitioned blur unread.
// Why, limits, history: rationale/derivations/plugin-design-kit.md § plugins/design-kit/scripts/motion-check.mjs
import { readFileSync, existsSync, mkdirSync, writeFileSync } from 'node:fs'
import { dirname, resolve, join } from 'node:path'
import { launchChromium, targetUrl, Missing, Usage } from './chromium.mjs'

const USAGE = `usage: motion-check.mjs <url|file.html> [--selector CSS] [--ms 3000] [--fps 60] [--pre 15] [--frames DIR]
                        [--viewport 1440x900] [--scale 1] [--project DIR] [--browser PATH] [--json]
       motion-check.mjs --static <file.html> [--json]
  rules, both modes: --min-ms 500 --max-ms 1100 (each CSS animation or transition; <= 16 ms is instant and exempt)
                     --max-blur 14 (px)  · no layout property animated · a prefers-reduced-motion path
  exit: 0 every rule held · 1 a rule broke · 2 usage or unreadable input
        3 NOT MEASURED: Playwright, or a Chromium it can launch, is missing (nothing is installed)
        4 NOT MEASURED: the page did not load, the recording failed, or nothing animated`

const LAYOUT = new Set(['width', 'height', 'min-width', 'min-height', 'max-width', 'max-height', 'top', 'right', 'bottom',
  'left', 'font-size', 'line-height', 'letter-spacing', 'word-spacing', 'gap', 'row-gap', 'column-gap', 'flex', 'flex-basis',
  'flex-grow', 'flex-shrink', 'border', 'border-width', 'outline-width', 'block-size', 'inline-size'])
const LAYOUT_RE = /^(margin|padding|inset|grid-template|border(-(top|right|bottom|left|block|inline)(-(start|end))?)?-width)/
const CHEAP = new Set(['transform', 'translate', 'rotate', 'scale', 'opacity', 'filter', 'clip-path', '-webkit-clip-path'])
const isLayout = (p) => LAYOUT.has(p) || LAYOUT_RE.test(p)
const INSTANT = 16 // ms: under one 60 fps frame nothing visibly moves, so a 0.01ms reduced-motion override is a still frame
const TIME_RE = /^(-?[\d.]+)(ms|s)$/i
const ms = (t) => { const m = TIME_RE.exec(t); return m ? Number(m[1]) * (m[2].toLowerCase() === 's' ? 1000 : 1) : null }

function fail(code, msg) {
  console.error(`motion-check: ${msg}`)
  process.exit(code)
}

function parseArgs(argv) {
  const o = { ms: 3000, fps: 60, pre: 15, minMs: 500, maxMs: 1100, maxBlur: 14, viewport: [1440, 900], scale: 1,
    project: process.cwd(), json: false, static: false }
  const need = (flag, v) => { if (v === undefined || v.startsWith('--')) fail(2, `${flag} needs a value\n${USAGE}`); return v }
  const num = (flag, v, min) => {
    const n = Number(need(flag, v))
    if (!Number.isFinite(n) || n < min) fail(2, `${flag} needs a number >= ${min}, got ${v}\n${USAGE}`)
    return n
  }
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]
    if (a === '-h' || a === '--help') { console.log(USAGE); process.exit(0) }
    else if (a === '--static') o.static = true
    else if (a === '--json') o.json = true
    else if (a === '--selector') o.selector = need(a, argv[++i])
    else if (a === '--frames') o.frames = need(a, argv[++i])
    else if (a === '--project') o.project = need(a, argv[++i])
    else if (a === '--browser') o.browser = need(a, argv[++i])
    else if (a === '--ms') o.ms = num(a, argv[++i], 1)
    else if (a === '--fps') o.fps = num(a, argv[++i], 1)
    else if (a === '--pre') o.pre = num(a, argv[++i], 0)
    else if (a === '--scale') o.scale = num(a, argv[++i], 0.1)
    else if (a === '--min-ms') o.minMs = num(a, argv[++i], 0)
    else if (a === '--max-ms') o.maxMs = num(a, argv[++i], 0)
    else if (a === '--max-blur') o.maxBlur = num(a, argv[++i], 0)
    else if (a === '--viewport') {
      const m = /^(\d+)x(\d+)$/.exec(need(a, argv[++i]))
      if (!m) fail(2, `--viewport needs WxH, got ${argv[i]}\n${USAGE}`)
      o.viewport = [Number(m[1]), Number(m[2])]
    } else if (a.startsWith('-')) fail(2, `unknown flag ${a}\n${USAGE}`)
    else if (o.target) fail(2, `one target only (got ${o.target} and ${a})\n${USAGE}`)
    else o.target = a
  }
  if (!o.target) fail(2, `needs a URL or an HTML file\n${USAGE}`)
  if (o.minMs > o.maxMs) fail(2, `--min-ms ${o.minMs} is above --max-ms ${o.maxMs}`)
  return o
}

// One verdict per motion item, shared by both modes: {where, props, duration, infinite, blur, reduce}.
function judge(items, o) {
  const out = []
  for (const it of items) {
    if (it.reduce) continue
    const props = [...new Set(it.props)]
    for (const p of props.filter(isLayout)) {
      out.push({ rule: 'layout-property', level: 'fail', where: it.where, detail: `${p} is a layout property: every frame re-lays out the page — animate transform or clip-path instead` })
    }
    if (props.includes('all')) {
      out.push({ rule: 'transition-all', level: 'warn', where: it.where, detail: 'transition: all animates whatever changes, layout properties included — name the cheap properties' })
    }
    const paint = props.filter((p) => p !== 'all' && !isLayout(p) && !CHEAP.has(p) && !p.startsWith('--'))
    if (paint.length) {
      out.push({ rule: 'paint-property', level: 'warn', where: it.where, detail: `${paint.join(', ')}: not transform, opacity, filter or clip-path (the skill's cheap set)` })
    }
    if (it.duration !== null && it.duration > INSTANT && (it.duration < o.minMs || it.duration > o.maxMs)) {
      out.push({ rule: 'duration', level: 'fail', where: it.where, detail: `${Math.round(it.duration)} ms is outside ${o.minMs}–${o.maxMs} ms (motion-system.md Values)`
        + (it.infinite ? '; an infinite CSS loop restarts under the capture seek — drive it from the JS clock' : '') })
    }
    if (it.blur > o.maxBlur) {
      out.push({ rule: 'blur', level: 'fail', where: it.where, detail: `blur(${it.blur}px) is above ${o.maxBlur} px` })
    }
  }
  return out
}

function lineAt(text, idx) { let n = 1; for (let i = 0; i < idx && i < text.length; i++) if (text[i] === '\n') n++; return n }
const stripComments = (s) => s.replace(/\/\*[\s\S]*?\*\//g, (m) => m.replace(/[^\n]/g, ' '))

function splitTop(s, sep) {
  const out = []; let depth = 0; let cur = ''
  for (const c of s) {
    if (c === '(') depth++
    else if (c === ')') depth = Math.max(0, depth - 1)
    if (c === sep && depth === 0) { out.push(cur); cur = '' } else cur += c
  }
  out.push(cur)
  return out.map((x) => x.trim()).filter(Boolean)
}

// Every brace block with its prelude, its own declarations (children excluded) and its ancestors' preludes.
function walk(css) {
  const out = []; const stack = []; let seg = ''; let segLine = 1; let line = 1
  for (const c of css) {
    if (c === '{') {
      const k = seg.lastIndexOf(';'); const head = seg.slice(0, k + 1); const pre = seg.slice(k + 1)
      if (stack.length) stack[stack.length - 1].own.push([head, segLine])
      const at = segLine + (head.match(/\n/g) || []).length + (pre.match(/^\s*/)[0].match(/\n/g) || []).length
      stack.push({ prelude: pre.trim(), line: at, own: [], ancestors: stack.map((f) => f.prelude) })
      seg = ''; segLine = line
    } else if (c === '}') {
      const f = stack.pop()
      if (f) { f.own.push([seg, segLine]); out.push(f) }
      seg = ''; segLine = line
    } else {
      seg += c
      if (c === '\n') line++
    }
  }
  return out
}

function decls(block) {
  const out = []
  for (const [text, start] of block.own) {
    let off = 0
    for (const d of splitTop(text, ';')) {
      const k = d.indexOf(':')
      if (k < 1) continue
      const at = text.indexOf(d, off); off = at + d.length
      out.push({ prop: d.slice(0, k).trim().toLowerCase(), value: d.slice(k + 1).trim(), line: start + (text.slice(0, Math.max(0, at)).match(/\n/g) || []).length })
    }
  }
  return out
}

const EASE = /^(ease|ease-in|ease-out|ease-in-out|linear|step-start|step-end|allow-discrete|normal|initial|inherit|unset)$/i
const ANIM_KW = /^(ease|ease-in|ease-out|ease-in-out|linear|step-start|step-end|infinite|alternate|alternate-reverse|reverse|normal|forwards|backwards|both|none|running|paused|initial|inherit|unset|\d+(\.\d+)?)$/i

function blursIn(value) { let b = 0; for (const m of value.matchAll(/blur\(\s*([\d.]+)px/gi)) b = Math.max(b, Number(m[1])); return b }

function attr(tag, name) { const m = new RegExp(`\\b${name}\\s*=\\s*("([^"]*)"|'([^']*)'|([^\\s>]+))`, 'i').exec(tag); return m ? (m[2] ?? m[3] ?? m[4]) : null }
const local = (href) => href && !/^(https?:)?\/\//i.test(href) && !/^(data|blob):/i.test(href)

function staticSources(file) {
  let html
  try { html = readFileSync(file, 'utf8') } catch (e) { fail(2, `${file}: ${e.message}`) }
  const base = dirname(resolve(file)); const css = []; const js = []; const notes = []
  for (const m of html.matchAll(/<style\b[^>]*>([\s\S]*?)<\/style>/gi)) css.push({ name: file, text: m[1], line0: lineAt(html, m.index + m[0].indexOf('>') + 1) - 1 })
  for (const m of html.matchAll(/\sstyle\s*=\s*("([^"]*)"|'([^']*)')/gi)) css.push({ name: file, text: `x{${m[2] ?? m[3]}}`, line0: lineAt(html, m.index) - 1 })
  for (const m of html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)) {
    const src = attr(m[1], 'src')
    if (!src) js.push(m[2])
    else if (local(src) && existsSync(join(base, src.split(/[?#]/)[0]))) js.push(readFileSync(join(base, src.split(/[?#]/)[0]), 'utf8'))
    else notes.push(`script not read: ${src}`)
  }
  for (const m of html.matchAll(/<link\b[^>]*>/gi)) {
    if (!/\brel\s*=\s*["']?[^"'>]*stylesheet/i.test(m[0])) continue
    const href = attr(m[0], 'href'); const p = href && join(base, href.split(/[?#]/)[0])
    if (local(href) && existsSync(p)) css.push({ name: p, text: readFileSync(p, 'utf8'), line0: 0 })
    else notes.push(`stylesheet not read: ${href}`)
  }
  return { css, js, notes }
}

function staticItems(file, o) {
  const { css, js, notes } = staticSources(file)
  const parsed = css.map((s) => ({ ...s, blocks: walk(stripComments(s.text)) }))
  const keyframes = new Map()
  let reducePath = js.some((t) => /prefers-reduced-motion/i.test(t))
  for (const s of parsed) {
    if (/prefers-reduced-motion/i.test(s.text)) reducePath = true
    for (const b of s.blocks) {
      const kf = [b.prelude, ...b.ancestors].map((p) => /^@(-webkit-)?keyframes\s+([\w-]+)/i.exec(p)).find(Boolean)
      if (!kf || /^@(-webkit-)?keyframes/i.test(b.prelude)) continue
      const k = keyframes.get(kf[2]) || { props: new Set(), blur: 0 }
      for (const d of decls(b)) { k.props.add(d.prop); if (d.prop.endsWith('filter')) k.blur = Math.max(k.blur, blursIn(d.value)) }
      keyframes.set(kf[2], k)
    }
  }
  const items = []
  for (const s of parsed) {
    for (const b of s.blocks) {
      const ctx = [b.prelude, ...b.ancestors]
      if (ctx.some((p) => /^@(-webkit-)?keyframes/i.test(p))) continue
      const reduce = ctx.some((p) => /prefers-reduced-motion\s*:\s*reduce/i.test(p))
      const where = (line) => `${s.name}:${s.line0 + line} ${b.prelude.replace(/\s+/g, ' ').slice(0, 60)}`
      const ds = decls(b)
      const get = (p) => ds.filter((d) => d.prop === p)
      for (const d of get('transition')) {
        for (const part of splitTop(d.value, ',')) {
          const toks = splitTop(part, ' ')
          const times = toks.map(ms).filter((t) => t !== null)
          const prop = toks.find((t) => ms(t) === null && !EASE.test(t) && !/\(/.test(t)) || 'all'
          if (prop === 'none') continue
          items.push({ where: where(d.line), props: [prop.toLowerCase()], duration: times.length ? times[0] : 0, infinite: false, blur: 0, reduce })
        }
      }
      const tp = get('transition-property').pop()
      if (tp) {
        const durs = (get('transition-duration').pop()?.value || '').split(',').map((t) => ms(t.trim())).filter((t) => t !== null)
        splitTop(tp.value, ',').forEach((p, i) => {
          if (p === 'none') return
          items.push({ where: where(tp.line), props: [p.toLowerCase()], duration: durs.length ? durs[i % durs.length] : null, infinite: false, blur: 0, reduce })
        })
      }
      for (const d of get('animation')) {
        for (const part of splitTop(d.value, ',')) {
          const toks = splitTop(part, ' ')
          const name = toks.find((t) => keyframes.has(t)) || toks.find((t) => ms(t) === null && !ANIM_KW.test(t) && !/\(/.test(t))
          if (!name || name === 'none') continue
          const k = keyframes.get(name) || { props: new Set(), blur: 0 }
          const times = toks.map(ms).filter((t) => t !== null)
          items.push({ where: where(d.line) + ` @keyframes ${name}`, props: [...k.props], duration: times.length ? times[0] : 0, infinite: toks.includes('infinite'), blur: k.blur, reduce })
        }
      }
      const an = get('animation-name').pop()
      if (an) {
        const durs = (get('animation-duration').pop()?.value || '').split(',').map((t) => ms(t.trim())).filter((t) => t !== null)
        const inf = /infinite/i.test(get('animation-iteration-count').pop()?.value || '')
        splitTop(an.value, ',').forEach((name, i) => {
          if (name === 'none') return
          const k = keyframes.get(name) || { props: new Set(), blur: 0 }
          items.push({ where: where(an.line) + ` @keyframes ${name}`, props: [...k.props], duration: durs.length ? durs[i % durs.length] : null, infinite: inf, blur: k.blur, reduce })
        })
      }
    }
  }
  return { items, reducePath, notes }
}

function runStatic(o) {
  const { items, reducePath, notes } = staticItems(o.target, o)
  const moving = items.filter((it) => !it.reduce)
  const findings = judge(items, o)
  if (moving.length && !reducePath) {
    findings.push({ rule: 'reduced-motion', level: 'fail', where: o.target, detail: `${moving.length} animation(s) or transition(s) and no prefers-reduced-motion in its CSS or scripts — the skill renders the still frame under reduce` })
  }
  return report(o, { mode: 'static', items: moving.length, reducePath, notes }, findings, moving.length === 0
    ? 'no CSS animation or transition declared — nothing was checked; JS-driven motion needs the browser run' : null)
}

function observer() {
  const desc = (el, pseudo) => {
    if (!el || !el.tagName) return String(el)
    const cls = typeof el.className === 'string' ? el.className.trim().split(/\s+/).filter(Boolean).slice(0, 2) : []
    return (el.tagName.toLowerCase() + (el.id ? '#' + el.id : '') + cls.map((c) => '.' + c).join('') + (pseudo || '')).slice(0, 80)
  }
  const parse = (s) => {
    const m = new Map()
    for (const d of (s || '').split(';')) { const k = d.indexOf(':'); if (k > 0) m.set(d.slice(0, k).trim().toLowerCase(), d.slice(k + 1).trim()) }
    return m
  }
  const ids = new WeakMap(); let n = 0
  const mc = { seen: new WeakSet(), anims: [], inline: new Map(), desc }
  const take = (list) => {
    for (const r of list) {
      if (r.attributeName !== 'style') continue
      const before = parse(r.oldValue); const after = parse(r.target.getAttribute('style'))
      if (!ids.has(r.target)) ids.set(r.target, ++n)
      for (const k of new Set([...before.keys(), ...after.keys()])) {
        if (before.get(k) === after.get(k)) continue
        const key = ids.get(r.target) + '|' + k
        const e = mc.inline.get(key) || { el: r.target, target: desc(r.target), prop: k, changes: 0, blur: 0 }
        e.changes++
        const v = after.get(k) || ''
        if (k.endsWith('filter')) for (const b of v.matchAll(/blur\(\s*([\d.]+)px/g)) e.blur = Math.max(e.blur, Number(b[1]))
        mc.inline.set(key, e)
      }
    }
  }
  const mo = new MutationObserver(take)
  mo.observe(document, { subtree: true, attributes: true, attributeFilter: ['style'], attributeOldValue: true })
  mc.report = (selector) => {
    take(mo.takeRecords())
    const root = selector ? document.querySelector(selector) : null
    const inside = (el) => !root || root === el || root.contains(el)
    return { anims: mc.anims, inline: [...mc.inline.values()].filter((e) => inside(e.el)).map(({ el, ...r }) => r) }
  }
  window.__motionCheck = mc
}

function sample({ i, pre, dt, selector }) {
  const mc = window.__motionCheck
  const contract = typeof window.__start === 'function' && typeof window.__tick === 'function'
  if (contract) { if (i === pre) window.__start(); if (i >= pre) window.__tick(dt / 1000) }
  const now = performance.now()
  const root = selector ? document.querySelector(selector) : null
  for (const a of document.getAnimations()) {
    if (!mc.seen.has(a)) {
      mc.seen.add(a)
      const eff = a.effect; const t = eff && eff.target
      if (!root || (t && (root === t || root.contains(t)))) {
        const timing = eff ? eff.getTiming() : {}
        const props = new Set(); let blur = 0
        for (const k of (eff && eff.getKeyframes ? eff.getKeyframes() : [])) {
          for (const [key, v] of Object.entries(k)) {
            if (['offset', 'computedOffset', 'easing', 'composite'].includes(key)) continue
            const p = key === 'cssFloat' ? 'float' : key.replace(/[A-Z]/g, (c) => '-' + c.toLowerCase())
            props.add(p)
            if (p.endsWith('filter') && typeof v === 'string') for (const b of v.matchAll(/blur\(\s*([\d.]+)px/g)) blur = Math.max(blur, Number(b[1]))
          }
        }
        if (a.transitionProperty) props.add(a.transitionProperty)
        mc.anims.push({ kind: a.constructor.name, name: a.transitionProperty || a.animationName || a.id || '', target: mc.desc(t, eff && eff.pseudoElement),
          duration: typeof timing.duration === 'number' ? timing.duration : 0, delay: timing.delay || 0,
          infinite: timing.iterations === Infinity, props: [...props], blur, frame: i })
      }
    }
    a.__m ??= (typeof window.__mark === 'number' ? window.__mark : now)
    a.pause()
    a.currentTime = Math.max(0, now - a.__m)
  }
  return { contract, lt: typeof window.__lt === 'number' ? window.__lt : null }
}

async function record(browser, url, o, reducedMotion, full) {
  const ctx = await browser.newContext({ viewport: { width: o.viewport[0], height: o.viewport[1] }, deviceScaleFactor: o.scale, reducedMotion })
  try {
    const page = await ctx.newPage()
    if (!page.clock) throw new Missing('this Playwright has no page.clock (it arrived in 1.45) — upgrade it in the project yourself')
    await page.addInitScript(observer)
    await page.clock.install({ time: 0 })
    try {
      await page.goto(url, { waitUntil: 'load', timeout: 30000 })
    } catch (e) {
      return { error: `the page did not load: ${String(e.message).split('\n')[0]}` }
    }
    await page.evaluate(() => document.fonts && document.fonts.ready)
    let el = null
    if (o.selector) {
      el = page.locator(o.selector).first()
      if (!(await page.locator(o.selector).count())) return { error: `--selector ${o.selector} matched no element` }
      await el.scrollIntoViewIfNeeded()
    }
    await page.clock.pauseAt(10000)
    const step = full ? 1000 / o.fps : 100
    const frames = Math.max(1, Math.ceil(o.ms / step))
    const pre = full ? o.pre : 0
    if (full && o.frames) mkdirSync(o.frames, { recursive: true })
    const loopTime = []; let contract = false
    for (let i = 0; i < frames + pre; i++) {
      const dt = Math.round((i + 1) * step) - Math.round(i * step)
      await page.clock.runFor(dt)
      const r = await page.evaluate(sample, { i, pre, dt, selector: o.selector || null })
      contract = r.contract
      loopTime.push(r.lt ?? 0)
      if (full && o.frames) {
        const path = join(o.frames, `${String(i).padStart(5, '0')}.png`)
        await (el ? el.screenshot({ path }) : page.screenshot({ path }))
      }
    }
    if (full && o.frames && contract) writeFileSync(join(o.frames, 'loop-time.json'), JSON.stringify(loopTime) + '\n')
    const data = await page.evaluate((s) => window.__motionCheck.report(s), o.selector || null)
    return { ...data, frames: frames + pre, contract }
  } finally {
    await ctx.close()
  }
}

const moves = (props) => props.some((p) => p !== 'opacity' && !p.startsWith('--'))

function itemsFrom(rec) {
  const items = rec.anims.map((a) => ({ where: `${a.target} (${a.kind}${a.name ? ' ' + a.name : ''})`, props: a.props, duration: a.duration,
    infinite: a.infinite, blur: a.blur, reduce: false }))
  for (const e of rec.inline.filter((x) => x.changes >= 3)) {
    items.push({ where: `${e.target} (inline style, ${e.changes} changes)`, props: [e.prop], duration: null, infinite: false, blur: e.blur, reduce: false })
  }
  return items
}

async function runBrowser(o) {
  let url
  try { url = targetUrl(o.target) } catch (e) { fail(2, e.message) }
  let launched
  try { launched = await launchChromium({ project: o.project, browser: o.browser }) } catch (e) {
    if (e instanceof Missing) fail(3, `NOT MEASURED — ${e.message}`)
    throw e
  }
  const { browser, via } = launched
  try {
    const normal = await record(browser, url, o, 'no-preference', true)
    if (normal.error) fail(4, `NOT MEASURED — ${normal.error}`)
    const items = itemsFrom(normal)
    if (!items.length) {
      return report(o, { mode: 'browser', via, frames: normal.frames }, [],
        `nothing animated in ${o.ms} ms — a hover-, click- or scroll-started animation needs a page that starts it (or --selector, which scrolls it into view)`)
    }
    const reduce = await record(browser, url, o, 'reduce', false)
    if (reduce.error) fail(4, `NOT MEASURED — reduced-motion pass: ${reduce.error}`)
    const findings = judge(items, o)
    const still = itemsFrom(reduce).filter((it) => moves(it.props) && (it.duration === null || it.duration > INSTANT))
    if (still.length) {
      findings.push({ rule: 'reduced-motion', level: 'fail', where: still[0].where,
        detail: `${still.length} animation(s) still move under prefers-reduced-motion: reduce — the skill renders the still frame there` })
    }
    return report(o, { mode: 'browser', via, frames: normal.frames, contract: normal.contract, animations: normal.anims.length,
      inline: normal.inline.filter((x) => x.changes >= 3).length, framesDir: o.frames || null }, findings, null)
  } catch (e) {
    if (e instanceof Missing) fail(3, `NOT MEASURED — ${e.message}`)
    fail(4, `NOT MEASURED — the recording failed: ${String(e && e.message).split('\n')[0]}`)
  } finally {
    await browser.close().catch(() => {})
  }
}

function report(o, meta, findings, nothing) {
  const failed = findings.filter((f) => f.level === 'fail')
  if (o.json) {
    console.log(JSON.stringify({ target: o.target, ...meta, findings, nothing: nothing || undefined,
      rules: { minMs: o.minMs, maxMs: o.maxMs, maxBlur: o.maxBlur } }, null, 2))
  } else {
    const what = meta.mode === 'static' ? `${meta.items} CSS animation(s)/transition(s) declared`
      : `${meta.frames} frames at ${o.fps} fps through ${meta.via}; ${meta.animations ?? 0} animation(s), ${meta.inline ?? 0} JS-animated style(s)`
        + (meta.contract ? '; drove the page\'s __start/__tick' : '') + (meta.framesDir ? `; PNGs in ${meta.framesDir}` : '')
    console.log(`motion-check (${meta.mode}): ${o.target} — ${what}`)
    for (const n of meta.notes || []) console.log(`note: ${n}`)
    if (nothing) { console.log(`motion-check: NOT MEASURED — ${nothing}`) } else {
      console.log('| rule | level | where | detail |')
      console.log('|---|---|---|---|')
      for (const f of findings) console.log(`| ${f.rule} | ${f.level} | ${f.where} | ${f.detail} |`)
      if (!findings.length) console.log('| - | - | - | every rule held |')
      console.log(`summary: ${failed.length} failed, ${findings.length - failed.length} warning(s) — layout property, duration ${o.minMs}–${o.maxMs} ms, blur <= ${o.maxBlur} px, reduced-motion path`)
    }
  }
  process.exit(nothing ? 4 : failed.length ? 1 : 0)
}

const o = parseArgs(process.argv.slice(2))
if (o.static) runStatic(o)
else await runBrowser(o).catch((e) => fail(e instanceof Usage ? 2 : 4, String(e && e.message)))
