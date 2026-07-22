---
name: automation-planning
description: Use when planning a browser automation or scraper before writing it — choose the tool, model the flow as steps, and sequence waits, extraction, error handling, and scale.
---

## Plan the automation before you write it

Coding-first automations rot fast. A selector that worked yesterday moves, the
target ships an anti-bot check, a session expires mid-run, a fixed `sleep`
turns flaky under load. Every one of those is a planning miss, not a coding
miss. Decide the tool, the flow, and the failure handling on paper first — then
the script is a transcription, not an experiment.

Two questions gate everything downstream: what is the goal (test, scrape,
recurring operation) and what does the target do to stop or throttle bots.
Answer those before naming a library.

## Tool decision tree

Walk it top to bottom; stop at the first branch that matches.

- **Testing a product you control, or need cross-browser coverage?** →
  **Playwright** — multi-language (Python, Node, .NET, Java), auto-waiting
  locators, a first-class test runner, trace viewer, and the widest browser
  reach (Chromium, Firefox, WebKit).
- **Chrome-only scripting or scraping in Node?** → **Puppeteer** —
  Chrome-centric with the smaller API surface; reach for `puppeteer-extra` and
  its stealth plugin when you need light evasion.
- **Let the language narrow the pick:**
  - Python / .NET / Java → Playwright.
  - Node → Puppeteer or Playwright.

If two options survive, prefer the one already in the repo's manifests over
introducing a new dependency — a second driver library in one project doubles
every pattern, fixture, and CI cache for no reach gain.

## Selector strategy

Decide how steps will find elements before writing the first one — selector
churn is the top maintenance cost of any automation:

- Prefer user-facing locators (role, label, visible text) over CSS chains;
  they survive markup refactors that rename classes and reshuffle wrappers.
- For an app you control, add stable `data-testid` hooks instead of binding to
  styling classes — then the automation and the UI can evolve independently.
- Never anchor to generated class names (CSS modules, utility hashes) or
  DOM position (`nth-child`) — both change without any visible UI change.

## Planning steps

Produce this sequence for the specific goal before writing code:

1. **State goal, target, and auth needs.** What data or action, on which
   site(s), behind what login. This frames every later choice.
2. **Pick the tool** via the decision tree above.
3. **Model the flow as discrete steps.** Break it into navigate → wait → act →
   extract units. Each step is one observable transition, nameable and
   independently retryable.
4. **Define a wait condition per step.** Selector visible, network idle, a
   specific response received — the concrete signal that the step is done.
   Never a fixed sleep: it is either too short (flaky) or too long (slow).
5. **Error, retry, and idempotency.** Decide which failures are transient
   (retry with backoff) versus fatal (stop). Make each step safe to re-run so a
   restart does not double-submit or double-scrape.
6. **Data extraction and storage.** Where extracted data lands (file, DB,
   queue), its shape, and how a partial run resumes without duplicating rows.
7. **Session and auth persistence.** Save storage state / cookies so runs
   reuse a login instead of re-authenticating every time; state where that
   session lives and when it expires.
8. **Concurrency, scale, and proxy strategy.** How many sessions run in
   parallel, whether each needs its own browser context and proxy, and which
   proxy pool to use when the target blocks datacenter IPs.
9. **Cleanup.** Always close pages, contexts, and browsers at the end —
   including on failure. Leaked instances leave headless browsers running and
   exhaust memory on the runner.

## Worked example

Goal: "Export the dashboard table from our staging site every night."

1. Single authenticated session, no cross-browser requirement, Node stack →
   **Puppeteer**.
2. Flow: launch → log in (persist storage state) → navigate to dashboard →
   wait for the table selector → extract rows → write CSV → close browser.
3. Transient navigation failures retry with backoff; the CSV write is
   idempotent per date so a re-run replaces rather than appends.

## Cross-references

Planning picks the tool; the tool plugins own its specifics. Once the tool is
chosen, pull details from the matching command instead of guessing here:

- `/playwright:check` — Playwright API, selectors, auto-wait, storage state.
- `/puppeteer:check` — Puppeteer and `puppeteer-extra` stealth patterns.
- `/api-docs-first:check` — verify any SDK or API against current official docs
  before coding the integration; never work an integration from memory.

## Anti-patterns

- Coding before choosing the tool — swapping driver libraries mid-project is a
  rewrite, not a patch.
- Hardcoded sleeps instead of explicit wait conditions.
- No proxy plan when the target blocks datacenter IPs — the run works locally
  and dies in production.
- Leaving browsers or pages running after a run — the silent resource leak.
- Scraping faster than the target tolerates — no rate limiting, no jitter; the
  fastest way to earn a block and lose the account.
- Storing no session state, so every run burns a fresh login and trips
  velocity-based defenses.
