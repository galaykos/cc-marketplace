---
name: playwright-patterns
description: Use when building or reviewing a Playwright automation — robust selectors, auto-wait discipline, network control, auth reuse, parallelism, and connecting to an anti-detect browser over CDP.
---

## Selector strategy — resilience first

Order by how tightly the selector couples to the user's contract, not the DOM:

1. **Role + accessible name** — `getByRole('button', { name: 'Sign in' })`.
   Survives markup refactors; fails loudly when accessibility breaks.
2. **Visible text / label** — `getByText`, `getByLabel` for content and form
   fields the user actually reads.
3. **Test id** — `getByTestId('checkout-submit')` when role/text can't
   disambiguate. It's an explicit contract, so it's stable, but it's invisible
   to users — use it as the escape hatch, not the default.
4. **Raw CSS/XPath** — last resort, and never deep `nth-child` chains or
   absolute XPath; they break on the first layout change.

Scope with chaining and filtering rather than global selectors:
`page.getByRole('listitem').filter({ hasText: 'Order 42' }).getByRole('button')`.
Never touch `page.$` / `ElementHandle` for interaction — the docs mark them
discouraged and they go stale when the DOM re-renders.

## Waiting — auto-wait, never fixed sleeps

- Actions auto-wait on actionability (visible, stable, enabled, editable,
  receives events). You do not add a wait before a `click` or `fill`.
- Assert with web-first, auto-retrying matchers: `expect(locator).toBeVisible()`,
  `toHaveText()`, `toHaveCount()`. They poll until true or timeout.
- Need to wait on the network, not the DOM? `page.waitForResponse(urlOrPredicate)`
  — start the promise BEFORE the click that triggers the request, then await it:

  ```js
  const resp = page.waitForResponse('**/api/orders');
  await page.getByRole('button', { name: 'Refresh' }).click();
  await resp;
  ```

- `waitForTimeout` is the flakiness anti-pattern. If you think you need it, you
  need a `waitForResponse`, an `expect(...).toBeVisible()`, or `waitForLoadState`.

## Network control — page.route

`page.route(url, handler)` intercepts matching requests; the handler picks one:

- `route.abort()` — block it (kill trackers, images, whole third-party hosts to
  speed a run or reduce a fingerprint surface).
- `route.fulfill({ status, body })` — mock the response without hitting the
  server; deterministic fixtures, error-path testing.
- `route.continue(overrides?)` — let it through, optionally rewriting URL,
  method, headers, or post data.

Measure by observing rather than intercepting: `page.on('response', ...)` or a
scoped `waitForResponse`. Register routes before the navigation that triggers
them, and unroute (`page.unroute`) when a phase no longer needs the handler.

## Auth reuse — storageState

Authenticating on every run is slow and brittle. Do it once, persist, reload:

```js
// once, after logging in:
await context.storageState({ path: 'auth/state.json' });
// per session thereafter:
const context = await browser.newContext({ storageState: 'auth/state.json' });
```

`storageState` captures cookies, localStorage, and IndexedDB. Under the test
runner, put the login in a **setup project** (`auth.setup.ts`) and declare it as
a `dependency` of the test projects, which then set `storageState` in their
config — login runs once, all tests start authenticated. Treat the state file
as a secret: git-ignore it and refresh it before it expires.

## Parallelism and isolation

- Tests run in worker processes; separate workers cannot share state. Turn on
  `fullyParallel: true` to parallelize within files too, or scope it with
  `test.describe.configure({ mode: 'parallel' })`.
- Control worker count with `workers` (config) or `--workers` (CLI); `workers: 1`
  serializes when a resource can't be shared.
- Isolation is per BrowserContext: one context per user/session, never shared
  across unrelated flows. Key per-worker fixtures off `testInfo.workerIndex` so
  parallel workers don't collide on the same test account or data row.

## Anti-detect composition — connect over CDP

When the target is a fingerprinted profile from AdsPower or Kameleo, Playwright
does NOT launch it. The anti-detect tool launches the browser and exposes a CDP
endpoint; Playwright attaches:

```js
const browser = await chromium.connectOverCDP(endpointURL);
const context = browser.contexts()[0] ?? await browser.newContext();
const page = context.pages()[0] ?? await context.newPage();
```

- `connectOverCDP` is **Chromium-only** — WebKit/Firefox are unsupported.
- The endpoint is the tool's, not yours: AdsPower's `browser/start` returns
  `ws.puppeteer` / `debug_port`; Kameleo's started profile exposes a debug port.
  Getting it is out of scope here — call `the `cmd-adspower-check` skill` or `the `cmd-kameleo-check` skill`.
- On an attached browser, prefer the EXISTING context (`browser.contexts()[0]`)
  so you drive the fingerprinted profile, not a fresh detectable one.
- Do NOT `browser.close()` a profile you attached to — you'd kill the anti-detect
  session. Close only pages/contexts you created; let the tool own the browser
  lifecycle.

## Data extraction, errors, cleanup

- Extract through locators: `locator.textContent()`, `allTextContents()`,
  `getAttribute()`, `locator.count()`. For structured pulls, `locator.evaluateAll`
  maps over matched nodes in one call.
- Wrap flows in try/finally; on failure capture evidence —
  `page.screenshot()` and a trace — before tearing down.
- Turn on tracing where it pays: `trace: 'on-first-retry'` in config records a
  trace only when a test retries, then `npx playwright show-trace` (or the HTML
  report) replays every action. Pair with `retries` on CI.
- Cleanup: close pages and contexts YOU opened. For a launched browser, close
  it; for a `connectOverCDP` attach, leave the browser to its owner.

## Review checklist

- No `waitForTimeout`, no `page.$` / `ElementHandle`, no deep CSS-nth/XPath.
- Locators lead with role/text/label; testid only where needed.
- Assertions are web-first (`expect(locator)...`), always awaited.
- Routes registered before their navigation; auth reused via `storageState`.
- One context per session; parallel workers don't share accounts.
- CDP attach is Chromium-only and never closes the borrowed browser.
