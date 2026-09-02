# React component library map — signals, ownership, theme channel, docs

> Last verified: 2026-09-02. Sources: each library's docs plus landscape
> surveys (untitledui.com/blog/react-component-libraries,
> greatfrontend.com/blog/top-headless-ui-libraries-for-react-in-2026,
> ui.shadcn.com/docs/changelog/2026-07-base-ui-default). Popularity notes are
> a snapshot; re-verify before quoting.

Read on demand from `component-libraries`. Detection signal → ownership model
→ theme channel → where the truth lives. A row without a sibling skill is
governed by the SKILL.md rules plus its docs URL.

## Headless (behaviour + a11y, no styles)

| Library | Signal | Theme channel | Docs | Notes |
|---|---|---|---|---|
| Base UI | `@base-ui/react` | none — your CSS/Tailwind, `data-*` state attrs | https://base-ui.com/react/overview/quick-start | MUI-maintained; v1.0 Dec 2025; `render` prop for polymorphism; shadcn/ui's default primitive since Jul 2026 |
| Radix Primitives | `radix-ui` (unified pkg, Feb 2026) or `@radix-ui/react-*` | none — `data-state` attrs | https://www.radix-ui.com/primitives/docs/overview/introduction | Still supported by shadcn (`-b radix`); WorkOS-owned, slower cadence; `asChild` |
| React Aria Components | `react-aria-components` (hooks: `react-aria`) | none — render props, `data-*`; `className` fn | https://react-spectrum.adobe.com/react-aria/ | Adobe; strictest a11y + i18n; the base under HeroUI and Untitled UI |
| Ark UI | `@ark-ui/react` | none — `data-*`; state machines | https://ark-ui.com/docs/overview/introduction | Chakra team; also Vue/Solid/Svelte; `.Root/.Trigger` compounds |
| Headless UI | `@headlessui/react` | none — Tailwind-first `data-*`/render props | https://headlessui.com | Tailwind Labs; small set (~10 components) |
| Ariakit | `@ariakit/react` | none | https://ariakit.org | Store-based state, fine-grained a11y |

## Styled, npm dependency (configure the theme, never patch)

| Library | Signal | Theme channel | Docs | Notes |
|---|---|---|---|---|
| Material UI | `@mui/material` | `createTheme` + CSS vars | https://mui.com/material-ui/ | sibling skill `mui-best-practices`; MUI X versioned separately |
| Mantine | `@mantine/core` | `createTheme` + `MantineProvider`, CSS modules | https://mantine.dev | 100+ components and hooks; `@mantine/hooks`, `/dates`, `/form` |
| Chakra UI | `@chakra-ui/react` | `createSystem`/`defineConfig` (v3), tokens + recipes | https://chakra-ui.com/docs | v3 is built on Ark UI; `asChild` |
| Ant Design | `antd` | `ConfigProvider` `theme.token`/`components`, CSS-in-JS | https://ant.design/docs/react/introduce | enterprise/data-heavy; `@ant-design/icons`, `@ant-design/pro-components` |
| HeroUI (ex-NextUI) | `@heroui/react` | Tailwind plugin `heroui()` themes | https://www.heroui.com/docs | Tailwind + React Aria; `tailwind-variants` |
| Astryx | `@astryxdesign/core` | `Theme`/`useTheme`, StyleX pre-compiled | https://astryx.atmeta.com/components | sibling skill `astryx-best-practices`; beta |
| Reshaped | `reshaped` | theme CSS vars via its CLI | https://reshaped.so/docs | open-sourced Sep 2025; Figma parity |
| React-Bootstrap | `react-bootstrap` + `bootstrap` | Bootstrap SCSS variables / CSS vars | https://react-bootstrap.github.io | Bootstrap semantics; no sibling skill (baseline-removed) |
| Fluent UI, Primer, Blueprint | `@fluentui/react-components`, `@primer/react`, `@blueprintjs/core` | each ships a provider + tokens | vendor docs | corporate design systems; stay inside them |

## Styled, copy-in / registry (owned code — edit it, do not re-fetch over edits)

| Library | Signal | Theme channel | Docs | Notes |
|---|---|---|---|---|
| shadcn/ui | `components.json`, `components/ui/*` | CSS variables (`--primary`, …) | https://ui.shadcn.com/docs | sibling skills `shadcn-best-practices`, `shadcn-theming`; Base UI default from Jul 2026, Radix via `-b radix` |
| ReUI, Aceternity UI | shadcn-style registries | shadcn CSS vars | https://reui.io/docs, https://ui.aceternity.com/components | sibling skills; no npm version to pin |
| Untitled UI React | `@untitledui/*` starter or copied files | Tailwind v4 `@theme` | https://www.untitledui.com/react | Tailwind + React Aria; open-source core, paid Pro |
| Kibo UI | shadcn registry (`kibo-ui` namespace) | shadcn CSS vars | https://www.kibo-ui.com | composed blocks; Shadcnblocks-owned since Oct 2025 |
| 21st.dev, shadcnblocks | registry URLs in `components.json` | shadcn CSS vars | https://21st.dev, https://www.shadcnblocks.com | community/commercial blocks; treat as copy-in |
| daisyUI | Tailwind plugin `daisyui` | Tailwind theme + daisyUI theme vars | https://daisyui.com/docs | class-based, no React runtime; governed by `tailwind-best-practices` |

## Landscape notes (snapshot)

- Tailwind integration is the leading selection factor in 2026 surveys;
  the growth is in headless + Tailwind stacks (shadcn, HeroUI, Untitled UI).
- shadcn/ui's July 2026 change makes Base UI the primitive for NEW inits;
  existing Radix projects need no migration. Detect which build a project has
  from its component files (`radix-ui` vs `@base-ui/react` imports), not from
  `components.json` alone.
- Ant Design and MUI remain the two largest by weekly downloads; Mantine is the
  fastest-growing full-styled set. Chakra v3 moved onto Ark UI internals.
- A library absent from this file is not unsupported — apply the SKILL.md
  rules and cite its docs; add a row when it recurs.
