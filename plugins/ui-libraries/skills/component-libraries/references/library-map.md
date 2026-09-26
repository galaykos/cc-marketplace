# Component library map (React, Vue, Svelte) — signals, ownership, theme channel, docs

> Last verified: 2026-09-22 — the Radix, Park UI, Flowbite and Svelte rows re-read
> against their own docs and npm that day; every other row carries its 2026-09-02
> reading.

Read on demand from `component-libraries`. A row with no sibling skill is governed
by the SKILL.md rules plus its docs URL.

## Headless (behaviour + a11y, no styles)

| Library | Signal | Theme channel | Docs | Notes |
|---|---|---|---|---|
| Base UI | `@base-ui/react` | none — your CSS/Tailwind, `data-*` attrs | https://base-ui.com/react/overview/quick-start | MUI-maintained; `render` prop; shadcn/ui's default primitive since Jul 2026 |
| Radix Primitives | `radix-ui` (unified pkg) or `@radix-ui/react-*` | none — `data-state` attrs | https://www.radix-ui.com/primitives/docs/overview/introduction | still supported by shadcn (`-b radix`); `asChild`. NOT `@radix-ui/themes` — the styled sibling below, which is what a "Radix project" with no `components.json` usually means |
| React Aria Components | `react-aria-components` (hooks: `react-aria`) | none — render props, `data-*`, `className` fn | https://react-spectrum.adobe.com/react-aria/ | strictest a11y + i18n; base of HeroUI and Untitled UI |
| Ark UI | `@ark-ui/react` | none — `data-*`; state machines | https://ark-ui.com/docs/overview/introduction | Chakra team; also Vue/Solid/Svelte; `.Root/.Trigger` compounds |
| Headless UI | `@headlessui/react` | none — Tailwind-first `data-*` | https://headlessui.com | small set |
| Ariakit | `@ariakit/react` | none | https://ariakit.org | store-based state |

## Styled, npm dependency (configure the theme, never patch)

| Library | Signal | Theme channel | Docs | Notes |
|---|---|---|---|---|
| Material UI | `@mui/material` | `createTheme` + CSS vars | https://mui.com/material-ui/ | sibling skill `mui-best-practices`; MUI X versioned separately |
| Radix Themes | `@radix-ui/themes` | `<Theme accentColor grayColor radius scaling panelBackground>` wrapping the app, then `--accent-1..12` / `--gray-*` | https://www.radix-ui.com/themes/docs/theme/overview | v3.x, the STYLED sibling of Radix Primitives: same org, different package, a full token system. Theming it through shadcn's `--primary` is the common mistake |
| Flowbite React | `flowbite-react` (vanilla sibling: `flowbite`, a Tailwind plugin) | `createTheme` + `ThemeProvider`, or a per-component `theme` prop — Tailwind CLASS STRINGS, not CSS variables | https://flowbite-react.com/docs | nested providers merge unless `root` is set; the class-string channel means `shadcn-theming`'s variable advice does not transfer |
| Mantine | `@mantine/core` | `createTheme` + `MantineProvider`, CSS modules | https://mantine.dev | `@mantine/hooks`, `/dates`, `/form` |
| Chakra UI | `@chakra-ui/react` | `createSystem`/`defineConfig` (v3), tokens + recipes | https://chakra-ui.com/docs | v3 is built on Ark UI; `asChild` |
| Ant Design | `antd` | `ConfigProvider` `theme.token`/`components` | https://ant.design/docs/react/introduce | `@ant-design/icons`, `/pro-components` |
| HeroUI (ex-NextUI) | `@heroui/react` | Tailwind plugin `heroui()` themes | https://www.heroui.com/docs | Tailwind + React Aria |
| Astryx | `@astryxdesign/core` (+ `theme-*`, `cli`) | `Theme` + `defineTheme()` light/dark tuples, `xstyle` (StyleX) | https://astryx.atmeta.com/docs/getting-started | sibling skill `astryx-best-practices`; beta 0.x |
| Reshaped | `reshaped` | theme CSS vars via its CLI | https://reshaped.so/docs | — |
| React-Bootstrap | `react-bootstrap` + `bootstrap` | Bootstrap SCSS variables / CSS vars | https://react-bootstrap.github.io | no sibling skill |
| Fluent UI, Primer, Blueprint | `@fluentui/react-components`, `@primer/react`, `@blueprintjs/core` | each ships a provider + tokens | vendor docs | corporate systems; stay inside them |

## Styled, copy-in / registry (owned code — edit it, do not re-fetch over edits)

| Library | Signal | Theme channel | Docs | Notes |
|---|---|---|---|---|
| shadcn/ui | `components.json`, `components/ui/*` | CSS variables (`--primary`, …) | https://ui.shadcn.com/docs | sibling skills `shadcn-best-practices`, `shadcn-theming`; Base UI default from Jul 2026, Radix via `-b radix` |
| ReUI, Aceternity UI | shadcn-style registries | shadcn CSS vars | https://reui.io/docs, https://ui.aceternity.com/components | sibling skills; no npm version to pin |
| Untitled UI React | `@untitledui/*` starter or copied files | Tailwind v4 `@theme` | https://www.untitledui.com/react | Tailwind + React Aria; open core, paid Pro |
| Park UI | `@park-ui/cli` plus a Panda CSS config | Panda recipes and tokens; Park UI's colour system replaces Panda's default 50–950 shades | https://park-ui.com/docs | Ark UI + Panda CSS; `@park-ui/cli add <component>` copies code you then own. React, Solid |
| daisyUI | Tailwind plugin `daisyui` | Tailwind theme + daisyUI theme vars | https://daisyui.com/docs | class-based, no React runtime; governed by `tailwind-best-practices` |

## Vue 3 (same ownership rules)

| Library | Signal | Theme channel | Docs | Notes |
|---|---|---|---|---|
| Reka UI (ex-Radix Vue) | `reka-ui` (old: `radix-vue`) | none — `data-*` attrs | https://reka-ui.com | primitive under shadcn-vue and Nuxt UI; `as-child` |
| shadcn-vue | `components.json`, `components/ui/*.vue` | shadcn CSS variables | https://www.shadcn-vue.com/docs | copy-in; Reka UI build; same `shadcn-theming` tokens as the React one |
| Headless UI (Vue) | `@headlessui/vue` | none — Tailwind-first | https://headlessui.com/v1/vue | small set |
| Ark UI (Vue) | `@ark-ui/vue` | none — `data-*` | https://ark-ui.com/vue/docs/overview/introduction | same state machines as the React build |
| PrimeVue | `primevue` | `definePreset` tokens, `@primeuix/themes`; Tailwind via `tailwindcss-primeui` | https://primevue.org | v4 tokens are CSS variables; unstyled + Tailwind passthrough supported |
| Vuetify | `vuetify` | `createVuetify({ theme })` | https://vuetifyjs.com | Material Design; v3 on Vue 3 |
| Element Plus | `element-plus` | SCSS variables / CSS vars (`--el-*`) | https://element-plus.org | — |
| Naive UI | `naive-ui` | `NConfigProvider` `themeOverrides` | https://www.naiveui.com | TS-first |
| Quasar | `quasar` | `setCssVar`/Sass vars, `quasar.config` | https://quasar.dev | app framework, not just components |
| Nuxt UI | `@nuxt/ui` | `app.config.ts` `ui` + Tailwind `@theme` | https://ui.nuxt.com | Reka UI + Tailwind v4; Nuxt or plain Vue |
| Inertia page props | `@inertiajs/vue3` / `@inertiajs/react` | — | `inertia-best-practices` (laravel plugin) | not a component library |

## Svelte 5 (same ownership rules)

| Library | Signal | Theme channel | Docs | Notes |
|---|---|---|---|---|
| Bits UI | `bits-ui` | none — `class` props + `data-*` attrs | https://bits-ui.com/docs | the primitive under shadcn-svelte; unstyled |
| shadcn-svelte | `components.json`, `$lib/components/ui/*.svelte` | shadcn CSS variables | https://www.shadcn-svelte.com/docs | copy-in; Bits UI + Tailwind; `shadcn-theming`'s tokens apply unchanged |
| Melt UI | `@melt-ui/svelte` (builders) OR `melt` (the runes rewrite) | none — builder props spread onto your elements | https://melt-ui.com, https://next.melt-ui.com | TWO packages, not one version: read which the manifest has. Both pre-1.0 |
| Skeleton | `@skeletonlabs/skeleton` + `@skeletonlabs/skeleton-svelte` | Tailwind `@import` of a theme file, then `data-theme` on `<html>` | https://www.skeleton.dev/docs | Tailwind design system; also ships a React build |

## Landscape notes

- shadcn/ui's July 2026 change makes Base UI the primitive for NEW inits; existing
  Radix projects need no migration. Detect which build a project has from its
  component files (`radix-ui` vs `@base-ui/react` imports), not `components.json`.
- A library absent from this file is not unsupported — apply the SKILL.md rules and
  cite its docs; add a row when it recurs.
