# automation-builder

Browser-automation planner and worker. A think-process skill turns an
automation goal into a tool choice — Playwright or Puppeteer — and a sequenced
plan. A shared `browser-automation-engineer` agent then scaffolds and runs the
automation, verifying every API against current docs.

## Usage

```
/automation-builder:build <automation-goal>
```

Runs the `automation-planning` skill for the goal, presents the tool pick and a
sequenced plan, then offers to build it with the `browser-automation-engineer`
agent. Headless runs stop at the plan.

## Tool decision tree

- **Testing a product you control, or need cross-browser coverage?** →
  **Playwright** (multi-language, auto-wait, best DX, Chromium/Firefox/WebKit).
- **Chrome-only scripting or scraping in Node?** → **Puppeteer** (Chrome-centric,
  `puppeteer-extra` stealth).
- **Language:** Python / .NET / Java → Playwright; Node → Puppeteer or
  Playwright.

## Worked example

**Goal:** "Export the dashboard table from our staging site every night."

1. **Plan** — single authenticated session on a Node stack, no cross-browser
   requirement, so pick **Puppeteer**.
2. **Sequence** — launch → log in (persist storage state) → navigate to the
   dashboard → wait for the data selector → extract → store as CSV → close the
   browser. Transient navigation failures retry with backoff.
3. **Build** — the `browser-automation-engineer` verifies the Puppeteer API via
   `/puppeteer:check`, scaffolds the script with explicit waits and cleanup,
   then runs it against the authorized target and reports the output.

## Pairs well with

- **playwright** / **puppeteer** — driver-library specifics and patterns.
- **api-docs-first** — verify any SDK or API against current official docs
  before coding the integration.
