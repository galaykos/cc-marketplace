---
name: playwright-docs
description: Use when writing or debugging Playwright automation — resolve the current API from live docs before coding, navigate by area, and apply Playwright conventions.
---

## Memory is stale here by design

Playwright ships on a fast, roughly monthly minor cadence (current stable is the
1.6x line — verify the exact number this session, do not trust this figure).
Whole call styles that recall suggests are now discouraged: `page.$` / `page.$$`
and `ElementHandle` are marked "discouraged, use Locator objects and web-first
assertions instead"; `page.waitForTimeout` is a documented anti-pattern. Every
method name, option, and version literal in your output must come from a page
fetched THIS session, not recall. If playwright.dev is unreachable, say so and
ask for a docs excerpt — never fill the gap from memory.

## Resolving the current version

- Fetch https://playwright.dev/docs/release-notes — the top section is the
  current stable version. Or run `npx playwright --version` in the repo.
- Grep the codebase for the installed pin: `@playwright/test` and `playwright`
  in `package.json` and the lockfile. Flag drift when the pin trails the current
  stable line by several minors — new locators and options won't exist there.
- Language variants live under sibling roots: `/python`, `/java`, `/dotnet`
  (e.g. https://playwright.dev/python/docs/intro). Method casing differs per
  language (`getByRole` in JS/TS, `get_by_role` in Python) — fetch the variant
  that matches the target codebase, not the JS docs by default.

## The link map

Start from the area page, not search — fetch and follow from these roots; if a
path 404s (docs get reshuffled), recover from https://playwright.dev/docs/intro:

| Task smells like | Start here (under /docs/) |
|---|---|
| First install, project setup | intro, writing-tests |
| Finding elements | locators (reference: api/class-locator) |
| Waiting / flakiness | actionability (auto-waiting model) |
| Web-first assertions | test-assertions (`expect(locator)`) |
| Intercept / mock / measure traffic | network (`page.route`, route.fulfill/abort) |
| Reuse a logged-in session | auth (storageState save/reload) |
| Test runner, fixtures, config | test-configuration, test-fixtures |
| Run tests in parallel | test-parallel (workers, fullyParallel) |
| Debug a run after the fact | trace-viewer-intro |
| Attach to an existing browser | api/class-browsertype (`connectOverCDP`) |
| Isolation boundary per session | browser-contexts |

## Conventions the docs enforce

- **Locators over raw selectors.** Prefer user-facing, resilient locators:
  `getByRole` first, then `getByText` / `getByLabel`, and `getByTestId` when
  role/text can't identify the element. A Locator re-queries the DOM on each use,
  so it never goes stale the way an `ElementHandle` does. The full built-in set
  is `getByRole`, `getByText`, `getByLabel`, `getByPlaceholder`, `getByAltText`,
  `getByTitle`, `getByTestId` — verify the exact names against the locators page
  for the target language, since Python/Java use snake/camel differently.
- **Web-first assertions.** Use `expect(locator).toBeVisible()`,
  `toHaveText()`, `toHaveValue()` — they auto-retry until the condition holds
  or the timeout expires. Never assert on a snapshotted value read once. These
  are distinct from generic non-retrying assertions like `expect(value)`.
- **Auto-waiting, not sleeps.** Playwright runs actionability checks before
  every action: visible, stable (bounding box steady across two frames),
  enabled, editable, and receives events (the element is the hit target, not
  covered by an overlay). Different actions need different subsets — `click`
  needs all of them, `fill` only visible/enabled/editable. Let these run; do
  not paper over timing with `waitForTimeout`.
- **One BrowserContext per isolated session.** A context is an incognito-like
  profile with its own cookies and storage; use one per user/session so state
  never leaks between them. `browser.newContext()` is cheap, and the test
  runner gives each test a fresh context automatically.
- **CDP attach is Chromium-only.** `browserType.connectOverCDP(endpointURL)`
  attaches to an already-running Chromium over the DevTools Protocol; it is
  explicitly unsupported for WebKit/Firefox. The endpoint is an HTTP or ws URL
  such as `http://localhost:9222/`. This is the seam for anti-detect browsers —
  see the playwright-patterns skill for the composition.

## Reading a reference page

- The class pages under `api/` are the authoritative signatures: `class-page`,
  `class-locator`, `class-browsercontext`, `class-browsertype`, `class-route`,
  `class-response`. When recall and a guide disagree, the class page wins.
- Options are keyword arguments on the method — check the reference for the
  exact option name and default (e.g. `page.route`, `newContext`,
  `connectOverCDP` all take an options object) rather than guessing.
- Deprecated vs discouraged is a real distinction here: `ElementHandle` and
  `page.$` are "discouraged" (still work, actively steered away from), while a
  handful of older APIs are hard-deprecated. Read the callout at the top of the
  page before recommending a call.

## When the task is anti-detect automation

Playwright does not launch the fingerprinted browser — an anti-detect tool
(AdsPower, Kameleo) does, then exposes a CDP endpoint. Playwright's job is only
to attach via `connectOverCDP` and drive it with the same locators and
auto-waiting as any other target. Getting the endpoint (start-profile call,
`ws.puppeteer` / `debug_port`) is that tool's concern — reference
`the `cmd-adspower-check` skill` and `the `cmd-kameleo-check` skill`. This skill owns the Playwright side.

## Anti-patterns (closer)

- Any method name, option, or version written from memory instead of a fetched
  page — the fast release cadence is the whole reason this skill exists.
- `page.waitForTimeout` / fixed sleeps to "let the page settle."
- `page.$` / `page.$$` / `ElementHandle` for interaction or assertion — the docs
  mark these discouraged; reach for a Locator.
- Brittle deep CSS-nth or absolute XPath chains instead of role/text/testid.
- Reading a value once and asserting on it, bypassing auto-retrying `expect`.
- Not awaiting an action or assertion — Playwright calls are async; a missing
  `await` silently drops the wait and the check.
- Sharing one BrowserContext across unrelated sessions, leaking auth and state.
- Assuming `connectOverCDP` works on Firefox/WebKit — Chromium only.
