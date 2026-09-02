---
name: mui-best-practices
description: Use when building or reviewing UI with Material UI (@mui/material, @mui/icons-material, @mui/x-*). Resolve the installed major from the lockfile first — v7 and v9 removed APIs a v5/v6 memory still recites. Covers imports, createTheme with CSS variables and colorSchemes, sx/styled/slotProps, dark mode via useColorScheme, MUI X versioning, and Base UI as MUI's headless sibling.
---

# Material UI best practices

Material UI is the React implementation of Material Design, shipped as
`@mui/material` with Emotion as the default styling engine. It is an npm
dependency, not owned code: you configure it through the theme and per-usage
overrides and never patch it. What a "Material" surface looks like is the
project's decision, not the library's.

## Version discipline: lockfile first, docs second

Major versions have removed real APIs, and Material UI **skipped v8** (v7 → v9,
to align with MUI X). For structural facts — package family, import shape, the
theme API, which majors changed what — read `references/mui.md` first. Props are
never answered from the digest. Before writing any MUI code:

1. Resolve the installed major from the lockfile (`@mui/material`). Resolve
   `@mui/x-*` separately: MUI X is versioned independently and its major need
   not equal Material UI's.
2. Check the current docs for THAT major (https://mui.com/material-ui/ — the
   version switcher and `/migration/` guides). A v5 or v6 pattern recited on a v9
   project is the most common defect: `Grid` props, deep imports, system props.
3. When the component has a `slots` / `slotProps` API, use it instead of
   reaching inside with class selectors.

## Installation and imports

- Core: `@mui/material` plus the Emotion peers (`@emotion/react`,
  `@emotion/styled`). Icons are a separate package (`@mui/icons-material`).
  Advanced components (Data Grid, Date Pickers, Charts, Tree View) live in
  `@mui/x-*` and are versioned apart, with a paid tier for some.
- Import one level deep, never deeper: `import Button from '@mui/material/Button'`
  or `import { Button } from '@mui/material'`. Deep private paths
  (`@mui/material/Button/ButtonBase`) were removed in v7; `styles` helpers come
  from `@mui/material/styles`.
- Next.js App Router needs `@mui/material-nextjs` (App Router cache provider) so
  Emotion styles stream correctly; do not hand-roll the registry.

## Theming and dark mode

- One `createTheme` at the app root, passed through `ThemeProvider`, with
  `CssBaseline` under it. Extend `palette`, `typography`, `shape`, `spacing`
  and `components` (default props, `styleOverrides`, `variants`) there — that
  is where the project's design tokens live, so `design-tokens` values map onto
  the theme, not onto per-component `sx` literals.
- Enable CSS variables: `createTheme({ cssVariables: true, colorSchemes: { light: …, dark: … } })`.
  In styles reference `theme.vars.palette.*`; use `theme.applyStyles('dark', {…})`
  instead of branching on `palette.mode`, which flashes on SSR and breaks with
  `colorSchemeSelector`.
- Dark mode reads and writes through `useColorScheme()` (`mode`, `setMode`);
  pick `colorSchemeSelector: 'class'` or `'data'` to match how the rest of the
  page toggles (Tailwind's `dark:` class, a `data-theme` attribute), and add
  `<InitColorSchemeScript />` on SSR frameworks to avoid the first-paint flash.
- Verify both schemes on every screen touched. A custom `primary` that passes
  contrast in light mode routinely fails on the dark `background.paper`.

## Styling and customisation

- Order of preference: theme `components` overrides for repeated changes →
  `styled()` for a reusable variant → `sx` for a one-off at the usage site.
  A `sx` block copy-pasted onto five instances is a theme override in disguise.
- `slotProps` and `slots` customise inner parts (`input`, `paper`,
  `transition`, `backdrop`); the `*Props`/`*Component` props they replaced were
  deleted across v7–v9. System shorthand props (`mt={2}` on `Box`, `Stack`,
  `Typography`) are gone in v9 — put them in `sx`.
- Layout: `Grid` is the CSS-grid based component with `size={{ xs: 12, md: 6 }}`
  (v7+); `GridLegacy` existed for one major and is removed in v9. `Stack` for
  1-D flow, `Box` as the styled `div`.
- Pigment CSS (zero-runtime) remains alpha and opt-in; Emotion is the default
  and the safe assumption unless the project already wires Pigment.

## Coexistence with other systems

- One design system owns a surface. MUI plus shadcn/ui or a Tailwind component
  set in one view doubles token vocabularies — choose per app or per bounded
  surface and record it. Tailwind utilities for LAYOUT beside MUI components is
  a known pattern; Tailwind for MUI colours and type is a token fork.
- Base UI (`@base-ui/react`) is MUI's headless sibling, not "MUI without
  styles": no theme, render-prop API, and the primitive shadcn/ui now defaults
  to. A project on Base UI is governed by `component-libraries` and
  `shadcn-best-practices`, not by this skill.
- Migrating: introduce MUI per route or per feature under its own
  `ThemeProvider` boundary, not component-by-component inside a shared view.

## Review checklist

- Installed majors resolved for `@mui/material` AND `@mui/x-*`; APIs checked
  against the docs for those majors.
- Imports one level deep; icons from `@mui/icons-material`.
- Tokens in the theme; no repeated `sx` literals that belong in `components`.
- `cssVariables` on; `theme.vars` + `applyStyles` instead of `palette.mode`
  branches; both colour schemes rendered.
- `slotProps`/`slots` over class-selector reach-ins; no removed `*Props` props.
- No second design system on the same surface without a recorded decision.

## Defer rule

- General React correctness (state, effects, keys) → web-dev's `frontend-reviewer`.
- Palette generation and colour VALUES → `/ui-ux:theme`; scale values → `design-tokens`.
- Full WCAG audit → `/ui-ux:audit`.
- shadcn/ReUI/Aceternity/Astryx surfaces → their sibling skills; any other
  library → `component-libraries` (this plugin).

## Anti-patterns

- **v5 from memory on a v9 project** — `Grid item xs={6}`, `PaperProps`,
  `createMuiTheme`, `Hidden`, deep imports: each is a removed API.
- **`palette.mode` branching** — flashes on SSR and ignores the colour-scheme
  selector; `applyStyles` exists for this.
- **`sx` as the theme** — the same override repeated per instance instead of
  once under `components`.
- **Class-selector surgery** — `.MuiInputBase-root` overrides where `slotProps`
  reaches the same element with a typed API.
- **Two design systems, one view** — MUI + shadcn mixed without a boundary.
