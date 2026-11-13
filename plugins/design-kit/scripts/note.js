// note.js — serve.py's /_note.js: the note widget every live page imports (Note button, or Alt+N outside a text field; click an element or "Note on this page"; posts /_note, lists /_notes), and with ?_outline=<selector> only an outline, for `dk notes --shot`.
// Acts on a loopback hostname only. Misses: elements inside iframes and closed shadow roots, canvas contents, errors logged before it loaded; a page's own script can still post a note.
// Why, limits, history: rationale/derivations/plugin-design-kit.md § plugins/design-kit/scripts/note.js
const LOOPBACK = ['127.0.0.1', 'localhost', '[::1]'];
const SKIP_DATA = /^data-(design-kit|original|bound)/;
const errors = [];

function outline(sel) {
  let el = null;
  try { el = document.querySelector(sel); } catch (e) { return; }
  if (!el) return;
  const box = document.createElement('div');
  box.setAttribute('data-design-kit-note', 'outline');
  document.documentElement.appendChild(box);
  // measured again whenever late images, fonts or scripts move the element before the headless shot
  const place = () => {
    el.scrollIntoView({ block: 'center', inline: 'center' });
    const r = el.getBoundingClientRect();
    box.style.cssText = 'position:fixed;box-sizing:border-box;pointer-events:none;z-index:2147483647;border:3px solid #d93025;'
      + 'border-radius:4px;box-shadow:0 0 0 4000px rgba(0,0,0,.2);'
      + `left:${r.left - 5}px;top:${r.top - 5}px;width:${r.width + 10}px;height:${r.height + 10}px`;
  };
  place();
  addEventListener('load', place);
  if (document.fonts) document.fonts.ready.then(place);
  if (typeof ResizeObserver === 'function') {
    const ro = new ResizeObserver(place);
    ro.observe(document.documentElement);
    ro.observe(el);
  }
}

// By code point: a cut through an emoji's surrogate pair posts a lone surrogate.
function cut(s, n) { return Array.from(String(s).slice(0, 2 * n)).slice(0, n).join(''); }

// An object is named by its tag, never walked or converted: a graph can be circular, and String() throws for Object.create(null).
function asText(x) {
  if (x instanceof Error) return String(x.message);
  return x !== null && (typeof x === 'object' || typeof x === 'function') ? Object.prototype.toString.call(x) : String(x);
}

function keep(msg) {
  errors.push(cut(msg, 300));
  if (errors.length > 5) errors.shift();
}

function selectorOf(el) {
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
  return parts.join(' > ');
}

function anchorOf(el) {
  const r = el.getBoundingClientRect();
  return {
    selector: selectorOf(el),
    tag: el.localName,
    text: cut(String(el.innerText ?? el.textContent ?? '').replace(/\s+/g, ' ').trim(), 200),
    rect: { x: Math.round(r.left + scrollX), y: Math.round(r.top + scrollY), w: Math.round(r.width), h: Math.round(r.height) },
  };
}

function theme() {
  const de = document.documentElement, body = document.body;
  for (const n of [de, body]) {
    const v = n && (n.getAttribute('data-scheme') || n.getAttribute('data-theme') || n.getAttribute('data-color-scheme'));
    if (v) return cut(v, 16);
  }
  for (const n of [de, body]) if (n && /\b(dark|light)\b/.test(String(n.className))) return /\bdark\b/.test(String(n.className)) ? 'dark' : 'light';
  for (const n of [body, de]) {
    const m = n && getComputedStyle(n).backgroundColor.match(/[\d.]+/g);
    if (m && (m.length < 4 || Number(m[3]) > 0)) return (0.2126 * m[0] + 0.7152 * m[1] + 0.0722 * m[2]) / 255 < 0.5 ? 'dark' : 'light';
  }
  const cs = getComputedStyle(de).colorScheme || '';
  if (/dark/.test(cs)) return /light/.test(cs) && !matchMedia('(prefers-color-scheme: dark)').matches ? 'light' : 'dark';
  return '';
}

const CSS_TEXT = `
:host{all:initial}
*{box-sizing:border-box}
.w{font:13px/1.4 system-ui,-apple-system,"Segoe UI",sans-serif;color:#1b1b1a}
button{font:inherit;color:#1b1b1a;cursor:pointer;border:1px solid #8c8a82;border-radius:6px;background:#fff;padding:4px 10px}
button:hover{background:#f1f0eb}
:focus-visible{outline:2px solid #1a56db;outline-offset:2px}
.tog{position:fixed;right:12px;bottom:40px;box-shadow:0 2px 8px rgba(0,0,0,.2)}
.tog[aria-expanded="true"]{background:#1b1b1a;color:#fff;border-color:#1b1b1a}
.hl{position:fixed;display:none;pointer-events:none;border:2px solid #1a56db;background:rgba(26,86,219,.08);border-radius:3px}
.card{position:fixed;width:300px;background:#fff;border:1px solid #c9c8c2;border-radius:10px;padding:10px 12px;box-shadow:0 8px 28px rgba(0,0,0,.2)}
.panel{right:12px;bottom:76px;max-height:min(60vh,420px);overflow:auto}
h2{font-size:13px;margin:0 0 4px}
p{margin:4px 0;color:#55534d}
ul{list-style:none;margin:8px 0 0;padding:0}
li{border-top:1px solid #e4e3de;padding:6px 0;overflow-wrap:anywhere}
.st{font-size:11px;font-weight:600;padding:0 6px;margin-right:4px;border-radius:999px;border:1px solid currentColor}
.st.open{color:#8a5a00}.st.addressed{color:#1f6b30}.st.dismissed{color:#55534d}
.reply{color:#1f6b30;margin-top:2px}
.on{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
label{display:block;font-weight:600}
textarea{display:block;width:100%;min-height:80px;margin-top:4px;font:inherit;font-weight:400;padding:6px;border:1px solid #8c8a82;border-radius:6px;resize:vertical;color:#1b1b1a;background:#fff}
.row{display:flex;gap:6px;justify-content:flex-end;margin-top:8px}
[hidden]{display:none!important}`;

const HTML = `<div class="w">
<button class="tog" type="button" aria-expanded="false" aria-controls="dkn-panel" aria-keyshortcuts="Alt+N" title="Notes on this page (Alt+N)">Notes</button>
<div class="hl" aria-hidden="true"></div>
<section class="card panel" id="dkn-panel" role="dialog" aria-label="Notes on this page" hidden>
<h2>Notes on this page</h2>
<p>Click an element, or Tab to one and press Enter, to leave a note on it. Esc closes.</p>
<p class="chk"></p>
<button type="button" data-act="page">Note on this page</button>
<ul aria-label="Notes left on this page"></ul>
<p role="status" aria-live="polite"></p>
</section>
<form class="card box" role="dialog" aria-label="Write a note" hidden>
<p class="on"></p>
<label>Note<textarea maxlength="2000" required></textarea></label>
<div class="row"><button type="button" data-act="cancel">Cancel</button><button type="submit">Send note</button></div>
</form>
</div>`;

function start() {
  // the capture is wrapped so the page's own console.error, error and rejection handling always run
  const logError = console.error;
  console.error = function (...args) {
    try { keep(args.map(asText).join(' ')); } catch (e) { /* not recorded */ }
    return logError.apply(this, args);
  };
  addEventListener('error', (e) => {
    try {
      const t = e.target;
      keep(t && t !== window && (t.src || t.href) ? 'failed to load ' + (t.src || t.href) : e.message || 'error');
    } catch (err) { /* not recorded */ }
  }, true);
  addEventListener('unhandledrejection', (e) => { try { keep('unhandled rejection: ' + asText(e.reason)); } catch (err) { /* not recorded */ } });

  const host = document.createElement('div');
  host.setAttribute('data-design-kit-note', '');
  host.style.cssText = 'all:initial;position:fixed;left:0;top:0;width:0;height:0;z-index:2147483647';
  const root = host.attachShadow({ mode: 'open' });
  const style = document.createElement('style');
  style.textContent = CSS_TEXT;
  root.append(style);
  root.appendChild(document.createRange().createContextualFragment(HTML));
  const $ = (s) => root.querySelector(s);
  const tog = $('.tog'), hl = $('.hl'), panel = $('.panel'), list = $('ul'), status = $('[role=status]');
  const box = $('.box'), on = $('.on'), ta = $('textarea'), chk = $('.chk');
  // a page's document-level key handlers (a deck's Space, a board's F/E/K) must not see typing in the widget
  for (const t of ['keydown', 'keyup', 'keypress']) host.addEventListener(t, (e) => e.stopPropagation());
  document.documentElement.appendChild(host);

  let picking = false, target = null, anchor = null;
  const mine = (e) => e.composedPath().includes(host);
  const isPage = (el) => !(el instanceof Element) || el === document.documentElement || el === document.body;
  const say = (msg) => { status.textContent = msg; };

  function show(el) {
    if (isPage(el)) { hl.style.display = 'none'; return; }
    target = el;
    const r = el.getBoundingClientRect();
    Object.assign(hl.style, { display: 'block', left: r.left + 'px', top: r.top + 'px', width: r.width + 'px', height: r.height + 'px' });
  }
  function place() {
    const W = innerWidth, H = innerHeight, bh = box.offsetHeight || 180;
    let x = Math.max(8, (W - 300) / 2), y = Math.max(8, H * 0.2);
    if (anchor) {
      const r = anchor.getBoundingClientRect();
      x = Math.min(Math.max(8, r.left), W - 308);
      y = r.bottom + 8 + bh <= H ? r.bottom + 8 : Math.max(8, r.top - bh - 8);
    }
    box.style.left = x + 'px'; box.style.top = y + 'px';
  }
  function openBox(el) {
    anchor = isPage(el) ? null : el;
    if (anchor) show(anchor); else hl.style.display = 'none';
    const words = anchor ? cut(String(anchor.innerText ?? anchor.textContent ?? '').replace(/\s+/g, ' ').trim(), 60) : '';
    on.textContent = anchor ? 'On <' + anchor.localName + '>' + (words ? ' "' + words + '"' : '') : 'On this page';
    box.hidden = false;
    place();
    ta.focus();
  }
  // Cancel and Escape discard the draft; toggling the widget off keeps it for the next box.
  function closeBox(keepDraft) { box.hidden = true; anchor = null; if (!keepDraft) ta.value = ''; }
  function setPicking(v) {
    picking = v;
    tog.setAttribute('aria-expanded', String(v));
    panel.hidden = !v;
    if (!v) { closeBox(true); hl.style.display = 'none'; target = null; } else refresh();
  }
  // the last `dk check` of this page, from /_checks (loopback only)
  async function checked() {
    try {
      const r = await fetch(location.origin + '/_checks?page=' + encodeURIComponent(location.pathname), { cache: 'no-store' });
      const c = r.ok ? await r.json() : null;
      if (!c) return;
      chk.textContent = !c.checked ? 'Not checked' : 'Checked ' + String(c.ts).replace('T', ' ').slice(0, 16) + ' UTC: '
        + c.findings + (c.findings === 1 ? ' finding' : ' findings') + (c.changed_since ? '; the page changed since' : '');
    } catch (e) { /* the line stays empty */ }
  }
  async function refresh() {
    checked();
    let rows;
    try {
      const r = await fetch(location.origin + '/_notes?page=' + encodeURIComponent(location.pathname), { cache: 'no-store' });
      if (!r.ok) return;
      rows = await r.json();
    } catch (e) { return; }
    tog.textContent = rows.length ? 'Notes (' + rows.length + ')' : 'Notes';
    const items = rows.slice(-20).reverse().map((row) => {
      const li = document.createElement('li');
      const st = document.createElement('span');
      st.className = 'st ' + row.status; st.textContent = row.status;
      const where = document.createElement('b');
      where.textContent = row.anchor && row.anchor.tag ? '<' + row.anchor.tag + '>' : 'Page';
      li.append(st, ' ', where, ' ', String(row.text));
      if (row.reply) {
        const rp = document.createElement('div');
        rp.className = 'reply'; rp.textContent = 'Reply: ' + row.reply;
        li.append(rp);
      }
      return li;
    });
    if (!items.length) { const li = document.createElement('li'); li.textContent = 'No notes on this page yet.'; items.push(li); }
    list.replaceChildren(...items);
  }

  tog.addEventListener('click', () => setPicking(!picking));
  $('[data-act=page]').addEventListener('click', () => openBox(null));
  $('[data-act=cancel]').addEventListener('click', () => { closeBox(); tog.focus(); });
  box.addEventListener('submit', async (e) => {
    e.preventDefault();
    const text = ta.value.trim();
    if (!text) { ta.focus(); return; }
    const body = { page: location.pathname, text, anchor: anchor ? anchorOf(anchor) : null,
      context: { viewport: { w: innerWidth, h: innerHeight }, theme: theme(), console: errors.slice() } };
    const enc = new TextEncoder();
    let json = JSON.stringify(body);
    while (enc.encode(json).length > 8000 && body.context.console.length) { body.context.console.shift(); json = JSON.stringify(body); }
    while (enc.encode(json).length > 8000) { body.text = cut(body.text, Math.floor(Array.from(body.text).length * 0.8)); json = JSON.stringify(body); }
    say('Sending…');
    try {
      const r = await fetch(location.origin + '/_note', { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Design-Kit-Note': '1' }, body: json });
      if (!r.ok) throw new Error('the server answered ' + r.status);
      ta.value = ''; closeBox(); tog.focus();
      say('Sent. The session reads it with dk notes.');
      refresh();
    } catch (err) { say('Not recorded: ' + asText(err)); }
  });

  // the event's real target, inside the shadow root too (at window level e.target is the host)
  const editable = (e) => {
    const t = e.composedPath()[0];
    return t instanceof Element && (t.isContentEditable || /^(input|textarea|select)$/.test(t.localName));
  };
  addEventListener('keydown', (e) => {
    // Alt+N in a field is typing (macOS Option+N is the dead key for ñ), never the widget's chord
    if (e.altKey && !e.ctrlKey && !e.metaKey && e.code === 'KeyN' && !editable(e)) {
      e.preventDefault(); e.stopPropagation(); setPicking(!picking); if (picking) tog.focus();
      return;
    }
    if (!picking) return;
    if (e.key === 'Escape') {
      e.preventDefault(); e.stopPropagation();
      if (!box.hidden) { closeBox(); tog.focus(); } else setPicking(false);
    } else if (e.key === 'Enter' && box.hidden && !mine(e) && !isPage(e.target)) {
      e.preventDefault(); e.stopPropagation(); openBox(e.target);
    }
  }, true);
  addEventListener('mousemove', (e) => { if (picking && box.hidden && !mine(e)) show(e.target); }, true);
  addEventListener('focusin', (e) => { if (picking && box.hidden && !mine(e)) show(e.target); }, true);
  addEventListener('scroll', () => { if (picking && target) show(target); if (!box.hidden && anchor) place(); }, true);
  // while picking, the page under the pointer neither navigates, picks, drags nor focuses
  for (const t of ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'dblclick', 'auxclick']) {
    addEventListener(t, (e) => { if (picking && !mine(e)) { e.preventDefault(); e.stopPropagation(); } }, true);
  }
  addEventListener('click', (e) => {
    if (!picking || mine(e)) return;
    e.preventDefault(); e.stopImmediatePropagation();
    openBox(e.target);
  }, true);
  refresh();
}

// last: start() reads the consts above, which a call before them would meet uninitialised
if (LOOPBACK.includes(location.hostname) && !window.__designKitNote) {
  window.__designKitNote = true;
  const want = new URLSearchParams(location.search).get('_outline');
  if (want !== null) outline(want); else start();
}
