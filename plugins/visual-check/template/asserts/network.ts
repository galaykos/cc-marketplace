// Category 4 — network failures (spec D11.4 / redteam).
// Flag failed requests (4xx/5xx responses, broken images/assets). The hard part
// is distinguishing a REAL failure from a TRANSIENT blip and from INFRA death:
//   - retry a failed request once; if it recovers → transient, NOT a hard fail.
//   - if it still 4xx/5xx or the asset is still broken → a hard `fail` finding.
//   - if the retry cannot connect (server died mid-run) → INFRA → the run is
//     `error` (exit 2), never `fail` (exit 1) — a dead dev server is not a UI bug.
// Capture is attached ONCE before driving; the classifier is a PURE function of
// the captured failures + an injected retry, so it is unit-testable browserless.

import type { Page } from '@playwright/test';
import { firstLine } from './util.ts';

export type NetFailure = { url: string; status: number | null; detail: string };
export type NetResult = { findings: string[]; infra: string[]; transient: string[] };
export type RetryOutcome = { ok: boolean; status: number | null } | null;
export type RetryFn = (url: string) => Promise<RetryOutcome>;

type RequestFailure = { errorText?: string } | null;
type NetRequest = { url(): string; failure(): RequestFailure };
type NetResponse = { url(): string; status(): number };
export type NetworkEmitter = {
  on(event: 'response', handler: (resp: NetResponse) => void): void;
  on(event: 'requestfailed', handler: (req: NetRequest) => void): void;
};

export type NetworkCapture = {
  /** Failures captured since the previous `drain()` (per-step attribution). */
  drain: () => NetFailure[];
  all: () => NetFailure[];
};

/** True when an error text signals the origin is unreachable — infra, not a UI fault. */
export function isInfraError(detail: string): boolean {
  return /ECONNREFUSED|ECONNRESET|ERR_CONNECTION_REFUSED|ERR_CONNECTION_RESET|ERR_CONNECTION_CLOSED|ERR_EMPTY_RESPONSE|ERR_ADDRESS_UNREACHABLE|ERR_NAME_NOT_RESOLVED|ERR_SOCKET_NOT_CONNECTED|socket hang up/i.test(
    detail,
  );
}

/** Attach response + requestfailed capture. Records only genuine failures. */
export function captureNetwork(page: Page | NetworkEmitter): NetworkCapture {
  const failures: NetFailure[] = [];
  let cursor = 0;
  const emitter = page as NetworkEmitter;
  emitter.on('response', (resp) => {
    const status = resp.status();
    if (status >= 400) failures.push({ url: resp.url(), status, detail: `HTTP ${status}` });
  });
  emitter.on('requestfailed', (req) => {
    const f = req.failure();
    failures.push({ url: req.url(), status: null, detail: (f && f.errorText) || 'request failed' });
  });
  return {
    drain: () => {
      const out = failures.slice(cursor);
      cursor = failures.length;
      return out;
    },
    all: () => failures.slice(),
  };
}

/**
 * Classify captured failures, retrying each once. Deduped by URL. An initial
 * connection-level error, or a retry that throws / cannot connect, is INFRA
 * (server down). A retry that comes back ok is TRANSIENT. Anything still failing
 * is a hard FINDING. Pure aside from the injected `retry`.
 */
export async function evaluateNetwork(failures: NetFailure[], retry: RetryFn): Promise<NetResult> {
  const out: NetResult = { findings: [], infra: [], transient: [] };
  const seen = new Set<string>();
  for (const f of failures) {
    if (seen.has(f.url)) continue;
    seen.add(f.url);

    if (isInfraError(f.detail)) {
      out.infra.push(`network infra: ${f.url} unreachable (${f.detail})`);
      continue;
    }

    let outcome: RetryOutcome;
    try {
      outcome = await retry(f.url);
    } catch (err) {
      out.infra.push(`network infra: ${f.url} died on retry (${firstLine(err)})`);
      continue;
    }

    if (outcome && outcome.ok) {
      out.transient.push(`transient: ${f.url} recovered on retry (was ${f.detail})`);
    } else {
      const stillDetail = outcome && outcome.status != null ? `HTTP ${outcome.status}` : f.detail;
      out.findings.push(`network failure: ${f.url} (${stillDetail})`);
    }
  }
  return out;
}

/** Live retry through Playwright's request context, then classify. */
export async function checkNetwork(page: Page, failures: NetFailure[]): Promise<NetResult> {
  return evaluateNetwork(failures, async (url) => {
    const resp = await page.request.get(url, { timeout: 5_000, failOnStatusCode: false });
    return { ok: resp.ok(), status: resp.status() };
  });
}
