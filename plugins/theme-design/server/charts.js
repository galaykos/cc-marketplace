/* theme-design chart shapes — turns <div class="chart" data-kind="bars|line|area|ring|donut" data-values="3,5,2,8"
   [data-labels="Jan,Feb"] [data-max="10"] [data-color="var(--primary)"]> into an inline SVG that reads as data,
   not as a box. Prototype-only: no axes maths beyond min/max, no interaction. Served as /charts.js and copied by the
   export so the folder still renders from disk. */
(function () {
  "use strict";
  var NS = "http://www.w3.org/2000/svg";
  function el(name, attrs) { var n = document.createElementNS(NS, name); for (var k in attrs) n.setAttribute(k, attrs[k]); return n; }
  function nums(s) { return (s || "").split(",").map(function (x) { return parseFloat(x); }).filter(function (x) { return !isNaN(x); }); }
  function render(box) {
    if (box.querySelector("svg")) return;
    var kind = box.dataset.kind || "bars", v = nums(box.dataset.values), color = box.dataset.color || "var(--primary)";
    if (!v.length) return;
    var W = 100, H = 40, max = parseFloat(box.dataset.max) || Math.max.apply(null, v) || 1, pad = 2;
    var svg = el("svg", { viewBox: "0 0 " + W + " " + H, preserveAspectRatio: "none" });
    var x = function (i) { return pad + i * ((W - pad * 2) / Math.max(v.length - 1, 1)); };
    var y = function (n) { return H - pad - (n / max) * (H - pad * 2); };
    if (kind === "bars") {
      var bw = (W - pad * 2) / v.length;
      v.forEach(function (n, i) {
        svg.appendChild(el("rect", { x: pad + i * bw + bw * 0.15, y: y(n), width: bw * 0.7, height: H - pad - y(n), rx: 1, fill: color, opacity: i === v.length - 1 ? 1 : 0.7 }));
      });
    } else if (kind === "line" || kind === "area") {
      var pts = v.map(function (n, i) { return x(i) + "," + y(n); }).join(" ");
      if (kind === "area") svg.appendChild(el("polygon", { points: x(0) + "," + (H - pad) + " " + pts + " " + x(v.length - 1) + "," + (H - pad), fill: color, opacity: 0.15 }));
      svg.appendChild(el("polyline", { points: pts, fill: "none", stroke: color, "stroke-width": 1.5, "stroke-linejoin": "round", "stroke-linecap": "round", "vector-effect": "non-scaling-stroke" }));
      svg.appendChild(el("circle", { cx: x(v.length - 1), cy: y(v[v.length - 1]), r: 1.6, fill: color }));
    } else if (kind === "ring" || kind === "donut") {
      svg.setAttribute("viewBox", "0 0 40 40"); svg.setAttribute("preserveAspectRatio", "xMidYMid meet");
      var total = v.reduce(function (a, b) { return a + b; }, 0) || 1, r = 15.9, off = 25, c = 2 * Math.PI * r;
      svg.appendChild(el("circle", { cx: 20, cy: 20, r: r, fill: "none", stroke: "var(--muted)", "stroke-width": 6 }));
      var palette = [color, "var(--accent-foreground)", "var(--muted-foreground)", "var(--warning, #d97706)", "var(--success, #16a34a)"];
      v.forEach(function (n, i) {
        var len = (n / total) * c;
        svg.appendChild(el("circle", { cx: 20, cy: 20, r: r, fill: "none", stroke: palette[i % palette.length], "stroke-width": 6, "stroke-dasharray": len + " " + (c - len), "stroke-dashoffset": off, transform: "rotate(-90 20 20)", opacity: i ? 0.8 : 1 }));
        off -= len;
      });
      if (box.dataset.center) { var t = el("text", { x: 20, y: 22.5, "text-anchor": "middle", "font-size": 7, "font-weight": 700, fill: "currentColor" }); t.textContent = box.dataset.center; svg.appendChild(t); }
    }
    box.appendChild(svg);
    if (box.dataset.labels) {
      var lab = document.createElement("div"); lab.className = "chart-labels";
      lab.style.cssText = "display:flex;justify-content:space-between;font-size:.7rem;color:var(--muted-foreground);margin-top:4px";
      box.dataset.labels.split(",").forEach(function (l) { var s = document.createElement("span"); s.textContent = l.trim(); lab.appendChild(s); });
      box.appendChild(lab);
    }
  }
  function all() { Array.prototype.forEach.call(document.querySelectorAll(".chart[data-values]"), render); }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", all); else all();
  window.__tdCharts = { render: render, all: all };
})();
