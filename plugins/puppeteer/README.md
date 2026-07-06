# puppeteer

Puppeteer automation navigator and patterns library. Puppeteer moves fast and
each release couples to a bundled Chrome build, so this plugin's rule is
absolute: every API name, option, and version comes from a page fetched in the
current session (pptr.dev), never from memory.

Covers the Page API, robust waits (`waitForSelector` / `waitForFunction` /
Locators), request interception and resource blocking, `puppeteer-extra` stealth
for fingerprint hardening, and attaching to an anti-detect browser (AdsPower,
Kameleo) over CDP via `puppeteer.connect({ browserWSEndpoint })`.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install puppeteer@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/puppeteer:check [automation-goal-or-api]` | Resolve the current Puppeteer major from live docs, map the goal to the right API, and report the robust-wait / interception / stealth / connect-over-CDP patterns it needs — all doc-backed |

## Example

```bash
/puppeteer:check log into a dashboard through my AdsPower profile and scrape the table
```

Reports something like: the current Puppeteer major to install, connecting with
`puppeteer.connect({ browserWSEndpoint, defaultViewport: null })` where the
endpoint comes from AdsPower's `browser/start` response (`ws.puppeteer`),
`waitForSelector` for the login form, request interception to block images and
analytics for speed, `puppeteer-extra-plugin-stealth` for fingerprint hardening,
`$$eval` to extract the table, and `disconnect()` (not `close()`) so the managed
session survives.

### Worked example — connect to AdsPower with stealth

```js
const { addExtra } = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
const puppeteer = addExtra(require('puppeteer-core'));
puppeteer.use(StealthPlugin());

// wsEndpoint comes from AdsPower browser/start -> data.ws.puppeteer
const browser = await puppeteer.connect({
  browserWSEndpoint: wsEndpoint,
  defaultViewport: null,          // keep the profile's real window size
});
const page = await browser.newPage();

await page.setRequestInterception(true);
page.on('request', req =>
  ['image', 'font', 'media'].includes(req.resourceType())
    ? req.abort()
    : req.continue());

await page.goto('https://dashboard.example.com', { waitUntil: 'networkidle2' });
await page.waitForSelector('#username', { visible: true });
// ... drive the page ...

await browser.disconnect();       // NOT close() — AdsPower owns the lifecycle
```

## What the skills enforce

- Current major from pptr.dev, never memory; `puppeteer` vs `puppeteer-core`
  and the bundled-Chrome coupling made explicit; old lockfile pins flagged
- A link map into the reference (Page API, waits, interception, connect /
  ConnectOptions, Locators) with 404 recovery from the API root
- Robust waits over sleeps; navigation waits armed via `Promise.all`
- Request interception that resolves every branch; resource blocking for speed
- `puppeteer-extra` + stealth as a headless-tell reducer, not invisibility
- Anti-detect composition: `connect({ browserWSEndpoint })`, `defaultViewport:
  null`, and `disconnect()` (never `close()`) for a managed session

A reminder hook nudges toward `/puppeteer:check` when a prompt mentions
Puppeteer, pptr, browserWSEndpoint, puppeteer-extra, or setRequestInterception.

## Pairs well with

- **playwright** — the sibling automation navigator; same discipline, different
  driver
- **adspower** / **kameleo** — obtain the `browserWSEndpoint` / CDP port this
  plugin connects to
- **camoufox** — a fingerprint-hardened Firefox alternative for anti-detect work
- **automation-builder** — assembles multi-step automation flows on top of these
  patterns
- **api-docs-first** — the generic docs-before-code discipline; puppeteer is its
  automation-specialized sibling
