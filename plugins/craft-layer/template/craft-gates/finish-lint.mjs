// finish-lint.mjs — craft-layer's UI finish linter, on the craft-gates Chromium driver: exit 1 on a dead control, placeholder copy, an empty list or table with no empty/loading/error state, or a Tab stop whose focus changes nothing visible; 0 clean; 2 not measured (no URL, the page did not load or did not finish within --timeout, CRAFT_EXPECT_TITLE unmatched, a bad argument); 3 no playwright package; 4 no Chromium that launches.
// Run from the project root: `NODE_PATH=<project>/node_modules node "${CLAUDE_PLUGIN_ROOT}/template/craft-gates/finish-lint.mjs" --url <url> [--src <dir>] [--json] [--timeout <s>]`. Misses: one 1280x800 viewport; handlers delegated to document/body; a library button that always passes handlers (MUI ButtonBase, AntD Button) reads live; closed shadow roots and iframes; focus-indicator contrast; a phrase split across inline elements; the source half of the list rule reads only files that fetch.
// Why, limits, history: rationale/derivations/plugin-craft-layer.md § plugins/craft-layer/template/craft-gates/finish-lint.mjs
import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs'
import { join, resolve, relative, delimiter, basename, dirname } from 'node:path'
import { createRequire } from 'node:module'

const USAGE = 'usage: node finish-lint.mjs [--url <url>] [--src <dir>] [--json] [--timeout <seconds, default 120>]'
const RULES = ['dead-control', 'placeholder-copy', 'stateless-collection', 'focus-ring']

const PLACEHOLDER = [
  ['lorem-ipsum', String.raw`\blorem\s+ipsum\b|\bdolor\s+sit\s+amet\b`, 'i'],
  // The marker form only: a kanban column "TODO" and "Venue: TBD" are copy.
  ['todo-marker', String.raw`\b(?:TODO|TBD|FIXME)\s*[:(]`, ''],
  ['coming-soon', String.raw`\bcoming\s+soon\b`, 'i'],
  ['placeholder-word', String.raw`\bplaceholder\b`, 'i'],
  // The whole chunk: "Untitled document" is an app's default name, "Untitled" alone is a stand-in.
  ['untitled', String.raw`^untitled[.…]?$`, 'i'],
  ['stand-in-name', String.raw`\b(?:John|Jane)\s+Doe\b|\bAcme\s+(?:Inc|Corp|Corporation)\b`, ''],
]

const EMPTY_STATE = String.raw`\b(?:no|zero)\s+(?:[\w'’-]+\s+){0,3}?(?:yet|found|results?|items?|matches|entries|records|data|available|here)\b|\bnothing\b|\bempty\b|\bloading\b|\b(?:couldn['’]?t|could not|failed to|unable to)\s+load\b|\btry again\b|\berror\b`

const DETAIL = {
  'no-href': 'an <a> with no href and nothing handling it: neither a link nor a button',
  'href-empty': 'href="" reloads the page, and nothing handles the click',
  'href-hash': 'href="#" with no handler: it jumps to the top and does nothing else',
  'javascript-void': 'a javascript: URL that does nothing, with no handler',
  'missing-target': 'points at an id no element on the page carries, and nothing handles the click',
  'no-handler': 'no click handler, no form to submit and no popover or command target',
  'lorem-ipsum': 'lorem ipsum',
  'todo-marker': 'a TODO, TBD or FIXME marker',
  'coming-soon': '"Coming soon"',
  'placeholder-word': 'the word "placeholder"',
  'untitled': '"Untitled" as a whole label',
  'stand-in-name': 'a stand-in name (John or Jane Doe, Acme Inc)',
  'empty-table': 'a table with no data rows and no empty, loading or error text in or beside it',
  'empty-list': 'a list with no items and no empty, loading or error text in or beside it',
  'no-state-branch': 'renders fetched data as a list with no empty, loading or error branch anywhere in the file',
  'no-focus-indicator': 'Tab focus changes no outline, box-shadow, border, background, colour or position',
}

const report = {
  tool: 'finish-lint', schema: 1, url: null, src: null,
  dom: { measured: false, reason: 'no --url and no BASE_URL', code: 2, browser: null, identity: null, controls: 0, tabStops: 0 },
  static: { files: 0 },
  findings: [], notes: [], exit: null,
}

function usage(msg) {
  console.error(`finish-lint: ${msg}\n${USAGE}`)
  process.exit(2)
}

const opt = { url: process.env.BASE_URL || '', src: process.cwd(), json: false, timeout: 120 }
const argv = process.argv.slice(2)
for (let i = 0; i < argv.length; i++) {
  const a = argv[i]
  if (a === '--json') opt.json = true
  else if (a === '--url' || a === '--src') {
    if (!argv[i + 1]) usage(`${a} needs a value`)
    opt[a.slice(2)] = argv[++i]
  } else if (a === '--timeout') {
    opt.timeout = Number(argv[++i])
    if (!(opt.timeout > 0)) usage('--timeout needs a number of seconds')
  } else if (a === '-h' || a === '--help') { console.log(USAGE); process.exit(0) }
  else usage(`unknown argument ${JSON.stringify(a)}`)
}
report.url = opt.url || null
report.src = resolve(opt.src)

let stopped = false   // set by the watchdog: a hung pass that wakes later writes nothing
const add = (rule, pattern, where, target, text, detail = DETAIL[pattern]) =>
  stopped || report.findings.push({ rule, pattern, where, target, text, detail, waived: null })

const SRC_EXT = /\.(?:html?|jsx?|tsx?|vue|svelte|astro|mdx)$/i
const SKIP_DIR = /^(?:node_modules|dist|build|out|coverage|vendor|craft|taskmaster-docs)$/i
const NOT_THE_PAGE = /(?:^|\/)(?:tests?|__tests__|e2e|spec|specs|stories|scripts|config|mocks?|fixtures?)\//i
const NOT_THE_PAGE_FILE = /\.(?:spec|test|stories|config|d)\.[jt]sx?$/i
const FETCH_RE = /\b(?:fetch|useQuery|useSuspenseQuery|useInfiniteQuery|useQueries|useSWR(?:Infinite)?|useFetch|useLazyFetch|useAsyncData|createResource|createQuery|useLoaderData)\s*\(|\$fetch\s*\(|\baxios(?:\.\w+)?\s*\(/
const COLLECTION_RE = /\.map\(\s*(?:async\s+)?(?:\([^()]*\)|[\w$]+)\s*=>\s*[(`]?\s*<|\bv-for\s*=\s*["'][^"']*?\b(?:in|of)\s+([\w$]+)|\{#each\s+([\w$]+)/g
const STATE_RE = [
  /\.length\s*(?:===?|!==?|>|<=?)\s*0\b|!\s*[\w$.?]+\.length\b|\.length\s*(?:\?|&&)|\bisEmpty\b|\{:else\}|\bv-else\b|<Empty\w*|\bnoResults?\b/,
  /\bis(?:Loading|Pending|Fetching)\b|\b(?:loading|pending)\s*(?:\?|&&|\)|===?)|<Skeleton|<Spinner|<Suspense\b|aria-busy|\{#await\b|['"](?:loading|pending)['"]/,
  /\bisError\b|\berror\s*(?:\?|&&|\)|===?|\.message)|<ErrorBoundary|errorElement|\{:catch\b|\bonError\b/,
]

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

const NAME = /[A-Za-z_$][\w$]*/g
const BIND_RE = /(?:\b(?:const|let|var)\s+(\{[^}]*\}|\[[^\]]*\]|[A-Za-z_$][\w$]*)(?:\s*:[^=;\n]+?)?|(?<![\w$.])([A-Za-z_$][\w$]*))\s*=(?![=>])([^;\n]*)/g
const STATE_PAIR_RE = /\[\s*([A-Za-z_$][\w$]*)\s*,\s*(set[A-Z][\w]*)\s*\]\s*=\s*(?:React\.)?use(?:State|Reducer)\b/g

/** Names bound from a fetch or data hook: directly, through another such name, or as useState set near a fetch. */
function fetchedNames(src) {
  const names = new Set()
  const binds = [...src.matchAll(BIND_RE)].map((m) => ({ names: (m[1] ?? m[2]).match(NAME) ?? [], rhs: m[3] }))
  for (let grew = true, n = 0; grew && n < 6; n++) {
    grew = false
    for (const b of binds) {
      if (b.names.every((x) => names.has(x))) continue
      const words = b.rhs.replace(/'[^']*'|"[^"]*"/g, '').match(NAME) ?? []
      if (FETCH_RE.test(b.rhs) || words.some((w) => names.has(w))) { b.names.forEach((x) => names.add(x)); grew = true }
    }
  }
  const fetchAt = [...src.matchAll(new RegExp(FETCH_RE.source, 'g'))].map((m) => m.index)
  for (const m of src.matchAll(STATE_PAIR_RE)) {
    for (const u of src.matchAll(new RegExp(`(?<![\\w$])${m[2]}(?![\\w$])`, 'g'))) {
      if (u.index < m.index + m[0].length) continue
      if (fetchAt.some((f) => f < u.index && u.index - f < 600)) { names.add(m[1]); break }
    }
  }
  return names
}

/** The member/call chain `.map` is called on, as text: `data?.rows`, `items.filter((x) => x.on)`, `(data ?? [])`. */
function receiverText(src, end) {
  let j = end
  const ws = () => { while (j > 0 && /[\s?!]/.test(src[j - 1])) j-- }
  for (let n = 0; n < 40; n++) {
    ws()
    const c = src[j - 1]
    if (c === ')' || c === ']') {
      const open = c === ')' ? '(' : '['
      let depth = 0, k = j - 1
      for (; k >= 0; k--) { if (src[k] === c) depth++; else if (src[k] === open && --depth === 0) break }
      if (k < 0) break
      j = k
      ws()
      if (!/[\w$]/.test(src[j - 1] ?? '')) break
      continue
    }
    const id = /[A-Za-z_$][\w$]*$/.exec(src.slice(Math.max(0, j - 80), j))
    if (!id) break
    j -= id[0].length
    while (j > 0 && /\s/.test(src[j - 1])) j--
    if (src[j - 1] !== '.') break
    j--
  }
  return src.slice(j, end)
}

// Next.js renders a route segment's loading.* and error.* around its page and every page below it.
function routeStates(file, root) {
  if (!/^page\.[jt]sx?$/.test(basename(file))) return false
  for (let d = dirname(file); d.startsWith(root); d = dirname(d)) {
    let names = []
    try { names = readdirSync(d) } catch { /* unreadable reads as absent */ }
    if (names.some((n) => /^(?:loading|error)\.[jt]sx?$/.test(n))) return true
    if (basename(d) === 'app' || d === root || dirname(d) === d) break
  }
  return false
}

function sourcePass() {
  const root = report.src
  if (!existsSync(root)) { report.notes.push(`source half: ${root} does not exist — not read`); return }
  for (const f of sourceFiles(root)) {
    const rel = relative(root, f) || f
    if (NOT_THE_PAGE.test(rel) || NOT_THE_PAGE_FILE.test(f)) continue
    let src
    try {
      if (statSync(f).size > 512 * 1024) continue
      src = readFileSync(f, 'utf8')
    } catch { continue }
    report.static.files++
    if (!FETCH_RE.test(src) || STATE_RE.some((re) => re.test(src)) || routeStates(f, root)) continue
    const fetched = fetchedNames(src)
    // A list counts only when it maps what was fetched: a module literal (LINKS.map) cannot be empty.
    const m = [...src.matchAll(COLLECTION_RE)].find((x) => {
      const recv = x[1] ?? x[2] ?? receiverText(src, x.index)
      return FETCH_RE.test(recv) || (recv.match(NAME) ?? []).some((w) => fetched.has(w))
    })
    if (!m) continue
    add('stateless-collection', 'no-state-branch', `${rel}:${src.slice(0, m.index).split('\n').length}`, rel,
      m[0].replace(/\s+/g, ' ').slice(0, 60))
  }
}

function loadPlaywright() {
  const bases = [process.cwd(), ...(process.env.NODE_PATH || '').split(delimiter).filter(Boolean)]
  for (const base of bases) {
    const req = createRequire(join(resolve(base), 'finish-lint.cjs'))
    for (const name of ['playwright', '@playwright/test', 'playwright-core']) {
      try { return { pw: req(req.resolve(name, { paths: [resolve(base)] })) } } catch { /* next */ }
    }
  }
  return null
}

async function launch(pw) {
  const ch = process.env.CRAFT_BROWSER_CHANNEL
  const tries = [...(ch ? [{ channel: ch }] : []), {}, ...(ch === 'chrome' ? [] : [{ channel: 'chrome' }])]
  const errors = []
  for (const o of tries) {
    const how = o.channel ? `channel ${o.channel}` : 'bundled Chromium'
    try {
      const browser = await pw.chromium.launch({ ...o, timeout: 30000 })
      return { browser, how: `${how} ${browser.version()}` }
    } catch (e) { errors.push(`${how}: ${String(e?.message ?? e).split('\n')[0]}`) }
  }
  return { browser: null, errors }
}

function notMeasured(code, reason) {
  if (!stopped) Object.assign(report.dom, { measured: false, code, reason })
}

let live = null   // the launched browser, for the watchdog to close

/** In-page helpers, installed once so each later evaluate can reach them. */
function installHelpers() {
  const f = (window.__finishLint = { nodes: [], anc: [], stops: [] })
  f.shown = (el) => (el.checkVisibility ? el.checkVisibility({ visibilityProperty: true }) : el.getClientRects().length > 0)
  f.name = (el) => {
    const cls = (typeof el.className === 'string' ? el.className : el.getAttribute('class') || '').trim().split(/\s+/)[0]
    return `${el.tagName.toLowerCase()}${el.id ? '#' + el.id : ''}${cls ? '.' + cls : ''}`
  }
  f.label = (el) => (el.getAttribute('aria-label') || el.innerText || el.textContent || el.getAttribute('value') ||
    el.getAttribute('title') || '').replace(/\s+/g, ' ').trim().slice(0, 60)
  f.up = (n) => n.parentElement ?? (n.getRootNode() instanceof ShadowRoot ? n.getRootNode().host : null)

  const EVENTS = ['click', 'mousedown', 'mouseup', 'pointerdown', 'pointerup', 'touchstart', 'touchend', 'keydown', 'keyup', 'keypress']
  const REACT_HANDLER = /^on(?:Click|MouseDown|MouseUp|PointerDown|PointerUp|TouchStart|TouchEnd|KeyDown|KeyUp|KeyPress)(?:Capture)?$/
  const DELEGATED = /^(?:__|\$\$)(?:click|mousedown|mouseup|pointerdown|pointerup|touchstart|touchend|keydown|keyup)$/
  const reactProps = (el) => { const k = Object.keys(el).find((x) => x.startsWith('__reactProps$')); return k ? el[k] || {} : null }
  const reactHandles = (p) => Object.keys(p).some((k) => REACT_HANDLER.test(k) && typeof p[k] === 'function')
  // React, Svelte 5 and Solid delegate to a root and keep the handler on the node; everything else binds to the node.
  f.handled = (el) => {
    if (!el.isConnected) return 'gone'
    if (EVENTS.some((t) => typeof el['on' + t] === 'function')) return 'inline'
    const p = reactProps(el)
    if (p) {
      if (reactHandles(p)) return 'react'
      // A React handler on an ancestor fires for this node too: synthetic events bubble.
      for (let a = f.up(el); a && a !== document.body; a = f.up(a)) { const q = reactProps(a); if (q && reactHandles(q)) return 'react' }
      return 'react-none'
    }
    return Object.keys(el).some((k) => DELEGATED.test(k) && typeof el[k] === 'function') ? 'delegated' : null
  }
  f.clipped = (el) => {
    const r = el.getBoundingClientRect()
    const cs = getComputedStyle(el)
    const c = cs.clip.match(/rect\((-?[\d.]+)px,?\s*(-?[\d.]+)px,?\s*(-?[\d.]+)px,?\s*(-?[\d.]+)px/)
    const out = cs.position === 'absolute' || cs.position === 'fixed'
    return (out && (r.width <= 1 || r.height <= 1)) || cs.clipPath === 'inset(50%)' || (!!c && (c[2] - c[4] <= 1 || c[3] - c[1] <= 1))
  }
  f.hidden = []
  const PROPS = ['box-shadow', 'background-color', 'background-image', 'color', 'text-decoration-line', 'opacity',
    'transform', 'filter', 'left', 'top', 'clip', 'clip-path', 'visibility']
  const clear = (c) => c === 'transparent' || /^rgba\(.*,\s*0\)$/.test(c)
  // An outline or border with no style, no width or no alpha paints nothing, whatever its offset or colour says.
  const line = (cs, k) => {
    const [style, width, color] = ['style', 'width', 'color'].map((p) => cs.getPropertyValue(`${k}-${p}`))
    if (style === 'none' || style === 'hidden' || parseFloat(width) === 0 || clear(color)) return 'none'
    return `${style} ${width} ${color}${k === 'outline' ? ' ' + cs.getPropertyValue('outline-offset') : ''}`
  }
  const part = (el, pseudo) => {
    const cs = getComputedStyle(el, pseudo)
    return [...['outline', 'border-top', 'border-right', 'border-bottom', 'border-left'].map((k) => line(cs, k)),
      ...PROPS.map((p) => cs.getPropertyValue(p))].join('|')
  }
  // Two ancestors (:focus-within), the labels and three later siblings (peer-focus-visible:, input:focus + label), and the
  // element with its pseudo-elements unless it is clipped or 1px: an sr-only input's own outline is never seen.
  f.snap = (el, hidden) => {
    const parts = hidden ? [] : [part(el), part(el, '::before'), part(el, '::after')]
    for (let a = f.up(el), k = 0; a && a !== document.body && k < 2; a = f.up(a), k++) parts.push(part(a))
    const near = [...(el.labels ?? [])]
    for (let n = el.nextElementSibling, k = 0; n && k < 3; n = n.nextElementSibling, k++) near.push(n)
    for (const n of near) parts.push(part(n), part(n, '::before'), part(n, '::after'))
    return parts.join('\n')
  }
}

function collect(o) {
  const f = window.__finishLint
  const roots = []
  const addRoot = (r) => { roots.push(r); for (const el of r.querySelectorAll('*')) if (el.shadowRoot) addRoot(el.shadowRoot) }
  addRoot(document)
  const all = (sel) => [...new Set(roots.flatMap((r) => [...r.querySelectorAll(sel)]))]
  const out = { scanned: 0, controls: [], placeholder: [], collections: [] }

  const here = new URL(location.href)
  const CONTROL = 'a, button, input[type=button], input[type=submit], input[type=reset], input[type=image], [role=button], [role=link]'
  for (const el of all(CONTROL)) {
    if (!f.shown(el) || el.closest('[inert]')) continue
    if (el.disabled || el.getAttribute('aria-disabled') === 'true') continue
    out.scanned++
    const tag = el.tagName.toLowerCase()
    let pattern = null
    if (tag === 'a') {
      if (!el.hasAttribute('href')) {
        if (!f.label(el)) continue                    // a bare anchor target, not a control
        pattern = 'no-href'
      } else {
        const href = el.getAttribute('href').trim()
        if (href === '') pattern = 'href-empty'
        else if (href === '#') pattern = 'href-hash'
        else if (/^javascript:/i.test(href)) {
          if (!/^javascript:\s*(?:void\s*\(?\s*0?\s*\)?)?\s*;?\s*$/i.test(href)) continue   // javascript:fn() runs code
          pattern = 'javascript-void'
        } else {
          let u
          try { u = new URL(href, location.href) } catch { continue }
          if (!u.hash || u.origin + u.pathname + u.search !== here.origin + here.pathname + here.search) continue
          let frag = u.hash.slice(1)
          try { frag = decodeURIComponent(frag) } catch { /* `#50%off` is not percent-encoding: match it as written */ }
          // `#top` scrolls to the top by the HTML spec; `#/` and `#!` are hash routes.
          if (/^top$/i.test(frag) || /^[/!]/.test(frag)) continue
          const root = el.getRootNode()
          if ((root.getElementById && root.getElementById(frag)) || document.getElementById(frag) || document.getElementsByName(frag)[0]) continue
          pattern = 'missing-target'
        }
      }
    } else {
      if (el.form && ['submit', 'reset', 'image'].includes(el.type)) continue
      if (el.popoverTargetElement || el.commandForElement) continue
      pattern = el.hasAttribute('popovertarget') || el.hasAttribute('commandfor') ? 'missing-target' : 'no-handler'
    }
    f.nodes.push(el)
    out.controls.push({ i: f.nodes.length - 1, pattern, target: f.name(el), text: f.label(el), handled: f.handled(el) })
  }

  const PH = o.placeholder.map(([id, src, flags]) => [id, new RegExp(src, flags)])
  const seen = new Set()
  const hit = (raw, el, where) => {
    const t = String(raw || '').replace(/\s+/g, ' ').trim()
    if (!t) return
    for (const [id, re] of PH) {
      if (!re.test(t)) continue
      const key = `${id}|${el ? f.name(el) : where}|${t.slice(0, 80)}`
      if (seen.has(key)) continue
      seen.add(key)
      out.placeholder.push({ pattern: id, target: el ? f.name(el) : where, text: t.slice(0, 80), where })
    }
  }
  hit(document.title, null, 'title')
  const CODE = 'code, pre, kbd, samp, var, template, .cm-editor, .CodeMirror, .monaco-editor, [contenteditable=""], [contenteditable=true], [contenteditable=plaintext-only]'
  for (const r of roots) {
    const start = r === document ? document.body : r
    if (!start) continue
    const w = document.createTreeWalker(start, NodeFilter.SHOW_TEXT)
    for (let n = w.nextNode(); n; n = w.nextNode()) {
      const el = n.parentElement
      if (!el || el.closest(`${CODE}, script, style, noscript, textarea`) || !f.shown(el)) continue
      hit(n.textContent, el, 'text')
    }
  }
  for (const el of all('[alt], [placeholder], [aria-label], [title], input[value]')) {
    if (el.closest(CODE) || !f.shown(el)) continue
    for (const a of ['alt', 'placeholder', 'aria-label', 'title']) if (el.hasAttribute(a)) hit(el.getAttribute(a), el, a)
    if (el.tagName === 'INPUT' && /^(?:submit|button|reset)$/i.test(el.type)) hit(el.value, el, 'value')
  }

  const EMPTY = new RegExp(o.emptyState, 'i')
  const SECTION = 'main, section, article, aside, nav, dialog, [role=region], [role=dialog], [role=main], [role=tabpanel]'
  // In it or an ancestor up to its nearest sectioning element; never body or a wrapper of several sections, whose text is the page's.
  const stated = (el) => {
    if (el.closest('[aria-busy="true"]') || EMPTY.test(el.innerText || '')) return true
    for (let a = el.parentElement; a && a !== document.body; a = a.parentElement) {
      const section = a.matches(SECTION)
      if (!section && a.querySelector(SECTION)) return false
      if (EMPTY.test(a.innerText || '')) return true
      if (section) return false
    }
    return false
  }
  for (const t of all('table')) {
    if (!f.shown(t) || t.closest('[aria-hidden="true"]')) continue
    const data = [...t.rows].filter((r) => r.parentElement !== t.tHead && r.parentElement !== t.tFoot &&
      [...r.cells].some((c) => c.tagName === 'TD'))
    if (data.length || stated(t)) continue
    out.collections.push({ pattern: 'empty-table', target: f.name(t), text: (t.tHead?.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 60) })
  }
  for (const l of all('ul, ol, [role=list], [role=listbox], [role=feed], [role=grid], [role=treegrid], [role=tree]')) {
    if (l.tagName === 'TABLE' || !f.shown(l) || l.closest('[aria-hidden="true"]')) continue
    // A toast viewport (Radix, Sonner: a fixed <ol>) or a live region is empty at rest by design.
    if (getComputedStyle(l).position === 'fixed' || l.closest('[aria-live]:not([aria-live=off])')) continue
    if (l.children.length || (l.textContent || '').trim() || stated(l)) continue
    out.collections.push({ pattern: 'empty-list', target: f.name(l), text: '' })
  }
  return out
}

/** The focused element as a new stop; `same` when Tab stayed on the last one (date fields, an iframe's contents); `end` on body or a revisit. */
function readStop() {
  const f = window.__finishLint
  let el = document.activeElement
  while (el && el.shadowRoot && el.shadowRoot.activeElement) el = el.shadowRoot.activeElement
  if (!el || el === document.body || el === document.documentElement) return { end: true }
  if (el === f.stops[f.stops.length - 1]) return { same: true, target: f.name(el) }
  if (f.stops.includes(el)) return { end: true }
  const i = f.stops.push(el) - 1
  const iframe = el.tagName === 'IFRAME'
  f.hidden[i] = !iframe && f.clipped(el)
  return { i, iframe, target: f.name(el), text: f.label(el), focused: iframe ? '' : f.snap(el, f.hidden[i]), outline: getComputedStyle(el).outlineStyle }
}

async function domPass() {
  const loaded = loadPlaywright()
  if (!loaded) {
    return notMeasured(3, 'missing: the playwright package — looked for playwright, @playwright/test and playwright-core under '
      + `${process.cwd()} and NODE_PATH; install it in the project (npm i -D @playwright/test), this script never installs anything`)
  }
  const { browser, how, errors } = await launch(loaded.pw)
  if (!browser) {
    return notMeasured(4, `missing: a Chromium that launches — ${errors.join('; ')}. Run \`npx playwright install chromium\` `
      + 'in the project, or set CRAFT_BROWSER_CHANNEL to an installed channel (chrome); this script never downloads one')
  }
  report.dom.browser = how
  live = browser
  try {
    const context = await browser.newContext({ viewport: { width: 1280, height: 800 } })
    const page = await context.newPage()
    let resp
    try { resp = await page.goto(opt.url, { waitUntil: 'load', timeout: 30000 }) } catch (e) {
      return notMeasured(2, `the page did not load: ${String(e?.message ?? e).split('\n')[0]}`)
    }
    if (resp && resp.status() >= 400) return notMeasured(2, `${opt.url} answered HTTP ${resp.status()}`)
    // Hydration and late chunks land after load; bounded, so a page that never goes idle still runs.
    await page.waitForLoadState('networkidle', { timeout: 5000 }).catch(() => {})

    const seen = await page.evaluate(() => ({ title: document.title, text: (document.body?.innerText ?? '').slice(0, 5000) }))
    const expect = process.env.CRAFT_EXPECT_TITLE?.trim()
    if (expect && !`${seen.title}\n${seen.text}`.includes(expect)) {
      return notMeasured(2, `WRONG APPLICATION: CRAFT_EXPECT_TITLE ${JSON.stringify(expect)} is not in the title or body of ${opt.url}, `
        + `which calls itself ${JSON.stringify(seen.title)}`)
    }
    report.dom.identity = expect ? `matched ${JSON.stringify(expect)}`
      : `NOT MEASURED — CRAFT_EXPECT_TITLE unset; the page calls itself ${JSON.stringify(seen.title)}`

    // Walk the page so scroll-revealed and lazy content is in the DOM before anything is read.
    await page.evaluate(async () => {
      const frame = () => new Promise((r) => requestAnimationFrame(() => r(null)))
      const step = Math.max(1, Math.round(innerHeight * 0.9))
      for (let y = 0, k = 0; y < document.body.scrollHeight && k < 60; y += step, k++) { scrollTo(0, y); await frame() }
      await Promise.race([document.fonts.ready, new Promise((r) => setTimeout(r, 3000))])
      scrollTo(0, 0)
      await frame()
    })
    await page.evaluate(installHelpers)
    const dom = await page.evaluate(collect, { placeholder: PLACEHOLDER, emptyState: EMPTY_STATE })

    const cdp = await context.newCDPSession(page)
    const INTERACTIVE = new Set(['click', 'mousedown', 'mouseup', 'pointerdown', 'pointerup', 'touchstart', 'touchend', 'keydown', 'keyup', 'keypress'])
    const listens = async (expression) => {
      const { result } = await cdp.send('Runtime.evaluate', { expression, objectGroup: 'finish-lint' })
      if (!result?.objectId) return false
      const { listeners } = await cdp.send('DOMDebugger.getEventListeners', { objectId: result.objectId, depth: 0 })
      return listeners.some((l) => INTERACTIVE.has(l.type))
    }
    const deadOf = async (controls) => {
      const ancestorCache = new Map()
      const dead = []
      for (const c of controls) {
        if (c.handled && c.handled !== 'react-none') continue
        if (await listens(`window.__finishLint.nodes[${c.i}]`)) continue
        if (c.handled !== 'react-none') {
          // Delegation to a container counts; to body or document it is the residual this file names.
          const anc = await page.evaluate((i) => {
            const f = window.__finishLint
            const out = []
            for (let n = f.up(f.nodes[i]); n && n !== document.body && n !== document.documentElement; n = f.up(n)) {
              let k = f.anc.indexOf(n)
              if (k < 0) k = f.anc.push(n) - 1
              out.push(k)
            }
            return out
          }, c.i)
          let delegated = false
          for (const k of anc) {
            if (!ancestorCache.has(k)) ancestorCache.set(k, await listens(`window.__finishLint.anc[${k}]`))
            if (ancestorCache.get(k)) { delegated = true; break }
          }
          if (delegated) continue
        }
        dead.push(c)
      }
      return dead
    }
    let dead = await deadOf(dom.controls)
    if (dead.length) {
      // Hydration can land after network idle: a control is dead only if it is still dead a moment later.
      await page.waitForTimeout(1500)
      const now = await page.evaluate((ix) => ix.map((i) => window.__finishLint.handled(window.__finishLint.nodes[i])), dead.map((c) => c.i))
      dead.forEach((c, k) => { c.handled = now[k] })
      dead = await deadOf(dead)
    }
    for (const c of dead) add('dead-control', c.pattern, 'dom', c.target, c.text)
    report.dom.controls = dom.scanned
    await cdp.send('Runtime.releaseObjectGroup', { objectGroup: 'finish-lint' }).catch(() => {})

    for (const p of dom.placeholder) add('placeholder-copy', p.pattern, p.where === 'text' ? 'dom' : `dom ${p.where}`, p.target, p.text,
      `${DETAIL[p.pattern]} in reader-visible ${p.where === 'text' ? 'copy' : p.where === 'title' ? 'page title' : `${p.where} text`}`)
    for (const c of dom.collections) add('stateless-collection', c.pattern, 'dom', c.target, c.text)

    // Transitions off, so the focused style read right after Tab is the settled one.
    await page.addStyleTag({ content: '*, *::before, *::after { transition: none !important; animation: none !important; }' })
    await page.evaluate(() => { document.activeElement?.blur?.(); scrollTo(0, 0) })
    const MAX_STOPS = 200
    const MAX_HELD = 40
    const stops = []
    const held = new Map()
    let trapped = null
    for (let same = 0; stops.length < MAX_STOPS;) {
      await page.keyboard.press('Tab')
      const s = await page.evaluate(readStop)
      if (s.end) break
      if (s.same) {
        held.set(s.target, (held.get(s.target) ?? 0) + 1)
        if (++same >= MAX_HELD) { trapped = s.target; break }
        continue
      }
      same = 0
      stops.push(s)
    }
    for (const [t, n] of held) report.notes.push(`focus-ring: Tab stayed on ${t} for ${n} more press(es) (its own fields, or an iframe's contents) — the walk went on past it`)
    if (trapped) report.notes.push(`focus-ring: Tab stayed on ${trapped} for ${MAX_HELD} presses — the walk stopped there, later stops not checked`)
    if (stops.length === MAX_STOPS) report.notes.push(`focus-ring: stopped after ${MAX_STOPS} Tab stops — later stops not checked`)
    await page.evaluate(() => { let el = document.activeElement; while (el?.shadowRoot?.activeElement) el = el.shadowRoot.activeElement; el?.blur?.() })
    const rest = await page.evaluate(() => window.__finishLint.stops.map((el, i) => (el.tagName === 'IFRAME' ? '' : window.__finishLint.snap(el, window.__finishLint.hidden[i]))))
    for (const s of stops) {
      if (s.iframe) { report.notes.push(`focus-ring: ${s.target} is an iframe Tab stop — its contents were not checked`); continue }
      if (s.focused === rest[s.i]) add('focus-ring', 'no-focus-indicator', 'dom', s.target, s.text, `${DETAIL['no-focus-indicator']} (outline-style ${s.outline})`)
    }
    report.dom.tabStops = stops.length
    if (!stopped) Object.assign(report.dom, { measured: true, code: 0, reason: null })
  } finally {
    await browser.close().catch(() => {})
  }
}

function readWaivers() {
  const p = resolve(process.cwd(), '.craft-layer/waivers.json')
  if (!existsSync(p)) return []
  try {
    const j = JSON.parse(readFileSync(p, 'utf8'))
    if (!Array.isArray(j)) throw new Error('not an array')
    return j.filter((w) => {
      if (!w || !RULES.includes(w.check)) return false
      if (String(w.reason ?? '').trim()) return true
      report.notes.push(`waiver for '${w.check}' has no reason — IGNORED (a waiver without a reason is a silence)`)
      return false
    })
  } catch (e) {
    report.notes.push(`waivers.json unparseable (${e.message}) — no waivers applied`)
    return []
  }
}

sourcePass()
if (opt.url) {
  let timer
  const watchdog = new Promise((r) => { timer = setTimeout(() => r('timeout'), opt.timeout * 1000) })
  try {
    if (await Promise.race([domPass(), watchdog]) === 'timeout') {
      notMeasured(2, `the browser pass did not finish in ${opt.timeout} s (a page that never yields, such as a busy loop) — raise --timeout for a slow page`)
      stopped = true
      await Promise.race([live?.close(), new Promise((r) => setTimeout(r, 5000))]).catch(() => {})
    }
  } catch (e) { notMeasured(2, `the browser pass crashed: ${String(e?.message ?? e).split('\n')[0]}`) }
  stopped = true
  clearTimeout(timer)
}
const waivers = readWaivers()
for (const fnd of report.findings) {
  const w = waivers.find((x) => x.check === fnd.rule && (!String(x.value ?? '').trim() || x.value === '*'
    || [fnd.pattern, fnd.target, fnd.text].some((v) => String(v).toLowerCase() === String(x.value).toLowerCase())))
  if (w) fnd.waived = w.reason
}

const open = report.findings.filter((x) => !x.waived)
// Page-controlled text reaches the terminal escaped: an id holding ESC or a bidi override must not drive it.
const safe = (s) => String(s).replace(/[\u0000-\u001f\u007f-\u009f\u200e\u200f\u202a-\u202e\u2066-\u2069]/g, (c) => `\\u${c.charCodeAt(0).toString(16).padStart(4, '0')}`)
report.exit = report.dom.measured ? (open.length ? 1 : 0) : report.dom.code
if (opt.json) {
  console.log(JSON.stringify(report, null, 2))
} else {
  console.log(`finish-lint · url ${report.url ?? 'none'} · source ${report.src}`)
  if (report.dom.browser) console.log(`browser:  ${report.dom.browser}`)
  if (report.dom.identity) console.log(`identity: ${safe(report.dom.identity)}`)
  console.log('')
  for (const x of report.findings) {
    console.log(`  ${(x.waived ? 'WAIVED' : 'FAIL').padEnd(6)} ${x.rule.padEnd(20)} ${x.pattern.padEnd(18)} ${safe(x.where)} ${safe(x.target)}`
      + `${x.text ? ' ' + safe(JSON.stringify(x.text)) : ''} — ${safe(x.detail)}${x.waived ? `  [waived: ${safe(x.waived)}]` : ''}`)
  }
  for (const n of report.notes) console.log(`  note   ${safe(n)}`)
  console.log('')
  console.log(`coverage: dom ${report.dom.measured ? `measured (${report.dom.controls} control(s), ${report.dom.tabStops} Tab stop(s))`
    : `NOT MEASURED (${safe(report.dom.reason)})`} · source ${report.static.files} file(s)`)
  console.log(!report.dom.measured
    ? `NOT MEASURED: the browser half did not run, so this proves nothing about the page${open.length ? `; the ${open.length} finding(s) above stand on their own` : ''}.`
    : open.length ? `${open.length} finish finding(s) — the build shipped unfinished UI.`
      : `OK: no dead control, placeholder copy, bare empty collection or invisible focus across ${report.dom.controls} control(s) and ${report.dom.tabStops} Tab stop(s).`)
}
process.exit(report.exit)
