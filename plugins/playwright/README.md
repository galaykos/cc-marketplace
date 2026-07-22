# playwright

Playwright automation navigator. Playwright ships on a fast, roughly monthly
cadence — locators get added, call styles get discouraged, options change — so
this plugin's rule is the same as its siblings: every method name, option, and
version comes from a page fetched on playwright.dev in the current session,
never from memory.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install playwright@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/playwright:check [automation-goal-or-api]` | Resolve the current stable version, the exact API surface (verified against the live reference), and the doc-backed patterns that apply — selectors, auto-waiting, network control, `storageState` auth, parallelism, tracing, and `connectOverCDP` |

## Authenticated sessions

The skills cover authenticating live Playwright MCP QA/E2E
sessions: pre-authenticated storage state by default (captured once by a human,
loaded via the MCP server's flags), or user-in-the-loop login as the fallback —
credentials are never typed by the model and never enter the transcript.

## What the skills enforce

- Current version from the release notes, never memory; installed pin flagged
  when it trails the current stable line
- Predefined link map per area (locators, auto-waiting, network, auth, test
  runner, trace viewer, `connectOverCDP`, browser contexts) with 404 recovery
- Resilient selectors (role → text/label → testid), web-first auto-retrying
  assertions, and auto-waiting instead of fixed sleeps
- Network control via `page.route` (abort / fulfill / continue), auth reuse via
  `storageState`, parallelism via workers and one context per session
- CDP attach discipline: `connectOverCDP` is Chromium-only; drive the existing
  context and close only what you opened

A reminder hook nudges toward `/playwright:check` when a prompt mentions
Playwright, `page.locator`, `getByRole`, `connectOverCDP`, or `BrowserContext`.

## Pairs well with

- **puppeteer** — the other CDP-driven automation library
- **automation-builder** — scaffolds the surrounding automation workflow
- **api-docs-first** — the generic docs-before-code discipline; playwright is
  its Playwright-specialized sibling
