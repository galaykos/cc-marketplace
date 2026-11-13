// Render check for scripts/preview-check.sh, which registers it in an isolated world of every page it loads (page script can neither see nor replace it), evaluates axe-core there after load, calls __vdRun() and reads the findings back over DevTools.
// Catches: E1 a blank page, failed loads (console and uncaught errors come from the browser, in preview-check.sh); E2 sideways scroll, too-wide boxes, clipped or overlapping text, targets under 24 px; E3 serious or critical axe-core (WCAG A/AA) violations; E4 stand-in text, identical rows, empty tables and lists; E5 identical variants or variants differing on several axes (advisory).
// Misses: what each check misses is listed in its derivation; nothing here judges whether a design is good; page script still runs and can change what is measured; past 4000 elements, the rest.
// Why, limits, history: rationale/derivations/plugin-taskmaster.md § plugins/taskmaster/scripts/preview-check.sh
(() => {
  'use strict';
  const CAP = 10; // findings per check and text, so one defect class cannot crowd the record
  const WALK = 4000; // elements a check walks, so a huge page stays inside the time bound
  const OWN = /^\/(_checks|_versions\.json|_feedback|favicon\.ico)$/; // the shell's own requests, and the browser's favicon probe
  const failed = new Map(); // absolute URL -> { el, what, status }
  let textCut = false; // E4 stopped before the last text node
  const cut = (s, n) => Array.from(String(s).slice(0, 2 * n)).slice(0, n).join('');
  const first = root => Array.prototype.slice.call(root.getElementsByTagName('*'), 0, WALK);

  // A load error is a DOM event, so this world sees it; a script error or a console call is the page world's (preview-check.sh reads those from the browser).
  addEventListener('error', e => {
    const t = e.target;
    if (t instanceof Element) {
      const raw = t.currentSrc || t.src || t.href;
      const url = raw && typeof raw === 'object' ? raw.baseVal : raw;
      if (url) failed.set(String(url), { el: t, what: t.localName });
    }
  }, true);

  const findings = [];
  const counts = new Map();
  function add(check, el, text, detail) {
    const key = check + '|' + text;
    counts.set(key, (counts.get(key) || 0) + 1);
    if (counts.get(key) > CAP) return;
    findings.push({ check, selector: typeof el === 'string' ? cut(el, 300) : el ? selectorOf(el) : null, text, detail: cut(detail, 300) });
  }

  function selectorOf(el) {
    const parts = [];
    for (let n = el; n && n.nodeType === 1 && n !== document.documentElement; n = n.parentElement) {
      if (n.id && document.querySelectorAll('#' + CSS.escape(n.id)).length === 1) { parts.unshift('#' + CSS.escape(n.id)); break; }
      let s = n.localName;
      const cls = Array.from(n.classList)[0];
      if (cls) s += '.' + CSS.escape(cls);
      const p = n.parentElement;
      if (p && n !== document.body) {
        const same = Array.from(p.children).filter(c => c.localName === n.localName);
        if (same.length > 1) s += ':nth-of-type(' + (same.indexOf(n) + 1) + ')';
      }
      parts.unshift(s);
      if (n === document.body) break;
    }
    return cut(parts.join(' > '), 300);
  }
  const textOf = el => (el.innerText || el.textContent || '').replace(/\s+/g, ' ').trim();
  function label(el) { const t = textOf(el); return el.localName + (t ? ' "' + cut(t, 40) + '"' : ''); }
  const letterOf = el => { const f = el.closest('.vd-frame'); return f && /^vd-([a-c])$/.test(f.id) ? f.id.slice(3).toUpperCase() : '?'; };
  const shown = el => (el.checkVisibility ? el.checkVisibility({ visibilityProperty: true }) : el.getClientRects().length > 0);
  const style = el => getComputedStyle(el);
  const clips = cs => cs.overflowX !== 'visible' || cs.overflowY !== 'visible';

  function checkLoad() {
    const b = document.body;
    const r = b && b.getBoundingClientRect();
    if (!r || r.width < 1 || r.height < 1 || !(textOf(b) || b.querySelector('img, svg, canvas, video, picture, iframe, object, embed'))) {
      add('E1', null, 'blank page', 'the body renders no text and no media');
    }
    for (const e of performance.getEntriesByType('resource')) {
      let u;
      try { u = new URL(e.name); } catch { continue; }
      const status = e.responseStatus || 0;
      if (status >= 400) {
        if (!failed.has(e.name)) failed.set(e.name, { el: null, what: e.initiatorType });
        failed.get(e.name).status = status;
      } else if (!status && u.origin === location.origin && !e.decodedBodySize && !e.transferSize
                 && !['fetch', 'xmlhttprequest', 'beacon'].includes(e.initiatorType) && !failed.has(e.name)) {
        failed.set(e.name, { el: null, what: e.initiatorType });
      }
    }
    failed.forEach((f, url) => {
      let u = null;
      try { u = new URL(url, location.href); } catch { /* reported as written */ }
      if (u && u.origin === location.origin && OWN.test(u.pathname)) return;
      const local = u && u.origin === location.origin;
      add('E1', f.el, 'resource failed to load', f.what + ' ' + (local ? u.pathname + u.search : url)
        + (f.status ? ' answered ' + f.status : local ? ' got no response' : ' (another host; preview-check.sh lets the page reach 127.0.0.1 only)'));
    });
  }

  let visible = null; // Set of rendered elements under body
  const insideCache = new Map();
  // True when an ancestor below `box` scrolls or clips its overflow, so el cannot widen box.
  function contained(el, box) {
    const p = el.parentElement;
    if (!p || p === box) return false;
    if (!insideCache.has(p)) insideCache.set(p, null);
    let v = insideCache.get(p);
    if (v === null) { v = style(p).overflowX !== 'visible' || contained(p, box); insideCache.set(p, v); }
    return v;
  }
  const range = document.createRange();
  // The outermost box reaching past the edge; else the element whose own text runs past it (an unbroken string).
  function culprit(box, left, right) {
    insideCache.clear();
    const scope = box === document.documentElement ? document.body : box;
    const hits = new Set();
    const spills = n => {
      if (n.nodeType !== 3 || !n.data.trim()) return false;
      range.selectNodeContents(n);
      return Array.from(range.getClientRects()).some(q => q.right > right + 1 || q.left < left - 1);
    };
    let spill = null;
    for (const el of first(scope)) {
      if (!visible.has(el) || contained(el, box)) continue;
      const r = el.getBoundingClientRect();
      if (r.right > right + 1 || r.left < left - 1) hits.add(el);
      else if (!spill && Array.from(el.childNodes).some(spills)) spill = el;
    }
    for (const h of hits) if (!hits.has(h.parentElement)) return h;
    return spill;
  }
  const clipCache = new Map();
  function clipBox(el) {
    if (!clipCache.has(el)) {
      let v = null;
      if (clips(style(el))) {
        const r = el.getBoundingClientRect();
        v = { l: r.left + el.clientLeft, t: r.top + el.clientTop };
        v.r = v.l + el.clientWidth;
        v.b = v.t + el.clientHeight;
      }
      clipCache.set(el, v);
    }
    return clipCache.get(el);
  }
  const meet = (a, b) => ({ l: Math.max(a.l, b.l), t: Math.max(a.t, b.t), r: Math.min(a.r, b.r), b: Math.min(a.b, b.b) });
  // [rect, text node] for the rendered text under el, each rect cut to every clipping box between it and el (el's own too when self).
  function textRects(el, self) {
    const out = [];
    const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
    for (let n = walker.nextNode(); n; n = walker.nextNode()) {
      if (!n.data.trim() || !visible.has(n.parentElement)) continue;
      range.selectNodeContents(n);
      for (const q of range.getClientRects()) {
        let r = { l: q.left, t: q.top, r: q.right, b: q.bottom };
        for (let a = n.parentElement; a; a = a.parentElement) {
          if (a === el && !self) break;
          const c = clipBox(a);
          if (c) r = meet(r, c);
          if (a === el) break;
        }
        if (r.r - r.l > 0.5 && r.b - r.t > 0.5) out.push([r, n, q]);
      }
    }
    return out;
  }
  function flow(el) {
    const cs = style(el);
    return /^(static|relative|sticky)$/.test(cs.position) && cs.float === 'none' && !/^(inline|contents|none)/.test(cs.display);
  }
  const TARGETS = 'a[href], button, input:not([type="hidden"]), select, textarea, summary, [role="button"], [role="link"], '
    + '[role="checkbox"], [role="switch"], [role="tab"], [role="radio"], [role="menuitem"], [role="option"]';

  function checkLayout() {
    scrollTo(0, 0);
    const root = document.documentElement;
    const vw = root.clientWidth;
    const culprits = [];

    // Sideways scroll: the page, and each shell variant box (it scrolls on purpose only downwards).
    const boxes = [[root, 0, vw, 'page scrolls sideways', 'the page']];
    document.querySelectorAll('.vd-frame > .vd-content').forEach(c => {
      if (!visible.has(c)) return;
      const r = c.getBoundingClientRect();
      boxes.push([c, r.left + c.clientLeft, r.left + c.clientLeft + c.clientWidth, 'variant scrolls sideways', 'variant ' + letterOf(c)]);
    });
    for (const [box, left, right, text, name] of boxes) {
      const width = box.scrollWidth;
      const room = box === root ? vw : box.clientWidth;
      if (width <= room + 1) continue;
      const c = culprit(box, left, right);
      if (c) culprits.push(c);
      add('E2', c || (box === root ? null : box), text, name + ' is ' + width + 'px wide in ' + room + 'px' + (c ? '; first element past the edge: ' + label(c) : ''));
    }

    // Wider than the viewport and cut off rather than scrolled: the outermost such box only.
    insideCache.clear();
    for (const el of visible) {
      const r = el.getBoundingClientRect();
      if (r.width <= vw + 1) continue;
      const p = el.parentElement;
      if (p && p !== document.body && visible.has(p) && p.getBoundingClientRect().width > vw + 1) continue;
      let scrolls = false;
      for (let a = p; a && a !== document.body; a = a.parentElement) if (/auto|scroll/.test(style(a).overflowX)) { scrolls = true; break; }
      if (scrolls || culprits.some(c => el.contains(c) || c.contains(el))) continue;
      add('E2', el, 'wider than the viewport', label(el) + ' is ' + Math.round(r.width) + 'px wide in a ' + vw + 'px viewport');
    }

    // Text clipped by overflow hidden or clip; an ellipsis whose full text sits in a title or aria-label is intended.
    for (const el of visible) {
      const cs = style(el);
      const cx = /hidden|clip/.test(cs.overflowX), cy = /hidden|clip/.test(cs.overflowY);
      if ((!cx && !cy) || el.clientWidth <= 1 || el.clientHeight <= 1) continue;
      if (!(cx && el.scrollWidth > el.clientWidth + 1) && !(cy && el.scrollHeight > el.clientHeight + 2)) continue;
      const told = el.closest('[title]') || el.getAttribute('aria-label');
      if (told && (cs.textOverflow === 'ellipsis' || cs.webkitLineClamp !== 'none')) continue;
      const box = clipBox(el);
      const hit = textRects(el, false).find(([r]) => (cx && (r.r > box.r + 1 || r.l < box.l - 1)) || (cy && (r.b > box.b + 2 || r.t < box.t - 2)));
      if (hit) add('E2', el, 'text clipped', label(el) + ' cuts off "' + cut(hit[1].data.replace(/\s+/g, ' ').trim(), 60) + '"');
    }

    // Overlapping text between in-flow block siblings (the next two of each), by 0.8 em glyph bands: a range rect is the font's taller content area.
    const rectsOf = new Map();
    const textBox = el => {
      if (!rectsOf.has(el)) {
        const rs = textRects(el, true).map(([r, n, q]) => {
          const pad = Math.max(0, (q.height - 0.8 * (parseFloat(style(n.parentElement).fontSize) || 16)) / 2);
          return { l: r.l, r: r.r, t: Math.max(r.t, q.top + pad), b: Math.min(r.b, q.bottom - pad) };
        }).filter(r => r.b > r.t);
        const all = rs.reduce((a, r) => (a ? { l: Math.min(a.l, r.l), t: Math.min(a.t, r.t), r: Math.max(a.r, r.r), b: Math.max(a.b, r.b) } : r), null);
        rectsOf.set(el, { rs, all });
      }
      return rectsOf.get(el);
    };
    const area = r => (r.r - r.l) * (r.b - r.t);
    const meets = (a, b) => { const m = meet(a, b); return m.r - m.l > 0 && m.b - m.t > 0; };
    const over = (a, b) => {
      const m = meet(a, b), w = m.r - m.l, h = m.b - m.t;
      return w >= 4 && h >= 4 && w * h >= 0.35 * Math.min(area(a), area(b)) ? m : null;
    };
    for (const parent of [document.body, ...visible]) {
      const kids = Array.from(parent.children).filter(k => visible.has(k) && flow(k));
      for (let i = 0; i < kids.length; i++) {
        for (let j = i + 1; j < Math.min(kids.length, i + 3); j++) {
          const a = textBox(kids[i]), b = textBox(kids[j]);
          if (!a.all || !b.all || !meets(a.all, b.all)) continue;
          let m = null;
          for (const ra of a.rs) { for (const rb of b.rs) { m = over(ra, rb); if (m) break; } if (m) break; }
          if (m) add('E2', kids[j], 'text overlaps', label(kids[i]) + ' and ' + label(kids[j]) + ' overlap by ' + Math.round(m.r - m.l) + 'x' + Math.round(m.b - m.t) + 'px');
        }
      }
    }

    // Targets under 24 x 24 CSS px, with WCAG 2.5.8's inline, native-control and spacing exceptions.
    const targets = Array.from(document.querySelectorAll(TARGETS)).filter(t => visible.has(t) && !t.disabled
      && (t.tabIndex >= 0 || !t.hasAttribute('role')) && !t.closest('[inert]'));
    const rects = targets.map(t => t.getBoundingClientRect());
    const small = r => r.width < 23.5 || r.height < 23.5;
    targets.forEach((t, i) => {
      const r = rects[i];
      if (!small(r)) return;
      const cs = style(t);
      if (cs.display === 'inline' && t.parentElement && textOf(t.parentElement).length > textOf(t).length) return;
      if (/^(checkbox|radio)$/.test(t.type) && cs.appearance !== 'none') return;
      const x = (r.left + r.right) / 2, y = (r.top + r.bottom) / 2;
      const crowded = targets.some((o, j) => {
        if (j === i || o.contains(t) || t.contains(o)) return false;
        const q = rects[j];
        if (small(q) && Math.hypot(x - (q.left + q.right) / 2, y - (q.top + q.bottom) / 2) < 24) return true;
        const dx = Math.max(q.left - x, 0, x - q.right), dy = Math.max(q.top - y, 0, y - q.bottom);
        return dx * dx + dy * dy < 144;
      });
      if (crowded) add('E2', t, 'target smaller than 24 px', label(t) + ' is ' + Math.round(r.width) + 'x' + Math.round(r.height) + 'px with another target within 12px of its centre');
    });
  }

  async function checkAxe() {
    // preview-check.sh evaluates axe-core in this world before __vdRun()
    if (!window.axe || typeof window.axe.run !== 'function') throw new Error('axe-core did not load');
    const axe = window.axe;
    const res = await axe.run(document, {
      runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'] },
      rules: { 'target-size': { enabled: false } }, // E2 measures target size
      resultTypes: ['violations'],
    });
    res.violations.filter(v => v.impact === 'serious' || v.impact === 'critical').forEach(v => {
      const target = v.nodes[0] && v.nodes[0].target && v.nodes[0].target[0];
      add('E3', typeof target === 'string' ? target : null, v.id,
        v.impact + ': ' + v.help + ' (' + v.nodes.length + ' element' + (v.nodes.length === 1 ? '' : 's') + ')');
    });
  }

  const STAND_INS = [
    [/\blorem ipsum\b|\bdolor sit amet\b|\bconsectetur adipiscing\b/i, 'lorem ipsum'],
    [/\bplaceholder\b/i, 'placeholder text'],
    [/\b(TODO|TBD|FIXME)\b/, 'TODO marker'],
    [/\b(your|some) (text|title|name|content|copy|description|heading|headline|message|logo|image|tagline|label) (goes )?here\b|\b(text|content|copy|title) goes here\b/i, 'template text'],
    [/^(item|row|card|entry|option|product|user|name|title|label|heading|text|link|tab|section|column|field|value|sample|example|test)\s*#?\s*(\d+|[nx])$/i, 'numbered stand-in'],
  ];
  function checkStandIns() {
    const hits = new Map();
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
      acceptNode: n => (/^(SCRIPT|STYLE|NOSCRIPT|TEMPLATE|TEXTAREA)$/.test(n.parentElement.tagName) ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT),
    });
    for (let n = walker.nextNode(), k = 0; n; n = walker.nextNode(), k++) {
      if (k >= WALK) { textCut = true; break; }
      const t = n.data.replace(/\s+/g, ' ').trim();
      if (!t) continue;
      for (const [re, name] of STAND_INS) if (re.test(t)) { if (!hits.has(name)) hits.set(name, []); hits.get(name).push([n.parentElement, t]); }
    }
    hits.forEach((list, name) => add('E4', list[0][0], name, '"' + cut(list[0][1], 60) + '"' + (list.length > 1 ? ' and ' + (list.length - 1) + ' more' : '')));

    for (const parent of [document.body, ...first(document.body)]) {
      if (parent.childElementCount < 3 || parent.closest('[data-state="loading"]')) continue;
      const groups = new Map();
      for (const k of parent.children) {
        if (!/^(TR|LI|ARTICLE)$/.test(k.tagName) && k.childElementCount < 2) continue;
        const t = (k.textContent || '').replace(/\s+/g, ' ').trim();
        if (t.length < 2) continue;
        if (!groups.has(t)) groups.set(t, []);
        groups.get(t).push(k);
      }
      groups.forEach((g, t) => { if (g.length >= 3) add('E4', g[0], 'identical rows', g.length + ' ' + g[0].localName + ' siblings read "' + cut(t, 60) + '"'); });
    }

    const filled = el => (el.textContent || '').trim() || el.querySelector('img, svg, input, button, select, a');
    document.body.querySelectorAll('table, ul, ol').forEach(el => {
      if (el.closest('[data-state="empty"]') || !(visible.has(el) || el.closest('[data-state]'))) return;
      const table = el.tagName === 'TABLE';
      const empty = table ? !Array.from(el.querySelectorAll('td')).some(filled) : !Array.from(el.children).some(li => li.tagName === 'LI' && filled(li));
      if (empty) add('E4', el, table ? 'empty table' : 'empty list', label(el) + ' has no filled ' + (table ? 'cell' : 'item') + ' and is not inside a data-state="empty" block');
    });
  }

  const IDREF = /^(id|class|for|headers|aria-(describedby|labelledby|controls|owns|activedescendant))$/;
  const tagOf = el => el.localName + Array.from(el.classList).sort().map(c => '.' + c).join('');
  function signature(content) {
    const raw = content.textContent || '';
    const pairs = new Set(), palette = new Set(), tree = [];
    [content, ...first(content)].forEach(el => {
      tree.push(tagOf(el) + Array.from(el.attributes).filter(a => !IDREF.test(a.name)).map(a => '[' + a.name + '=' + a.value + ']').sort().join(''));
      if (el !== content) pairs.add(tagOf(el.parentElement) + '>' + tagOf(el));
      const cs = style(el);
      palette.add('ink ' + cs.color);
      if (cs.backgroundColor !== 'rgba(0, 0, 0, 0)') palette.add('fill ' + cs.backgroundColor);
      if (cs.backgroundImage !== 'none') palette.add('image ' + cs.backgroundImage);
      if (parseFloat(cs.borderTopWidth) > 0) palette.add('line ' + cs.borderTopColor);
      palette.add('font ' + cs.fontFamily + ' ' + cs.fontSize + ' ' + cs.fontWeight);
    });
    return { text: raw.replace(/\s+/g, ' ').trim(), words: new Set(raw.toLowerCase().match(/[\p{L}\p{N}]{2,}/gu) || []), pairs, palette, tree: tree.join('|') };
  }
  const shared = (a, b) => { if (!a.size && !b.size) return 1; let n = 0; a.forEach(x => { if (b.has(x)) n++; }); return n / (a.size + b.size - n); };
  const pct = x => Math.round(x * 100) + '%';
  function checkVariants() {
    const contents = Array.from(document.querySelectorAll('.vd-frame > .vd-content'));
    const sig = contents.map(signature);
    for (let i = 0; i < sig.length; i++) {
      for (let j = i + 1; j < sig.length; j++) {
        const a = sig[i], b = sig[j];
        const names = 'variants ' + letterOf(contents[i]) + ' and ' + letterOf(contents[j]);
        const words = shared(a.words, b.words), pairs = shared(a.pairs, b.pairs), palette = shared(a.palette, b.palette);
        if (a.text === b.text && a.tree === b.tree && palette === 1) {
          add('E5', contents[j], 'variants identical', 'advisory: ' + names + ' have the same text, markup, colours and fonts; nothing separates them');
        } else if (words < 0.5 && pairs < 0.5 && palette < 0.5) {
          add('E5', contents[j], 'variants differ on several axes', 'advisory: ' + names + ' share ' + pct(words) + ' of words, ' + pct(pairs)
            + ' of parent>child tags and ' + pct(palette) + ' of colours and fonts; a pick between them cannot say which change won');
        }
      }
    }
  }

  async function run() {
    const total = document.body.getElementsByTagName('*').length;
    visible = new Set(first(document.body).filter(shown));
    for (const [id, fn] of [['E3', checkAxe], ['E1', checkLoad], ['E2', checkLayout], ['E4', checkStandIns], ['E5', checkVariants]]) {
      try { await fn(); } catch (err) { add(id, null, 'check failed to run', String((err && err.message) || err)); }
    }
    scrollTo(0, 0);
    findings.sort((a, b) => (a.check < b.check ? -1 : a.check > b.check ? 1 : 0));
    return { findings: findings.slice(), capped: Math.max(0, total - WALK, textCut ? 1 : 0) };
  }

  // A web font that never arrives must not hold the check: fonts get 3 s, as in design-kit.
  window.__vdRun = () => Promise.race([document.fonts ? document.fonts.ready : null, new Promise(r => setTimeout(r, 3000))])
    .then(() => new Promise(r => requestAnimationFrame(() => setTimeout(r, 0))))
    .then(run);
})();
