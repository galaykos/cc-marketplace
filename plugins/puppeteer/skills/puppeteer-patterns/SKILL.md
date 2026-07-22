---
name: puppeteer-patterns
description: Use when building or reviewing a Puppeteer automation — robust waits, request interception, stealth, resource blocking, and connecting to a running Chrome via browserWSEndpoint.
---

## Scope

Reusable Puppeteer automation patterns. Verify
every API name against live docs first (puppeteer-docs skill / `/puppeteer:check`)
— the version couples to a bundled Chrome build and method names shift between
majors. The code shapes below are illustrative; confirm signatures for the major
the codebase pins before shipping.

## Robust waits, never sleeps

Fixed sleeps encode a guess about timing and break under load. Wait on the
actual condition:

- Element present/visible: `await page.waitForSelector('.result', { visible: true })`.
- Arbitrary page state: `await page.waitForFunction(() => window.__ready === true)`
  — the escape hatch when no selector expresses "the app finished".
- Navigation triggered by a click: bind the wait and the action together so the
  wait is armed before navigation fires:

```js
await Promise.all([
  page.waitForNavigation({ waitUntil: 'networkidle2' }),
  page.click('a.next'),
]);
```

- Prefer Locators (`page.locator(sel)`) for new code where the fetched docs show
  them: they auto-wait and retry the action, collapsing wait+act into one call.
- Choose the weakest `waitUntil` that guarantees your target: `domcontentloaded`
  for static markup, `networkidle2` for XHR-driven apps — `load` alone often
  fires before the content you want exists.

## Request interception — block and mock

Enable once, then handle every branch or the page hangs (an intercepted request
stalls until continued, aborted, or responded):

```js
await page.setRequestInterception(true);
page.on('request', req => {
  const type = req.resourceType();
  if (['image', 'font', 'media'].includes(type)) return req.abort();
  if (req.url().includes('analytics')) return req.abort();
  req.continue();
});
```

- Blocking images/fonts/media/analytics is the cheapest speed win for scraping
  — fewer bytes and fewer third-party beacons fire.
- Mock a response with `req.respond({ status, contentType, body })` to stub an
  API without touching the network.
- Multiple handlers: switch to Cooperative Intercept Mode — pass a numeric
  priority to `continue`/`abort`/`respond`, and check
  `req.isInterceptResolutionHandled()` synchronously before acting so two
  handlers do not both resolve the same request.

## Stealth with puppeteer-extra

For fingerprint hardening, wrap Puppeteer with `puppeteer-extra` and register the
stealth plugin. It layers evasions (navigator.webdriver masking, chrome.runtime
mock, plugins/mimetypes, WebGL vendor, UA/platform override, and more):

```js
const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
puppeteer.use(StealthPlugin());

const browser = await puppeteer.launch({ headless: true });
```

- To patch a non-default package (e.g. `puppeteer-core`) use `addExtra`:
  `const puppeteer = addExtra(require('puppeteer-core')); puppeteer.use(StealthPlugin())`.
- Stealth reduces trivial headless tells; it is not invisibility. Serious
  anti-bot defences still profile behaviour and TLS — pair with realistic
  pacing and rate limits.
- Individual evasions can be toggled via the plugin's `enabledEvasions` option
  when one interferes with the target site.

## Extraction and concurrency

- Extract in the page context: `page.$$eval('.row', els => els.map(e => e.textContent))`
  returns serializable data only — never a DOM node.
- Parallelise with multiple pages on one browser (`browser.newPage()`), but cap
  the pool: each page is a real tab and memory adds up. For isolation between
  jobs, use separate `browser.createBrowserContext()` contexts.
- Always clean up: `await page.close()` per job and `await browser.close()` at
  the end — and only `close()` a browser you `launch()`ed. See cleanup below.

## Attaching to a running Chrome — connect over CDP

When the automation drives an already-running Chrome (a debugging session, or a
browser some other tool manages), Puppeteer attaches to it over CDP instead of
launching its own:

```js
const browser = await puppeteer.connect({
  browserWSEndpoint: wsEndpoint,   // the running browser's DevTools ws:// URL
  defaultViewport: null,           // inherit the real window size
});
```

- Set `defaultViewport: null` so Puppeteer does not resize the managed window.
- Do NOT `browser.close()` a browser you only connected to — that kills the
  session for whoever owns it. Call `browser.disconnect()` to detach and leave
  the lifecycle to the owner.

## Cleanup and error handling

- Wrap the run in `try/finally`; in `finally`, `disconnect()` connected browsers
  and `close()` launched ones. A crashed script that leaks a browser process is
  the classic Puppeteer resource bug.
- Set a sane `protocolTimeout`/navigation timeout so a stuck page fails loudly
  instead of hanging a worker forever.
- On interception errors, ensure every code path resolves the request — an
  unhandled branch stalls the page and looks like a hang, not an error.

## Anti-patterns

- Fixed sleeps in place of `waitForSelector` / `waitForFunction` / a Locator.
- Enabling interception without continuing/aborting/responding every request.
- `browser.close()` on a browser you only connected to (use `disconnect()`).
- Resizing a managed window by omitting `defaultViewport: null` on connect.
- Treating stealth as a guarantee rather than a headless-tell reducer.
- Unbounded page pools that exhaust memory; leaked browsers on error paths.
