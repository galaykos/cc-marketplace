// viewer.js — serve.py's /_viewer.js: the bar around a page's sandboxed frame. Asks /_page where the page is and frames it at the address's query and hash, seeded with what the page stored in this browser (its 0.19.3 board state moved in once); keeps the frame's hash, writes and print key, pings it, and says when it stops answering or left; frames it again, once its last messages are in, when the page's own /_events says so or a lost server is back; shows a board's reported pick in a strip, clamped as picks.py clamps it, until this tab sends or discards it, one row a send, by a press made 600 ms or more after the strips, the drawer or the window last changed; asks in a strip for each host the page was refused, at most 10, posts an approval to /_allow and frames the page again, and lists the hosts allowed and blocked in a drawer; there too lists the page's newest 20 notes and has one typed, on an element picked in the page or on the page itself, and sent as a pick is; offers a link in a strip, or goes to it when it is a page here, the user acted and no note is half typed; on another device has no pick, approval or note to send and says where they are; shows the last dk check, focuses the frame on load and by Tab, forgets what deleted pages stored, and unregisters service workers.
// Misses: a host that an allowed one redirects to, which a browser reports under the allowed one's name; a host a page makes up, asked for like one it was refused; a host refused more than a second after a reload, off the list until then; an approval another tab made, until the next load; a kind of file a host is refused 300 ms or more after its first, said with the host again; the ring of a frame reached by Tab, there until the focus is back in the viewer; a note half typed at a tab reload; what a page says a note is on; the end of a long note, where what the page says of it leaves too little of the server's 8 KiB; a key or an element picked in the page while something can be sent, done up to 1.5 s late; messages of a frame that takes over 300 ms to answer; two tabs of one page overwrite each other's keys; a frame that opened a blank page or a file of its own folder reads as one that does not answer; a page that never stops computing may block its own reload, which gets the same process; a page that floods it with messages slows the viewer too, and one that opens dialog after dialog keeps its Send and Discard from acting; a window that lost the focus for under 100 ms; the board's server swapped for another project's in the second before a Send; a page drawing a bar of its own inside the frame.
// Why, limits, history: rationale/derivations/plugin-design-kit.md § plugins/design-kit/scripts/viewer.js
(() => {
  const $ = (id) => document.getElementById(id);
  const { page, version } = document.body.dataset;
  const about = (route, of) => route + '?page=' + encodeURIComponent(of);
  const ask = (route, of = page) => fetch(about(route, of), { cache: 'no-store' });
  const make = (tag, text, more) => Object.assign(document.createElement(tag), { textContent: text }, more);
  const button = (label, act, more) => make('button', label, { type: 'button', onclick: () => act(), ...more });
  const isObject = (o) => Object.prototype.toString.call(o) === '[object Object]';

  // the time from which a press of a consent control counts
  let actsFrom = 0, holds = 0;
  function hold() {
    const mine = ++holds;
    actsFrom = Infinity;
    requestAnimationFrame(() => setTimeout(() => { if (mine === holds) actsFrom = performance.now() + 600; })); // what changed is painted by then
  }
  /** Makes control one that records or grants: act runs on a click, Enter or Space made 600 ms or more after what the last hold() was for was painted. */
  function guard(control, act) {
    control.dataset.consent = '';
    control.onclick = (e) => { if (e.timeStamp >= actsFrom && control.ariaDisabled !== 'true') act(); };
    return control;
  }

  const GONE = { text: 'This page was deleted' };
  const HUNG = { text: 'This page is not answering', acts: [['Reload page', show]] };
  const FULL = { text: 'Storage is full; changes to this page are not saved' };
  // in the order they are shown
  const STRIPS = ['page', 'server', 'storage', 'pick', 'blocked', 'more', 'link', 'lan'];
  /** Shows spec.text (a string or the nodes of a line), the elements of spec.more, and spec.acts (buttons, or a [label, act] for each) as the strip of this kind, and of this key where a kind has several, or removes that strip when spec is null; the same again is left alone, so it is announced once. The focus stays on the control it was on, else on the strip's first button, else goes to the frame. */
  function strip(kind, spec, key = '') {
    const all = [...$('strips').children], old = all.find((s) => s.dataset.kind === kind && s.dataset.key === key), el = make('div');
    if (spec) {
      Object.assign(el.dataset, { kind, key });
      el.append(make('p'), ...(spec.more || []), ...(spec.acts || []).map((act) => (Array.isArray(act) ? button(...act) : act)));
      el.firstChild.append(...[spec.text].flat());
      if (old?.isEqualNode(el)) return;
    }
    const held = old?.contains(document.activeElement) && document.activeElement;
    if (!spec) old?.remove();
    else if (old) old.replaceWith(el);
    else $('strips').insertBefore(el, all.find((s) => STRIPS.indexOf(s.dataset.kind) > STRIPS.indexOf(kind)) || null);
    const is = (s) => s.localName === held.localName && (s.localName === 'ul' || s.textContent === held.textContent);
    if (held) ([...el.querySelectorAll('button, ul')].find(is) || el.querySelector('button') || frame)?.focus();
  }
  let changed = -Infinity; // when the strips or the drawer last did
  const due = new Map();
  /** Draws what a page brought to the strip of this kind: while a consent control is there, no sooner than 1.5 s after the last change, so a page cannot keep it from acting. */
  function bring(kind, draw) {
    due.set(kind, draw);
    settle();
  }
  function settle() {
    if (!due.size || document.querySelector('[data-consent]') && performance.now() < changed + 1500) return;
    for (const draw of due.values()) draw();
    due.clear();
  }
  const seen = new MutationObserver(() => { changed = performance.now(); hold(); });
  for (const id of ['strips', 'drawer']) seen.observe($(id), { attributes: true, characterData: true, childList: true, subtree: true });
  for (const [on, type] of [[$('strips'), 'scroll'], [$('drawer'), 'scroll'], [window, 'resize'], [document, 'visibilitychange'], [document, 'fullscreenchange']]) on.addEventListener(type, hold);
  let away = false;
  // not the focus event: the window gets one when the focus leaves the frame too, and none when it comes back with the focus in the frame
  setInterval(() => {
    const here = document.hasFocus();
    if (away || !here) hold();
    away = !here;
    settle();
  }, 100);

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
    bring('storage', () => strip('storage', unsaved.size ? FULL : null));
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
    const mine = frame = document.createElement('iframe');
    frame.setAttribute('sandbox', 'allow-scripts allow-forms allow-modals allow-downloads');
    frame.setAttribute('allow', 'clipboard-write');
    frame.title = at.title;
    frame.name = JSON.stringify({ dk: 1, store: Object.fromEntries(stored(at)) });
    frame.src = at.src + (query && '?' + query) + location.hash;
    frame.onload = () => setTimeout(() => { if (mine === frame) unlist(); }, 1000);
    strip('storage', null);
    $('frame').replaceChildren(frame);
    watch();
  }
  function tell(t, data) { frame?.contentWindow.postMessage({ dk: 1, t, ...data }, '*'); } // a null origin takes no other target

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
    acts.append(button('Reload page', show, { className: 'primary' }), make('a', 'Back to gallery', { href: '/_gallery', draggable: false }));
    area.className = 'stopped';
    area.append(text, acts);
    $('frame').replaceChildren(area);
    if (held) text.focus();
  });

  // name -> its range, or its two values, and its words, as in picks.py
  const KNOBS = {
    space: [0, 64, (v) => `spacing base ${v}px`], radius: [0, 64, (v) => `corner radius ${v}px`], hue: [0, 360, (v) => `accent hue ${v}°`],
    type: [0.5, 3, (v) => `type scale ×${v}`], density: [0.5, 3, (v) => `density ×${v}`], scheme: ['light', 'dark', (v) => `${v} scheme`],
  };
  // what serve.py's _hidden escapes: it draws nothing, or reorders the text around it
  const HIDDEN = /([\p{C}\p{Zl}\p{Zp}\u{FE00}-\u{FE0F}\u{E0100}-\u{E01EF}\u{180B}-\u{180F}\u{115F}\u{1160}\u{3164}\u{FFA0}\u{2800}])/u;
  const isPick = (m) => (m.picked === null || Number.isInteger(m.picked)) && isObject(m.knobs) && isObject(m.text);
  /** [scope, its object] for the scopes named, then for the artboards 1 to 99 in order. */
  const scopes = (of, ...named) => [...named.map((k) => [k, of[k]]), ...Object.entries(of).filter(([k]) => /^[1-9]\d?$/.test(k))].filter(([, v]) => isObject(v));
  function knob([low, high], v) {
    if (typeof low === 'string') return v === low || v === high ? v : undefined;
    return typeof v === 'number' && !Number.isNaN(v) ? Math.min(high, Math.max(low, v)) : undefined;
  }
  // by code point, and a lone surrogate as "?", as Python counts and serve.py stores them
  const cut = (s, n) => Array.from(s.slice(0, 2 * n)).slice(0, n).join('').replace(/\p{Cs}/gu, '?');
  /** The picked, knobs and text of a report as picks.py would store them: what is shown is what is sent. */
  function clamp({ picked, knobs, text }) {
    const shot = { picked: picked >= 1 && picked <= 99 ? picked : null, knobs: {}, text: {} };
    for (const [scope, given] of scopes(knobs, 'all')) {
      const own = Object.entries(KNOBS).map(([name, rule]) => [name, knob(rule, given[name])]).filter(([, v]) => v !== undefined);
      if (own.length) shot.knobs[scope] = Object.fromEntries(own);
    }
    let left = 100;
    for (const [scope, given] of scopes(text)) {
      for (const [path, edit] of Object.entries(given)) {
        if (!left || !/^[a-z0-9:/-]{1,200}$/.test(path) || !isObject(edit) || typeof edit.was !== 'string' || typeof edit.now !== 'string') continue;
        (shot.text[scope] ||= {})[path] = { was: cut(edit.was, 500), now: cut(edit.now, 500) };
        left--;
      }
    }
    return shot;
  }
  /** A page's words, apart from the text around them, a character that draws nothing as its number. */
  function drawn(s) {
    const bdi = make('bdi');
    bdi.append(...s.split(HIDDEN).map((part, i) => (i % 2 ? make('code', 'U+' + part.codePointAt(0).toString(16).toUpperCase()) : part)));
    return bdi;
  }
  /** A line for each knob value and each text edit, as the parts of a list item. */
  function lines({ knobs, text }) {
    const named = (scope) => (scope === 'all' ? 'All artboards' : 'Artboard ' + scope);
    return [
      ...scopes(knobs, 'all').flatMap(([scope, own]) => Object.entries(own).map(([name, v]) => [`${named(scope)}: ${KNOBS[name][2](v)}`])),
      ...scopes(text).flatMap(([scope, own]) => Object.entries(own).map(([path, { was, now }]) => [`${named(scope)} text, ${path}: “`, drawn(was), '” → “', drawn(now), '”'])),
    ];
  }
  function list(label, items, more) {
    const ul = make('ul', null, more);
    ul.setAttribute('aria-label', label);
    for (const parts of items) {
      const li = make('li');
      li.append(...parts);
      ul.append(li);
    }
    return ul;
  }

  const REFUSALS = [400, 403, 413, 507];
  const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
  const newCid = () => Array.from(crypto.getRandomValues(new Uint8Array(8)), (b) => b.toString(16).padStart(2, '0')).join('');
  /** Posts body to a write route: what it said, why it is not recorded, '' once it is (taken says which answer says so), and whether the same again would be refused too. */
  async function post(route, header, body, taken = (said) => said?.recorded === true) {
    try {
      const r = await fetch(route, { method: 'POST', headers: { 'Content-Type': 'application/json', [header]: '1' }, body: JSON.stringify(body), signal: AbortSignal.timeout(10000) });
      const said = await r.json().catch(() => null);
      return { said, why: r.ok && taken(said) ? '' : 'Not recorded: ' + (said?.error || 'the server answered ' + r.status), refused: REFUSALS.includes(r.status) };
    } catch (e) {
      return { why: 'The preview server did not answer', refused: false };
    }
  }
  // sessionStorage's name for this page's pick, '' where none can be sent; the pick on screen, { shot, cid, updated, sending, why, refused }; the one reported since, { shot, updated }
  let place = '', pick = null, newer = null;
  function stash() {
    const { shot, cid } = newer && !same(newer.shot, pick?.shot) ? newer : pick || {};
    try {
      if (shot) sessionStorage.setItem(place, JSON.stringify({ cid, ...shot })); else sessionStorage.removeItem(place);
    } catch (e) { /* this browser keeps no site data: the strip lasts as long as this viewer */ }
  }
  /** Brings back the pick this tab has not sent, the first time, and once another project is served here. */
  function unstash(at) {
    const now = at.writable && page.startsWith('boards/') ? `dk-pick:${at.project}:${page}` : '';
    if (now === place) return;
    place = now;
    pick = newer = null;
    try {
      const { cid, ...shot } = JSON.parse(sessionStorage.getItem(place));
      if (isPick(shot)) pick = { shot: clamp(shot), cid: /^[0-9a-f]{16}$/.test(cid) ? cid : newCid() };
    } catch (e) { /* none */ }
    drawPick();
  }
  function report(m) {
    const shot = clamp(m);
    newer = { shot, updated: !!pick && (pick.updated || !same(shot, pick.shot)) };
    stash();
    bring('pick', present);
  }
  function present() {
    if (!newer || pick?.sending) return;
    pick = { cid: same(newer.shot, pick?.shot) ? pick.cid : newCid(), ...newer };
    newer = null;
    stash();
    drawPick();
  }
  function drawPick() {
    if (!pick) return strip('pick', null);
    const changes = lines(pick.shot), said = pick.shot.picked ? `Artboard ${pick.shot.picked} picked` : changes.length ? 'Changes, no artboard picked' : 'Pick cleared';
    strip('pick', {
      text: pick.updated ? [said + ' ', make('strong', 'Updated')] : said,
      more: [...(changes.length ? [list('Changes', changes, { tabIndex: 0 })] : []), ...(pick.why ? [make('p', pick.why, { className: 'why' })] : [])],
      acts: [...(pick.refused ? [] : [guard(button(pick.why ? 'Send again' : 'Send pick', null, { className: 'primary' }), send)]), guard(button('Discard'), discard)],
    });
  }
  function discard() {
    pick = null;
    stash();
    drawPick();
  }
  async function send() {
    const mine = pick;
    mine.sending = true;
    // not disabled, which would take the focus off it
    for (const one of document.querySelectorAll('[data-kind="pick"] [data-consent]')) one.ariaDisabled = 'true';
    const { why, refused } = await post('/_decision', 'X-Design-Kit-Decision', { cid: mine.cid, board: page.split('/').pop(), ...mine.shot });
    if (mine !== pick) return;
    pick = why ? { ...mine, sending: false, why, refused } : null;
    stash();
    drawPick();
    bring('pick', present);
  }

  const isText = (s) => typeof s === 'string';
  const isBox = (r, ...sides) => isObject(r) && sides.every((k) => Number.isFinite(r[k]));
  const isAnchor = (a) => a === null || isObject(a) && [a.selector, a.tag, a.text].every(isText) && isBox(a.rect, 'x', 'y', 'w', 'h');
  const isContext = (c) => isObject(c) && isBox(c.viewport, 'w', 'h') && isText(c.theme) && Array.isArray(c.console) && c.console.length <= 5 && [...c.console].every(isText);
  // what a page says, cut as serve.py's note_row cuts it: its bytes are taken from the note's own
  const anchorOf = ({ selector, tag, text, rect: { x, y, w, h } }) => ({ selector: cut(selector, 512), tag: cut(tag, 32), text: cut(text, 200), rect: { x, y, w, h } });
  const contextOf = ({ viewport: { w, h }, theme, console: lines }) => ({ viewport: { w, h }, theme: cut(theme, 16), console: lines.map((line) => cut(line, 300)) });

  const local = !$('notes').hidden; // another device leaves no note and approves no host
  const LOADS = new Map([['script', 'scripts'], ['style', 'styles'], ['img', 'images'], ['font', 'fonts'], ['media', 'media']]);
  const isBlocked = ({ host, kind }) => isText(host) && host.length > 0 && host.length <= 253 && LOADS.has(kind);
  const words = (kinds) => [...LOADS].filter(([kind]) => kinds.has(kind)).map(([, word]) => word).join(', ');
  // the hosts this page may load from; why it may from none; those to stay blocked in this tab, and sessionStorage's name for them; those a change is asked for; the last one refused
  let hosts = [], broken = '', kept = new Set(), keptAt = '', failed = {};
  const asking = new Set();
  // host -> the kinds of file the page was refused from it, none yet when it was just removed, and the frame last refused one
  const refused = new Map();
  let listing = make('div');
  const refusal = make('p', null, { className: 'why', role: 'status' });
  function refuse({ host: given, kind }) {
    const host = given.toLowerCase(), { kinds = new Set() } = refused.get(host) || {};
    if (hosts.includes(host) || !refused.has(host) && refused.size === 100) return; // a page may name any number
    refused.set(host, { kinds: kinds.add(kind), frame });
    setTimeout(() => bring('blocked', drawHosts), 300); // the refusals of one load come one by one, and are said once
  }
  /** Forgets the hosts that only a frame before this one was refused; called once this one is loaded and has said its own. */
  function unlist() {
    for (const [host, at] of refused) if (at.frame !== frame) refused.delete(host);
    bring('blocked', drawHosts);
  }
  /** Takes /_page's word for what this page may load. */
  function admit(at) {
    if (!local) return;
    hosts = at.hosts;
    broken = at.hosts_error ? at.hosts_error[0].toUpperCase() + at.hosts_error.slice(1) : '';
    for (const host of hosts) refused.delete(host);
    keptAt = `dk-blocked:${at.project}:${page}`;
    try {
      kept = new Set(JSON.parse(sessionStorage.getItem(keptAt)) || []);
    } catch (e) { /* this browser keeps no site data: as long as this viewer */ }
    drawHosts();
  }
  function keepBlocked(host, on) {
    if (on) kept.add(host); else kept.delete(host);
    try { sessionStorage.setItem(keptAt, JSON.stringify([...kept])); } catch (e) { /* as above */ }
  }
  /** Has the server let this page load from host, or no longer, and the page framed anew once it does. */
  async function permit(host, allow) {
    if (asking.has(host)) return;
    asking.add(host);
    failed = {};
    for (const one of document.querySelectorAll('[data-host]')) if (one.dataset.host === host) one.ariaDisabled = 'true';
    const { said: answer, why } = await post('/_allow', 'X-Design-Kit-Allow', { page, host, allow }, (given) => Array.isArray(given?.hosts));
    asking.delete(host);
    if (why) failed = { host, why };
    else {
      hosts = answer.hosts;
      refused.delete(host);
      if (allow) keepBlocked(host, false); else refused.set(host, { kinds: new Set() });
    }
    drawHosts();
    if (!why) show();
  }
  /** A button that lets this page load from host, or ends that: guarded both ways, as a double click on Allow reaches the Remove that takes its place. */
  function permitting(label, host, allow) {
    const control = button(label, null, { ariaLabel: `${label}: ${drawn(host).textContent}`, ariaDisabled: asking.has(host) ? 'true' : null });
    control.dataset.host = host;
    return guard(control, () => permit(host, allow));
  }
  function drawHosts() {
    const asks = [...refused].filter(([host, { kinds }]) => kinds.size && !kept.has(host)), shown = new Map(asks.slice(0, 10)), more = asks.length - shown.size;
    for (const { dataset: { key } } of $('strips').querySelectorAll('[data-kind="blocked"]')) if (!shown.has(key)) strip('blocked', null, key);
    for (const [host, { kinds }] of shown) {
      const whys = [host === asks[0][0] && broken, host === failed.host && failed.why].filter(Boolean);
      strip('blocked', {
        text: [drawn(host), ' blocked: ' + words(kinds)],
        more: whys.map((why) => make('p', why, { className: 'why' })),
        acts: [permitting('Allow for this page', host, true), button('Keep blocked', () => { keepBlocked(host, true); drawHosts(); }, { ariaLabel: 'Keep blocked: ' + drawn(host).textContent })],
      }, host);
    }
    strip('more', more ? { text: `${more} more ${more === 1 ? 'host' : 'hosts'} blocked; Network lists ${more === 1 ? 'it' : 'them'}` } : null);
    const n = hosts.length + refused.size, at = document.activeElement, held = at === $('network') || listing.contains(at);
    $('network').hidden = !n;
    $('network').textContent = `Network (${n})`;
    if (!n && open === 'network') toggle('network');
    if (!n && held) frame?.focus();
    drawListing();
  }
  /** Lists the hosts while their panel is open; the focus stays at its host, else goes to the first. */
  function drawListing() {
    const now = make('div'), group = (title, rows) => (rows.length ? [make('h3', title), list(title + ' hosts', rows, { className: 'hosts' })] : []);
    if (open === 'network') {
      now.append(
        ...(broken ? [make('p', broken, { className: 'why' })] : []),
        ...group('Allowed', hosts.map((host) => [drawn(host), permitting('Remove', host, false)])),
        ...group('Blocked', [...refused].map(([host, { kinds }]) => [drawn(host), ...(kinds.size ? [make('span', words(kinds))] : []), permitting('Allow', host, true)])),
      );
    }
    refusal.textContent = failed.why ? `${drawn(failed.host).textContent}: ${failed.why}` : '';
    if (listing.isEqualNode(now)) return;
    const held = listing.contains(document.activeElement) && document.activeElement.dataset.host;
    listing.replaceWith(now);
    listing = now;
    if (held) ([...now.querySelectorAll('button')].find((one) => one.dataset.host === held) || now.querySelector('button'))?.focus();
  }

  const path = '/' + page.split('/').map(encodeURIComponent).join('/'); // as page_of reads it
  const HINT = 'Click an element, or Tab to one and press Enter, to leave a note on it. Escape closes.';
  const chips = [$('chip'), make('p', null, { id: 'check' })];
  const said = make('p', null, { role: 'status' });
  const onPage = button('Note on this page', () => {
    if (note?.sending) return;
    compose(null, { console: [] }, onPage);
    note.asked = true;
    tell('ask');
  });
  let listed = list('Notes left on this page', []);
  // the id of the button whose panel is open in the drawer, '' when none is; whether that is the notes; the note being written, or null: its elements, the button that opened it, what the page said, the body last sent with its cid
  let open = '', noting = false, note = null;
  const panels = new Map();
  function panel(id, title, ...parts) {
    const section = make('section', null, { ariaLabel: title, hidden: true });
    section.append(make('h2', title), ...parts);
    $('drawer').append(section);
    Object.assign($(id), { ariaExpanded: 'false', onclick: () => toggle(id) });
    $(id).setAttribute('aria-controls', 'drawer');
    panels.set(id, section);
  }
  if (local) {
    panel('notes', 'Notes on this page', chips[1], onPage, said, listed);
    Object.assign($('notes'), { title: 'Notes on this page (Alt+N)', ariaKeyShortcuts: 'Alt+N' });
    panel('network', 'Network', refusal, listing);
  }
  /** Opens a panel, in place of the other, or closes it; while the notes are open the page reports what is picked in it. */
  function toggle(id) {
    if (!local) return;
    open = open === id ? '' : id;
    $('drawer').hidden = !open;
    for (const [one, section] of panels) {
      section.hidden = one !== open;
      $(one).ariaExpanded = String(one === open);
    }
    const on = open === 'notes';
    if (on !== noting) tell('notes', { on });
    noting = on;
    said.textContent = '';
    if (noting) {
      refresh();
      requestAnimationFrame(() => { said.textContent = HINT; }); // a live region reads out only what changes once it is shown
    } else if (note && !note.sending && !note.text.value.trim()) leave(false);
    drawListing();
  }
  function back() {
    if (!open) return;
    if (noting && note) return drop();
    const was = $(open);
    toggle(open);
    was.focus();
  }
  async function refresh() {
    check();
    const rows = await ask('/_notes', path).then((r) => (r.ok ? r.json() : null)).catch(() => null);
    if (!rows) return;
    $('notes').textContent = rows.length ? `Notes (${rows.length})` : 'Notes';
    const now = list('Notes left on this page', rows.length ? rows.slice(-20).reverse().map(({ status, anchor, text, reply }) => [
      make('span', status, { className: 'st ' + status }), ' ', make('b', anchor?.tag ? `<${anchor.tag}>` : 'Page'), make('div', text), ...(reply ? [make('div', 'Reply: ' + reply, { className: 'reply' })] : []),
    ]) : [['No notes on this page yet.']]);
    if (listed.isEqualNode(now)) return;
    listed.replaceWith(now);
    listed = now;
  }
  /** The note being written is now on anchor, or on the page when that is null; a composer is opened for it, by opener, when there is none. */
  function compose(anchor, context, opener) {
    note ||= blank(opener);
    Object.assign(note, { anchor, context, asked: false });
    const words = anchor ? cut(anchor.text, 60) : '';
    note.on.replaceChildren(...(anchor ? ['On <', drawn(anchor.tag), '>', ...(words ? [' “', drawn(words), '”'] : [])] : ['On this page']));
    explain('');
    // a page must not take the focus from Send pick
    if (![note.box, $('strips')].some((at) => at.contains(document.activeElement))) note.text.focus();
  }
  function blank(opener) {
    const box = make('div', null, { role: 'group', ariaLabel: 'Write a note' }), label = make('label', 'Note'), acts = make('div');
    const on = make('p', null, { id: 'on' }), why = make('p', null, { id: 'why', className: 'why', role: 'status' });
    const text = make('textarea', null, { maxLength: 2000, required: true, oninput: () => { if (why.textContent) explain(''); } });
    const send = guard(button('Send note', null, { className: 'primary' }), sendNote), cancel = button('Cancel', drop);
    text.setAttribute('aria-describedby', 'on why');
    label.append(text);
    acts.append(send, cancel);
    box.append(on, label, why, acts);
    onPage.after(box);
    return { box, on, why, text, send, cancel, opener };
  }
  function explain(why, label = 'Send note') {
    if (!label && document.activeElement === note.send) note.text.focus();
    note.why.textContent = why;
    note.send.textContent = label;
    note.send.hidden = !label;
  }
  function leave(focus) {
    const { box, opener } = note;
    note = null;
    if (focus) opener.focus();
    box.remove();
  }
  function drop() {
    if (!note.sending) leave(true);
  }
  async function sendNote() {
    const mine = note, body = { page: path, text: mine.text.value.trim(), anchor: mine.anchor, context: { ...mine.context, console: [...mine.context.console] } };
    if (!body.text) {
      explain('A note needs text');
      return mine.text.focus();
    }
    const over = () => new TextEncoder().encode(JSON.stringify(body)).length > 8000;
    while (over() && body.context.console.length) body.context.console.shift();
    while (over() && body.text) body.text = cut(body.text, Math.floor(Array.from(body.text).length * 0.8));
    const json = JSON.stringify(body);
    if (json !== mine.json) Object.assign(mine, { json, cid: newCid() });
    const pending = (on) => {
      mine.sending = mine.text.readOnly = on;
      for (const one of [mine.send, mine.cancel]) one.ariaDisabled = on ? 'true' : null;
    };
    pending(true);
    said.textContent = 'Sending…';
    const { why, refused } = await post('/_note', 'X-Design-Kit-Note', { cid: mine.cid, ...body });
    pending(false);
    said.textContent = why ? '' : 'Sent. The session reads it with dk notes.';
    if (why) explain(why, refused ? '' : 'Send again'); else leave(mine.box.contains(document.activeElement));
    if (!why) refresh();
  }

  const isLink = ({ href }) => isText(href) && href.length <= 2048 && /^(https?|mailto):/.test(href) && URL.canParse(href);
  function offer(to) {
    const done = () => strip('link', null);
    strip('link', { text: to.href, acts: [guard(button('Open'), () => { window.open(to.href, '_blank', 'noopener,noreferrer'); done(); }), ['Dismiss', done]] });
  }
  /** Goes to a page of this docroot when the user acted and no note is half typed; offers any other address. */
  async function follow(to) {
    const active = () => !!navigator.userActivation?.isActive;
    if (to.origin === location.origin) {
      to.search = '';
      if (!drafted()) {
        const there = active() && await fetch(to.href, { method: 'HEAD', cache: 'no-store' }).catch(() => null);
        if (!active()) return;
        if (there?.ok && /^text\/html\b/.test(there.headers.get('Content-Type')) && !drafted()) return location.assign(to.href);
      }
    }
    bring('link', () => offer(to));
  }

  /** A key of the page: pressed there only while the page has the focus, and done while it still has. */
  function pressed(act) {
    const there = () => document.activeElement === frame;
    if (there()) bring('drawer', () => { if (there()) act(); });
  }
  const KEYS = new Map([
    ['print', () => tell('print')],
    ['notes', () => pressed(() => toggle('notes'))],
    ['escape', () => pressed(() => { if (!noting || !drafted()) back(); })],
  ]);
  const isHash = (h) => typeof h === 'string' && /^#[\w/=&.%-]{0,128}$/.test(h);
  // message type -> [whether its fields have their shape, what it does]
  const HANDLERS = new Map([
    ['ready', [(m) => isHash(m.hash), () => { if (noting) tell('notes', { on: true }); if (document.activeElement === document.body) frame.focus(); }]],
    ['hash', [(m) => isHash(m.hash), (m) => history.replaceState(null, '', m.hash)]],
    ['pong', [(m) => Number.isInteger(m.n) && m.n > 0 && m.n <= pings, (m) => { expect(); say({ hung: false }); answered(m); }]],
    ['store', [isStore, keep]],
    ['pick', [(m) => place && isPick(m), report]],
    ['anchor', [(m) => noting && isAnchor(m.anchor) && isContext(m.context), ({ anchor, context }) => bring('note', () => { if (noting && !note?.sending) compose(anchor && anchorOf(anchor), contextOf(context), $('notes')); })]],
    ['context', [(m) => note?.asked && isContext(m.context), (m) => Object.assign(note, { context: contextOf(m.context), asked: false })]],
    ['blocked', [(m) => local && isBlocked(m), refuse]],
    ['link', [isLink, ({ href }) => follow(new URL(href))]],
    ['key', [(m) => KEYS.has(m.name), (m) => KEYS.get(m.name)()]],
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
  addEventListener('keydown', (e) => {
    if (e.altKey && !e.ctrlKey && !e.metaKey && e.code === 'KeyN' && !/^(input|textarea|select)$/.test(e.target.localName)) {
      e.preventDefault();
      toggle('notes');
      $('notes').focus();
    } else if (e.key === 'Escape' && !e.isComposing) back(); // one that ends an IME's composition drops no draft
  });
  // Chrome's Tab passes by a frame whose page has nothing to focus, a deck say
  addEventListener('keydown', (e) => {
    if (!frame || e.key !== 'Tab' || e.shiftKey || e.altKey || e.ctrlKey || e.metaKey) return;
    if (e.target !== [...document.querySelectorAll('a, button, textarea, [tabindex="0"]')].filter((one) => one.checkVisibility()).pop()) return;
    e.preventDefault();
    frame.focus();
    frame.dataset.reached = '';
  });
  document.addEventListener('focusin', () => frame?.removeAttribute('data-reached'));
  addEventListener('hashchange', () => show()); // typed into the address: the frame's own hash comes by replaceState, which tells no one

  async function check() {
    const c = await ask('/_checks').then((r) => (r.ok ? r.json() : null)).catch(() => null);
    if (!c) return;
    const textContent = !c.checked ? 'Not checked' : `Checked, ${c.findings} ${c.findings === 1 ? 'problem' : 'problems'}${c.changed_since ? '; page changed since' : ''}`;
    const className = !c.checked || c.changed_since ? '' : c.findings ? 'warn' : 'ok';
    for (const chip of chips) if (chip.textContent !== textContent) Object.assign(chip, { textContent, className });
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
    unstash(at);
    build(at);
    admit(at);
    if (at.writable) refresh();
    else strip('lan', { text: `Open ${at.local} on the computer running the server to leave notes, picks or approvals.` });
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

  document.querySelector('#bar a').draggable = false;
  navigator.serviceWorker?.getRegistrations().then((all) => all.forEach((one) => one.unregister()));
  connect();
  show();
})();
