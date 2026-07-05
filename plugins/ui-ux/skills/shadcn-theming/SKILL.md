---
name: shadcn-theming
description: Use when creating or restyling a shadcn/ui theme — design the CSS-variable token set (light + dark), verify contrast, preview colours and components on one always-live localhost URL, iterate one axis at a time, then apply to globals.css without clobbering.
---

## A theme is a token set, not sprinkled colors

shadcn/ui theming lives entirely in CSS custom properties — a `:root` block for
light and a `.dark` block for dark. Components consume tokens (`bg-primary`,
`text-muted-foreground`); they never hold literal colors. Creating or changing a
theme therefore means writing ONE token set — never editing `components/ui/*`
files to recolor them, never scattering hex values through pages.

## The token inventory

Every surface token ships with a readable partner — the pairing rule is the
spine of the system:

- Surfaces: `background`, `card`, `popover`, `secondary`, `muted`, `accent` —
  each with its `-foreground`.
- Action: `primary` / `primary-foreground` (the brand carrier),
  `destructive` / `destructive-foreground`.
- Chrome: `border`, `input`, `ring` (usually follows primary), `radius`.
- Data: `chart-1` … `chart-5` — hues spread around the wheel, same perceived
  lightness, so any subset still reads as one family.
- Shell: the `sidebar-*` group when the app has one.

A theme that skips a `-foreground` inherits one that was tuned for another
surface — that is where unreadable buttons come from.

## Pin the format to the installed stack

Read before generating — lock beats memory (stack-scan doctrine):

- `components.json`: `cssVariables` must be true for token theming;
  `baseColor` names the neutral scale the project started from.
- Tailwind v4 (package.json/lockfile): tokens in `oklch()`, mapped via
  `@theme inline` in globals.css — no tailwind.config color block.
- Tailwind v3: tokens as HSL triplets (`--primary: 222 47% 11%`) consumed by
  `hsl(var(--primary))` mappings in `tailwind.config`.

Suggesting oklch to a v3 project (or config edits to a v4 one) produces a theme
that silently does nothing.

## Building the palette

- Start from the existing neutral base (zinc/slate/stone) — don't churn every
  surface to change a brand.
- Express the brand as `primary` in oklch: pick hue, then set lightness ~0.55–0.65
  (light mode) so white foreground passes contrast; `ring` follows primary.
- Surfaces stay low-chroma (≤ 0.03): tinted greys, not pastel walls.
- Contrast gates are hard: 4.5:1 for body-size text on its surface, 3:1 for
  large text and UI boundaries (border on background). Check every pair you
  emit — both modes — before showing anything.

## Dark mode is a second design, not an inversion

- Background near-black but not black: oklch lightness ~0.13–0.16 keeps depth.
- Accents LIGHTEN and often drop a little chroma in dark mode — the same
  primary that worked on white vibrates on near-black.
- Elevation flips from shadows to borders/lighter surfaces; `card` sits a step
  above `background`, not equal to it.

## The live theme preview

The decision aid the whole skill exists for — colours are judged rendered, not
as variable names:

1. Write ONE self-contained `theme-preview.html` (scratch dir or `docs/mockups/`):
   the candidate token blocks inline, a swatch grid naming every token, and real
   component mockups built from the tokens — all button variants, a card with
   form inputs, a destructive alert, badges, a chart-color strip — light and
   dark rendered SIDE BY SIDE (two panels, `.dark` on one).
2. Serve it once on a stable URL: `python3 -m http.server 8124` from the file's
   directory, told to the user as `http://localhost:8124/theme-preview.html`.
3. Embed the body-compare auto-reload snippet from the taskmaster plugin's
   visual-decisions skill (poll → fetch → reload on change); with it, every
   regeneration appears in the open tab — the URL never changes.
4. Iterate by rewriting the token blocks in place. Kill the server by PID when
   the theme is accepted; stale-server recovery: `lsof -ti :8124 | xargs kill`.

## Iteration protocol

- Up to 3 candidates per round, rendered as columns in the same page — never
  serial single reveals.
- One axis per round: hue first, then chroma/warmth, then radius. Ask for the
  pick via AskUserQuestion with a tradeoff line per candidate.
- Two rounds is the budget; a third means the direction question upstream was
  never answered — go back and ask it in words.

## Applying the theme

- Read the project's current `globals.css` FIRST; show the token diff and get a
  yes before writing — never clobber a hand-tuned theme wholesale.
- Emit the full `:root` + `.dark` blocks (v4: oklch + `@theme inline` mapping
  already present; v3: HSL triplets, plus any missing `tailwind.config`
  mappings).
- Non-token colors found in components during the work are findings for
  `/ui-ux:review`, not silent fixes.
- For sharing across projects, the same tokens can ship as a registry-style
  JSON theme object — offer it, don't force it.

## Anti-patterns

- Recoloring by editing `components/ui/*` source or compiled CSS output.
- Dark mode via `filter: invert()` or by copying light values verbatim.
- A `primary` whose `primary-foreground` fails 4.5:1 — the most common broken
  shadcn theme in the wild.
- Chart colors improvised per page instead of `chart-*` tokens.
- Picking a theme from swatches alone — components change how colours read;
  judge the preview, both modes.
- Opening a new preview file/port per iteration — one URL, always live.
