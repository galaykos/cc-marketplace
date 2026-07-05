---
description: Create or restyle a shadcn/ui theme with a live preview URL for the colours
argument-hint: [brand-color-vibe-or-reference]
---

Build a shadcn/ui theme for this project from $ARGUMENTS (a brand color, a vibe
like "warm editorial", or a reference site). Invoke the shadcn-theming skill
from this plugin and follow it exactly.

1. Read the ground truth first: `components.json` (cssVariables, baseColor),
   the current `globals.css` token blocks, and the Tailwind major version from
   the lockfile — if the stack-scan plugin is installed, reuse its inventory.
2. If $ARGUMENTS is empty, ask for direction in one round: brand color or hue
   family, light/dark priority, and any reference the user wants to echo.
3. Generate up to 3 candidate token sets (light + dark each, contrast-checked),
   write `theme-preview.html`, start the preview server, and give the user the
   stable URL — candidates as columns, light and dark side by side.
4. Iterate per the skill's protocol: one axis per round, picks via
   AskUserQuestion, regenerate in place so the open tab reloads itself.
5. On acceptance: show the diff against the existing `globals.css` (plus
   `tailwind.config` mappings on v3), then offer the write as a selectable
   choice (AskUserQuestion): "Apply this theme to globals.css now
   (Recommended)" / "Skip — keep the preview only"; write only on the first
   option. Kill the preview server, report the final token block and where
   it was written.
