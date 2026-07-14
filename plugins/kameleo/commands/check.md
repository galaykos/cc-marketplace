---
description: Resolve the current Kameleo Local API/SDK usage for an automation task
argument-hint: [automation-goal]
---
<!-- generated from templates/navigator-check.md.tmpl by scripts/generate.sh — edit the template or .chassis.json, not this file -->

Invoke the `kameleo-docs` skill from this plugin for $ARGUMENTS (an automation
goal — if empty, ask what is being built). The Local API and its SDKs change
between Kameleo releases, so everything reported must come from docs fetched
now, not memory.

1. Fetch the Kameleo Local API reference
   (https://developer.kameleo.io/reference/api-reference/) and, if it renders
   JS-only, name the gap and ask for a docs excerpt or the swagger.json rather
   than filling it from memory.
2. Confirm the base URL (`http://localhost:5050`) and the official SDK for the
   caller's language (`kameleo-local-api-client` — Python/.NET/Node). Prefer the
   SDK over raw HTTP when a language SDK exists.
3. Map $ARGUMENTS onto the flow and report, in order:
   - The endpoints/SDK calls involved: search **fingerprints**, create a
     **profile** from a fingerprint, **start** the profile, stop it, and any
     profile-setting updates (canvas/WebGL/geolocation/timezone).
   - The full **fingerprint → profile → start → connect** flow.
   - The **driver handoff**: the CDP/WebSocket endpoint the started profile
     exposes, and how Playwright (`connectOverCDP`) or Puppeteer
     (`browserWSEndpoint`) attaches to it — defer the driver side to
     `/playwright:check` or `/puppeteer:check`.
   - Session hygiene: the Kameleo app must be running to serve the Local API;
     stop/clean up profiles when done.

4. If any needed page is unreachable, name it, say what could not be verified,
   and ask for a docs excerpt — do not substitute memory for the missing page.

5. When endpoints/SDK, flow, and handoff are all resolved, ask via AskUserQuestion:
   "Proceed with the task using these doc-backed endpoints now
   (Recommended)" / "Stop here — report only". Headless: report only.
