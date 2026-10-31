#!/usr/bin/env node
// shrink.mjs <command> [args...] — opt-in MCP stdio proxy (an MCP server's command becomes node, this file, the real command): trims filler, hedges and preambles from the `description` of tools/list, prompts/list and resources/list responses, nothing else; TERSE_SHRINK_AGGRESSIVE=1 also drops articles.
// Misses: prose off its phrase lists; a catalog line carrying a 16+-digit integer passes unshrunk. Fails open: any parse error or unexpected shape forwards the line untouched.
// Why, limits, history: rationale/derivations/plugin-candor.md § plugins/candor/scripts/shrink.mjs
import { spawn } from 'node:child_process';
import { StringDecoder } from 'node:string_decoder';

const [, , cmd, ...args] = process.argv;
if (!cmd) {
  process.stderr.write('terse-shrink: usage: shrink.mjs <command> [args...]\n');
  process.exit(2);
}

const AGGRESSIVE = process.env.TERSE_SHRINK_AGGRESSIVE === '1';

// Fenced blocks, inline code, URLs, paths, {placeholders} and ALL_CAPS identifiers are lifted out, then put back verbatim.
const PROTECT = /```[\s\S]*?```|`[^`]*`|https?:\/\/\S+|\/[\w.-]+(?:\/[\w.-]+)+|\{[^}]*\}|\b[A-Z][A-Z0-9_]{2,}\b/g;

const FILLER = [
  /\bthis (?:tool|command|function|endpoint|resource|prompt) (?:allows you to|lets you|can be used to|is used to|will)\s*/gi,
  /\b(?:please )?note that\s*/gi,
  /\b(?:you can use this to|use this (?:tool )?(?:when|to))\s*/gi,
  /\b(?:just|simply|really|actually|basically|essentially|generally|quite|very)\s+/gi,
  /\b(?:it (?:is|'s) (?:worth|important) (?:noting|to note) that)\s*/gi,
  /\b(?:in order to)\b/gi,
  /\b(?:make sure to|be sure to)\b/gi,
  /\b(?:if (?:you )?(?:want|need) to,?)\s*/gi,
];
const REPLACE = [
  [/\bin order to\b/gi, 'to'],
  [/\bmake sure to\b/gi, 'ensure'],
  [/\bis able to\b/gi, 'can'],
  [/\bhas the ability to\b/gi, 'can'],
  [/\ba (?:large )?number of\b/gi, 'many'],
];

function squeeze(text) {
  if (typeof text !== 'string' || text.length < 40) return text;

  // Printable on purpose: a control-character sentinel makes git call this file binary.
  const held = [];
  let s = text.replace(PROTECT, (m) => `@@${held.push(m) - 1}@@`);

  for (const [re, to] of REPLACE) s = s.replace(re, to);
  for (const re of FILLER) s = s.replace(re, '');
  if (AGGRESSIVE) s = s.replace(/\b(?:a|an|the)\s+/gi, '');

  s = s.replace(/[ \t]{2,}/g, ' ').replace(/\n{3,}/g, '\n\n').trim();
  // A removed preamble leaves a lowercase sentence start.
  s = s.replace(/(^|[.!?]\s+)([a-z])/g, (_, lead, ch) => lead + ch.toUpperCase());
  s = s.replace(/@@(\d+)@@/g, (_, i) => held[Number(i)]);

  // An entry the model cannot read is worse than a verbose one.
  return s.length ? s : text;
}

// Only a response to a list request is a catalog: matching on shape rewrote `tools/call` results that carry a `resources` array.
const CATALOG_METHODS = new Set([
  'tools/list', 'prompts/list', 'resources/list', 'resources/templates/list',
]);
const pendingCatalog = new Set();

function noteRequest(line) {
  try {
    const msg = JSON.parse(line);
    const each = Array.isArray(msg) ? msg : [msg];
    for (const m of each) {
      if (m && CATALOG_METHODS.has(m.method) && m.id !== undefined) pendingCatalog.add(String(m.id));
    }
  } catch { /* not JSON we understand — nothing to remember */ }
}

// True only when a description changed; the caller re-serializes only then, as a JSON round-trip rounds integers above 2^53.
function shrinkPayload(obj) {
  if (!obj || obj.id === undefined || !pendingCatalog.delete(String(obj.id))) return false;
  const r = obj.result;
  if (!r || typeof r !== 'object') return false;
  let changed = false;
  for (const key of ['tools', 'prompts', 'resources', 'resourceTemplates']) {
    if (Array.isArray(r[key])) {
      for (const entry of r[key]) {
        if (entry && typeof entry.description === 'string') {
          const next = squeeze(entry.description);
          if (next !== entry.description) { entry.description = next; changed = true; }
        }
      }
    }
  }
  return changed;
}

const child = spawn(cmd, args, { stdio: ['pipe', 'pipe', 'inherit'] });
child.on('error', (e) => {
  process.stderr.write(`terse-shrink: cannot start upstream: ${e.message}\n`);
  process.exit(1);
});
child.on('exit', (code, signal) => process.exit(signal ? 1 : (code ?? 0)));

// Upstream requests pass byte-for-byte, read only for catalog ids. StringDecoder: a chunk boundary inside a multibyte character turns toString() halves into U+FFFD.
const inDecoder = new StringDecoder('utf8');
let inBuf = '';
process.stdin.on('data', (chunk) => {
  child.stdin.write(chunk);
  inBuf += inDecoder.write(chunk);
  let nl;
  while ((nl = inBuf.indexOf('\n')) !== -1) {
    noteRequest(inBuf.slice(0, nl));
    inBuf = inBuf.slice(nl + 1);
  }
  if (inBuf.length > 1e6) inBuf = ''; // a line this long is not a JSON-RPC request
});
process.stdin.on('end', () => child.stdin.end());

const outDecoder = new StringDecoder('utf8');
let buf = '';
child.stdout.on('data', (chunk) => {
  buf += outDecoder.write(chunk);
  let nl;
  while ((nl = buf.indexOf('\n')) !== -1) {
    const line = buf.slice(0, nl);
    buf = buf.slice(nl + 1);
    if (!line.trim()) { process.stdout.write('\n'); continue; }
    let out = line;
    try {
      const obj = JSON.parse(line);
      // Only when a description changed, and never with a 16+-digit integer on the line: rounding an id is worse than a verbose description.
      if (shrinkPayload(obj) && !/[0-9]{16,}/.test(line)) out = JSON.stringify(obj);
    } catch {
      out = line; // not JSON, or an unexpected shape — forward as-is
    }
    process.stdout.write(out + '\n');
  }
});
child.stdout.on('end', () => {
  if (buf) process.stdout.write(buf);
  process.stdout.end();
});
