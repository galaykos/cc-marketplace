---
name: cmd-api-docs-first-check
description: "Use when the user asks to check that current API docs back the integration code you are about to write or review."
---

_This skill wraps the `/api-docs-first:check` command; pass the command's input as the skill's argument (`$ARGUMENTS`)._


Invoke the api-docs-first skill from this plugin for $ARGUMENTS (a library, SDK, or API
name). Report:

1. Exact installed version from the lockfile/manifest.
2. Docs source located (URL or file path) — or state that none was found.
3. The specific symbols/endpoints verified against those docs.
4. If no docs are accessible: a direct request to the user for a docs URL or file,
   and what you will NOT do until then (no integration code from memory).

5. When docs were located and symbols verified, ask via AskUserQuestion:
   "Proceed with the integration against these verified docs now
   (Recommended)" / "Stop here — check only". Headless: report only.
