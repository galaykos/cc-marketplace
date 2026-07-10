---
description: Stage interactive shadcn component variants for a visual decision in a self-contained greenfield sandbox
argument-hint: [decision-description]
---

Stage the visual/UI decision described in $ARGUMENTS (if empty, ask what choice
needs deciding first). Invoke the `studio` skill from this plugin and follow it
exactly.

1. Detect and route per the skill's table. Host is already a runnable Vite+React
   app → defer to `design-preview:real-preview` (renders the project's own
   components). Node below `20.19` (the Vite floor) or absent → static-shell fallback, before any
   write. Otherwise (empty/greenfield dir, or a non-React stack) → shadcn-studio.
2. Ask the strict consent gate, naming the resolved scratch path actually taken
   (outside the work tree by default), the `npm ci` + `vite dev` commands, and
   the port. Declined → static-shell fallback.
3. Provision once per session (stale recovery → copy template → isolated
   `npm ci` → `vite dev` on the dedicated port); author `src/variants/*.tsx` as
   real shadcn JSX with realistic data; hand over the resolved URL.
4. Ask for the pick via AskUserQuestion; iterate in place via HMR. Record the
   pick as a self-contained note (copy the chosen JSX out before cleanup) — never
   a path into the scratch dir.
5. Clean up per the skill's contract: kill studio's own server, delete the
   scratch dir, verify by search, and report the pick. Never touch a server or
   file another skill owns.
