---
name: cmd-camoufox-check
description: "Use when the user asks to resolve the current Camoufox Python usage and launch options for an automation task."
---

_This skill wraps the `/camoufox:check` command; pass the command's input as the skill's argument (`$ARGUMENTS`)._


Invoke the camoufox-docs skill from this plugin for $ARGUMENTS (an automation
goal — if empty, ask what is being built). Everything reported must come from
pages fetched now, not memory: Camoufox is young and its launch options change.

1. Fetch the live docs — `https://camoufox.com/python/usage/` and
   `https://camoufox.com/python/installation/` (and `/python/config/` when
   fingerprint injection is in scope). State the current import path
   (`from camoufox.sync_api import Camoufox`) and the context-manager launch
   pattern verbatim from the page.
2. Map $ARGUMENTS to the launch options that shape it (`humanize`, `geoip`,
   `os`, `proxy`, `block_images`, `block_webrtc`, `config`,
   `persistent_context`, `addons`) and report each with its doc-verified type.
3. Report, in order:
   - The install + `camoufox fetch` step and the exact import/launch snippet
   - The launch options the goal needs, with types and what each controls
   - That the browser is a Playwright Firefox `Browser` — Playwright
     page/locator APIs apply unchanged (cross-reference `the `cmd-playwright-check` skill`)
   - Constraints that shape the code: Firefox-only (no Chromium/CDP), let
     Camoufox generate a consistent fingerprint rather than hand-setting values
4. If any needed page is unreachable, name it, say what could not be verified,
   and ask for a docs excerpt — do not substitute memory for the missing page.

5. When usage, launch options, and constraints all resolved, ask via
   AskUserQuestion: "Proceed with the task using these doc-backed usage and
   options now (Recommended)" / "Stop here — report only".
   Headless: report only.
