/* theme-design editor — injected into every page the session server serves.
   Vanilla, no deps. Captures chat + direct-manipulation gestures, posts them
   to /__td/event, listens on /__td/events for assistant replies and reloads.
   Live changes made here are PREVIEW ONLY: they vanish on reload until Claude
   writes them into the page/tokens (html mode) or the project source (proxy). */
(function () {
  "use strict";
  if (window.__td) return;
  var HDR = { "Content-Type": "application/json", "X-Theme-Design": "1" };
  var state = { tool: "select", selected: null, pending: 0, drag: null, resize: null, panelOpen: sessionStorage.getItem("td-open") !== "0" };

  // ---- helpers -----------------------------------------------------------
  function post(path, body) {
    return fetch(path, { method: "POST", headers: HDR, body: JSON.stringify(body) }).then(function (r) { return r.json(); });
  }
  function inPanel(el) { return !!(el && el.closest && el.closest("#__td-panel, .__td-handle, #__td-hover")); }
  function selectorFor(el) {
    if (!el || el === document.body) return "body";
    if (el.id) return "#" + CSS.escape(el.id);
    var parts = [];
    var node = el;
    while (node && node !== document.body && parts.length < 5) {
      var part = node.tagName.toLowerCase();
      var dataId = node.getAttribute("data-td") || node.getAttribute("data-testid");
      if (dataId) { parts.unshift(part + "[data-td=\"" + dataId + "\"]"); break; }
      var cls = Array.prototype.filter.call(node.classList, function (c) { return c.indexOf("__td") !== 0 && c.length < 40; }).slice(0, 2);
      if (cls.length) part += "." + cls.map(function (c) { return CSS.escape(c); }).join(".");
      var parent = node.parentElement;
      if (parent) {
        var same = Array.prototype.filter.call(parent.children, function (s) { return s.tagName === node.tagName; });
        if (same.length > 1) part += ":nth-of-type(" + (same.indexOf(node) + 1) + ")";
      }
      parts.unshift(part);
      node = parent;
    }
    return parts.join(" > ");
  }
  function describe(el) {
    var r = el.getBoundingClientRect();
    var cs = getComputedStyle(el);
    return {
      selector: selectorFor(el),
      tag: el.tagName.toLowerCase(),
      text: (el.innerText || "").trim().slice(0, 80),
      rect: { x: Math.round(r.left + scrollX), y: Math.round(r.top + scrollY), w: Math.round(r.width), h: Math.round(r.height) },
      computed: { color: cs.color, background: cs.backgroundColor, font: cs.fontSize + " " + cs.fontFamily.split(",")[0], padding: cs.padding, margin: cs.margin, radius: cs.borderRadius }
    };
  }
  function send(type, extra) {
    var ev = Object.assign({ type: type, page: location.pathname, tool: state.tool }, extra || {});
    state.pending++; renderPending();
    return post("/__td/event", ev).then(function () { logLine("gesture", type + (ev.selector ? " " + ev.selector : "")); });
  }

  // ---- panel -------------------------------------------------------------
  var panel = document.createElement("aside");
  panel.id = "__td-panel";
  panel.innerHTML =
    '<header><strong>theme-design</strong><span id="__td-presence" title="whether the Claude Code session is blocked on the poll right now"></span><span id="__td-pending" title="gestures and messages sent since Claude last replied"></span>' +
    '<button id="__td-toggle" title="collapse">–</button></header>' +
    '<nav id="__td-tools">' +
    '<button data-tool="select" class="on" title="click to select, then note / colour / resize">Select</button>' +
    '<button data-tool="move" title="drag an element; drop on a sibling to reorder">Move</button>' +
    '<button data-tool="text" title="double-click text to edit it">Text</button>' +
    '<select id="__td-skin" title="skin: how this wireframe could look in a library — a lookalike, not the library"></select>' +
    '</nav>' +
    '<section id="__td-inspector"><em>Nothing selected.</em></section>' +
    '<section id="__td-log"></section>' +
    '<form id="__td-chat"><textarea rows="2" placeholder="Tell Claude what to change… (Enter sends, Shift+Enter newline)"></textarea>' +
    '<div class="__td-row"><button type="submit">Send</button><button type="button" id="__td-end" title="ends the session and triggers export">End session</button></div></form>';
  document.documentElement.appendChild(panel);
  var hover = document.createElement("div"); hover.id = "__td-hover"; document.documentElement.appendChild(hover);
  var log = panel.querySelector("#__td-log");
  var inspector = panel.querySelector("#__td-inspector");
  var chat = panel.querySelector("#__td-chat");
  var textarea = chat.querySelector("textarea");

  function renderPending() {
    var el = panel.querySelector("#__td-pending");
    el.textContent = state.pending ? state.pending + " queued" : "";
  }
  function renderPresence() {
    var el = panel.querySelector("#__td-presence");
    el.className = state.listening ? "__td-on" : "__td-off";
    el.textContent = state.listening ? "listening" : "away";
    el.title = state.listening
      ? "Claude is blocked on the poll: the next thing you do is applied when it lands"
      : "No session is polling. What you send is kept; it is applied when the session polls again or when you type a prompt in that terminal";
  }
  function logLine(role, text) {
    var line = document.createElement("div");
    line.className = "__td-line __td-" + role;
    line.textContent = text;
    log.appendChild(line);
    log.scrollTop = log.scrollHeight;
  }
  function setPanel(open) {
    state.panelOpen = open;
    panel.classList.toggle("__td-collapsed", !open);
    sessionStorage.setItem("td-open", open ? "1" : "0");
  }
  panel.querySelector("#__td-toggle").addEventListener("click", function () { setPanel(!state.panelOpen); });
  setPanel(state.panelOpen);

  panel.querySelector("#__td-tools").addEventListener("click", function (e) {
    var b = e.target.closest("button[data-tool]"); if (!b) return;
    state.tool = b.dataset.tool;
    Array.prototype.forEach.call(panel.querySelectorAll("button[data-tool]"), function (x) { x.classList.toggle("on", x === b); });
    document.body.classList.toggle("__td-moving", state.tool === "move");
  });

  chat.addEventListener("submit", function (e) {
    e.preventDefault();
    var text = textarea.value.trim(); if (!text) return;
    var extra = { text: text };
    if (state.selected) extra.selector = selectorFor(state.selected);
    logLine("user", text);
    send("message", extra);
    textarea.value = "";
  });
  textarea.addEventListener("keydown", function (e) {
    if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); chat.requestSubmit(); }
  });
  panel.querySelector("#__td-end").addEventListener("click", function () {
    logLine("user", "(end session)");
    send("end", {});
  });

  // ---- inspector ---------------------------------------------------------
  function select(el) {
    if (state.selected) state.selected.classList.remove("__td-selected");
    removeHandles();
    state.selected = el;
    if (!el) { inspector.innerHTML = "<em>Nothing selected.</em>"; return; }
    el.classList.add("__td-selected");
    var d = describe(el);
    inspector.innerHTML =
      '<code>' + escapeHtml(d.selector) + '</code>' +
      '<div class="__td-meta">' + d.rect.w + '×' + d.rect.h + ' · ' + escapeHtml(d.computed.font) + ' · r ' + escapeHtml(d.computed.radius) + '</div>' +
      '<div class="__td-row"><label>bg <input type="color" data-prop="background-color" value="' + toHex(d.computed.background) + '"></label>' +
      '<label>text <input type="color" data-prop="color" value="' + toHex(d.computed.color) + '"></label></div>' +
      '<form class="__td-note"><input placeholder="note about this element…"><button>Note</button></form>';
    Array.prototype.forEach.call(inspector.querySelectorAll("input[type=color]"), function (inp) {
      // describe() must see the element BEFORE the preview lands, or `computed`
      // reports the picked colour and the token match in the skill has nothing to match.
      var from = null;
      inp.addEventListener("input", function () {
        if (!from) from = describe(el);
        el.style.setProperty(inp.dataset.prop, inp.value);
      });
      inp.addEventListener("change", function () {
        send("style", Object.assign(from || describe(el), { property: inp.dataset.prop, value: inp.value }));
        from = null;
      });
    });
    inspector.querySelector(".__td-note").addEventListener("submit", function (e) {
      e.preventDefault();
      var note = e.target.querySelector("input").value.trim(); if (!note) return;
      logLine("user", "note: " + note);
      send("annotate", Object.assign(describe(el), { text: note }));
      e.target.querySelector("input").value = "";
    });
    addHandles(el);
  }
  function escapeHtml(s) { return String(s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  function toHex(rgb) {
    var m = /rgba?\((\d+),\s*(\d+),\s*(\d+)/.exec(rgb || "");
    if (!m) return "#000000";
    return "#" + [m[1], m[2], m[3]].map(function (n) { return ("0" + (+n).toString(16)).slice(-2); }).join("");
  }

  // ---- hover + click -----------------------------------------------------
  document.addEventListener("mousemove", function (e) {
    if (state.drag || state.resize) return;
    var el = e.target;
    if (inPanel(el) || el === document.documentElement || el === document.body) { hover.style.display = "none"; return; }
    var r = el.getBoundingClientRect();
    hover.style.cssText = "display:block;left:" + (r.left + scrollX) + "px;top:" + (r.top + scrollY) + "px;width:" + r.width + "px;height:" + r.height + "px";
  }, true);
  document.addEventListener("click", function (e) {
    if (inPanel(e.target) || state.tool === "text") return;
    if (state.justDragged) { state.justDragged = false; e.preventDefault(); e.stopPropagation(); return; }
    if (e.target.closest("a, button, input, select, textarea") && !e.altKey) { e.preventDefault(); }
    e.preventDefault(); e.stopPropagation();
    if (state.tool === "select" || state.tool === "move") {
      var target = e.target === document.body || e.target === document.documentElement ? null : e.target;
      select(target);
      if (target) send("select", describe(target));
    }
  }, true);

  // ---- text edit ---------------------------------------------------------
  document.addEventListener("dblclick", function (e) {
    if (state.tool !== "text" || inPanel(e.target)) return;
    var el = e.target; if (!el.innerText) return;
    e.preventDefault();
    var before = el.innerText;
    el.contentEditable = "true"; el.focus();
    el.addEventListener("blur", function done() {
      el.contentEditable = "false";
      el.removeEventListener("blur", done);
      var after = el.innerText;
      if (after !== before) send("text", Object.assign(describe(el), { before: before.slice(0, 500), after: after.slice(0, 500) }));
    });
  }, true);

  // ---- move --------------------------------------------------------------
  document.addEventListener("mousedown", function (e) {
    if (state.tool !== "move" || inPanel(e.target) || e.button !== 0) return;
    var el = e.target; if (el === document.body) return;
    e.preventDefault();
    state.drag = { el: el, x: e.clientX, y: e.clientY, from: describe(el) };
    el.classList.add("__td-dragging");
  }, true);
  document.addEventListener("mousemove", function (e) {
    if (!state.drag) return;
    var d = state.drag;
    d.el.style.transform = "translate(" + (e.clientX - d.x) + "px," + (e.clientY - d.y) + "px)";
  });
  document.addEventListener("mouseup", function (e) {
    if (!state.drag) return;
    var d = state.drag; state.drag = null;
    d.el.classList.remove("__td-dragging");
    d.el.style.pointerEvents = "none";
    var under = document.elementFromPoint(e.clientX, e.clientY);
    d.el.style.pointerEvents = "";
    var dx = e.clientX - d.x, dy = e.clientY - d.y;
    if (Math.abs(dx) < 4 && Math.abs(dy) < 4) { d.el.style.transform = ""; return; }
    var target = under && !inPanel(under) && under !== d.el && !d.el.contains(under) ? under : null;
    while (target && target.parentElement !== d.el.parentElement && target !== document.body) target = target.parentElement;
    if (target === document.body) target = null;
    var placement = null;
    if (target) {
      var r = target.getBoundingClientRect();
      var before = (e.clientY - r.top) < r.height / 2 && (e.clientX - r.left) < r.width / 2;
      placement = { target: selectorFor(target), position: before ? "before" : "after", sibling: true };
    }
    // The browser fires `click` right after this mouseup only when mousedown and
    // mouseup hit the same element; a drop on a sibling fires none, so the flag
    // must expire on its own or it eats the user's next real click.
    state.justDragged = true;
    setTimeout(function () { state.justDragged = false; }, 0);
    send("move", Object.assign(d.from, { dx: dx, dy: dy, drop: placement }));
    // Preview: a sibling drop reorders in place; a free drop keeps the translate until reload.
    if (placement) {
      d.el.style.transform = "";
      target.insertAdjacentElement(placement.position === "before" ? "beforebegin" : "afterend", d.el);
    }
  });

  // ---- resize ------------------------------------------------------------
  function removeHandles() { Array.prototype.forEach.call(document.querySelectorAll(".__td-handle"), function (h) { h.remove(); }); }
  function addHandles(el) {
    var h = document.createElement("div"); h.className = "__td-handle";
    positionHandle(h, el);
    document.documentElement.appendChild(h);
    h.addEventListener("mousedown", function (e) {
      e.preventDefault(); e.stopPropagation();
      var r = el.getBoundingClientRect();
      state.resize = { el: el, h: h, x: e.clientX, y: e.clientY, w: r.width, hh: r.height, from: describe(el) };
    });
  }
  function positionHandle(h, el) {
    var r = el.getBoundingClientRect();
    h.style.left = (r.right + scrollX - 6) + "px"; h.style.top = (r.bottom + scrollY - 6) + "px";
  }
  document.addEventListener("mousemove", function (e) {
    if (!state.resize) return;
    var s = state.resize;
    s.el.style.width = Math.max(8, s.w + e.clientX - s.x) + "px";
    s.el.style.height = Math.max(8, s.hh + e.clientY - s.y) + "px";
    positionHandle(s.h, s.el);
  });
  document.addEventListener("mouseup", function () {
    if (!state.resize) return;
    var s = state.resize; state.resize = null;
    var r = s.el.getBoundingClientRect();
    send("resize", Object.assign(s.from, { to: { w: Math.round(r.width), h: Math.round(r.height) } }));
  });

  // ---- SSE ---------------------------------------------------------------
  var es = new EventSource("/__td/events");
  es.onmessage = function (e) {
    var msg; try { msg = JSON.parse(e.data); } catch (err) { return; }
    if (msg.type === "assistant") { state.pending = 0; renderPending(); logLine("assistant", msg.text); }
    if (msg.type === "presence") { state.listening = !!msg.listening; renderPresence(); }
    if (msg.type === "reload") setTimeout(function () { location.reload(); }, 150);
  };
  fetch("/__td/transcript").then(function (r) { return r.text(); }).then(function (t) {
    t.split("\n").filter(Boolean).slice(-40).forEach(function (line) {
      var m = /^- \*\*(user|assistant)\*\* \([^)]*\): (.*)$/.exec(line);
      if (m) logLine(m[1], m[2]);
    });
  });
  var skinSel = panel.querySelector("#__td-skin");
  fetch("/__td/state").then(function (r) { return r.json(); }).then(function (s) {
    state.pending = s.pending || 0; renderPending();
    state.listening = !!s.listening; renderPresence();
    (s.skins || []).forEach(function (name) {
      var o = document.createElement("option"); o.value = name; o.textContent = "skin: " + name; skinSel.appendChild(o);
    });
    if (s.skin) skinSel.value = s.skin;
    skinSel.hidden = !(s.skins || []).length;
  });
  skinSel.addEventListener("change", function () {
    var name = skinSel.value;
    post("/__td/skin", { name: name, page: location.pathname }).then(function (r) {
      if (r && r.ok) logLine("gesture", "skin " + name + " (lookalike of its defaults, not the library)");
    });
  });

  window.__td = { state: state, selectorFor: selectorFor, send: send };
})();
