---
name: shadcn-theming
description: Use when creating or restyling a UI colour theme — shadcn/ReUI/Aceternity CSS variables, Tailwind semantic tokens, or Bootstrap Sass variables: light + dark, contrast checks, live preview on one localhost URL, one axis at a time, applied to the stack's real target without clobbering.
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

## Pin the stack before generating anything

DETECT first, ask only what the repo cannot answer — a theme aimed at the wrong
vocabulary is written to a file the project never reads:

- `components.json` with `cssVariables: true` → shadcn names (ReUI and
  Aceternity ride the same variables — nothing extra to do).
- `bootstrap` in package.json, or a `.scss` importing `bootstrap/scss/bootstrap`
  → Bootstrap: Sass `$variables`, `[data-bs-theme="dark"]`, no `-foreground`
  pairing. Read `references/token-vocabularies.md` before emitting anything.
- `tailwindcss` and no `components.json` → Tailwind with no semantic layer yet;
  the theme creates it, so say that rather than implying you are editing it.
- Signals for two stacks at once (a live migration) is the one case to ask
  outright which target this theme is for.

The preview is the same in every case — it decides COLOUR, not component look.
Never present it as "how your app will look"; the skeleton is generic HTML, not
your stack's components.

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

1. Never hand-write a theme page. Copy `assets/theme-shell.html` (relative to
   this skill's directory) to `taskmaster-docs/mockups/theme.html` and fill its
   SLOTs. The starter already carries the component skeleton (every button
   variant, a card with form inputs, a destructive alert, badges, a swatch grid,
   a chart strip), the 🎨 favicon, the `Phone 375 / Tablet 768 / Full` viewport
   axis, and the auto-reload lane — so none of that can be forgotten and the
   chrome is never restyled. Starter unreadable (broken plugin cache) is the one
   case for hand-building; say so when it happens.
2. Fill token VALUES only, into `SLOT: candidate-tokens` — light scoped to the
   section id, dark to that section's `.ts-panel.dark`. For a second or third
   candidate, duplicate the `CANDIDATE-START`…`CANDIDATE-END` section and change
   only its id and label: panel markup stays byte-identical across candidates,
   or the pick stops being attributable to colour.
3. Light and dark are BOTH on screen, always — the starter ships no mode toggle
   by design. Judge colour by comparing the two panels, never by flipping
   between them. The viewport control is the axis that does move: check the
   palette at 375 too, where a card on `background` is the whole screen.
4. Serve it on the shared preview server: reuse a live `${PREVIEW_PORT:-8123}`
   server (`lsof -ti :${PREVIEW_PORT:-8123}`) — when the taskmaster plugin is
   installed, its visual-decisions `assets/serve.py` is the preferred first
   start (adds SSE push-reload; static rungs below degrade to polling). Else
   start `python3 -m http.server "${PREVIEW_PORT:-8123}" --bind 127.0.0.1 -d taskmaster-docs/mockups`
   in the background (no python3 →
   `php -S 127.0.0.1:${PREVIEW_PORT:-8123} -t taskmaster-docs/mockups` →
   `npx serve -l tcp://127.0.0.1:${PREVIEW_PORT:-8123} taskmaster-docs/mockups`) —
   the stable URL is `http://localhost:${PREVIEW_PORT:-8123}/theme.html`.
5. Iterate by rewriting the token blocks in place. When the theme is accepted,
   kill the server only if this flow started it — mockups, walkthroughs, and
   diagrams share it. Stale recovery: `lsof -ti :${PREVIEW_PORT:-8123} | xargs kill`.

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
  mappings). Bootstrap instead takes Sass `$variables` BEFORE the import — a
  `--bs-*`-only theme leaves Sass-compiled components uncoloured.
- Non-token colors found during the work are not silent fixes — after the
  theme is applied, offer as a selectable choice: "Run the ui-ux review on
  the flagged components now (Recommended)" / "Skip".
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
- Publishing the preview as a remote Artifact instead of serving it locally —
  a hosted page has no viewport control, no push-reload lane, and no ledger
  file, and it ships the project's unreleased palette off the machine.
