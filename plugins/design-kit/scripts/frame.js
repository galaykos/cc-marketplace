// frame.js — injected first into every page under /_c/: stands in for localStorage, sessionStorage and a POST to /_decision; framed, sends the viewer what its bridge takes.
// Misses: a page can undo or imitate all of it (the viewer is the boundary); window.open, navigation by script; iframes, closed shadow roots; a write as the page unloads, or in the last 100 ms before the viewer drops the frame unpinged.
// Why, limits, history: rationale/derivations/plugin-design-kit.md § plugins/design-kit/scripts/frame.js
(function () {
  if (window.__designKitFrame) return; window.__designKitFrame = true;
  const at = /^(\/_c\/[\w-]{22}\.[\w-]+(\.s)?)\//.exec(location.pathname);
  if (!at) return;
  const own = at[1], framed = !at[2], viewer = parent;
  if (framed && viewer === window) {
    stop(); // ends the parser: no script of the page runs meanwhile
    return location.replace(location.origin + location.pathname.slice(own.length) + location.search + location.hash);
  }
  const later = setTimeout.bind(window), cancel = clearTimeout.bind(window);
  const on = (types, fn) => { for (const t of types.split(' ')) addEventListener(t, fn, true); };
  const url = (s) => { try { return new URL(s, document.baseURI); } catch (e) { return {}; } };
  const send = (t, data) => framed && viewer.postMessage({ dk: 1, t, ...data }, location.origin);

  function storage(map, changed) {
    const short = (k) => String(k).split(own).join('');
    const cost = (k) => (map.has(k) ? k.length + map.get(k).length : 0);
    const keys = () => [...map.keys()];
    let size = 0;
    for (const k of keys()) size += cost(k);
    const api = {
      get length() { return map.size; },
      key: (i) => keys()[i] ?? null,
      getItem: (k) => map.get(short(k)) ?? null,
      setItem(k, v) {
        k = short(k); v = String(v);
        const next = size - cost(k) + k.length + v.length;
        if (next > 256 * 1024 || k.length > 256) throw new DOMException('over 256 KB, or a key over 256 characters', 'QuotaExceededError');
        size = next; map.set(k, v); changed(k, v);
      },
      removeItem(k) {
        k = short(k);
        size -= cost(k);
        if (map.delete(k)) changed(k, null);
      },
      clear() { size = 0; map.clear(); changed(); },
    };
    const has = (k) => typeof k === 'string' && !(k in api) && map.has(short(k));
    return new Proxy(api, {
      get: (t, k) => (has(k) ? t.getItem(k) : t[k]),
      set: (t, k, v) => (t.setItem(k, v), true),
      has: (t, k) => k in t || has(k),
      deleteProperty: (t, k) => (t.removeItem(k), true),
      ownKeys: keys,
      getOwnPropertyDescriptor: (t, k) => (has(k) ? { value: t.getItem(k), writable: true, enumerable: true, configurable: true } : undefined),
    });
  }

  const saved = new Map(), waiting = new Map();
  let cleared, leaving, timer = 0, told = location.hash;
  try {
    const from = JSON.parse(window.name);
    if (from.dk === 1) for (const [k, v] of Object.entries(from.store)) if (typeof v === 'string') saved.set(k, v);
  } catch (e) { /* no seed */ }
  const hash = () => (/^#?[\w/=&.%-]{0,128}$/.test(location.hash) ? location.hash || '#' : '');
  function flush() {
    cancel(timer); timer = 0;
    if (cleared) send('store', { clear: true });
    if (waiting.size) send('store', { items: [...waiting] });
    cleared = false; waiting.clear();
    if (leaving) window.name = JSON.stringify({ dk: 1, store: Object.fromEntries(saved) }); // seeds a page that reloads itself
    if (told !== location.hash) {
      told = location.hash;
      if (hash()) send('hash', { hash: hash() });
    }
  }
  function soon() { if (leaving) flush(); else if (!timer) timer = later(flush, 100); }
  const stand = (name, value) => Object.defineProperty(window, name, { get: () => value });
  stand('localStorage', storage(saved, (k, v) => {
    if (k === undefined) { waiting.clear(); cleared = true; } else waiting.set(k, v);
    soon();
  }));
  stand('sessionStorage', storage(new Map(), () => {}));

  const fetched = fetch.bind(window);
  window.fetch = (input, init) => {
    const u = url(input instanceof Request ? input.url : input);
    if (u.origin !== location.origin || u.pathname !== '/_decision' || !/^post$/i.test(init?.method || input.method)) return fetched(input, init);
    return new Request(input, init).text().then((body) => {
      const { picked, knobs, text } = JSON.parse(body);
      send('pick', { picked, knobs, text });
    }).catch(() => {}).then(() => Response.json({ recorded: false }, { status: 409 }));
  };
  if (!framed) return;

  // beforeunload too: Chrome's pagehide messages carry no source, so the viewer drops them
  on('beforeunload pagehide', () => { leaving = true; flush(); later(() => { leaving = false; }, 1000); });
  for (const name of ['pushState', 'replaceState']) {
    const H = History.prototype, native = H[name];
    H[name] = function (...args) { native.apply(this, args); soon(); };
  }
  on('hashchange', soon);

  const blocked = new Map();
  on('securitypolicyviolation', (e) => {
    const [, kind] = /^(script|style|img|font|media)-src/.exec(e.effectiveDirective) || [], u = url(e.blockedURI);
    if (!e.isTrusted || !kind || u.protocol !== 'https:' || u.port) return;
    const host = u.hostname, kinds = blocked.get(host) || [];
    if (kinds.includes(kind) || (!blocked.has(host) && blocked.size === 10)) return;
    blocked.set(host, kinds.concat(kind));
    send('blocked', { host, kind });
  });

  // by code point: half an emoji posts a lone surrogate
  const cut = (s, n) => Array.from(String(s).slice(0, 2 * n)).slice(0, n).join('');
  // by its tag: an object can be circular, or have no toString
  const asText = (x) => (x instanceof Error ? String(x.message) : Object(x) === x ? {}.toString.call(x) : String(x));
  const errors = [], logError = console.error, root = document.documentElement;
  function keep(say) {
    try { errors.push(cut(say(), 300)); } catch (e) { /* not recorded */ }
    if (errors.length > 5) errors.shift();
  }
  console.error = (...args) => { keep(() => args.map(asText).join(' ')); logError.apply(console, args); };
  on('error', (e) => keep(() => {
    const t = e.target, from = t !== window && (t.src || t.href);
    return from ? 'failed to load ' + from : e.message || 'error';
  }));
  on('unhandledrejection', (e) => keep(() => 'unhandled rejection: ' + asText(e.reason)));

  function selectorOf(el) {
    const parts = [], all = (s) => document.querySelectorAll(s), esc = CSS.escape;
    for (let n = el; n && n !== root; n = n.parentElement) {
      if (n.id && all('#' + esc(n.id)).length === 1) { parts.unshift('#' + esc(n.id)); break; }
      let seg = esc(n.localName);
      const data = [...n.attributes].find((a) => /^data-(?!design-kit|original|bound)/.test(a.name) && a.value.length <= 64);
      if (data) seg += '[' + esc(data.name) + '="' + esc(data.value) + '"]';
      const same = [...n.parentNode.children].filter((c) => c.localName === n.localName);
      if (same.length > 1) seg += ':nth-of-type(' + (same.indexOf(n) + 1) + ')';
      parts.unshift(seg);
      const hits = all(parts.join(' > '));
      if (hits.length === 1 && hits[0] === el) break;
    }
    return parts.join(' > ');
  }
  function anchorOf(el) {
    const r = el.getBoundingClientRect(), px = Math.round;
    return {
      selector: selectorOf(el), tag: el.localName,
      text: cut(String(el.innerText ?? el.textContent).replace(/\s+/g, ' ').trim(), 200),
      rect: { x: px(r.left + scrollX), y: px(r.top + scrollY), w: px(r.width), h: px(r.height) },
    };
  }
  function theme() {
    const both = [root, document.body].filter(Boolean);
    for (const n of both) {
      const d = n.dataset, v = d.scheme || d.theme || d.colorScheme;
      if (v) return cut(v, 16);
    }
    for (const n of both) if (/\b(dark|light)\b/.test(n.className)) return /\bdark\b/.test(n.className) ? 'dark' : 'light';
    for (const n of both.reverse()) {
      const m = getComputedStyle(n).backgroundColor.match(/[\d.]+/g);
      if (m && (m.length < 4 || m[3] > 0)) return (0.2126 * m[0] + 0.7152 * m[1] + 0.0722 * m[2]) / 255 < 0.5 ? 'dark' : 'light';
    }
    const cs = getComputedStyle(root).colorScheme || '';
    if (/dark/.test(cs)) return /light/.test(cs) && !matchMedia('(prefers-color-scheme: dark)').matches ? 'light' : 'dark';
    return '';
  }
  const context = () => ({ viewport: { w: innerWidth, h: innerHeight }, theme: theme(), console: errors });

  const outline = document.createElement('div');
  outline.dataset.designKitNote = '';
  let picking = false, target = null;
  const isPage = (el) => !(el instanceof Element) || /^(html|body)$/.test(el.localName);
  const eat = (e) => { e.preventDefault(); e.stopImmediatePropagation(); };
  const pick = (el) => send('anchor', { anchor: isPage(el) ? null : anchorOf(el), context: context() });
  function show(el) {
    target = el;
    if (isPage(el)) return outline.remove();
    const r = el.getBoundingClientRect();
    outline.style.cssText = 'all:initial;position:fixed;box-sizing:border-box;pointer-events:none;z-index:2147483647;border:2px solid #1a56db;background:rgba(26,86,219,.08);'
      + `border-radius:3px;left:${r.left}px;top:${r.top}px;width:${r.width}px;height:${r.height}px`;
    if (!outline.isConnected) root.append(outline);
  }
  on('mousemove focusin', (e) => picking && show(e.target));
  on('scroll', () => picking && show(target));
  on('pointerdown mousedown pointerup mouseup dblclick auxclick click', (e) => {
    if (picking && e.isTrusted) {
      eat(e);
      if (e.type === 'click') pick(e.target);
    } else if (/^(aux)?click$/.test(e.type)) link(e);
  });

  function link(e) {
    const to = (n) => n.href && (n.href.baseVal ?? n.href);
    const a = e.composedPath().find((n) => /^(a|area)$/.test(n.localName) && to(n)), u = url(a && to(a)), here = u.origin === location.origin;
    if (!a || !u.href || a.isContentEditable || e.button > 1 || u.protocol === 'javascript:' || u.href.startsWith(location.href.split('#')[0] + '#')) return;
    const href = here ? u.href.replace(own + '/', '/') : u.href;
    const report = () => /^(https?|mailto):/.test(href) && href.length <= 2048 && send('link', { href });
    if (e.button || e.ctrlKey || e.metaKey || e.shiftKey || e.altKey) { e.preventDefault(); return report(); } // Chrome opens a tab for these, sandbox or not
    // the page's handlers decide first, wherever they listen; the sandbox refuses the new window
    const was = a.getAttribute('target');
    a.setAttribute('target', '_blank');
    later(() => {
      if (was === null) a.removeAttribute('target'); else a.setAttribute('target', was);
      if (!e.defaultPrevented) report();
    });
  }

  on('keydown', (e) => {
    if (!e.isTrusted) return;
    const el = e.composedPath()[0], mod = e.ctrlKey || e.metaKey, tell = (name) => send('key', { name });
    // in a field Alt+N is typing (macOS: the dead key for ñ)
    if (e.altKey && !mod && e.code === 'KeyN' && !el.isContentEditable && !/^(input|textarea|select)$/.test(el.localName)) { eat(e); tell('notes'); }
    else if (mod && !e.altKey && !e.shiftKey && /^p$/i.test(e.key)) { eat(e); tell('print'); }
    else if (e.key === 'Escape') { if (picking) eat(e); tell('escape'); }
    else if (e.key === 'Enter' && picking && !isPage(e.target)) { eat(e); pick(e.target); }
  });

  on('message', (e) => {
    const m = e.data;
    if (!e.isTrusted || e.source !== viewer || !m || m.dk !== 1) return;
    e.stopImmediatePropagation();
    if (m.t === 'ping') { if (timer) flush(); send('pong', { n: m.n }); }
    else if (m.t === 'notes') { picking = m.on === true; show(null); }
    else if (m.t === 'print') print();
    else if (m.t === 'ask') send('context', { context: context() });
    else if (m.t === 'storefull' && saved.has(m.k)) waiting.set(m.k, saved.get(m.k));
  });
  send('ready', { hash: hash() || '#' });
})();
