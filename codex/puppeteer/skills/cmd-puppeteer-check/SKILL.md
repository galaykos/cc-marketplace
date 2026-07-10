---
name: cmd-puppeteer-check
description: "Use when the user asks to resolve the current Puppeteer API and doc-backed patterns for an automation task."
---

_This skill wraps the `/puppeteer:check` command; pass the command's input as the skill's argument (`$ARGUMENTS`)._


Invoke the puppeteer-docs skill from this plugin for $ARGUMENTS (an automation
goal, a Page method, or an area like request interception — if empty, ask what
is being automated). Everything reported must come from pages fetched now, not
memory: Puppeteer versions move fast and couple to a bundled Chrome build.

1. Fetch https://pptr.dev and state the current major version, then note the
   bundled-Chrome coupling. Grep the codebase for `puppeteer`/`puppeteer-core`
   pins in lockfiles and flag versions far behind the current major.
2. Map $ARGUMENTS to an API area via the skill's link map and fetch the relevant
   reference pages (page API, waitForSelector/waitForFunction, request
   interception, puppeteer.connect / ConnectOptions, puppeteer-extra stealth).
3. Report, in order:
   - Current Puppeteer major to install, and the exact API surface involved
   - The **robust-wait** approach for the goal (explicit waits, never fixed
     sleeps) and whether request interception or resource blocking applies
   - If detection matters: the puppeteer-extra + stealth composition, and — for
     anti-detect browsers — `puppeteer.connect({ browserWSEndpoint })` with a
     pointer to the `cmd-adspower-check` skill or the `cmd-kameleo-check` skill to obtain the endpoint
   - Constraints that shape the code: await discipline, interception stall
     behaviour, cleanup (close pages/browser)
4. If any needed page is unreachable, name it, say what could not be verified,
   and ask for a docs excerpt — do not substitute memory for the missing page.

5. When the API version, patterns, and constraints all resolve, ask via
   AskUserQuestion: "Proceed with the task using these doc-backed API and
   patterns now (Recommended)" / "Stop here — report only".
   Headless: report only.
