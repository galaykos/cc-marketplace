---
name: command-check
description: "Check that current API docs back the integration code you are about to write or review"
---

Read [the Codex execution contract](../../references/codex.md) before using helpers or delegating.

Invoke the `api-docs-first` skill from this plugin for the user-supplied arguments (a library, SDK, or API
name). Report:

1. Exact installed version from the lockfile/manifest.
2. Docs source located (URL or file path) — or state that none was found.
3. The specific symbols/endpoints verified against those docs.
4. If no docs are accessible: a direct request to the user for a docs URL or file,
   and what you will NOT do until then (no integration code from memory).

5. When docs were located and symbols verified, ask via a user question using the available interaction tool:
   "Proceed with the integration against these verified docs now
   (Recommended)" / "Stop here — check only". Headless: report only.
