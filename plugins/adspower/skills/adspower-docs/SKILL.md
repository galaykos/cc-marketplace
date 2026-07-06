---
name: adspower-docs
description: Use when integrating the AdsPower Local API — resolve current endpoints from live docs before coding, and apply the Local API conventions.
---

## Memory is stale here by design

The AdsPower Local API is a client on the user's own machine, and its port and
endpoint paths shift across AdsPower app versions — a path or port answered from
memory can be wrong on the very next release. Every endpoint path, port, and
response field in your output must come from a page fetched THIS session, not
recall. Verify against the live docs each session before writing code.

The Postman reference (documenter.getpostman.com) renders JavaScript-only, so a
plain fetch returns just the page title. Prefer the official static docs, which
fetch cleanly, and fall back to asking the user for an excerpt only if both are
unreachable — the api-docs-first rule. Do not invent endpoints beyond what a
fetched page confirms.

## Resolving the current endpoints

- Official docs (static, fetch these first):
  https://localapi-doc-en.adspower.com/ — "API Overview" and "Code Samples"
  sections carry the request/response examples.
- Postman reference (JS-only, needs a rendered browser):
  https://documenter.getpostman.com/view/45822952/2sB34hEzQH
- Confirm the app's configured API port in the AdsPower client (Settings →
  Local API). The default below is only a default — the user may have changed
  it, and older versions used different ports.

## Base URL and response envelope

- Base URL: `http://local.adspower.net:50325` (or `http://127.0.0.1:50325`).
  Both point at the local AdsPower client; there is no cloud host for this API.
- Every response uses the envelope `{ "code": 0, "msg": "...", "data": {...} }`.
  `code: 0` means success. A non-zero `code` is a failure — read `msg` for the
  reason and branch on `code`, never on the wording of `msg`.
- Local API, local-only: it listens on the machine running AdsPower, no cloud
  host. Auth is off by default; when "security verification" is enabled in the
  client, every call needs an `Authorization: Bearer <apiKey>` header.

## The endpoint map

Verify each name and path against the live doc before use — the shapes below are
the confirmed lifecycle endpoints, not an exhaustive list:

| Task | Endpoint (verify against live doc) |
|---|---|
| List profiles | `GET /api/v1/user/list` |
| Create / update / delete profile | profile CRUD under `/api/v1/user/` |
| List groups | group-list endpoint under `/api/v1/group/` |
| Start a browser | `GET /api/v1/browser/start?user_id=...` |
| Stop a browser | `GET /api/v1/browser/stop?user_id=...` |
| Check active / status | `GET /api/v1/browser/active?user_id=...` |

A profile is identified by its `user_id`; most browser calls take `user_id` as
a query parameter. Profile-list results are paginated — read the `data.list`
array and the paging fields the live doc names, don't assume a single page.

Some builds also accept the human-facing `serial_number` in place of `user_id`
on the same endpoints; prefer `user_id` as the stable identifier and only fall
back to `serial_number` when the live doc says a call requires it.

## What "start browser" returns

On success (`code: 0`), `/api/v1/browser/start` returns a `data` object with the
connection endpoints for the launched browser (verified response shape):

- `data.ws.puppeteer` — CDP WebSocket URL, e.g.
  `ws://127.0.0.1:9222/devtools/browser/...`. Use it for Puppeteer
  (`puppeteer.connect({ browserWSEndpoint })`) AND Playwright
  (`chromium.connectOverCDP(data.ws.puppeteer)`).
- `data.ws.selenium` — a `host:port` (e.g. `127.0.0.1:9333`) for Selenium's
  Chrome `debuggerAddress` option.
- `data.webdriver` — path to the matching WebDriver binary for that browser.
- `data.marionette_port` — Firefox remote-debugging port (newer patch builds).

Read these from the live response, not from memory. The adspower-patterns skill
owns how to hand these to a driver.

`browser/start` also accepts optional query flags the live doc lists — for
example a headless flag and a flag to disable loaded extensions. Check the doc
for the flags your goal needs rather than assuming defaults; a profile started
with the wrong flags connects fine but behaves differently than expected.

## Conventions

- Rate limit: roughly one request per second. Throttle every call — bursts get
  rejected, and the failure looks like a flaky API rather than your own pacing.
- Local-only: the API answers only on the machine running AdsPower. There is no
  remote auth to configure; if calls fail, the client is closed or the port is
  wrong, not a credential problem.
- Always stop what you start: a browser left running after `browser/start` is a
  resource leak. Pair every start with a stop, including on the failure path.
- Confirm the port from the client's settings before hardcoding it; treat the
  default port as a starting guess, not a guarantee.

## Anti-patterns

- Calling faster than the rate limit (≈1 req/s) and treating the resulting
  rejections as random flakiness instead of throttling.
- Leaving browsers running — starting profiles without a matching stop leaks
  processes and memory until the client is restarted.
- Assuming an endpoint path, port, or response field from memory instead of the
  live doc — the whole reason this skill exists is that they drift by version.
- Hardcoding `50325` without checking the app's configured API port; the user
  may run the Local API on a different port.
- Branching on `msg` text instead of the numeric `code`; `msg` wording is not a
  stable contract, `code` is.
- Treating the Postman page's empty JS-only fetch as "no docs" and inventing
  endpoints — name the gap and ask instead.
