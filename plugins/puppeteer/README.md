# puppeteer

Puppeteer automation navigator and patterns library. Puppeteer moves fast and
each release couples to a bundled Chrome build, so this plugin's rule is
absolute: every API name, option, and version comes from a page fetched in the
current session (pptr.dev), never from memory.

Covers the Page API, robust waits (`waitForSelector` / `waitForFunction` /
Locators), request interception and resource blocking, `puppeteer-extra` stealth
for fingerprint hardening, and attaching to a running Chrome over CDP via
`puppeteer.connect({ browserWSEndpoint })`.

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
/puppeteer:check log into the staging dashboard and scrape the reports table
```

Reports something like: the current Puppeteer major to install,
`waitForSelector` for the login form, request interception to block images and
analytics for speed, `puppeteer-extra-plugin-stealth` for fingerprint
hardening, `$$eval` to extract the table, and a `try/finally` cleanup that
closes what the run opened.

### Worked example — stealth on a launched browser

```js
const { addExtra } = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
const puppeteer = addExtra(require('puppeteer'));
puppeteer.use(StealthPlugin());

const browser = await puppeteer.launch();
const page = await browser.newPage();

await page.setRequestInterception(true);
page.on('request', req =>
  ['image', 'font', 'media'].includes(req.resourceType())
    ? req.abort()
    : req.continue());

await page.goto('https://dashboard.example.com', { waitUntil: 'networkidle2' });
await page.waitForSelector('#username', { visible: true });
// ... drive the page ...

await browser.close();            // close what you launched
```

## What the skills enforce

- Current major from pptr.dev, never memory; `puppeteer` vs `puppeteer-core`
  and the bundled-Chrome coupling made explicit; old lockfile pins flagged
- A link map into the reference (Page API, waits, interception, connect /
  ConnectOptions, Locators) with 404 recovery from the API root
- Robust waits over sleeps; navigation waits armed via `Promise.all`
- Request interception that resolves every branch; resource blocking for speed
- `puppeteer-extra` + stealth as a headless-tell reducer, not invisibility
- Connect discipline: `connect({ browserWSEndpoint })`, `defaultViewport:
  null`, and `disconnect()` (never `close()`) for a browser you attached to

A reminder hook nudges toward `/puppeteer:check` when a prompt mentions
Puppeteer, pptr, browserWSEndpoint, puppeteer-extra, or setRequestInterception.

## Pairs well with

- **playwright** — the sibling automation navigator; same discipline, different
  driver
- **automation-builder** — assembles multi-step automation flows on top of these
  patterns
- **api-docs-first** — the generic docs-before-code discipline; puppeteer is its
  automation-specialized sibling
