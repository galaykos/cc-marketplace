---
description: Create or restyle a CSS-variable UI theme (shadcn/ReUI/Aceternity, Tailwind, or Bootstrap) with a live preview URL for the colours
argument-hint: [brand-color-vibe-or-reference]
---

Build a UI theme for this project from $ARGUMENTS (a brand color, a vibe like
"warm editorial", or a reference site). Invoke the shadcn-theming skill from
this plugin and follow it exactly.

1. Resolve the STACK before anything else — detect, do not ask blind. Read
   `components.json` (cssVariables, baseColor), `package.json`/lockfile for
   `bootstrap` vs `tailwindcss`, any `.scss` importing `bootstrap/scss/bootstrap`,
   the current `globals.css` token blocks, and the Tailwind major version; if
   the stack-scan plugin is installed, reuse its inventory. Collect EVERY
   signal before deciding — not a first-match cascade, or a migration resolves
   to whichever rule you happened to check first. `components.json` +
   `tailwindcss` is ONE signal (shadcn is Tailwind-based), not two. Then:
   - exactly one signal → state the detected stack in one line and continue;
   - two genuinely different ones (Bootstrap + Tailwind), or none at all → ask via
     AskUserQuestion which target this theme is for: shadcn / ReUI / Aceternity
     (shadcn CSS variables) · Tailwind semantic tokens · Bootstrap (Sass
     `$variables`).
   The skill's `references/token-vocabularies.md` holds the per-stack mapping,
   the Bootstrap traps (`-rgb` companions, `[data-bs-theme="dark"]`, no
   `-foreground` pairing), and the detection rules. Read it for anything but
   plain shadcn.
2. If $ARGUMENTS is empty, ask for direction in one round: brand color or hue
   family, light/dark priority, and any reference the user wants to echo.
3. Generate up to 3 candidate token sets (light + dark each, contrast-checked),
   write `taskmaster-docs/mockups/theme.html`, reuse-or-start the shared preview
   server (port `${PREVIEW_PORT:-8123}`), and give the user the stable URL.
   Build the page by copying the skill's `assets/theme-shell.html` starter —
   it already carries the component skeleton, the favicon, the auto-reload
   lane, and the `Phone 375 / Tablet 768 / Full` viewport control, so
   candidates land as columns with light and dark side by side and the palette
   can be judged at device width. The preview always uses the starter's own
   token names whatever the stack — it decides COLOUR, not component look; say
   so rather than implying the page shows the user's app. Never publish the
   preview as a remote artifact; the decision lives on the local URL.
4. Iterate per the skill's protocol: one axis per round, picks via
   AskUserQuestion, regenerate in place so the open tab reloads itself.
5. On acceptance: show the diff against the real target for the detected stack —
   `globals.css` (plus `tailwind.config` mappings on v3), or the Sass partial
   holding `$variables` before the Bootstrap import — then offer the write as a
   selectable choice (AskUserQuestion): "Apply this theme now (Recommended)" /
   "Skip — keep the preview only"; write only on the first option. Kill the
   preview server only if this flow started it (other flows share it), then
   report the final token block and where it was written.
