# adspower

AdsPower Local API navigator. AdsPower is an anti-detect browser that manages
browser profiles; its **Local API** runs on your own machine (default
`http://local.adspower.net:50325`, also `http://127.0.0.1:50325`) and controls
those profiles. This plugin's rule: the Local API's port and endpoint paths
drift across AdsPower versions, so every endpoint, port, and response field
comes from docs fetched in the current session, never from memory.

Covers the profile lifecycle — list/create a profile, start and stop its
browser, obtain the browser's CDP/WebSocket endpoint — and handing that started
browser to Playwright or Puppeteer to drive.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install adspower@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/adspower:check [automation-goal]` | Resolve the current Local API endpoints, the start/stop lifecycle, what `browser/start` returns, the CDP handoff to a driver, and the rate/cleanup constraints — all doc-backed |

## Example

```bash
/adspower:check start a profile and scrape a page with Puppeteer
```

Reports something like: the base URL and configured API port, the
`/api/v1/browser/start?user_id=...` call, the `{ code, msg, data }` envelope,
and that on `code: 0` the `data` carries `ws.puppeteer`, `debug_port`, and
`webdriver`. The worked handoff:

```js
// 1. Start the profile's browser (throttle: ~1 req/s)
const r = await fetch(
  'http://local.adspower.net:50325/api/v1/browser/start?user_id=' + userId
).then(x => x.json());
if (r.code !== 0) throw new Error('adspower: ' + r.msg);

// 2. Connect Puppeteer to the endpoint AdsPower handed back — connect, not launch
const browser = await puppeteer.connect({
  browserWSEndpoint: r.data.ws.puppeteer,
});

// 3. ...drive the page...

// 4. Always stop what you started
await fetch(
  'http://local.adspower.net:50325/api/v1/browser/stop?user_id=' + userId
);
```

## What the skills enforce

- Current endpoints and port from the live docs each session, never memory;
  the Postman-hosted reference is JS-only, so if a fetch returns nothing the
  gap is named and you are asked for the reference (never invented endpoints)
- The `{ code, msg, data }` envelope — branch on the numeric `code`, not `msg`
- The lifecycle: list/create profile → `browser/start` → read
  `ws.puppeteer`/`debug_port` → drive with a library → `browser/stop`
- The CDP handoff: `connect`, never `launch`, so the profile's fingerprint and
  proxy survive
- The ~1 request/second rate limit with a shared throttle and backoff
- Start/stop hygiene: every start paired with a `finally` stop, tracking ids so
  cleanup stops exactly what was started

A reminder hook nudges toward `/adspower:check` when a prompt mentions AdsPower,
the Local API port, anti-detect, or a browser profile.

## Pairs well with

- **playwright** — connect over CDP to the started browser's `debug_port`
- **puppeteer** — connect to the started browser's `ws.puppeteer` endpoint
- **kameleo** — another anti-detect browser with its own Local API
- **camoufox** — anti-detect Firefox automation
- **automation-builder** — assembles the end-to-end automation around this
- **api-docs-first** — the generic docs-before-code discipline; adspower is its
  AdsPower-specialized sibling
