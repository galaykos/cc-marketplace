#!/usr/bin/env node
// terse-shrink — an MCP stdio proxy that trims prose out of a server's tool
// catalog before it reaches the model.
//
// A large MCP server spends 5-15k tokens of always-on context describing itself.
// Most of that is prose the dispatcher does not need: "This tool allows you to
// …", "Please note that …", hedges, and restatements of the tool name.
//
// OPT-IN, and nothing wires it for you. Point an MCP server's command at this
// file with the real command as arguments:
//
//   "mcpServers": {
//     "fs": { "command": "node",
//             "args": ["<plugin>/scripts/shrink.mjs", "npx", "-y", "@some/mcp-server"] } }
//
// WHAT IT CHANGES: the `description` field of entries in tools/list, prompts/list
// and resources/list responses. Nothing else. Names, input schemas, arguments,
// results and every request travelling upstream pass through byte-for-byte —
// a proxy that edited a schema would change what the model can call, not just
// what it reads.
//
// WHY IT IS CONSERVATIVE BY DEFAULT: a tool description is the routing signal.
// Stripping articles saves a few percent and can flip which tool the model
// picks, so the default pass removes only filler phrases, hedges and
// self-referential preambles. TERSE_SHRINK_AGGRESSIVE=1 adds article dropping
// for parity with a full caveman-style pass — measurably smaller, measurably
// riskier, and off unless you ask.
//
// FAIL-OPEN: any parse error, any unexpected shape, and the line is forwarded
// untouched. A proxy that drops a message breaks the server it was meant to make
// cheaper.
import { spawn } from 'node:child_process';

const [, , cmd, ...args] = process.argv;
if (!cmd) {
  process.stderr.write('terse-shrink: usage: shrink.mjs <command> [args...]\n');
  process.exit(2);
}

const AGGRESSIVE = process.env.TERSE_SHRINK_AGGRESSIVE === '1';

// Spans that must survive verbatim: fenced blocks, inline code, URLs, paths,
// {placeholders}, and ALL_CAPS identifiers. They are lifted out, the prose is
// rewritten, then they are put back.
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

  // Placeholder is printable on purpose: a control-character sentinel works at
  // runtime but turns this source file into something git calls binary and an
  // editor refuses to render. `@@n@@` cannot appear in a description that was
  // not already broken.
  const held = [];
  let s = text.replace(PROTECT, (m) => `@@${held.push(m) - 1}@@`);

  for (const [re, to] of REPLACE) s = s.replace(re, to);
  for (const re of FILLER) s = s.replace(re, '');
  if (AGGRESSIVE) s = s.replace(/\b(?:a|an|the)\s+/gi, '');

  s = s.replace(/[ \t]{2,}/g, ' ').replace(/\n{3,}/g, '\n\n').trim();
  // Deleting a mid-sentence preamble leaves a lowercase sentence start; re-cap
  // the head and anything after terminal punctuation.
  s = s.replace(/(^|[.!?]\s+)([a-z])/g, (_, lead, ch) => lead + ch.toUpperCase());
  s = s.replace(/@@(\d+)@@/g, (_, i) => held[Number(i)]);

  // Never hand back an empty description: an entry the model cannot read is
  // worse than a verbose one.
  return s.length ? s : text;
}

function shrinkPayload(obj) {
  const r = obj?.result;
  if (!r || typeof r !== 'object') return obj;
  for (const key of ['tools', 'prompts', 'resources', 'resourceTemplates']) {
    if (Array.isArray(r[key])) {
      for (const entry of r[key]) {
        if (entry && typeof entry.description === 'string') {
          entry.description = squeeze(entry.description);
        }
      }
    }
  }
  return obj;
}

const child = spawn(cmd, args, { stdio: ['pipe', 'pipe', 'inherit'] });
child.on('error', (e) => {
  process.stderr.write(`terse-shrink: cannot start upstream: ${e.message}\n`);
  process.exit(1);
});
child.on('exit', (code, signal) => process.exit(signal ? 1 : (code ?? 0)));

process.stdin.pipe(child.stdin); // requests upstream: never touched

let buf = '';
child.stdout.on('data', (chunk) => {
  buf += chunk.toString('utf8');
  let nl;
  while ((nl = buf.indexOf('\n')) !== -1) {
    const line = buf.slice(0, nl);
    buf = buf.slice(nl + 1);
    if (!line.trim()) { process.stdout.write('\n'); continue; }
    let out = line;
    try {
      out = JSON.stringify(shrinkPayload(JSON.parse(line)));
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
