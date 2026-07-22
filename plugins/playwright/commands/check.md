---
description: Resolve the current Playwright API and doc-backed patterns for an automation task
argument-hint: [automation-goal-or-api]
---
<!-- generated from templates/navigator-check.md.tmpl by scripts/generate.sh — edit the template or .chassis.json, not this file -->

Invoke the `playwright-docs` skill from this plugin for $ARGUMENTS (an automation
goal, an API name, or a page interaction — if empty, ask what is being
automated). Everything reported must come from pages fetched now, not memory.

1. Fetch https://playwright.dev/docs and state the current stable version.
   Grep the codebase for the installed pin (`@playwright/test`, `playwright` in
   package.json / lockfiles) and flag drift from the current stable line.
2. Map $ARGUMENTS to a doc area via the skill's link map (locators,
   auto-waiting, network, auth/storageState, test runner, trace viewer,
   connectOverCDP, browser contexts) and fetch the relevant reference pages.
3. Report, in order:
   - Current version to target, and the exact API surface involved (method
     names verified against the fetched reference, not recalled)
   - The doc-backed patterns from the playwright-patterns skill that apply —
     selector strategy, auto-wait discipline, network control, auth reuse,
     parallelism, tracing
   - Constraints that shape the code: Chromium-only CDP, one context per
     isolated session, no fixed sleeps, web-first assertions

4. If any needed page is unreachable, name it, say what could not be verified,
   and ask for a docs excerpt — do not substitute memory for the missing page.

5. When the version, API, and patterns are all resolved, ask via AskUserQuestion:
   "Proceed with the task using these doc-backed APIs and patterns now
   (Recommended)" / "Stop here — report only". Headless: report only.
