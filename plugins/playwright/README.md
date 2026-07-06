# playwright

Playwright automation navigator. Playwright ships on a fast, roughly monthly
cadence — locators get added, call styles get discouraged, options change — so
this plugin's rule is the same as its siblings: every method name, option, and
version comes from a page fetched on playwright.dev in the current session,
never from memory. It also owns the Playwright side of driving an anti-detect
browser (AdsPower / Kameleo) over CDP.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install playwright@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/playwright:check [automation-goal-or-api]` | Resolve the current stable version, the exact API surface (verified against the live reference), and the doc-backed patterns that apply — selectors, auto-waiting, network control, `storageState` auth, parallelism, tracing, and `connectOverCDP` |

## Example — automate an AdsPower profile

```bash
/playwright:check log into a dashboard in an AdsPower profile and scrape the table
```

The anti-detect tool launches the fingerprinted browser and hands back a CDP
endpoint; Playwright attaches and drives it:

```js
// endpoint from AdsPower browser/start (see /adspower:check)
const browser = await chromium.connectOverCDP(endpointURL);
const context = browser.contexts()[0] ?? await browser.newContext();
const page = context.pages()[0] ?? await context.newPage();

await page.getByRole('link', { name: 'Reports' }).click();
await expect(page.getByRole('table')).toBeVisible();
const rows = await page.getByRole('row').allTextContents();
// leave the browser to AdsPower — close only what you opened
```

`connectOverCDP` is Chromium-only; use the profile's existing context so you
drive the fingerprinted session, not a fresh detectable one.

## What the skills enforce

- Current version from the release notes, never memory; installed pin flagged
  when it trails the current stable line
- Predefined link map per area (locators, auto-waiting, network, auth, test
  runner, trace viewer, `connectOverCDP`, browser contexts) with 404 recovery
- Resilient selectors (role → text/label → testid), web-first auto-retrying
  assertions, and auto-waiting instead of fixed sleeps
- Network control via `page.route` (abort / fulfill / continue), auth reuse via
  `storageState`, parallelism via workers and one context per session
- Anti-detect composition: attach over CDP, drive the existing context, never
  close the borrowed browser

A reminder hook nudges toward `/playwright:check` when a prompt mentions
Playwright, `page.locator`, `getByRole`, `connectOverCDP`, or `BrowserContext`.

## Pairs well with

- **puppeteer** — the other CDP-driven automation library; same anti-detect seam
- **adspower** / **kameleo** — launch the fingerprinted browser and expose the
  CDP endpoint that `connectOverCDP` attaches to
- **camoufox** — anti-detect Firefox option for automation targets
- **automation-builder** — scaffolds the surrounding automation workflow
- **api-docs-first** — the generic docs-before-code discipline; playwright is
  its Playwright-specialized sibling
