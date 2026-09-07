# Material UI structure digest — packages, imports, theme API, majors

> Last verified: 2026-09-02 — https://mui.com/material-ui/ (stable major: v9;
> https://mui.com/versions/ and https://mui.com/material-ui/migration/ for the
> per-major guides)

Read on demand from mui-best-practices. Structure-stable material only:
package family, import shape, the theme API surface, and what each major
removed. Nothing in this file answers a component-props question — those come
from the docs for the installed major.

## Package family

| Package | Role | Versioned with `@mui/material`? |
|---|---|---|
| `@mui/material` | components, `createTheme`, `ThemeProvider`, `CssBaseline` | — |
| `@emotion/react`, `@emotion/styled` | default styling engine (peers) | no |
| `@mui/icons-material` | Material Icons as components | yes |
| `@mui/system`, `@mui/styled-engine` | `sx`/`styled` plumbing, rarely imported directly | yes |
| `@mui/lab` | incubating components | yes (own pre-release tags) |
| `@mui/material-nextjs` | Next.js App/Pages Router Emotion cache | yes |
| `@mui/x-data-grid`, `@mui/x-date-pickers`, `@mui/x-charts`, `@mui/x-tree-view` | MUI X, some with Pro/Premium tiers | **no** — independent majors |
| `@base-ui/react` | Base UI, MUI-maintained headless primitives (v1.0 Dec 2025) | no — separate product |
| `@pigment-css/*` | zero-runtime CSS, alpha, opt-in | no |

## Import shape

- `import Button from '@mui/material/Button'` (path import, tree-shakes without
  config) or `import { Button } from '@mui/material'` (barrel; fine with modern
  bundlers). Never a second path segment — removed in v7.
- Theme utilities: `import { createTheme, ThemeProvider, styled, useTheme } from '@mui/material/styles'`.
- Colour scheme: `import { useColorScheme } from '@mui/material/styles'`;
  `import InitColorSchemeScript from '@mui/material/InitColorSchemeScript'`.

## Theme API (v6+)

```ts
const theme = createTheme({
  cssVariables: { colorSchemeSelector: 'class' }, // or true, 'data', a custom selector
  colorSchemes: { light: { palette: {…} }, dark: { palette: {…} } },
  typography: {…}, shape: { borderRadius: 8 }, spacing: 4,
  components: { MuiButton: { defaultProps: {…}, styleOverrides: {…}, variants: […] } },
});
```

- `theme.vars.palette.primary.main` → `var(--mui-palette-primary-main)`.
- `theme.applyStyles('dark', { … })` inside `styled`/`sx` callbacks replaces
  `theme.palette.mode === 'dark' ? … : …`.
- `useColorScheme()` returns `{ mode, setMode, systemMode }`; `mode` may be
  `'system'`.
- `InitColorSchemeScript` goes in the document `<head>`/root layout on SSR so
  the stored scheme applies before hydration.

## What each major removed or changed

| Major | Date | Notable |
|---|---|---|
| v5 | 2021 | Emotion replaces JSS; `sx`; `@material-ui/*` → `@mui/*` |
| v6 | Aug 2024 | `cssVariables`/`colorSchemes` stable in `createTheme`; `Grid2` introduced; Pigment CSS opt-in |
| v7 | Mar 2025 | `Grid2` becomes `Grid` (`size`, `offset` props); old grid → `GridLegacy`; deep imports beyond one level removed; `createMuiTheme`, `experimentalStyled`, `Hidden`, `onBackdropClick` removed; lab components (Alert, Autocomplete, Rating, Skeleton…) import from `@mui/material`; `slotProps` standardised; TS ≥ 4.9 |
| v8 | — | **skipped** to align numbering with MUI X |
| v9 | Apr 2026 | `GridLegacy` removed; system shorthand props (`mt`, `p`, …) removed from `Box`/`Stack`/`Typography`/`Grid` — use `sx`; remaining `*Props`/`*Component` props (`PaperProps`, `BackdropComponent`, `TransitionComponent`…) → `slots`/`slotProps`; `Stepper` renders `<ol>/<li>`; 23 duplicate `*Outline` icon exports dropped; `MuiTouchRipple` gone from theme component types; browser floor Chrome 117 / Safari 17 |

## Detection

- Manifest: `@mui/material` (this skill), `@mui/x-*` (MUI X, check its own
  major), `@base-ui/react` (Base UI → `component-libraries`, not this skill).
- Source: `from '@mui/material` imports, `sx={{` props, `createTheme(`.
