// viewer.js — serve.py's /_viewer.js: the bar around a page's sandboxed frame. Asks /_page where the page is and frames it at the address's query and hash, seeded with what the page stored in this browser (its 0.19.3 board state moved in once); keeps the frame's hash, writes and print key, pings it, and says when it stops answering or left; frames it again, once its last messages are in, when the page's own /_events says so or a lost server is back; shows the last dk check, focuses the frame, forgets what deleted pages stored, and unregisters service workers.
// Misses: notes, picks, approvals and links; messages of a frame that takes over 300 ms to answer; two tabs of one page overwrite each other's keys; a frame that opened a blank page or a file of its own folder reads as one that does not answer; a page that never stops computing may block its own reload, which gets the same process; a page that floods it with store messages slows the viewer too; a page drawing a bar of its own inside the frame.
// Why, limits, history: rationale/derivations/plugin-design-kit.md § plugins/design-kit/scripts/viewer.js
(() => {
  const $ = (id) => document.getElementById(id);
  const { page, version } = document.body.dataset;
  const about = (route, of) => route + '?page=' + encodeURIComponent(of);
  const ask = (route, of = page) => fetch(about(route, of), { cache: 'no-store' });
  const make = (tag, text, more) => Object.assign(document.createElement(tag), { textContent: text }, more);
  const button = (label, act, more) => make('button', label, { type: 'button', onclick: () => act(), ...more });

  const GONE = { text: 'This page was deleted' };
  const HUNG = { text: 'This page is not answering', acts: [['Reload page', show]] };
  const FULL = { text: 'Storage is full; changes to this page are not saved' };
  // in the order they are shown
  const STRIPS = ['page', 'server', 'storage', 'pick', 'blocked', 'link'];
  /** Shows spec.text, and a button for each [label, act] of spec.acts, as the strip of this kind, or removes that strip when spec is null; the same words again are left alone, so they are announced once. */
  function strip(kind, spec) {
    const all = [...$('strips').children], old = all.find((s) => s.dataset.kind === kind);
    if (spec && old?.firstChild.textContent === spec.text) return;
    const held = old?.contains(document.activeElement);
    old?.remove();
    if (spec) {
      const el = make('div');
      el.dataset.kind = kind;
      el.append(make('p', spec.text), ...(spec.acts || []).map(([label, act]) => button(label, act)));
      $('strips').insertBefore(el, all.find((s) => STRIPS.indexOf(s.dataset.kind) > STRIPS.indexOf(kind)) || null);
    }
    if (held) frame?.focus();
  }

  let gone = false, hung = false;
  function say(now) {
    ({ gone, hung } = { gone, hung, ...now });
    strip('page', gone ? GONE : hung ? HUNG : null);
  }

  const CAP = 256 * 1024;
  // the page's entries in localStorage are prefix + key; costs has what each counts towards CAP, unsaved the keys refused since the frame was built
  let prefix = '', used = 0;
  const costs = new Map(), unsaved = new Set();
  // a name may hold the ":" that ends it in an entry
  const coded = (name) => name.replace(/[%:]/g, encodeURIComponent), decoded = (name) => name.replace(/%25|%3A/g, decodeURIComponent);
  const entries = (start) => Object.keys(localStorage).filter((name) => name.startsWith(start));
  function count(k, cost) {
    used += cost - (costs.get(k) || 0);
    if (cost) costs.set(k, cost); else costs.delete(k);
  }
  /** Writes one of the page's keys, or removes it when v is null; false when that is past CAP or the browser refuses. */
  function put(k, v) {
    const cost = v === null ? 0 : k.length + v.length;
    if (cost && used - (costs.get(k) || 0) + cost > CAP) return false;
    try {
      if (v === null) localStorage.removeItem(prefix + k); else localStorage.setItem(prefix + k, v);
    } catch (e) { return false; }
    count(k, cost);
    return true;
  }
  /** What the page stored, as a Map; 0.19.3's board state is moved in, under the key the page in the frame asks for, when there is none. */
  function stored(at) {
    const kept = new Map();
    prefix = `dk-store:${at.project}:${coded(page)}:`;
    costs.clear(); unsaved.clear(); used = 0;
    try {
      for (const name of entries(prefix)) {
        const k = name.slice(prefix.length), v = localStorage.getItem(name);
        kept.set(k, v); count(k, k.length + v.length);
      }
      const board = 'design-kit:/' + at.src.split('/').slice(3).join('/'), old = 'design-kit:' + new URL('/' + page, location).pathname;
      const v = kept.has(board) ? null : localStorage.getItem(old);
      if (v !== null && put(board, v)) { kept.set(board, v); localStorage.removeItem(old); }
    } catch (e) { /* this browser keeps no site data: the page starts empty */ }
    return kept;
  }
  const isItem = (i) => Array.isArray(i) && i.length === 2 && typeof i[0] === 'string' && i[0].length <= 256 && (i[1] === null || typeof i[1] === 'string');
  const isStore = (m) => (m.items === undefined ? m.clear === true : m.clear === undefined && Array.isArray(m.items) && m.items.length <= CAP && [...m.items].every(isItem));
  function keep({ items }) {
    for (const [k, v] of items || [...entries(prefix).map((name) => name.slice(prefix.length)), ...unsaved].map((k) => [k, null])) {
      if (put(k, v)) { unsaved.delete(k); continue; }
      if (unsaved.size < 1000) unsaved.add(k); // a page may name any number
      tell('storefull', { k });
    }
    strip('storage', unsaved.size ? FULL : null);
  }
  /** Forgets what this project's deleted pages stored. */
  async function prune(project) {
    const mine = `dk-store:${project}:`, left = new Set(entries(mine).map((name) => decoded(name.split(':')[2])));
    left.delete(page);
    const list = left.size && await fetch('/_index.json', { cache: 'no-store' }).then((r) => (r.ok ? r.json() : null)).catch(() => null);
    if (!list) return;
    for (const one of list) left.delete(one.path);
    for (const one of left) { // the list has only .html and .htm, and nothing of design-system/
      const r = await ask('/_page', one).catch(() => null);
      if (r?.status === 404) for (const name of entries(mine + coded(one) + ':')) localStorage.removeItem(name);
    }
  }

  // each field as it was typed: a page may read its query by its text
  const query = location.search.slice(1).split('&').filter((field) => !['static', 'key'].includes([...new URLSearchParams(field).keys()][0])).join('&');
  let frame;
  function build(at) {
    frame = document.createElement('iframe');
    frame.setAttribute('sandbox', 'allow-scripts allow-forms allow-modals allow-downloads');
    frame.setAttribute('allow', 'clipboard-write');
    frame.title = at.title;
    frame.name = JSON.stringify({ dk: 1, store: Object.fromEntries(stored(at)) });
    frame.src = at.src + (query && '?' + query) + location.hash;
    strip('storage', null);
    $('frame').replaceChildren(frame);
    watch();
  }
  function tell(t, data) { frame.contentWindow.postMessage({ dk: 1, t, ...data }, '*'); } // a null origin takes no other target

  let pings = 0, next = 0, patience = 0, answered = () => {};
  function ping() {
    clearTimeout(next);
    tell('ping', { n: ++pings });
    if (!document.hidden) next = setTimeout(ping, 2000);
  }
  function expect() {
    clearTimeout(patience);
    if (!document.hidden) patience = setTimeout(() => say({ hung: true }), 8000);
  }
  /** Pings the frame every 2 s and gives each answer 8 s, for as long as there is a frame and the viewer is visible. */
  function watch() {
    clearTimeout(next); clearTimeout(patience);
    if (frame) { expect(); ping(); }
  }
  document.addEventListener('visibilitychange', watch);
  /** Done when the frame has answered a ping, after the messages it still held, or after 300 ms. */
  const emptied = () => new Promise((done) => {
    ping();
    const n = pings;
    answered = (m) => { if (m.n >= n) done(); };
    setTimeout(done, 300);
  });

  document.addEventListener('securitypolicyviolation', (e) => {
    if (!frame || e.effectiveDirective !== 'frame-src') return;
    const left = frame, text = make('p', 'Page stopped: it tried to open another site.', { tabIndex: -1 }), acts = make('div'), area = make('div');
    frame = null;
    watch(); say({ hung: false });
    const held = [left, document.body].includes(document.activeElement);
    if (!held) area.setAttribute('role', 'alert');
    acts.append(button('Reload page', show, { className: 'primary' }), make('a', 'Back to gallery', { href: '/_gallery' }));
    area.className = 'stopped';
    area.append(text, acts);
    $('frame').replaceChildren(area);
    if (held) text.focus();
  });

  const isHash = (h) => typeof h === 'string' && /^#[\w/=&.%-]{0,128}$/.test(h);
  // message type -> [whether its fields have their shape, what it does]
  const HANDLERS = new Map([
    ['ready', [(m) => isHash(m.hash), () => { if (document.activeElement === document.body) frame.focus(); }]],
    ['hash', [(m) => isHash(m.hash), (m) => history.replaceState(null, '', m.hash)]],
    ['pong', [(m) => Number.isInteger(m.n) && m.n > 0 && m.n <= pings, (m) => { expect(); say({ hung: false }); answered(m); }]],
    ['store', [isStore, keep]],
    ['key', [(m) => ['notes', 'escape', 'print'].includes(m.name), (m) => { if (m.name === 'print') tell('print'); }]],
  ]);
  const acted = []; // when, the last 50
  function spare() {
    const now = performance.now();
    if (acted.length === 50 && now - acted[0] < 1000) return false;
    if (acted.push(now) > 50) acted.shift();
    return true;
  }
  addEventListener('message', (e) => {
    const m = e.data;
    if (!frame || e.source !== frame.contentWindow || !m || m.dk !== 1) return;
    const [fits, act] = HANDLERS.get(m.t) || [];
    if (fits?.(m) && (m.t === 'store' || spare())) act(m);
  });
  addEventListener('keydown', (e) => {
    if (!frame || !(e.ctrlKey || e.metaKey) || e.altKey || e.shiftKey || !/^p$/i.test(e.key)) return;
    e.preventDefault();
    tell('print');
  });
  addEventListener('hashchange', () => show()); // typed into the address: the frame's own hash comes by replaceState, which tells no one

  async function check() {
    const c = await ask('/_checks').then((r) => (r.ok ? r.json() : null)).catch(() => null);
    if (!c) return;
    $('chip').textContent = !c.checked ? 'Not checked' : `Checked, ${c.findings} ${c.findings === 1 ? 'problem' : 'problems'}${c.changed_since ? '; page changed since' : ''}`;
    $('chip').className = !c.checked || c.changed_since ? '' : c.findings ? 'warn' : 'ok';
  }

  const drafted = () => [...document.querySelectorAll('textarea')].some((t) => t.value.trim());

  let turn = 0, pruned = false;
  async function show() {
    const mine = ++turn;
    const r = await ask('/_page').catch(() => null);
    const at = r?.ok && await r.json().catch(() => null);
    if (mine !== turn) return;
    if (!at && r?.status !== 404) return lose();
    wait = 0;
    strip('server', null);
    if (!at) return say({ gone: true });
    say({ gone: false });
    if (frame) await emptied();
    if (mine !== turn) return;
    if (String(at.version) !== version && !drafted()) return location.reload();
    document.title = $('title').textContent = at.title;
    build(at);
    if (at.writable) check();
    if (!pruned) prune(at.project);
    pruned = true;
  }

  let events, wait = 0, retry = 0;
  function connect() {
    retry = 0;
    events = new EventSource(about('/_events', page));
    events.onopen = () => { if (wait) show(); };
    events.onmessage = show; // reload or gone: /_page says which
    events.onerror = lose;
  }
  async function lose() {
    events.close();
    if (retry) return;
    const mine = ++turn; // an answer still on its way is from before
    wait = Math.min(wait * 2 || 1000, 30000);
    retry = setTimeout(connect, wait);
    const r = await ask('/_page').catch(() => null);
    if (mine !== turn) return;
    const deleted = r?.status === 404; // a deleted page has no stream
    strip('server', deleted ? null : { text: 'Preview server stopped; retrying' });
    if (deleted) say({ gone: true });
  }

  navigator.serviceWorker?.getRegistrations().then((all) => all.forEach((one) => one.unregister()));
  connect();
  show();
})();
