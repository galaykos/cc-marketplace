// viewer.js — serve.py's /_viewer.js: the bar around a page's sandboxed frame. Asks /_page where the page is, frames it at the address's hash and keeps that hash the frame's, frames it again, once its last messages are in, when the page's own /_events says so or a lost server is back, shows the last dk check, focuses the frame, and unregisters service workers.
// Misses: notes, picks, approvals and page state; a frame that hangs or left; messages of a frame that takes over 300 ms to answer; a page drawing a bar of its own inside the frame.
// Why, limits, history: rationale/derivations/plugin-design-kit.md § plugins/design-kit/scripts/viewer.js
(() => {
  const $ = (id) => document.getElementById(id);
  const { page, version } = document.body.dataset;
  const about = (route) => route + '?page=' + encodeURIComponent(page);
  const ask = (route) => fetch(about(route), { cache: 'no-store' });

  const GONE = { text: 'This page was deleted' };
  // in the order they are shown
  const STRIPS = ['page', 'server', 'storage', 'pick', 'blocked', 'link'];
  /** Shows spec.text as the strip of this kind, or removes that strip when spec is null; the same words again are left alone, so they are announced once. */
  function strip(kind, spec) {
    const all = [...$('strips').children], old = all.find((s) => s.dataset.kind === kind);
    if (spec && old?.textContent === spec.text) return;
    old?.remove();
    if (!spec) return;
    const el = document.createElement('div');
    el.dataset.kind = kind;
    el.textContent = spec.text;
    $('strips').insertBefore(el, all.find((s) => STRIPS.indexOf(s.dataset.kind) > STRIPS.indexOf(kind)) || null);
  }

  let frame;
  function build(at) {
    frame = document.createElement('iframe');
    frame.setAttribute('sandbox', 'allow-scripts allow-forms allow-modals allow-downloads');
    frame.setAttribute('allow', 'clipboard-write');
    frame.title = at.title;
    frame.name = JSON.stringify({ dk: 1, store: {} });
    frame.src = at.src + location.hash;
    $('frame').replaceChildren(frame);
  }

  let pings = 0, answered = () => {};
  /** Done when the frame has answered a ping, after the messages it still held, or after 300 ms. */
  const emptied = () => new Promise((done) => {
    answered = done;
    frame.contentWindow.postMessage({ dk: 1, t: 'ping', n: ++pings }, '*'); // a null origin takes no other target
    setTimeout(done, 300);
  });

  const isHash = (h) => typeof h === 'string' && /^#[\w/=&.%-]{0,128}$/.test(h);
  // message type -> [whether its fields have their shape, what it does]
  const HANDLERS = new Map([
    ['ready', [(m) => isHash(m.hash), () => { if (document.activeElement === document.body) frame.focus(); }]],
    ['hash', [(m) => isHash(m.hash), (m) => history.replaceState(null, '', m.hash)]],
    ['pong', [(m) => m.n === pings, () => answered()]],
  ]);
  addEventListener('message', (e) => {
    const m = e.data;
    if (!frame || e.source !== frame.contentWindow || !m || m.dk !== 1) return;
    const [fits, act] = HANDLERS.get(m.t) || [];
    if (fits?.(m)) act(m);
  });

  async function check() {
    const c = await ask('/_checks').then((r) => (r.ok ? r.json() : null)).catch(() => null);
    if (!c) return;
    $('chip').textContent = !c.checked ? 'Not checked' : `Checked, ${c.findings} ${c.findings === 1 ? 'problem' : 'problems'}${c.changed_since ? '; page changed since' : ''}`;
    $('chip').className = !c.checked || c.changed_since ? '' : c.findings ? 'warn' : 'ok';
  }

  const drafted = () => [...document.querySelectorAll('textarea')].some((t) => t.value.trim());

  let turn = 0;
  async function show() {
    const mine = ++turn;
    const r = await ask('/_page').catch(() => null);
    const at = r?.ok && await r.json().catch(() => null);
    if (mine !== turn) return;
    if (!at && r?.status !== 404) return lose();
    wait = 0;
    strip('server', null);
    if (!at) return strip('page', GONE);
    strip('page', null);
    if (frame) await emptied();
    if (mine !== turn) return;
    if (String(at.version) !== version && !drafted()) return location.reload();
    document.title = $('title').textContent = at.title;
    build(at);
    if (at.writable) check();
  }

  let events, wait = 0, retry = 0;
  function connect() {
    retry = 0;
    events = new EventSource(about('/_events'));
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
    const gone = r?.status === 404; // a deleted page has no stream
    strip('server', gone ? null : { text: 'Preview server stopped; retrying' });
    if (gone) strip('page', GONE);
  }

  navigator.serviceWorker?.getRegistrations().then((all) => all.forEach((one) => one.unregister()));
  connect();
  show();
})();
