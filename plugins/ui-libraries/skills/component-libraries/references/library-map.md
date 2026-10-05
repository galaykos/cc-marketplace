# Component library map (React, Vue, Svelte) — signals, ownership, theme channel, docs

> Last verified: 2026-10-05 — the Organisation design systems rows (GOV.UK Frontend, USWDS,
> Shopify Polaris, IBM Carbon, Atlassian) added from npm and their official docs that day;
> the Base UI, HeroUI, PrimeVue and Vuetify rows carry their 2026-09-26 re-read and the
> PrimeReact, Catalyst and Tremor rows their 2026-09-26 reading; the Radix, Park UI,
> Flowbite and Svelte rows their 2026-09-22 reading; every other row its 2026-09-02 reading.

Read on demand from `component-libraries`. A row with no sibling skill is governed
by the SKILL.md rules plus its docs URL.

## Headless (behaviour + a11y, no styles)

| Library | Signal | Theme channel | Docs | Notes |
|---|---|---|---|---|
| Base UI | `@base-ui/react` (pre-1.0 name: `@base-ui-components/react`) | none — your CSS/Tailwind, `data-*` attrs | https://base-ui.com/react/overview/quick-start | MUI-maintained; `render` prop; shadcn/ui's default primitive since Jul 2026. The old name is deprecated on npm ("renamed to `@base-ui/react`", last `1.0.0-rc.0`) — see Landscape notes |
| Radix Primitives | `radix-ui` (unified pkg) or `@radix-ui/react-*` | none — `data-state` attrs | https://www.radix-ui.com/primitives/docs/overview/introduction | still supported by shadcn (`-b radix`); `asChild`. NOT `@radix-ui/themes` — the styled sibling below, which is what a "Radix project" with no `components.json` usually means |
| React Aria Components | `react-aria-components` (hooks: `react-aria`) | none — render props, `data-*`, `className` fn | https://react-spectrum.adobe.com/react-aria/ | strictest a11y + i18n; base of HeroUI and Untitled UI, and a shadcn/ui base since Jul 2026 (`--base aria`) |
| Ark UI | `@ark-ui/react` | none — `data-*`; state machines | https://ark-ui.com/docs/overview/introduction | Chakra team; also Vue/Solid/Svelte; `.Root/.Trigger` compounds |
| Headless UI | `@headlessui/react` | none — Tailwind-first `data-*` | https://headlessui.com | small set |
| Ariakit | `@ariakit/react` | none | https://ariakit.org | store-based state |

## Styled, npm dependency (configure the theme, never patch)

| Library | Signal | Theme channel | Docs | Notes |
|---|---|---|---|---|
| Material UI | `@mui/material` | `createTheme` + CSS vars | https://mui.com/material-ui/ | sibling skill `mui-best-practices`; MUI X versioned separately |
| Radix Themes | `@radix-ui/themes` | `<Theme accentColor grayColor radius scaling panelBackground>` wrapping the app, then `--accent-1..12` / `--gray-*` | https://www.radix-ui.com/themes/docs/theme/overview | v3.x, the STYLED sibling of Radix Primitives: same org, different package, a full token system. Theming it through shadcn's `--primary` is the common mistake |
| Flowbite React | `flowbite-react` (vanilla sibling: `flowbite`, a Tailwind plugin) | `createTheme` + `ThemeProvider`, or a per-component `theme` prop — Tailwind CLASS STRINGS, not CSS variables | https://flowbite-react.com/docs | nested providers merge unless `root` is set; the class-string channel means `ui-ux:shadcn-theming`'s variable advice does not transfer |
| Mantine | `@mantine/core` | `createTheme` + `MantineProvider`, CSS modules | https://mantine.dev | `@mantine/hooks`, `/dates`, `/form` |
| Chakra UI | `@chakra-ui/react` | `createSystem`/`defineConfig` (v3), tokens + recipes | https://chakra-ui.com/docs | v3 is built on Ark UI; `asChild` |
| Ant Design | `antd` | `ConfigProvider` `theme.token`/`components` | https://ant.design/docs/react/introduce | `@ant-design/icons`, `/pro-components` |
| HeroUI (ex-NextUI) | `@heroui/react` + `@heroui/styles` (v3); v2: `@heroui/react` alone plus a `heroui()` plugin in `tailwind.config` | v3: CSS variables (`--accent`, `--accent-foreground`, …) from `@import "@heroui/styles";` placed after `@import "tailwindcss";`; light/dark by `class` + `data-theme` on `<html>` | https://heroui.com/docs/react | v3 (`3.2.6` at the stamp) needs React 19+ and Tailwind v4, is built on React Aria, and needs NO Provider. v2 (last `2.8.x`) used the `heroui()` Tailwind plugin and `HeroUIProvider` — v2 setup recited on a v3 install is the common mistake. Its docs name an MCP, `@heroui/react-mcp` |
| Astryx | `@astryxdesign/core` (+ `theme-*`, `cli`) | `Theme` + `defineTheme()` light/dark tuples, `xstyle` (StyleX) | https://astryx.atmeta.com/docs/getting-started | sibling skill `astryx-best-practices`; beta 0.x |
| Reshaped | `reshaped` | theme CSS vars via its CLI | https://reshaped.so/docs | — |
| React-Bootstrap | `react-bootstrap` + `bootstrap` | Bootstrap SCSS variables / CSS vars | https://react-bootstrap.github.io | no sibling skill |
| PrimeReact | v11: `@primereact/ui`, `@primereact/core`, `@primeuix/themes`, `primereact`; v10: `primereact` alone plus `primereact/resources/*.css` imports | v11: `<PrimeReactProvider theme={{ preset: Aura }}>` — presets Aura, Material, Lara, Nora from `@primeuix/themes`, `definePreset` tokens rendered as `--p-*` CSS variables, per-instance `dt` prop | https://primereact.dev | v11 (Jul 2026, `11.1.0` at the stamp) is a rewrite under a paid-above-thresholds licence with a key — sibling skill `primereact-best-practices`. v10 (`10.9.9`, MIT) stays on npm's `v10-stable` tag. primereact.org 301s to primereact.dev |
| Fluent UI, Primer, Blueprint | `@fluentui/react-components`, `@primer/react`, `@blueprintjs/core` | each ships a provider + tokens | vendor docs | corporate systems; stay inside them |

## PrimeReact 11 — now a sibling skill

Since 2026-09-26 PrimeReact has its own skill in this plugin, `primereact-best-practices`:
version check, packages, theming, the compound-part API, renames, the Tailwind registry and
the v10 guard all live there. This section keeps only the licence terms, because the PrimeVue
row below shares them.

- **Licence and key.** v11 ships under the PrimeUI Licence, not MIT. The Community
  tier is free only while ALL hold: under $1M revenue, fewer than 5 developers, fewer
  than 10 employees, under $3M funding; otherwise it is paid per developer. Pass the
  key as `<PrimeReactProvider license="…">` (from `@primereact/core`); a missing or
  invalid key may render a licence notice. Peers: React 19+.

Standing: **recorded** — no script reads a manifest against this section; a
reviewer applying `component-libraries` is its only reader (agent-graded).

## Styled, copy-in / registry (owned code — edit it, do not re-fetch over edits)

| Library | Signal | Theme channel | Docs | Notes |
|---|---|---|---|---|
| shadcn/ui | `components.json`, `components/ui/*` | CSS variables (`--primary`, …) | https://ui.shadcn.com/docs | `ui-ux:shadcn-best-practices`, `ui-ux:shadcn-theming`; Base UI default from Jul 2026, Radix via `-b radix`, React Aria via `--base aria` |
| ReUI, Aceternity UI | shadcn-style registries | shadcn CSS vars | https://reui.io/docs, https://ui.aceternity.com/components | sibling skills in this plugin, `reui-best-practices` and `aceternity-best-practices`; no npm version to pin |
| Catalyst | component files (`link.tsx`, `button.tsx` and siblings) importing `@headlessui/react`, `motion` and `clsx` — no Catalyst npm package | Tailwind's default theme (colour palette, spacing, shadows), changed through `@theme`; no variable layer of its own | https://catalyst.tailwindui.com/docs | Tailwind Plus (paid): a zip downloaded from the account, `javascript/` or `typescript/` folder copied in, owned from then on; built for Tailwind v4. Wire `link.tsx` to the router (`Headless.DataInteractive` around the Next.js, Remix or Inertia link) |
| Tremor | copied files plus its `chartUtils.ts`, `cx`, `focusRing` utilities; deps `recharts`, `@radix-ui/react-*`, `tailwind-variants`, `@remixicon/react` | Tailwind palette NAMES in `chartUtils.ts` `chartColors` (`blue`, `emerald`, …) — not CSS variables | https://www.tremor.so/docs/getting-started/installation | copy-paste charts and dashboard parts on Recharts + Radix; React 18.2+, Tailwind v4; not in the shadcn CLI directory. The npm `@tremor/react` (`3.18.7`, Jan 2025, peer React 18, Tailwind v3 era) is the legacy product: do not install it on React 19 or Tailwind v4. Point `chartColors` at the theme's chart tokens, or the charts fork the palette |
| Untitled UI React | `@untitledui/*` starter or copied files | Tailwind v4 `@theme` | https://www.untitledui.com/react | Tailwind + React Aria; open core, paid Pro |
| Park UI | `@park-ui/cli` plus a Panda CSS config | Panda recipes and tokens; Park UI's colour system replaces Panda's default 50–950 shades | https://park-ui.com/docs | Ark UI + Panda CSS; `@park-ui/cli add <component>` copies code you then own. React, Solid |
| daisyUI | Tailwind plugin `daisyui` | Tailwind theme + daisyUI theme vars | https://daisyui.com/docs | class-based, no React runtime; governed by `ui-ux:tailwind-best-practices` |

## Vue 3 (same ownership rules)

| Library | Signal | Theme channel | Docs | Notes |
|---|---|---|---|---|
| Reka UI (ex-Radix Vue) | `reka-ui` (old: `radix-vue`) | none — `data-*` attrs | https://reka-ui.com | primitive under shadcn-vue and Nuxt UI; `as-child` |
| shadcn-vue | `components.json`, `components/ui/*.vue` | shadcn CSS variables | https://www.shadcn-vue.com/docs | copy-in; Reka UI build; same `ui-ux:shadcn-theming` tokens as the React one |
| Headless UI (Vue) | `@headlessui/vue` | none — Tailwind-first | https://headlessui.com/v1/vue | small set |
| Ark UI (Vue) | `@ark-ui/vue` | none — `data-*` | https://ark-ui.com/vue/docs/overview/introduction | same state machines as the React build |
| PrimeVue | `primevue` (+ `@primeuix/themes`) | `app.use(PrimeVue, { theme: { preset: Aura } })`, `definePreset` tokens rendered as `--p-*` CSS variables; Tailwind via `tailwindcss-primeui`, or `unstyled` + pass-through | https://primevue.dev | v5 (Jul 2026, `5.0.1` at the stamp) moved from MIT to the PrimeUI Licence — same Community thresholds and key as PrimeReact above, set as `app.use(PrimeVue, { license: '…' })`. v5 removed the APIs v4 deprecated (`Dropdown` → `Select`, `Calendar` → `DatePicker`, `InputSwitch` → `ToggleSwitch`, `OverlayPanel` → `Popover`, `TabView` → `Tabs`; presets only from `@primeuix/themes`, `switchTheme` → `usePreset`), assumes a 16px root (each preset ships a 14px compat variant), and deprecates `Chart`/`Editor` for paid PrimeUI Pro. primevue.org 301s to primevue.dev; v4 (MIT) is npm's `v4-stable` |
| Vuetify | `vuetify` | `createVuetify({ theme: { defaultTheme, themes } })`, read as `rgb(var(--v-theme-*))`; cascade layers `vuetify-core` … `vuetify-final` | https://vuetifyjs.com | Vuetify 4 (Feb 2026, `4.2.2` at the stamp) on Vue 3.5+: Material Design 3 type classes (`text-h1` → `text-display-large`, …) and 6 elevation levels; default theme `system`, not `light`; smaller md/lg/xl breakpoints; `VRow`/`VCol` on CSS `gap` (`dense` → `density="compact"`); unlayered app CSS now always beats Vuetify's. v3 is npm's `v3-stable`; guide at https://vuetifyjs.com/en/getting-started/upgrade-guide/ |
| Element Plus | `element-plus` | SCSS variables / CSS vars (`--el-*`) | https://element-plus.org | — |
| Naive UI | `naive-ui` | `NConfigProvider` `themeOverrides` | https://www.naiveui.com | TS-first |
| Quasar | `quasar` | `setCssVar`/Sass vars, `quasar.config` | https://quasar.dev | app framework, not just components |
| Nuxt UI | `@nuxt/ui` | `app.config.ts` `ui` + Tailwind `@theme` | https://ui.nuxt.com | Reka UI + Tailwind v4; Nuxt or plain Vue |
| Inertia page props | `@inertiajs/vue3` / `@inertiajs/react` | — | `laravel:inertia-best-practices` | not a component library |

## Svelte 5 (same ownership rules)

| Library | Signal | Theme channel | Docs | Notes |
|---|---|---|---|---|
| Bits UI | `bits-ui` | none — `class` props + `data-*` attrs | https://bits-ui.com/docs | the primitive under shadcn-svelte; unstyled |
| shadcn-svelte | `components.json`, `$lib/components/ui/*.svelte` | shadcn CSS variables | https://www.shadcn-svelte.com/docs | copy-in; Bits UI + Tailwind; `ui-ux:shadcn-theming`'s tokens apply unchanged |
| Melt UI | `@melt-ui/svelte` (builders) OR `melt` (the runes rewrite) | none — builder props spread onto your elements | https://melt-ui.com, https://next.melt-ui.com | TWO packages, not one version: read which the manifest has. Both pre-1.0 |
| Skeleton | `@skeletonlabs/skeleton` + `@skeletonlabs/skeleton-svelte` | Tailwind `@import` of a theme file, then `data-theme` on `<html>` | https://www.skeleton.dev/docs | Tailwind design system; also ships a React build |

## Organisation design systems (the organisation's own service only)

When the project IS that organisation's service or platform app, the package is required,
not chosen — SKILL.md §1. The restriction column is the official source's rule; a brief
that only wants the look installs no restricted row.

| System | Signal (brief or repo) | Package(s) | Theme channel | Docs | Use restriction |
|---|---|---|---|---|---|
| GOV.UK Frontend | a site on one of the service manual's three domain forms — `gov.uk/myservice`, `myservice.service.gov.uk`, `myblog.blog.gov.uk` — not every `*.gov.uk` site (a council's own domain is not GOV.UK); `govuk-frontend` in the manifest; `{% from "govuk/components/…/macro.njk" %}` in templates | `govuk-frontend` (`6.5.1` at the stamp; MIT, docs OGL 3.0) | none for the brand — Sass `$govuk-*` settings (asset and font paths); components ship as Nunjucks macros (`govukButton`) and HTML | https://design-system.service.gov.uk, https://frontend.design-system.service.gov.uk | a site on those three forms must look like GOV.UK. Any other — other UK public-sector sites included — "can use the patterns" but must not "identify itself as being part of GOV.UK", "use the crown or GOV.UK logotype in the header", "use the GDS Transport typeface", "suggest that it's an official UK government website if it's not" or "use the GOV.UK brand colours" — https://www.gov.uk/service-manual/design/making-your-service-look-like-govuk |
| USWDS | a US federal site on a `.gov` domain; `@uswds/uswds` in the manifest | `@uswds/uswds` (`3.14.0` at the stamp); `uswds` is the 2.x name | Sass settings: `@use "uswds-core" with ($theme-color-primary: …)` | https://designsystem.digital.gov/documentation/settings/ | the official-government-site banner: "Do NOT use the banner on non-government domains such as a .com or .org." — https://designsystem.digital.gov/components/banner/ |
| Shopify Polaris | a Shopify app (`shopify.app.toml`) whose UI is its App Home in Shopify admin | Polaris web components from `<script src="https://cdn.shopify.com/shopifycloud/polaris.js">`, types `@shopify/polaris-types` (`1.1.0`). `@shopify/polaris` (React, `13.9.5`) is DEPRECATED — npm: "use Polaris web components" | none to override — `<s-page>` and the other `<s-*>` custom elements render in shadow DOM | https://shopify.dev/docs/api/polaris | the `@shopify/polaris` LICENSE.md (13.9.5): its rights "may only be exercised to develop and distribute applications that integrate or interoperate with Shopify software or services", and a stand-alone app not embedded in Shopify must be "dissimilar and visually distinct from Shopify products and services". App Home "is the area in the Shopify admin where your apps open" — https://shopify.dev/docs/api/app-home |
| IBM Carbon | an IBM product, said in the brief; `@carbon/*` in the manifest | `@carbon/react` (`1.117.0`) + `@carbon/styles` (`1.116.0`); `@carbon/web-components` (`2.64.0`) without React | `<Theme theme="g100">` (`white`, `g10`, `g90`, `g100`) in React; the same themes as Sass from `@carbon/styles` | https://carbondesignsystem.com | none found — Apache-2.0. Outside IBM it is an ordinary library under §1's install-asked rule |
| Atlassian | an Atlassian app for Jira, Confluence or another Atlassian product: Forge Custom UI (an iframe; its docs point to the Atlassian Design System) or Connect (`atlassian-connect.json`) → `@atlaskit/*`; Forge UI Kit (`manifest.yml`, `@forge/react` in the manifest) → `@forge/react` components instead — "UI Kit relies only on the `@forge/react` components and does not directly rely on React DOM" | Custom UI / Connect: `@atlaskit/*` — `@atlaskit/tokens` (`20.2.0`), `@atlaskit/primitives` (`22.5.4`), one package per component (`@atlaskit/button`). UI Kit: `@forge/react` | `@atlaskit/tokens`: `token('color.text')` in styles, `setGlobalTheme({…})` at the root | https://atlassian.design, https://developer.atlassian.com/platform/forge/ui-kit/overview/ | the Atlassian Design System License: for software "that interoperate[s] or [is] integrated with Atlassian's software and cloud products" — https://atlassian.design/license (npm metadata reads Apache-2.0; the licence page is the use term). Not `@atlaskit/pragmatic-drag-and-drop` and its `-hitbox`, `-auto-scroll` and other `pragmatic-drag-and-drop-*` siblings: a general-purpose Apache-2.0 drag-and-drop library ("any experience on any tech stack", npm), not the design system — the restriction and the lookalike rule do not apply to it |

Standing: **recorded** — no script re-reads these restrictions; SKILL.md §1, which applies
them, is agent-graded.

## Landscape notes

- shadcn/ui's July 2026 change makes Base UI the primitive for NEW inits; existing
  Radix projects need no migration. The `components.json` `style` value names the
  base: a `base-`, `radix-` or `aria-` prefix (`base-nova`, `radix-vega`) means Base
  UI, Radix or React Aria, and the legacy `new-york`/`default` values predate the
  choice and mean Radix. Confirm against the component files' imports
  (`@base-ui/react`, `radix-ui`, `react-aria-components`). Per-base API differences:
  `ui-ux:shadcn-best-practices`, its `references/bases.md`.
- `@base-ui-components/react` is Base UI's pre-1.0 package name, still pulled by some
  registry items. Both it and `@base-ui/react` in one lockfile is two copies of the
  same primitives — a finding; move the old imports to `@base-ui/react`.
- A library absent from this file is not unsupported — apply the SKILL.md rules and
  cite its docs; add a row when it recurs.
