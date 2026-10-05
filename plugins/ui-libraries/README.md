# ui-libraries

Component-library skills: **Material UI** (with MUI X Data Grid, Pickers and Charts),
**Astryx** (Meta's design system), **ReUI** and **Aceternity UI** (shadcn-compatible
registries), and a library-agnostic **component-libraries** skill for every other React
or Vue component library — headless (Base UI, Radix, React Aria, Ark, Headless UI) or
styled (Mantine, Chakra, Ant Design, HeroUI, PrimeVue, Vuetify, Element Plus) — and for an
organisation's own service owed its official design system (GOV.UK Frontend, USWDS, Polaris,
Carbon, Atlassian), with a per-library map of detection signals, theme channels and docs URLs.

These skills lived in `ui-ux` until 2026-09-26. They moved because `ui-ux` had reached
the marketplace's per-plugin prose cap, and the split keeps the foundations (shadcn,
Tailwind, theming, tokens, motion, the WCAG audit, `/ui-ux:build`) and the library
layer each under it.

> **Pairs with `ui-ux` — install both.** `/ui-ux:build` and the ui-ux agents are what load
> these skills; without ui-ux they only fire through skill-router or by name. Nothing
> installs the pair for you: no plugin here may declare `dependencies`, and the suites
> that used to carry both were retired the same day these skills moved.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install ui-libraries@cc-plugins-marketplace
/plugin install ui-ux@cc-plugins-marketplace
```

## Skills

| Skill | Reach for it when |
|---|---|
| `mui-best-practices` | The project imports `@mui/material`, `@mui/icons-material` or `@mui/x-*` — imports, `createTheme` with CSS variables, `sx`/`slotProps`, MUI X per-major APIs |
| `astryx-best-practices` | The project imports `@astryxdesign/*` or runs the `astryx` CLI — beta 0.x, pin the installed version first |
| `primereact-best-practices` | The project imports `primereact`, `@primereact/*` or `@primeuix/*` — v10 or v11 from the lockfile first, v11's PrimeUI licence key, token presets on `PrimeReactProvider`, compound parts, the renames and the Tailwind registry |
| `reui-best-practices` | ReUI registry components or blocks — shadcn-compatible installs, owned-code discipline |
| `aceternity-best-practices` | Aceternity UI motion-heavy marketing components — placement limits, motion deps, reduced motion |
| `component-libraries` | Any other React or Vue component library, two libraries on one surface, or an organisation's own service that must use its official design system (GOV.UK, USWDS, Polaris, Carbon, Atlassian) — library-agnostic rules plus `references/library-map.md` |

With `skill-router` installed, the skills load on their own when a matching import or
manifest appears. `/ui-ux:build` and the `ui-ux` agents name them as `ui-libraries:<skill>`.

The router keys on quoted package imports, so organisation design systems reach a page in
forms it does not match: GOV.UK Frontend's Nunjucks templates
(`{% from "govuk/components/button/macro.njk" import govukButton %}`), Sass entry points
(`@use "node_modules/govuk-frontend/dist/govuk"`, USWDS's `@use "uswds-core" with (…)`) and
Polaris's CDN script tag (`<script src="https://cdn.shopify.com/shopifycloud/polaris.js">`). Those, and a
brief for a UK government service, US federal site, Shopify app, IBM product or Atlassian
app before any import exists, reach `component-libraries` through its description alone.

Credit: the official-design-system rule in `component-libraries` is adapted from [leonxlnx/taste-skill](https://github.com/leonxlnx/taste-skill) at ce26fc25 (MIT, © 2026 Leonxlnx), rewritten here rather than copied; the package names and use restrictions were re-read from each system's official docs and npm on 2026-10-05, and the rule's effect on what the model installs is unmeasured.

## Pairs well with

- **ui-ux** — shadcn/ui and Tailwind skills, theming, design tokens, motion, the WCAG audit, and the build/review agents that load these skills
- **craft-layer** — the creative-build studio that builds on either layer

## Evals

`evals/` holds control-arm probes from the 2026-09-25 design-capability corpus
(`rationale/2026-09-25-design-capability-corpus/`): each case names a rule the base model
is expected to get wrong from memory, and a new artifact for that rule ships only if the
no-plugin arm fails it. Run them with the write grant — the cases write files, and
`Write`/`Edit` are gated tools the runner will not hand a plugin without it:

```bash
claude plugin eval ./plugins/ui-libraries --ablation with-without --runs 5 \
  --allow-tools Write Edit --no-publish --trust-plugin
```

Without the grant the suite still loads and then declines the case, so a clean-looking run
has measured nothing. State the run count and vote spread with any delta.
