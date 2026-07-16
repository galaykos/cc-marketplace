// Browser-free unit tests for the four "not broken" assert categories (card 07).
// The browser-touching orchestration is thin; the classification logic is pure
// and is exercised here with fakes so the categories are provable without a run.

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { checkDom, type ExpectFn } from './dom.ts';
import { captureConsole, type ConsoleEmitter } from './console.ts';
import { evaluateLayout } from './layout.ts';
import { evaluateNetwork, isInfraError, type NetFailure } from './network.ts';

// --- DOM ---------------------------------------------------------------------

function fakePage(): { locator: (s: string) => { sel: string } } {
  return { locator: (sel: string) => ({ sel }) };
}
// expect() whose matchers pass for selectors in `pass`, else throw.
function fakeExpect(pass: Set<string>): ExpectFn {
  const mk = (sel: string) => {
    const ok = () => Promise.resolve();
    const bad = () => Promise.reject(new Error(`locator resolved to no element for ${sel}`));
    const f = pass.has(sel) ? ok : bad;
    return { toBeVisible: f, toBeHidden: f, toBeAttached: f, toHaveCount: f, toContainText: f };
  };
  return ((loc: { sel: string }) => mk(loc.sel)) as unknown as ExpectFn;
}

test('dom: all assertions hold → no findings', async () => {
  const findings = await checkDom(
    fakePage() as never,
    fakeExpect(new Set(['nav.sidebar'])),
    [{ selector: 'nav.sidebar', state: 'visible' }],
    100,
  );
  assert.deepEqual(findings, []);
});

test('dom: a failed visible assertion is reported with selector + state', async () => {
  const findings = await checkDom(
    fakePage() as never,
    fakeExpect(new Set()),
    [{ selector: '#sidebar', state: 'visible' }],
    100,
  );
  assert.equal(findings.length, 1);
  assert.match(findings[0], /#sidebar expected visible →/);
});

// --- Console -----------------------------------------------------------------

type Handlers = { console?: (m: { type(): string; text(): string }) => void; pageerror?: (e: { message?: string }) => void };
function fakeEmitter(h: Handlers): ConsoleEmitter {
  return {
    on: (event: string, handler: (arg: never) => void) => {
      if (event === 'console') h.console = handler as never;
      if (event === 'pageerror') h.pageerror = handler as never;
    },
  } as ConsoleEmitter;
}

test('console: captures console.error + pageerror; drain windows are per-step', () => {
  const h: Handlers = {};
  const cap = captureConsole(fakeEmitter(h));
  h.console!({ type: () => 'log', text: () => 'noise' }); // ignored (not error)
  h.console!({ type: () => 'error', text: () => 'widget failed' });
  const first = cap.drain();
  assert.deepEqual(first, ['console.error: widget failed']);
  h.pageerror!({ message: 'Uncaught TypeError: x is not a function' });
  const second = cap.drain();
  assert.deepEqual(second, ['pageerror: Uncaught TypeError: x is not a function']);
  assert.deepEqual(cap.drain(), []); // nothing new
  assert.equal(cap.all().length, 2);
});

// --- Layout ------------------------------------------------------------------

const cleanSnap = {
  scrollWidth: 1280, clientWidth: 1280, bodyText: 'content', imageCount: 0,
  regionSelector: null, region: null,
};

test('layout: horizontal overflow is flagged', () => {
  const f = evaluateLayout({ ...cleanSnap, scrollWidth: 3000 });
  assert.equal(f.length, 1);
  assert.match(f[0], /horizontal overflow/);
});

test('layout: blank render (no text, no images) is flagged', () => {
  const f = evaluateLayout({ ...cleanSnap, bodyText: '   ' });
  assert.deepEqual(f, ['blank render: body has no visible text or images']);
});

test('layout: zero-size and overlap on the asserted region are flagged', () => {
  const zero = evaluateLayout({ ...cleanSnap, regionSelector: '#x', region: { found: true, width: 0, height: 10, covered: false } });
  assert.match(zero[0], /zero-size render on #x/);
  const cover = evaluateLayout({ ...cleanSnap, regionSelector: '#x', region: { found: true, width: 50, height: 10, covered: true } });
  assert.match(cover[0], /overlap: #x is obscured/);
});

test('layout: a clean page yields no findings', () => {
  assert.deepEqual(evaluateLayout(cleanSnap), []);
});

// --- Network -----------------------------------------------------------------

test('network: a failure that recovers on retry is transient, not a hard fail', async () => {
  const fails: NetFailure[] = [{ url: 'http://h/asset.js', status: 503, detail: 'HTTP 503' }];
  const r = await evaluateNetwork(fails, async () => ({ ok: true, status: 200 }));
  assert.deepEqual(r.findings, []);
  assert.equal(r.transient.length, 1);
  assert.match(r.transient[0], /recovered on retry/);
});

test('network: a failure that stays 5xx on retry is a hard finding', async () => {
  const fails: NetFailure[] = [{ url: 'http://h/asset.png', status: 500, detail: 'HTTP 500' }];
  const r = await evaluateNetwork(fails, async () => ({ ok: false, status: 500 }));
  assert.equal(r.findings.length, 1);
  assert.match(r.findings[0], /network failure: http:\/\/h\/asset.png \(HTTP 500\)/);
  assert.deepEqual(r.transient, []);
});

test('network: a retry that cannot connect (server died) is infra, never a fail', async () => {
  const fails: NetFailure[] = [{ url: 'http://h/asset.png', status: 500, detail: 'HTTP 500' }];
  const r = await evaluateNetwork(fails, async () => { throw new Error('connect ECONNREFUSED 127.0.0.1:3000'); });
  assert.deepEqual(r.findings, []);
  assert.equal(r.infra.length, 1);
  assert.match(r.infra[0], /died on retry/);
});

test('network: an initial connection-level failure is infra without a retry', async () => {
  const fails: NetFailure[] = [{ url: 'http://h/', status: null, detail: 'net::ERR_CONNECTION_REFUSED' }];
  let retried = false;
  const r = await evaluateNetwork(fails, async () => { retried = true; return { ok: true, status: 200 }; });
  assert.equal(retried, false, 'must not retry a dead-origin failure');
  assert.equal(r.infra.length, 1);
});

test('network: failures are deduped by url', async () => {
  const fails: NetFailure[] = [
    { url: 'http://h/a', status: 500, detail: 'HTTP 500' },
    { url: 'http://h/a', status: 500, detail: 'HTTP 500' },
  ];
  let calls = 0;
  const r = await evaluateNetwork(fails, async () => { calls++; return { ok: false, status: 500 }; });
  assert.equal(calls, 1);
  assert.equal(r.findings.length, 1);
});

test('network: isInfraError recognises connection-level codes only', () => {
  assert.equal(isInfraError('net::ERR_CONNECTION_REFUSED'), true);
  assert.equal(isInfraError('connect ECONNREFUSED'), true);
  assert.equal(isInfraError('HTTP 500'), false);
  assert.equal(isInfraError('net::ERR_FILE_NOT_FOUND'), false);
});
