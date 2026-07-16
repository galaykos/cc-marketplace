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
  off?(event: 'response' | 'requestfailed', handler: (arg: never) => void): void;
};

export type NetworkCapture = {
  /** Failures captured since the previous `drain()` (per-step attribution). */
  drain: () => NetFailure[];
  all: () => NetFailure[];
  /** Detach the response/requestfailed listeners — stops the capture leaking. */
  dispose: () => void;
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
  const onResponse = (resp: NetResponse) => {
    const status = resp.status();
    if (status >= 400) failures.push({ url: resp.url(), status, detail: `HTTP ${status}` });
  };
  const onFailed = (req: NetRequest) => {
    const f = req.failure();
    const detail = (f && f.errorText) || 'request failed';
    // net::ERR_ABORTED is an intentional cancellation (navigation, aborted fetch),
    // not a real failure — drop it so it never becomes a finding.
    if (/ERR_ABORTED/i.test(detail)) return;
    failures.push({ url: req.url(), status: null, detail });
  };
  emitter.on('response', onResponse);
  emitter.on('requestfailed', onFailed);
  return {
    drain: () => {
      const out = failures.slice(cursor);
      cursor = failures.length;
      return out;
    },
    all: () => failures.slice(),
    dispose: () => {
      emitter.off?.('response', onResponse as never);
      emitter.off?.('requestfailed', onFailed as never);
    },
  };
}

/**
 * Classify captured failures, retrying each once. Deduped by URL. An initial
 * connection-level error — or a retry that throws one — is INFRA (server down).
 * A retry that throws anything else (timeout/abort) or comes back still 4xx/5xx
 * is a hard FINDING. A null retry outcome is inconclusive → INFRA, never a fail.
 * A retry that comes back ok is TRANSIENT. Pure aside from the injected `retry`.
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
      const detail = firstLine(err);
      // Only a connection-level throw means the origin died (infra). A retry that
      // times out or is aborted is the asset STILL failing — a hard fail.
      if (isInfraError(detail)) {
        out.infra.push(`network infra: ${f.url} died on retry (${detail})`);
      } else {
        out.findings.push(`network failure: ${f.url} (retry failed: ${detail})`);
      }
      continue;
    }

    if (outcome == null) {
      // Retry produced no verdict — inconclusive, not a persistent fail.
      out.infra.push(`network infra: ${f.url} retry inconclusive (no response)`);
    } else if (outcome.ok) {
      out.transient.push(`transient: ${f.url} recovered on retry (was ${f.detail})`);
    } else {
      const stillDetail = outcome.status != null ? `HTTP ${outcome.status}` : f.detail;
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
