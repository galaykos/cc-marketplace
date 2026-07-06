# automation-builder

Browser-automation planner and worker. A think-process skill turns an
automation goal into a tool choice — Playwright/Puppeteer for pure automation,
or an anti-detect browser (AdsPower/Kameleo/Camoufox) when the run needs
fingerprint spoofing or multi-account isolation — and a sequenced plan. A shared
`browser-automation-engineer` agent then scaffolds and runs the automation,
verifying every API against current docs.

## Usage

```
/automation-builder:build <automation-goal>
```

Runs the `automation-planning` skill for the goal, presents the tool pick and a
sequenced plan, then offers to build it with the `browser-automation-engineer`
agent. Headless runs stop at the plan.

## Tool decision tree

- **Need anti-detect fingerprints or multi-account isolation?** → an anti-detect
  browser: **AdsPower** or **Kameleo** (commercial profile managers that hand a
  CDP endpoint to a driver), or **Camoufox** (open-source, self-contained
  Firefox).
- **Pure automation or testing, no fingerprint spoofing?** → **Playwright**
  (multi-language, auto-wait, best DX) or **Puppeteer** (Node, Chrome-centric,
  `puppeteer-extra` stealth).
- **Language:** Python → Playwright-python or Camoufox; Node → Puppeteer /
  Playwright; .NET / Java → Playwright or the Kameleo SDK.

The anti-detect browser provides the browser instance and fingerprint; the
driver library (Playwright/Puppeteer) provides the automation. Camoufox merges
both.

## Worked example

**Goal:** "Log into 20 accounts on a site that fingerprints browsers and export
each dashboard."

1. **Plan** — multi-account + fingerprinting means an anti-detect browser. The
   stack is Node, so pick **AdsPower** (profile per account) driven by
   **Puppeteer** over its CDP endpoint.
2. **Sequence** — per account: start profile → connect driver → wait for login
   form → authenticate (persist session) → navigate to dashboard → wait for the
   data selector → extract → store → stop profile. Concurrency capped, each
   profile on its own proxy.
3. **Build** — the `browser-automation-engineer` verifies the AdsPower and
   Puppeteer APIs via `/adspower:check` and `/puppeteer:check`, scaffolds the
   script with explicit waits and cleanup, then runs it against the authorized
   target and reports the output.

## Pairs well with

- **playwright** / **puppeteer** — driver-library specifics and patterns.
- **adspower** / **kameleo** / **camoufox** — anti-detect browser specifics.
- **api-docs-first** — verify any SDK or API against current official docs
  before coding the integration.
