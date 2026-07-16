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
    'http://preview.localhost/',
    'file:///Users/dev/app/index.html',
  ]) {
    assert.equal(classifyUrl(u).local, true, u);
    assert.equal(classifyUrl(u).category, 'local', u);
  }
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

test('a metadata target warns with the SSRF/credential wording and is refused', () => {
  const r = evaluateEgressGuard({ urls: [{ role: 'target', url: 'http://169.254.169.254/' }], ack: false });
  assert.equal(r.ok, false);
  assert.match(r.warnings[0], /METADATA/);
  assert.match(r.warnings[0], /exfiltrate/i);
});

test('an internal target is refused without ack', () => {
  const r = evaluateEgressGuard({ urls: [{ role: 'target', url: 'http://10.0.0.5:3000/' }], ack: false });
  assert.equal(r.ok, false);
  assert.match(r.warnings[0], /INTERNAL/);
});
