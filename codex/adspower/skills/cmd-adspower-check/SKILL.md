---
name: cmd-adspower-check
description: "Use when the user asks to resolve the current AdsPower Local API endpoints and lifecycle for an automation task."
---

_This skill wraps the `/adspower:check` command; pass the command's input as the skill's argument (`$ARGUMENTS`)._


Invoke the adspower-docs skill from this plugin for $ARGUMENTS (an automation
goal — if empty, ask what is being built). Everything reported must come from
docs fetched now, not memory: the Local API port and endpoint paths change
across AdsPower versions.

1. Fetch the AdsPower Local API docs
   (https://documenter.getpostman.com/view/45822952/2sB34hEzQH). If the Postman
   page renders JS-only and returns little, say so and ask the user for the
   endpoint reference (api-docs-first rule) — do not invent endpoints.
2. Confirm the base URL (`http://local.adspower.net:50325` or
   `http://127.0.0.1:50325`) and the app's configured API port; note the
   `{ "code": 0, "msg", "data" }` envelope where `code: 0` means success.
3. Report, in order:
   - The exact endpoints for the goal: profile list (`/api/v1/user/list`),
     create/update/delete, group list, start (`/api/v1/browser/start`),
     stop (`/api/v1/browser/stop`), active (`/api/v1/browser/active`)
   - What **start** returns: `data.ws.puppeteer`, `data.ws.selenium`,
     `data.debug_port`, `data.webdriver`
   - The **CDP handoff**: `ws.puppeteer` → `puppeteer.connect`, or
     `debug_port` → Playwright `connectOverCDP` (see the `cmd-puppeteer-check` skill,
     the `cmd-playwright-check` skill for the driver side)
   - Constraints: the ~1 request/second rate limit, local-only (no cloud
     auth), and the always-stop-what-you-start rule
4. If the docs page is unreachable, name it, say what could not be verified,
   and ask for a docs excerpt — do not substitute memory for the missing page.

5. When endpoints, lifecycle, and handoff all resolved, ask via
   AskUserQuestion: "Proceed with the automation using these doc-backed
   endpoints now (Recommended)" / "Stop here — report only".
   Headless: report only.
