import { test } from 'node:test';
import assert from 'node:assert/strict';
import { classifyUrl, evaluateEgressGuard, EGRESS_ACK_FLAG } from './url.ts';

// ---- Classification --------------------------------------------------------

test('localhost, loopback, bind-all, and file:// targets are all local', () => {
  for (const u of [
    'http://localhost:3000/',
    'http://127.0.0.1:5173/app',
    'http://[::1]:8080/',
    'http://0.0.0.0:4000/',
    'file:///Users/dev/app/index.html',
  ]) {
    assert.equal(classifyUrl(u).local, true, u);
    assert.equal(classifyUrl(u).category, 'local', u);
  }
});

test('only the BARE localhost is trusted — a *.localhost label is NOT local', () => {
  const c = classifyUrl('http://preview.localhost/');
  assert.equal(c.local, false);
  assert.equal(c.category, 'production');
});

test('only the exact 0.0.0.0 is bind-all — the rest of 0.0.0.0/8 is not local', () => {
  assert.equal(classifyUrl('http://0.0.0.0:4000/').category, 'local');
  const c = classifyUrl('http://0.1.2.3/');
  assert.equal(c.local, false);
  assert.equal(c.category, 'production');
});

test('IPv4-mapped IPv6 literals reclassify to their embedded v4 bucket', () => {
  assert.equal(classifyUrl('http://[::ffff:127.0.0.1]/').category, 'local');
  assert.equal(classifyUrl('http://[::ffff:10.0.0.5]/').category, 'internal');
  assert.equal(classifyUrl('http://[::ffff:192.168.1.1]/').category, 'internal');
  // The dangerous one: a metadata IP smuggled through a mapped literal stays metadata.
  assert.equal(classifyUrl('http://[::ffff:169.254.169.254]/').category, 'metadata');
});

test('cloud metadata endpoints classify as metadata (the SSRF class)', () => {
  assert.equal(classifyUrl('http://169.254.169.254/latest/meta-data/').category, 'metadata');
  assert.equal(classifyUrl('http://100.100.100.200/').category, 'metadata');
  assert.equal(classifyUrl('http://metadata.google.internal/computeMetadata/v1/').category, 'metadata');
});

test('private networks and link-local classify as internal', () => {
  assert.equal(classifyUrl('http://10.0.0.5:3000/').category, 'internal');
  assert.equal(classifyUrl('http://172.16.4.9/').category, 'internal');
  assert.equal(classifyUrl('http://192.168.1.20:8080/').category, 'internal');
  assert.equal(classifyUrl('http://169.254.10.10/').category, 'internal');
  assert.equal(classifyUrl('http://build.internal/').category, 'internal');
});

test('public hostnames and public IPs classify as production', () => {
  assert.equal(classifyUrl('https://app.example.com/dashboard').category, 'production');
  assert.equal(classifyUrl('https://8.8.8.8/').category, 'production');
});

test('an unparseable URL fails safe to non-local (production)', () => {
  const c = classifyUrl('not a url');
  assert.equal(c.local, false);
  assert.equal(c.category, 'production');
});

// ---- Guard evaluation ------------------------------------------------------

test('an all-local run passes with no warnings and no ack', () => {
  const r = evaluateEgressGuard({ urls: [{ role: 'target', url: 'http://localhost:3000/' }], ack: false });
  assert.equal(r.ok, true);
  assert.deepEqual(r.warnings, []);
});

test('a production target WARNS and is REFUSED without ack', () => {
  const r = evaluateEgressGuard({ urls: [{ role: 'target', url: 'https://app.example.com/' }], ack: false });
  assert.equal(r.ok, false);
  assert.equal(r.warnings.length, 1);
  assert.match(r.warnings[0], /PRODUCTION/);
  assert.match(r.reason ?? '', new RegExp(EGRESS_ACK_FLAG));
});

test('the same production target PROCEEDS (still warns) once acked', () => {
  const r = evaluateEgressGuard({ urls: [{ role: 'target', url: 'https://app.example.com/' }], ack: true });
  assert.equal(r.ok, true);
  assert.equal(r.warnings.length, 1);
});

test('an internal target is refused without ack but PROCEEDS once acked', () => {
  const url = 'http://10.0.0.5:3000/';
  const refused = evaluateEgressGuard({ urls: [{ role: 'target', url }], ack: false });
  assert.equal(refused.ok, false);
  assert.match(refused.warnings[0], /INTERNAL/);
  const acked = evaluateEgressGuard({ urls: [{ role: 'target', url }], ack: true });
  assert.equal(acked.ok, true);
});

test('a metadata target warns with the SSRF/credential wording and is refused', () => {
  const r = evaluateEgressGuard({ urls: [{ role: 'target', url: 'http://169.254.169.254/' }], ack: false });
  assert.equal(r.ok, false);
  assert.match(r.warnings[0], /METADATA/);
  assert.match(r.warnings[0], /exfiltrate/i);
});

test('a metadata target is HARD-BLOCKED — --ack-egress cannot acknowledge it', () => {
  const r = evaluateEgressGuard({ urls: [{ role: 'target', url: 'http://169.254.169.254/' }], ack: true });
  assert.equal(r.ok, false, 'ack must NOT unblock a metadata endpoint');
  assert.match(r.reason ?? '', /HARD-BLOCK/i);
  // The per-URL warning states the ack flag does not apply.
  assert.match(r.warnings[0], new RegExp(`CANNOT be overridden with ${EGRESS_ACK_FLAG}`));
});
