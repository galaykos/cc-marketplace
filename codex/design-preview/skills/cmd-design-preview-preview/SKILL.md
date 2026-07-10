---
name: cmd-design-preview-preview
description: "Use when the user asks to render a visual decision with the project's real components on its own Vite dev server."
---

_This skill wraps the `/design-preview:preview` command; pass the command's input as the skill's argument (`$ARGUMENTS`)._


Run a real-component preview for the visual decision described in $ARGUMENTS
(if empty, ask what choice needs deciding first). Invoke the real-preview skill
from this plugin and follow it exactly.

1. Detect the stack per the skill's table (Vite config, React plugin, dev
   script, component paths) — reuse the stack-scan inventory when installed.
   Any check failing: offer the fallback immediately, do not improvise.
2. Ask the strict consent gate, naming the exact files to be written and the
   dev-server command. Declined: fall back to the taskmaster shell mockup when
   installed.
3. Write the scratch entry (`design-preview.html` + `src/__design-preview__/`),
   reuse or start the dev server, and hand over the preview URL — 2-3 variants,
   one axis, the project's own components with realistic data.
4. Ask for the pick via AskUserQuestion; iterate at most twice via HMR edits in
   place.
5. Clean up per the skill's contract: delete both scratch paths, verify by
   search, kill the server only if this flow started it, and report the pick.
