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

Three questions gate everything downstream: what is the goal (test, scrape,
multi-account operation), what does the target do to stop bots, and does the
run need to look like distinct real users. Answer those before naming a
library.

## Tool decision tree

Walk it top to bottom; stop at the first branch that matches.

- **Need anti-detect fingerprints or multi-account isolation?** (each session
  must present as a different real browser — distinct fingerprint, cookies,
  proxy). → An anti-detect browser:
  - **AdsPower** or **Kameleo** — commercial profile managers. They own the
    fingerprint and profile lifecycle and hand back a CDP endpoint that a
    driver library connects to. Kameleo ships a first-class .NET/Java SDK.
  - **Camoufox** — open-source, hardened Firefox. Self-contained: fingerprint
    spoofing and automation live in one Python package, no external manager.
- **Pure automation or testing, no fingerprint spoofing?** →
  - **Playwright** — multi-language (Python, Node, .NET, Java), auto-waiting,
    the best developer experience and cross-browser reach.
  - **Puppeteer** — Node, Chrome-centric; reach for `puppeteer-extra` and its
    stealth plugin when you need light evasion without a full anti-detect stack.
- **Let the language narrow the pick:**
  - Python → Playwright-python or Camoufox.
  - Node → Puppeteer or Playwright.
  - .NET / Java → Playwright or the Kameleo SDK.

If two options survive, prefer the one already in the repo's manifests over
introducing a new dependency.

## Architecture: who provides what

Keep the two layers straight — most integration confusion comes from blurring
them:

- The **anti-detect browser** (AdsPower, Kameleo) PROVIDES the browser instance
  and the fingerprint, then exposes a CDP endpoint.
- The **driver library** (Playwright, Puppeteer) PROVIDES the automation — it
  connects over that CDP endpoint and drives the page.
- **Camoufox merges both**: it is the browser and its Python API is the driver,
  so there is no endpoint to wire.

Wire order for the commercial anti-detect path: start the profile → get the CDP
endpoint → connect the driver over it → automate → stop the profile.

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
7. **Session and auth persistence.** Save storage state / cookies / profile so
   runs reuse a login instead of re-authenticating every time; state where that
   session lives and when it expires.
8. **Concurrency, scale, and proxy strategy.** How many sessions run in
   parallel, whether each needs its own profile and proxy, and which proxy pool
   to use when the target blocks datacenter IPs.
9. **Cleanup.** Always stop browsers and release/close profiles at the end —
   including on failure. Leaked instances exhaust the pool and leave headless
   browsers running.

## Cross-references

Planning picks the tool; the tool plugins own its specifics. Once the tool is
chosen, pull details from the matching command instead of guessing here:

- `the `cmd-playwright-check` skill` — Playwright API, selectors, auto-wait, storage state.
- `the `cmd-puppeteer-check` skill` — Puppeteer and `puppeteer-extra` stealth patterns.
- `the `cmd-adspower-check` skill` — AdsPower profile lifecycle and CDP endpoint.
- `the `cmd-kameleo-check` skill` — Kameleo profiles and SDK.
- `the `cmd-camoufox-check` skill` — Camoufox fingerprint and Python API.
- `the `cmd-api-docs-first-check` skill` — verify any SDK or API against current official docs
  before coding the integration; never work an integration from memory.

## Anti-patterns

- Coding before choosing the tool — retrofitting anti-detect onto a plain
  Playwright script mid-project is a rewrite, not a patch.
- Hardcoded sleeps instead of explicit wait conditions.
- No proxy plan when the target blocks datacenter IPs — the run works locally
  and dies in production.
- Leaving browsers or profiles running after a run — the silent resource leak.
- Scraping faster than the target tolerates — no rate limiting, no jitter; the
  fastest way to earn a block and lose the account.
- Storing no session state, so every run burns a fresh login and trips
  velocity-based defenses.
