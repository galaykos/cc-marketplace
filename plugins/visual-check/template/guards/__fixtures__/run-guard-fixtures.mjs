// Runtime demonstration of the URL/egress guard (spec D17). Pure Node — no browser,
// no network — so it runs anywhere the gate does. Exits non-zero if any assertion
// fails so it doubles as an integration check for `guards/url.ts`.
//
//   node guards/__fixtures__/run-guard-fixtures.mjs
//
// Proves the contract the card requires:
//   A. a PRODUCTION url          → warns + REFUSED without ack (needs --ack-egress)
//   B. that same url + ack       → PROCEEDS (warning still surfaced)
//   C. a cloud METADATA endpoint → warns (SSRF/credential wording) + refused
//   D. an INTERNAL private host  → warns + refused
//   E. a localhost DEV url       → NO warning, proceeds freely (no ack)
//   F. a file:// local target    → NO warning, proceeds freely (no ack)

import * as path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { classifyUrl, evaluateEgressGuard } from '../url.ts';

const here = path.dirname(fileURLToPath(import.meta.url));
const localFile = pathToFileURL(path.join(here, 'fixture.html')).href;

let failures = 0;
function check(label, cond, detail = '') {
  const tag = cond ? 'PASS' : 'FAIL';
  if (!cond) failures++;
  process.stdout.write(`  [${tag}] ${label}${detail ? ' — ' + detail : ''}\n`);
}

function guard(url, ack) {
  return evaluateEgressGuard({ urls: [{ role: 'target', url }], ack });
}

// A. production, no ack → warns + refused
process.stdout.write('\nA. production url, no ack:\n');
const a = guard('https://app.example.com/dashboard', false);
check('classified production', classifyUrl('https://app.example.com/dashboard').category === 'production');
check('refused (ok:false)', a.ok === false, a.reason);
check('warned', a.warnings.some((w) => /PRODUCTION/.test(w)));
check('reason points at --ack-egress', /--ack-egress/.test(a.reason || ''));

// B. production, WITH ack → proceeds, still warns
process.stdout.write('\nB. production url, --ack-egress:\n');
const b = guard('https://app.example.com/dashboard', true);
check('proceeds (ok:true)', b.ok === true, b.reason || '');
check('warning still surfaced', b.warnings.length === 1);

// C. cloud metadata → warns (SSRF wording) + refused
process.stdout.write('\nC. cloud metadata endpoint:\n');
const c = guard('http://169.254.169.254/latest/meta-data/', false);
check('classified metadata', classifyUrl('http://169.254.169.254/').category === 'metadata');
check('refused', c.ok === false);
check('SSRF/credential wording', c.warnings.some((w) => /METADATA/.test(w) && /exfiltrate/i.test(w)));

// D. internal private host → warns + refused
process.stdout.write('\nD. internal private host:\n');
const d = guard('http://10.0.0.5:3000/', false);
check('classified internal', classifyUrl('http://10.0.0.5:3000/').category === 'internal');
check('refused', d.ok === false);
check('warned INTERNAL', d.warnings.some((w) => /INTERNAL/.test(w)));

// E. localhost dev url → NO warning, proceeds
process.stdout.write('\nE. localhost dev url:\n');
const e = guard('http://localhost:3000/', false);
check('classified local', classifyUrl('http://localhost:3000/').category === 'local');
check('proceeds without ack', e.ok === true);
check('NO warning emitted', e.warnings.length === 0);

// F. file:// local target → NO warning, proceeds
process.stdout.write('\nF. file:// local target:\n');
const f = guard(localFile, false);
check('classified local', classifyUrl(localFile).local === true);
check('proceeds without ack', f.ok === true);
check('NO warning emitted', f.warnings.length === 0);

process.stdout.write(`\n${failures === 0 ? 'ALL GUARD FIXTURES PASSED' : failures + ' ASSERTION(S) FAILED'}\n`);
process.exit(failures === 0 ? 0 : 1);
