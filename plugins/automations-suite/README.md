# automations-suite

Meta-bundle: the browser-automation category in one install — the Playwright,
Puppeteer, AdsPower, Kameleo, and Camoufox navigators plus the
automation-builder planner and its browser-automation-engineer agent.
Uninstalls cleanly with `/automations-suite:uninstall`, which prunes the
plugins the bundle auto-installed.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install automations-suite@cc-plugins-marketplace
```

## What's included

- **playwright** — Playwright API navigator (`/playwright:check`): live-docs link map, robust-automation patterns, driving anti-detect browsers over CDP
- **puppeteer** — Puppeteer API navigator (`/puppeteer:check`): live-docs link map, stealth via puppeteer-extra, attaching over `browserWSEndpoint`
- **adspower** — AdsPower Local API navigator (`/adspower:check`): profile lifecycle, rate limits, handing the started browser to Playwright/Puppeteer
- **kameleo** — Kameleo Local API navigator (`/kameleo:check`): fingerprint → profile → start flow, CDP connection from Playwright/Puppeteer
- **camoufox** — Camoufox navigator (`/camoufox:check`): Python launch options (humanize, geoip, proxy), Playwright-Firefox integration, fingerprint injection
- **automation-builder** — planner + browser-automation-engineer agent (`/automation-builder:build`): turns an automation goal into a tool choice and sequenced plan, then scaffolds and runs it

## Commands

| Command | What it does |
|---------|--------------|
| `/automations-suite:uninstall` | Uninstall the bundle AND prune every plugin it auto-installed — manually installed plugins are never touched |

## Example

```bash
/automations-suite:uninstall    # dry-run preview, explicit confirm, then prune
```

## Pairs well with

- **api-docs-first** — the doc-verification discipline every navigator in this bundle defers to
- **testing** — test-quality review for the Playwright/Puppeteer suites you end up writing
- **debugging** — systematic root-causing when an automation flow breaks mid-run
