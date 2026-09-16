---
name: tailwind-best-practices
description: Use when writing or reviewing Tailwind CSS — utility classes, class order, `@apply`, arbitrary values, dark mode, `tailwind.config.js` vs v4's CSS-first `@theme`/`@custom-variant`/`@source`, and the v4 utility renames (`shadow-sm`, `rounded`, `outline-none`, `ring`, `bg-opacity-*`). Colour values are shadcn-theming; scales are design-tokens.
---

> Last verified: 2026-09-15 — https://tailwindcss.com/docs/upgrade-guide

## Resolve the major from the CSS, not from `package.json` alone

Read the entry stylesheet before advising. It is the only signal that cannot lie:

- `@import "tailwindcss";` → **v4**. `@tailwind base/components/utilities;` → **v3**.
- **A `tailwind.config.js` on disk does NOT mean v3.** v4 no longer detects it; a v4
  project can still load one with `@config "../../tailwind.config.js";`. Grep for
  `@config` before concluding anything from the file's existence.
- Build wiring moved: v4 uses `@tailwindcss/postcss`, `@tailwindcss/vite`, or
  `@tailwindcss/cli`. A `tailwindcss` entry in a PostCSS plugin list is v3 wiring.

## The v3 answers that land nowhere on v4

Each row is a remedy the corpus still recommends and v4 does not have. Recommending
one produces a confident edit that changes nothing — the expensive failure here.

| The v3 answer | On v4 |
|---|---|
| `tailwind.config.js` → `theme.extend` | not read unless `@config` names it; tokens live in `@theme { --color-brand: … }` in CSS |
| `darkMode: 'class'` in the config | `@custom-variant dark (&:where(.dark, .dark *));` in CSS — data-attribute form: `@custom-variant dark (&:where([data-theme=dark], [data-theme=dark] *));` |
| `content: [...]` globs | automatic detection; `.gitignore`d files, `node_modules`, binaries, CSS files and lockfiles are skipped. Add a path with `@source "../node_modules/@acme/ui";` |
| `safelist: [...]` in the config | unsupported key; use `@source inline("underline")`, with variants as `@source inline("{hover:,focus:,}underline")` |
| `corePlugins` / `separator` | unsupported keys — no replacement, drop the requirement |
| `theme('screens.xl')` in CSS | `theme(--breakpoint-xl)`, or read the variable directly: `var(--color-red-500)` |

**`@apply` in a second file silently produces nothing on v4.** A CSS module, a
`<style>` block in a `.vue`/`.svelte` file, or any stylesheet other than the entry one
is compiled on its own and knows no utilities. It needs an explicit reference:

```css
@reference "../../app.css";
h1 { @apply text-2xl font-bold; }
```

Without it the rule compiles clean and the element is unstyled — no error to grep for.

## The renames, and which are loud

`outline-none` → `outline-hidden`, `flex-shrink-*` → `shrink-*`, `flex-grow-*` →
`grow-*`, `overflow-ellipsis` → `text-ellipsis`, `decoration-slice`/`-clone` →
`box-decoration-slice`/`-clone`, and every `*-opacity-*` utility
(`bg-opacity-50`) → the modifier form (`bg-black/50`). These are loud: the old name
generates no CSS, so the effect is visibly absent.

**The scale shift is the quiet one.** v4 renamed the bare and `-sm` steps of five
families, so a v3 class string still compiles and renders a DIFFERENT value:

| v3 | v4 |
|---|---|
| `shadow-sm` / `shadow` | `shadow-xs` / `shadow-sm` |
| `rounded-sm` / `rounded` | `rounded-xs` / `rounded-sm` |
| `blur-sm` / `blur` | `blur-xs` / `blur-sm` |
| `drop-shadow-sm` / `drop-shadow` | `drop-shadow-xs` / `drop-shadow-sm` |
| `backdrop-blur-sm` / `backdrop-blur` | `backdrop-blur-xs` / `backdrop-blur-sm` |
| `ring` (3px) | `ring-3`; bare `ring` is now 1px |

So `shadow-sm` copied from a v3 answer into a v4 file is not an error, it is a
one-step-lighter shadow, and `ring` is a third of the width it used to be. Flag these
by NAME when a diff mixes eras; no build output will.

## What holds on both majors

- **Complete class strings only.** The compiler scans source text, so
  `` className={`bg-${color}-600`} `` generates nothing. Use a lookup map of whole
  strings (`{ blue: "bg-blue-600 hover:bg-blue-500" }`). On v4 the escape for a string
  that genuinely cannot be static is `@source inline(...)`, not a config safelist.
- **A repeated arbitrary value is a missing token.** `w-[137px]` once is a one-off;
  twice is `@theme` (v4) or `theme.extend` (v3). The scales themselves are
  `design-tokens`; the colour values are `shadcn-theming`.
- **Class order belongs to the formatter.** Install `prettier-plugin-tailwindcss` and
  stop reviewing order by hand — hand-sorting is the noisy-diff source, not the fix.

## Defer rule

- Colour values, ramps, light/dark token blocks → `shadcn-theming` (it owns the v3 HSL
  vs v4 oklch split; do not restate it here).
- Spacing, type, radius, elevation and motion SCALES → `design-tokens`.
- Component structure in `components/ui/` → `shadcn-best-practices`; any other
  library → `component-libraries`.
- Contrast, focus visibility and target size → `/ui-ux:audit`.

## Anti-patterns

Named for citing in a review; each rule is stated once above.

- **Config-file advice to a v4 project** — a `darkMode`, `content:` or `safelist` edit
  with no `@config` line in the CSS.
- **Unreferenced `@apply`** — in a `<style>` block or CSS module, silently producing nothing.
- **Mixed-era scale names** — v3 `shadow`/`rounded`/`ring` left in a v4 file.
- **`@apply` clusters** standing in for a component.

Config keys, variant syntax and utility names move between majors; check
https://tailwindcss.com/docs for the installed one rather than recalling either.
