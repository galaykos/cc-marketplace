# Material UI structure digest — packages, imports, theme API, majors

> Last verified: 2026-09-26 — https://mui.com/material-ui/ — npm:@mui/material@9
> (stable major: v9, `9.4.0` on npm that day; MUI X `9.14.0`. Per-major guides:
> https://mui.com/material-ui/migration/ and https://mui.com/x/migration/)

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
| `@mui/x-data-grid`, `@mui/x-date-pickers`, `@mui/x-charts`, `@mui/x-tree-view` | MUI X, some with Pro/Premium tiers (`-pro`, `-premium` packages); Scheduler and Chat are v9 alphas | **no** — independent majors, table below |
| `@mui/x-license` | `LicenseInfo.setLicenseKey()` for every Pro/Premium package | no — follows MUI X |
| `@mui/joy` | Joy UI — removed from the repo in v9, on hold (section below) | no — last `5.0.0-beta.52` |
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

## MUI X per major

MUI X majors are separate from Material UI's: resolve `@mui/x-*` from the lockfile
and read the matching guide under https://mui.com/x/migration/. Since v9 every MUI
X package peers on `@mui/material` `^7.3.0 || ^9.0.0` — a v5 or v6 core cannot
take MUI X v9.

| Package | v8 (from v7) | v9 (from v8) |
|---|---|---|
| Data Grid `@mui/x-data-grid*` | `rowSelectionModel` is `{ type: 'include' \| 'exclude', ids: Set<GridRowId> }`, not an array — `onRowSelectionModelChange` too; toolbar is `showToolbar`, not `slots={{ toolbar: GridToolbar }}`; `useGridApiRef()` starts as `null`; `LicenseInfo` only from `@mui/x-license`; `unstable_rowSpanning`/`unstable_dataSource`/`unstable_listView` lost the prefix (`unstable_listColumn` → `listViewColumn`); TypeScript 5+ | new licence key; `experimentalFeatures={{ charts: true }}` gone — `chartsIntegration` on `DataGridPremium`; locale key `filterPanelColumns` → `filterPanelColumn`; action cells lost the `menu` role |
| Pickers `@mui/x-date-pickers*` | adapter names flipped: `AdapterDateFns` now means date-fns v3+ (it was `AdapterDateFnsV3`), the date-fns v2 adapter is `AdapterDateFnsV2`, same for Jalali; range pickers default to the single-input field; custom slot components read `usePickerContext()`, not props | new licence key (Pro); `enableAccessibleFieldDOMStructure` removed — the section-based `PickersTextField` is the only field, so a custom `textField` slot rendering an `<input>` crashes; `InputProps`/`inputProps`/`InputLabelProps` → `slotProps`; `PickersDay` → `PickerDay`; `unstableFieldRef` → `fieldRef`; codemod `npx @mui/x-codemod@latest v9.0.0/pickers/preset-safe <path>` |
| Charts `@mui/x-charts*` | not digested here — read `/x/migration/migration-charts-v7/` | `Chart*` → `Charts*` (`ChartContainer` → `ChartsContainer`, `ChartZoomSlider` → `ChartsZoomSlider`); series `id` is string-only and unique across ALL series; line `showMark` defaults to `false`; `useAxisTooltip()` → `useAxesTooltip()`, which returns an array; `.highlighted`/`.faded` classes → `[data-highlighted]`/`[data-faded]` |

**Licence keys do not cross majors.** A v8 Pro/Premium key fails on v9: regenerate
it in the MUI Store account (same expiry, no charge), then set it once, before the
first render, with `LicenseInfo.setLicenseKey()` from `@mui/x-license`. A missing,
expired or wrong-major key renders a watermark and a console warning in development
AND production.

Standing of this section and the next: **recorded** — no script compares a lockfile
with these rows; a reviewer applying this skill is the only reader (agent-graded).

## Joy UI

Joy UI (`@mui/joy`) is not a v9 package. Its code and docs were removed from the
main repo in v9 (docs now live at https://v7.mui.com/joy-ui/), MUI's 2026 roadmap
lists it "on hold" with no plans, and npm's last release is `5.0.0-beta.52`
(March 2025), which depends on `@mui/system` 5.x.

- New work: do not start on Joy. MUI's own Joy docs recommend Material UI for new
  projects because MUI guarantees its support.
- Existing Joy app: pin `5.0.0-beta.52`. MUI publishes no Joy-to-Material guide or
  codemod at the stamp date; the documented bridge is "Using Joy UI and Material UI together"
  (https://v7.mui.com/joy-ui/integrations/material-ui/) — Material's `ThemeProvider`
  keyed with `THEME_ID`, Joy's `CssVarsProvider` inside it — then move one route at
  a time. That page predates v9: with Material v9 the lockfile carries two
  `@mui/system` majors, so check the bundle before calling the bridge done.

## Detection

- Manifest: `@mui/material` (this skill), `@mui/x-*` (MUI X, check its own
  major), `@mui/joy` (Joy UI, section above), `@base-ui/react` (Base UI →
  `component-libraries`, not this skill).
- Source: `from '@mui/material` imports, `sx={{` props, `createTheme(`.
