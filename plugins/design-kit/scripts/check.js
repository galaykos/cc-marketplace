// check.js — render-check.py evaluates it in an isolated world of the loaded page (after axe-core), so page script cannot read, replace or answer for it; its completion value is the findings, returned over DevTools.
// E1 nothing rendered; E2 sideways overflow, cut-off and overlapping text, small targets; E3 axe-core serious and critical; E4 placeholder text, repeated rows, empty tables and lists. Misses: iframes, closed shadow roots, canvas and image text, states behind interaction; past 4000 elements, the rest.
// Why, limits, history: rationale/derivations/plugin-design-kit.md § plugins/design-kit/scripts/check.js
(() => {
'use strict';
const KEEP = 60; // findings returned; the rest are counted as dropped
const WALK = 4000; // elements a check walks, so a huge page stays inside the time bound
const SKIP_DATA = /^data-(design-kit|original|bound)/;
const NOT_TEXT = 'script,style,noscript,template,[data-design-kit-check]';

function cut(s, n) { return Array.from(String(s ?? '').slice(0, 2 * n)).slice(0, n).join(''); }
function squash(s) { return String(s ?? '').replace(/\s+/g, ' ').trim(); }

// note.js's selector, copied: importing note.js would start its widget
function selectorOf(el) {
  if (!(el instanceof Element)) return null;
  const parts = [];
  for (let n = el; n && n.nodeType === 1 && n !== document.documentElement; n = n.parentElement) {
    if (n.id && document.querySelectorAll('#' + CSS.escape(n.id)).length === 1) { parts.unshift('#' + CSS.escape(n.id)); break; }
    let seg = CSS.escape(n.localName);
    const data = Array.from(n.attributes).find((a) => a.name.startsWith('data-') && !SKIP_DATA.test(a.name) && a.value.length <= 64);
    if (data) seg += '[' + CSS.escape(data.name) + '="' + CSS.escape(data.value) + '"]';
    const same = n.parentElement ? Array.from(n.parentElement.children).filter((c) => c.localName === n.localName) : [];
    if (same.length > 1) seg += ':nth-of-type(' + (same.indexOf(n) + 1) + ')';
    parts.unshift(seg);
    try {
      const hits = document.querySelectorAll(parts.join(' > '));
      if (hits.length === 1 && hits[0] === el) break;
    } catch (e) { /* keep climbing */ }
  }
  return parts.join(' > ') || el.localName;
}

// The page kind from what the builders stamp: a board's design-kit-board metas, a deck's generator meta.
function kind() {
  if (document.querySelector('meta[name="design-kit-board"]')) return 'board';
  if (/^design-kit slides/.test(document.querySelector('meta[name="generator"]')?.content || '')) return 'deck';
  return document.querySelector('meta[name="design-kit-artifact"]') ? 'artifact' : 'page';
}

// The designed stage: an isolated artboard's frame (#board=N), a deck's .deck; else the viewport (null).
function stageOf(k) {
  if (k === 'board') return document.querySelector('.dk-board.isolated .dk-frame');
  if (k === 'deck') return document.querySelector('.deck');
  return null;
}

let textCut = 0; // the smallest text-node cap a walk stopped at

function* texts(root, cap = 5000) {
  const w = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
    acceptNode: (t) => (t.data.trim() && !t.parentElement?.closest(NOT_TEXT) ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT),
  });
  for (let t, n = 0; (t = w.nextNode()); n++) {
    if (n >= cap) { textCut = Math.min(textCut || cap, cap); return; }
    yield t;
  }
}

function lineRects(t) {
  const r = document.createRange();
  r.selectNodeContents(t);
  return Array.from(r.getClientRects()).filter((q) => q.width > 0.5 && q.height > 0.5);
}

function blank(scope, out) {
  const b = scope.getBoundingClientRect();
  let painted = false;
  if (b.width > 0 && b.height > 0) {
    for (const t of texts(scope)) {
      if (lineRects(t).length && getComputedStyle(t.parentElement).visibility !== 'hidden') { painted = true; break; }
    }
    painted = painted || Array.from(scope.querySelectorAll('img,svg,canvas,video,picture,iframe,object,embed,input,button,select,textarea'))
      .some((e) => { const r = e.getBoundingClientRect(); return r.width > 1 && r.height > 1; });
  }
  if (!painted) {
    out.push({ check: 'E1.blank', selector: null, text: 'nothing visible rendered',
      detail: `the page box is ${Math.round(b.width)}x${Math.round(b.height)} px with no visible text, image or control` });
  }
}

// The first WALK elements under root, and how many there are.
function elements(root) {
  const all = root.getElementsByTagName('*');
  return { list: Array.prototype.slice.call(all, 0, WALK), total: all.length };
}

const MEDIA = 'img,svg,canvas,video,picture,iframe,object,embed,input,button,select,textarea,table';
const LOREM = /\b(lorem ipsum|dolor sit amet|consectetur adipiscing)\b/i;
const TODO = /\b(TODO|FIXME)\b/;
// template nouns only (taskmaster's list): "your company name here" is filler, "track your order here" is copy
const NOUN = '(?:text|title|name|content|copy|description|heading|headline|message|logo|image|tagline|label)';
const FILLER = new RegExp('\\b(placeholder|(?:your|some) (?:[a-z]+ )?' + NOUN + ' (?:goes )?here|insert (?:your )?(?:[a-z]+ )?' + NOUN
  + ' here|(?:text|content|copy|title) goes here|sample text|dummy text)\\b', 'i');
const CODE = 'pre,code,kbd,samp';
const GENERIC = /^(item|card|feature|product|title|heading|label|name|user|entry|row|link|button|text|value|tab)\s*#?\d{1,3}$/i;

// The box content is clipped to: the viewport for the root, html and body; else the padding box.
function clipBox(el) {
  if (!el || el === document.documentElement || el === document.body) {
    const de = document.documentElement;
    return { left: 0, top: 0, right: de.clientWidth, bottom: de.clientHeight };
  }
  const r = el.getBoundingClientRect(), left = r.left + el.clientLeft, top = r.top + el.clientTop;
  return { left, top, right: left + el.clientWidth, bottom: top + el.clientHeight };
}

// A scroll or clip container between el and the stage keeps what pokes out of el inside itself.
function held(el, st) {
  for (let p = el.parentElement; p && p !== st && p !== document.body && p !== document.documentElement; p = p.parentElement) {
    if (getComputedStyle(p).overflowX !== 'visible') return true;
  }
  return false;
}

function shown(el) {
  for (let e = el; e; e = e.parentElement) {
    const cs = getComputedStyle(e);
    if (cs.visibility === 'hidden' || Number(cs.opacity) < 0.1) return false;
  }
  return true;
}

const px = (n) => Math.round(n) + ' px';

// E2: content past the right edge of the viewport or stage; the page scrolls sideways, or (clipped root, stage) it is cut off.
function overflow(st, out, where) {
  const de = document.documentElement, scope = st || document.body, b = clipBox(st);
  const width = b.right - b.left, esc = [], parked = [];
  for (const el of elements(scope).list) {
    if (esc.length >= 3) break;
    if (el.closest(NOT_TEXT) || esc.some((e) => e.el.contains(el)) || parked.some((x) => x.contains(el))) continue;
    const r = el.getBoundingClientRect();
    if (r.width < 1 || r.height < 1 || (r.right <= b.right + 1 && r.width <= width + 1)) continue;
    // wholly past the right edge: an off-canvas drawer or slide, parked there on purpose
    if (r.left >= b.right) { parked.push(el); continue; }
    if (held(el, st) || getComputedStyle(el).visibility === 'hidden') continue;
    const words = squash(el.textContent);
    esc.push({ el, right: r.right, text: words || '<' + el.localName + '>', content: !!words || el.matches(MEDIA) || !!el.querySelector(MEDIA) });
  }
  for (const t of texts(scope)) {
    if (esc.length >= 4) break;
    const p = t.parentElement;
    if (esc.some((e) => e.el.contains(p)) || parked.some((x) => x.contains(p)) || getComputedStyle(p).overflowX !== 'visible' || held(p, st)) continue;
    const rs = lineRects(t), right = Math.max(-Infinity, ...rs.map((q) => q.right));
    if (right > b.right + 1 && Math.min(...rs.map((q) => q.left)) < b.right) esc.push({ el: p, right, text: squash(t.data), content: true });
  }
  const clipsX = (el) => /hidden|clip/.test(getComputedStyle(el).overflowX);
  const scrolls = !st && !clipsX(de) && !(document.body && clipsX(document.body));
  const over = Math.round(st ? st.scrollWidth - st.clientWidth : de.scrollWidth - de.clientWidth);
  const what = st ? (st.matches('.deck') ? 'slide' : 'artboard') : 'viewport';
  if (scrolls && over > 1) {
    if (!esc.length) out.push({ check: 'E2.overflow', selector: null, text: `content runs ${over} px past the viewport`, detail: `the page scrolls sideways at ${px(width)}${where}` });
    for (const e of esc) {
      out.push({ check: 'E2.overflow', selector: selectorOf(e.el), text: cut(e.text, 80),
        detail: `ends at ${px(e.right - b.left)} in a ${px(width)} viewport; the page scrolls sideways by ${over} px${where}` });
    }
    return;
  }
  for (const e of esc) {
    if (e.content) out.push({ check: 'E2.wide', selector: selectorOf(e.el), text: cut(e.text, 80), detail: `ends at ${px(e.right - b.left)}, past the ${px(width)} ${what}: cut off${where}` });
  }
}

// E2: text a hidden/clip overflow cuts through; text wholly outside (a carousel's next slide, a collapsed panel) is meant to be hidden.
function clipped(st, out, where) {
  const scope = st || document.body, seen = new Set();
  for (const t of texts(scope)) {
    if (seen.size >= 5) break;
    const p = t.parentElement;
    let c = p, cs = null;
    for (; c; c = c.parentElement) {
      cs = getComputedStyle(c);
      if (cs.overflowX !== 'visible' || cs.overflowY !== 'visible') break;
    }
    if (!c || seen.has(c)) continue;
    // overflow() owns the horizontal edge of the viewport and of the stage
    const edgeOwner = c === st || c === document.body || c === document.documentElement;
    const cx = !edgeOwner && /hidden|clip/.test(cs.overflowX), cy = /hidden|clip/.test(cs.overflowY);
    if (!cx && !cy) continue;
    const b = clipBox(c);
    if (b.right - b.left < 3 || b.bottom - b.top < 3) continue;
    // vertically, the glyphs' 0.8 em band, not the font's content area: a line box shorter than that area clips nothing visible
    const fs = parseFloat(getComputedStyle(p).fontSize) || 16;
    let inside = false, past = 0, edge = '';
    for (const q of lineRects(t)) {
      const pad = Math.max(0, (q.height - 0.8 * fs) / 2), top = q.top + pad, bottom = q.bottom - pad;
      const ix = Math.min(q.right, b.right) - Math.max(q.left, b.left), iy = Math.min(bottom, b.bottom) - Math.max(top, b.top);
      if (ix > 0 && iy > 0) inside = true;
      for (const [on, d, e] of [[cx, q.right - b.right, 'right'], [cx, b.left - q.left, 'left'], [cy, bottom - b.bottom, 'bottom'], [cy, b.top - top, 'top']]) {
        if (on && d > past) { past = d; edge = e; }
      }
    }
    if (!inside || past <= 1) continue;
    let detail = `cut ${px(past)} past the ${edge} edge of ${selectorOf(c)} (overflow: ${cs.overflowX} ${cs.overflowY})${where}`;
    const tp = getComputedStyle(p), across = edge === 'left' || edge === 'right';
    // an ellipsis marks a horizontal cut; a line clamp's marks a vertical one
    if ((across && [cs.textOverflow, tp.textOverflow].includes('ellipsis')) || (!across && cs.getPropertyValue('-webkit-line-clamp') !== 'none')) {
      const full = p.closest('[title],[aria-label]');
      if (full && squash(full.getAttribute('title') || full.getAttribute('aria-label'))) continue;
      detail = `an ellipsis hides the rest and no title or aria-label holds the full text${where}`;
    }
    seen.add(c);
    out.push({ check: 'E2.clipped', selector: selectorOf(p), text: cut(squash(t.data), 80), detail });
  }
}

// Inside a fixed or sticky box: it moves with the viewport, so what it covers at scroll 0 scrolls clear.
function pinned(el) {
  for (let e = el; e && e !== document.documentElement; e = e.parentElement) {
    if (/^(fixed|sticky)$/.test(getComputedStyle(e).position)) return true;
  }
  return false;
}

// E2: two text blocks (neither inside the other) whose lines cover each other.
function overlap(st, out, where) {
  const scope = st || document.body, blocks = new Map();
  for (const t of texts(scope, 3000)) {
    // a range rect is the font's content area, up to 1.4 em tall: at line-height 1 neighbours touch while their glyphs do not, so compare a 0.8 em band
    const fs = parseFloat(getComputedStyle(t.parentElement).fontSize) || 16;
    const rs = lineRects(t).map((q) => {
      const pad = Math.max(0, (q.height - 0.8 * fs) / 2);
      return { left: q.left, right: q.right, top: q.top + pad, bottom: q.bottom - pad, width: q.width, height: q.height - 2 * pad };
    });
    if (!rs.length) continue;
    let b = t.parentElement;
    while (b && b !== scope && /^(inline|contents)/.test(getComputedStyle(b).display)) b = b.parentElement;
    if (!blocks.has(b)) blocks.set(b, []);
    blocks.get(b).push(...rs);
  }
  // sorted by top, so a block is compared only with those starting above its bottom
  const list = Array.from(blocks).filter(([el]) => shown(el) && !pinned(el)).map(([el, rs]) => [el, rs,
    Math.min(...rs.map((r) => r.top)), Math.max(...rs.map((r) => r.bottom))]).sort((x, y) => x[2] - y[2]);
  const vw = document.documentElement.clientWidth, vh = document.documentElement.clientHeight;
  let n = 0;
  for (let i = 0; i < list.length && n < 3; i++) {
    for (let j = i + 1; j < list.length && n < 3 && list[j][2] < list[i][3]; j++) {
      const [a, ra] = list[i], [b, rb] = list[j];
      if (a.contains(b) || b.contains(a)) continue;
      let hit = null;
      ra.some((p) => rb.some((q) => {
        const l = Math.max(p.left, q.left), t = Math.max(p.top, q.top), w = Math.min(p.right, q.right) - l, h = Math.min(p.bottom, q.bottom) - t;
        if (w >= 4 && h >= 4 && w * h >= 0.35 * Math.min(p.width * p.height, q.width * q.height)) hit = [l + w / 2, t + h / 2];
        return hit;
      }));
      // something else drawn on top there (a fixed bar, a dialog) covers both: not these two blocks overlapping
      if (hit && hit[0] >= 0 && hit[1] >= 0 && hit[0] < vw && hit[1] < vh) {
        const top = document.elementFromPoint(hit[0], hit[1]);
        if (top && !a.contains(top) && !b.contains(top)) hit = null;
      }
      if (hit) {
        n++;
        out.push({ check: 'E2.overlap', selector: selectorOf(b), text: cut(squash(b.textContent), 80),
          detail: `its text covers the text of ${selectorOf(a)} ("${cut(squash(a.textContent), 40)}")${where}` });
      }
    }
  }
}

// E3: axe-core's serious and critical violations; its off-by-default target-size rule (WCAG 2.5.8, spacing and inline exceptions included) is E2.target.
async function accessibility(ctx, out, seen, where) {
  const r = await window.axe.run(ctx, { resultTypes: ['violations'], rules: { 'target-size': { enabled: true } } });
  for (const v of r.violations) {
    const check = v.id === 'target-size' ? 'E2.target' : 'E3.' + v.id;
    if (check !== 'E2.target' && v.impact !== 'serious' && v.impact !== 'critical') continue;
    v.nodes.slice(0, 3).forEach((n, i) => {
      const sel = (n.target || []).map((x) => (Array.isArray(x) ? x.join(' ') : x)).join(' >>> ') || null;
      if (seen.has(check + '\u0000' + sel)) return;
      seen.add(check + '\u0000' + sel);
      const msg = [n.any, n.all, n.none].map((c) => c && c[0] && c[0].message).find(Boolean) || n.failureSummary || '';
      const of = v.nodes.length > 1 ? `element ${i + 1} of ${v.nodes.length}; ` : '';
      out.push({ check, selector: sel, text: v.help, detail: `${v.impact}; ${of}${squash(msg)}${where}` });
    });
  }
}

// E4: what a generated page should not still say.
function content(scope, out) {
  const seen = new Set(), counts = {}, generic = new Map();
  const add = (check, el, text, detail, key = text) => {
    if (seen.has(check + '\u0000' + key)) return;
    seen.add(check + '\u0000' + key);
    counts[check] = (counts[check] || 0) + 1;
    if (counts[check] <= 3) out.push({ check, selector: selectorOf(el), text: cut(text, 80), detail });
  };
  for (const t of texts(scope)) {
    const s = squash(t.data), p = t.parentElement;
    if (p.closest(CODE)) continue; // quoted code: a TODO in a diff is the diff's
    let m;
    if (LOREM.test(s)) add('E4.lorem', p, s, 'lorem ipsum filler');
    if ((m = TODO.exec(s))) add('E4.todo', p, s, `a ${m[1]} left in the page`);
    if ((m = FILLER.exec(s))) add('E4.placeholder', p, s, `placeholder wording: "${m[1]}"`);
    if ((m = GENERIC.exec(s))) generic.set(m[1].toLowerCase(), (generic.get(m[1].toLowerCase()) || []).concat([[p, s]]));
  }
  for (const hits of generic.values()) {
    if (hits.length >= 2) add('E4.generic', hits[0][0], hits[0][1], `${hits.length} numbered stand-in labels: ${hits.slice(0, 3).map((h) => h[1]).join(', ')}`);
  }
  for (const parent of [scope, ...elements(scope).list]) {
    if (parent.children.length < 3 || parent.closest(NOT_TEXT) || parent.closest(CODE)) continue;
    const same = new Map();
    for (const c of parent.children) {
      if (/^(td|th|option|br|hr|col|source|track|script|style|template)$/.test(c.localName)) continue;
      const s = squash(c.textContent);
      if (s.length >= 8 && /\p{L}/u.test(s)) same.set(c.localName + '\u0000' + s, (same.get(c.localName + '\u0000' + s) || 0) + 1);
    }
    for (const [key, n] of same) {
      const [tag, s] = key.split('\u0000');
      if (n >= 3) { add('E4.repeat', parent, s, `${n} sibling <${tag}> elements say the same`); break; }
    }
  }
  for (const el of scope.querySelectorAll('table,ul,ol,dl')) {
    if (el.closest(NOT_TEXT)) continue;
    const cells = el.localName === 'table' ? el.querySelectorAll('td') : el.children;
    if (Array.from(cells).some((c) => squash(c.textContent) || c.querySelector('img,svg,canvas,video,input,select,textarea,button'))) continue;
    add('E4.empty', el, el.localName === 'table' ? 'a table with no filled data cell' : `an empty <${el.localName}>`,
      el.localName === 'table' ? 'no <td> holds text, an image or a control' : 'no item holds text, an image or a control', selectorOf(el));
  }
}

// A deck shows one slide at a time: each slide in turn, every fragment shown, transitions off, then the deck as it was.
async function eachSlide(st, fn, capped) {
  const every = st.querySelectorAll(':scope > .slide'), slides = Array.from(every).slice(0, 60);
  if (every.length > 60) capped.push(`slides 61-${every.length} not checked: a check covers the first 60`);
  const was = slides.map((s) => s.classList.contains('current'));
  const frags = Array.from(st.querySelectorAll('.fragment')).map((f) => [f, f.classList.contains('shown')]);
  const still = document.createElement('style');
  still.setAttribute('data-design-kit-check', '');
  still.textContent = '*,*::before,*::after{transition:none!important}';
  (document.head || document.documentElement).appendChild(still);
  frags.forEach(([f]) => f.classList.add('shown'));
  try {
    for (let i = 0; i < slides.length; i++) {
      slides.forEach((s, j) => s.classList.toggle('current', j === i));
      await fn(slides[i], ` (slide ${i + 1})`);
    }
  } finally {
    slides.forEach((s, j) => s.classList.toggle('current', was[j]));
    frags.forEach(([f, on]) => f.classList.toggle('shown', on));
    still.remove();
  }
}

async function settle() {
  if (document.readyState !== 'complete') await new Promise((r) => addEventListener('load', r, { once: true }));
  if (document.fonts) await Promise.race([document.fonts.ready, new Promise((r) => setTimeout(r, 3000))]);
  await Promise.race([new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))), new Promise((r) => setTimeout(r, 200))]);
}

async function main() {
  await settle();
  const k = kind(), st = stageOf(k), scope = st || document.body || document.documentElement;
  const out = [], skipped = [], capped = [];
  const total = scope.getElementsByTagName('*').length;
  if (total > WALK) capped.push(`the first ${WALK} of ${total} elements measured`);
  const step = async (name, fn) => {
    try { await fn(); } catch (e) { skipped.push(name + ': ' + cut(e && e.message, 120)); }
  };
  const seen = new Set();
  await step('E1', () => blank(scope, out));
  if (innerWidth < 600 && !document.querySelector('meta[name="viewport"]')) {
    out.push({ check: 'E2.viewport', selector: null, text: 'no <meta name="viewport">',
      detail: `a phone lays the page out 980 px wide and shrinks it; this check measured it at ${innerWidth} px` });
  }
  const axeOk = !!(window.axe && typeof window.axe.run === 'function'); // render-check.py evaluates axe-core in this world first
  if (!axeOk) skipped.push('E3 and E2.target: axe-core did not load');
  const layout = async (where, ctx) => {
    await step('E2 overflow', () => overflow(st, out, where));
    await step('E2 clipped', () => clipped(st, out, where));
    await step('E2 overlap', () => overlap(st, out, where));
    if (axeOk) await step('E3', () => accessibility(ctx, out, seen, where));
  };
  if (k === 'deck' && st) {
    if (axeOk) await step('E3', () => accessibility(document, out, seen, ''));
    await eachSlide(st, (slide, where) => layout(where, slide), capped);
  } else {
    await layout('', document);
  }
  await step('E4', () => content(scope, out));
  if (textCut) capped.push(`text checks stopped at the first ${textCut} text nodes`);
  const findings = out.slice(0, KEEP).map((f) => ({ check: String(f.check), selector: f.selector ? cut(f.selector, 300) : null,
    text: cut(f.text, 120), detail: cut(f.detail, 240) }));
  return { kind: k, width: innerWidth, height: innerHeight, findings, dropped: out.length - findings.length,
    skipped: skipped.slice(0, 10).map((x) => cut(x, 200)), capped: capped.map((x) => cut(x, 200)) };
}

return main().catch((e) => ({ error: cut(e && e.message, 200) }));
})();
