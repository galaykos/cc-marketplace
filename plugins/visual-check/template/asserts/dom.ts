// Category 1 — DOM / functional state (spec D11.1).
// Web-first Playwright assertions that prove the interaction actually worked
// (the sidebar opened/closed, the field holds the typed text). A tripped
// assertion is returned as a human-readable finding; the caller turns a
// non-empty finding list into a `fail` step + a `reasons[]` entry.

import type { Locator, Page } from '@playwright/test';
import { firstLine } from './util.ts';

export type DomState = 'visible' | 'hidden' | 'exists' | 'absent';
export type DomAssert = { selector: string; state: string; text?: string };

/** The only states `checkDom` knows how to assert — anything else is a config error. */
const KNOWN_STATES: ReadonlySet<string> = new Set(['visible', 'hidden', 'exists', 'absent']);

// The slice of Playwright's `expect(locator)` surface the DOM checks use.
// Modelled as an interface so the logic is unit-testable with a fake `expect`.
export type LocatorMatchers = {
  toBeVisible(o?: { timeout?: number }): Promise<void>;
  toBeHidden(o?: { timeout?: number }): Promise<void>;
  toBeAttached(o?: { timeout?: number }): Promise<void>;
  toHaveCount(n: number, o?: { timeout?: number }): Promise<void>;
  toContainText(t: string, o?: { timeout?: number }): Promise<void>;
};
export type ExpectFn = (locator: Locator) => LocatorMatchers;

/**
 * Evaluate the `expect.dom` assertions of a step. Each `{selector, state, text?}`
 * is checked with the matching web-first assertion (auto-retrying up to
 * `timeoutMs`). Returns one finding per failed assertion; an empty array means
 * every DOM expectation held.
 */
export async function checkDom(
  page: Page,
  expect: ExpectFn,
  asserts: DomAssert[],
  timeoutMs: number,
): Promise<string[]> {
  const findings: string[] = [];
  for (const a of asserts) {
    // An unknown/unsupported state (typo, or 'enabled'/'checked') must be a hard
    // finding — never silently coerced to `visible`, which would let it PASS.
    if (!KNOWN_STATES.has(a.state)) {
      findings.push(`${a.selector} unknown dom state '${a.state}'`);
      continue;
    }
    const loc = page.locator(a.selector);
    const opts = { timeout: timeoutMs };
    try {
      switch (a.state) {
        case 'hidden':
          await expect(loc).toBeHidden(opts);
          break;
        case 'exists':
          await expect(loc).toBeAttached(opts);
          break;
        case 'absent':
          await expect(loc).toHaveCount(0, opts);
          break;
        case 'visible':
        default:
          await expect(loc).toBeVisible(opts);
          break;
      }
      // A text assertion only makes sense for a present element — skip it for
      // `absent` (0 matches) and `hidden` (toContainText would spuriously fail).
      if (
        typeof a.text === 'string' &&
        a.text !== '' &&
        (a.state === 'visible' || a.state === 'exists')
      ) {
        await expect(loc).toContainText(a.text, opts);
      }
    } catch (err) {
      const label = a.text ? `${a.state} text~"${a.text}"` : a.state;
      findings.push(`${a.selector} expected ${label} → ${firstLine(err)}`);
    }
  }
  return findings;
}
