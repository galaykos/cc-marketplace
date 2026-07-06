---
name: puppeteer-docs
description: Use when writing or debugging Puppeteer automation — resolve the current API from live docs before coding, navigate by area, and apply Puppeteer conventions.
---

## Memory is stale here by design

Puppeteer ships fast and, unlike a server API, each release couples to a
specific bundled Chrome build — an example written from recall targets a
Chrome/DevTools-Protocol surface that has since moved. Method names get renamed
or deprecated between majors (`waitForTimeout` is gone), Locators arrived as the
modern waiting API, and `puppeteer` vs `puppeteer-core` differ in whether a
browser downloads at install. Every method name, option, and version literal in
your output must come from a page fetched THIS session, not recall. If pptr.dev
is unreachable, say so and ask for a docs excerpt — never fill the gap from
memory.

## Resolving the current version

- Fetch https://pptr.dev — the header states the current major (25.x at time of
  writing; verify live, do not assume). The whole reason this skill exists is
  that this number moves.
- Puppeteer bundles a matched Chrome build; `puppeteer-core` does not download
  one and expects you to point at an existing binary. Know which the codebase
  uses before advising an install.
- Modern package managers block install scripts, so the browser may not have
  downloaded — `npx puppeteer browsers install` fetches it manually. A "browser
  not found" error is usually this, not a code bug.
- Grep lockfiles for `puppeteer` / `puppeteer-core` pins and flag versions far
  behind the current major — an old pin drags an old Chrome and old evasions.

## The link map

Start from the reference root, not search — fetch and follow from these; if a
path 404s (the site reshuffles), recover from https://pptr.dev/api:

| Task smells like | Start here |
|---|---|
| Any Page method | /api/puppeteer.page |
| Waiting for the DOM | /api/puppeteer.page.waitforselector, .waitforfunction |
| Navigation waits | /api/puppeteer.page.waitfornavigation |
| Running code in the page | /api/puppeteer.page.evaluate, .$eval, .$$eval |
| Blocking/mocking requests | /api/puppeteer.page.setrequestinterception |
| Launching a browser | /api/puppeteer.puppeteernode.launch |
| Attaching over CDP | /api/puppeteer.puppeteer.connect, .connectoptions |
| Modern waiting API | /api/puppeteer.page.locator (Locators) |
| Stealth / fingerprinting | puppeteer-extra + puppeteer-extra-plugin-stealth (npm) |
| Cooperative interception | /guides/network-interception |

## Core API conventions

- Everything is async: every `page.*` call returns a Promise — `await` it. An
  unawaited action is the top source of flaky, out-of-order automation.
- `launch(options)` starts a bundled browser; `connect({ browserWSEndpoint })`
  attaches to a running one. Both return a `Browser`; `browser.newPage()` gives
  a `Page`.
- `page.goto(url, { waitUntil })` navigates. `waitUntil` chooses the readiness
  signal (`load`, `domcontentloaded`, `networkidle0`/`networkidle2`) — pick the
  weakest signal that guarantees your target exists, not always `load`.
- Extraction runs in the page: `page.evaluate(fn, ...args)` returns serializable
  values only; `page.$eval(sel, fn)` / `page.$$eval(sel, fn)` scope a function
  to one or all matched elements. DOM nodes cannot cross back to Node.
- `page.$(sel)` / `page.$$(sel)` return element handles; remember to dispose
  handles you hold to avoid leaks.

## Waiting — the load-bearing decision

- `waitForSelector(sel, { visible, hidden, timeout })` waits for an element to
  appear (or leave). This is the default explicit wait.
- `waitForFunction(fn, { polling, timeout }, ...args)` waits until a predicate
  in the page is truthy — the escape hatch for "wait until this app state is
  true" that no selector expresses.
- `waitForNavigation({ waitUntil })` waits for the next navigation; pair it with
  the action that triggers it via `Promise.all`, never sequentially, or the
  navigation fires before you start waiting.
- Locators (`page.locator(sel)`) are the newer API: they auto-wait and retry the
  action, folding wait+act into one call. Prefer them for new code where the
  fetched docs show them; fall back to `waitFor*` for conditions they do not
  cover.

## Request interception basics

- `await page.setRequestInterception(true)` then `page.on('request', ...)`. Once
  enabled, EVERY request stalls until you call `.continue()`, `.abort()`, or
  `.respond()` on it — forget one branch and the page hangs.
- Use it to block heavy resources (images/fonts/media/analytics) for speed, or
  to mock a response. Filter on `request.resourceType()` or `request.url()`.
- With multiple handlers, use Cooperative Intercept Mode: pass a numeric
  priority to `continue`/`abort`/`respond` and guard with
  `request.isInterceptResolutionHandled()` synchronously before acting.
- Inspect `request.interceptResolutionState()` synchronously when you need to
  see whether an earlier handler already resolved the request; the returned
  `action` maps to the `InterceptResolutionAction` enum.

## Connecting over CDP

- `puppeteer.connect(options)` returns a `Browser` for an already-running
  instance instead of launching one. The key option is `browserWSEndpoint` (a
  `ws://` DevTools URL); `browserURL` lets Puppeteer discover the endpoint from
  an HTTP debugging port.
- Other `ConnectOptions` worth knowing from the reference: `defaultViewport`
  (`null` to inherit the real window size), `protocol` (`cdp` vs
  `webDriverBiDi`), `headers`, and `targetFilter`. Fetch
  /api/puppeteer.connectoptions for the current full list — do not assume.
- This is the seam anti-detect browsers plug into: they expose a CDP endpoint
  and you attach to it. The patterns skill owns that composition; obtaining the
  endpoint is /adspower:check or /kameleo:check territory.

## Anti-patterns

- Any method name, option, or version written from memory instead of a fetched
  page — the bundled-Chrome coupling is the whole reason this skill exists.
- Fixed sleeps: `waitForTimeout` (removed) or a bare `setTimeout` race instead
  of `waitForSelector` / `waitForFunction` / a Locator. Time is not a wait
  condition.
- Unawaited promises — actions fire out of order and errors vanish.
- Enabling interception and leaving a request branch without continue/abort/
  respond, hanging the page.
- Blocking resources you actually need (a site that lazy-loads content behind
  the very requests you aborted).
- Ignoring the bundled-Chromium version: an old pin means old Chrome behaviour
  and stale stealth evasions.
- Reaching for `puppeteer-core` without pointing it at a browser binary, then
  wondering why launch fails.
