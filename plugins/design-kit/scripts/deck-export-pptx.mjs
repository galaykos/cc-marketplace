#!/usr/bin/env node
// deck-export-pptx.mjs <deck.html> <out.pptx>
//
// WHAT IT DOES. Reads the native content of a design-kit deck — every
// <section class="slide"> with its data-title, data-notes, headings, list items,
// paragraphs, code blocks, big figures and data-URI images — and writes a PPTX
// with real text boxes and pictures via pptxgenjs, so the deck is editable in
// PowerPoint/Keynote/Google Slides. Not a screenshot exporter.
//
// WHAT IT DOES NOT DO. Fragments, transitions, nested-list indentation beyond one
// level and CSS theme colours are not carried; the theme's accent is read from
// --dk-accent when present, everything else is PowerPoint defaults. Driven by
// deck-export.sh, which owns the pptxgenjs install consent.
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";

const require = createRequire(process.env.NODE_PATH ? process.env.NODE_PATH + "/" : import.meta.url);
const [, , deckPath, outPath] = process.argv;
if (!deckPath || !outPath) {
  console.error("usage: deck-export-pptx.mjs <deck.html> <out.pptx>");
  process.exit(2);
}

const html = readFileSync(deckPath, "utf8");
const unescape = (s) => s.replace(/&quot;/g, '"').replace(/&#x27;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&");
const strip = (s) => unescape(s.replace(/<[^>]+>/g, "")).replace(/\s+\n/g, "\n").trim();
const attr = (block, name) => {
  const m = block.match(new RegExp(`${name}="([^"]*)"`));
  return m ? unescape(m[1]) : "";
};

const sections = [...html.matchAll(/<section class="slide[^"]*"[^>]*>[\s\S]*?<\/section>/g)].map((m) => m[0]);
if (!sections.length) {
  console.error("deck-export-pptx: no <section class=\"slide\"> found — is this a design-kit deck?");
  process.exit(4);
}
const accentMatch = html.match(/--dk-accent:\s*(#[0-9a-fA-F]{6})/);
const accent = accentMatch ? accentMatch[1].slice(1) : "245C9A";

const PptxGenJS = require("pptxgenjs");
const pptx = new PptxGenJS();
pptx.layout = "LAYOUT_16x9";
pptx.title = strip((html.match(/<title>([\s\S]*?)<\/title>/) || [, "Deck"])[1]);

for (const block of sections) {
  const slide = pptx.addSlide();
  const isTitle = /class="slide title"/.test(block);
  const title = attr(block, "data-title");
  const notes = attr(block, "data-notes");
  const body = block.replace(/<h[12][^>]*>[\s\S]*?<\/h[12]>/, "").replace(/<aside class="notes">[\s\S]*?<\/aside>/, "");

  slide.addText(title, { x: 0.6, y: isTitle ? 1.6 : 0.4, w: 8.8, h: isTitle ? 1.4 : 0.9, fontSize: isTitle ? 36 : 28, bold: true, color: "1B1A17" });
  let y = isTitle ? 3.1 : 1.4;

  const subtitle = body.match(/<div class="subtitle">([\s\S]*?)<\/div>/);
  if (subtitle && strip(subtitle[1])) {
    slide.addText(strip(subtitle[1]), { x: 0.6, y, w: 8.8, h: 0.8, fontSize: 18, color: "6B685F" });
    y += 0.9;
  }
  const items = [...body.matchAll(/<li[^>]*>([\s\S]*?)(?=<ul>|<ol>|<\/li>)/g)].map((m) => strip(m[1])).filter(Boolean);
  if (items.length) {
    slide.addText(items.map((t) => ({ text: t, options: { bullet: true, breakLine: true } })), { x: 0.6, y, w: 8.8, h: Math.min(3.8, 0.45 * items.length + 0.2), fontSize: 18, color: "1B1A17", valign: "top" });
    y += Math.min(3.8, 0.45 * items.length + 0.3);
  }
  for (const p of [...body.matchAll(/<p[^>]*>([\s\S]*?)<\/p>/g)].map((m) => strip(m[1])).filter(Boolean)) {
    slide.addText(p, { x: 0.6, y, w: 8.8, h: 0.6, fontSize: 18, color: "1B1A17" });
    y += 0.65;
  }
  for (const f of [...body.matchAll(/<div class="figure"><div class="value">([\s\S]*?)<\/div><div class="caption">([\s\S]*?)<\/div><\/div>/g)]) {
    slide.addText(strip(f[1]), { x: 0.6, y, w: 8.8, h: 1.4, fontSize: 60, bold: true, color: accent });
    slide.addText(strip(f[2]), { x: 0.6, y: y + 1.4, w: 8.8, h: 0.5, fontSize: 16, color: "6B685F" });
    y += 2.0;
  }
  for (const c of [...body.matchAll(/<pre><code[^>]*>([\s\S]*?)<\/code><\/pre>/g)].map((m) => unescape(m[1]))) {
    slide.addText(c, { x: 0.6, y, w: 8.8, h: 1.6, fontSize: 12, fontFace: "Courier New", color: "1B1A17", fill: { color: "F3F2EE" }, valign: "top" });
    y += 1.7;
  }
  for (const img of [...body.matchAll(/<img [^>]*src="(data:[^"]+)"/g)]) {
    slide.addImage({ data: img[1], x: 0.6, y, w: 4.5, h: 2.5, sizing: { type: "contain", w: 4.5, h: 2.5 } });
    y += 2.6;
  }
  if (notes) slide.addNotes(notes);
}

await pptx.writeFile({ fileName: outPath });
console.log(`deck-export-pptx: ${outPath} (${sections.length} slides)`);
