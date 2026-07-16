// Category 2 — console + page errors (spec D11.2).
// A page that logs a `console.error` or throws an uncaught exception during the
// flow is broken even if it looks right. Capture is attached ONCE before the
// page is driven; each step that requests the `console` category `drain()`s the
// errors seen since the previous drain, so a finding is attributed to the step
// whose action provoked it.

import type { Page } from '@playwright/test';

// Minimal shape of the page-event surface the capture needs — lets the drain
// cursor be unit-tested with a fake page (no browser).
type ConsoleMsg = { type(): string; text(): string };
type PageErr = { message?: string };
export type ConsoleEmitter = {
  on(event: 'console', handler: (msg: ConsoleMsg) => void): void;
  on(event: 'pageerror', handler: (err: PageErr) => void): void;
};

export type ConsoleCapture = {
  /** Errors captured since the previous `drain()` (per-step attribution). */
  drain: () => string[];
  /** Every console/page error captured so far. */
  all: () => string[];
};

/** Attach console-error + uncaught-pageerror capture. Call once, before driving. */
export function captureConsole(page: Page | ConsoleEmitter): ConsoleCapture {
  const errors: string[] = [];
  let cursor = 0;
  const emitter = page as ConsoleEmitter;
  emitter.on('console', (msg) => {
    if (msg.type() === 'error') errors.push(`console.error: ${msg.text()}`);
  });
  emitter.on('pageerror', (err) => {
    errors.push(`pageerror: ${(err && err.message) || String(err)}`);
  });
  return {
    drain: () => {
      const out = errors.slice(cursor);
      cursor = errors.length;
      return out;
    },
    all: () => errors.slice(),
  };
}
