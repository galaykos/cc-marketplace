# Changelog — ui-libraries

Consumer-facing changes only. Newest first.

## 0.2.0 — 2026-10-05

- **An organisation's own service uses its official design system.** `component-libraries` §1 now says: when the project IS a GOV.UK service (one of the service manual's three domain forms, not every `*.gov.uk` site), a US federal `.gov` site, a Shopify app, an IBM product or an Atlassian app — said in the brief or evident in the repo — its official package is the required library, ranking above "do not install one unasked" because the system is the requirement. A repo already on another library makes it a migration to raise with the user, never a second library added silently, and a decided `Stack:`/`Locks:` line still outranks it. Never recreate its CSS by hand; never import its tokens and override most of them. A brief that wants only the look never installs a restricted system (GOV.UK, the USWDS banner, Polaris, Atlassian); another UK public-sector site may use GOV.UK's patterns, never its crown, GDS Transport or brand colours. Standing: agent-graded.
- **Five rows in `library-map.md`'s new Organisation design systems table**, read from npm and the official docs on 2026-10-05: GOV.UK Frontend (`govuk-frontend` 6.5.1), USWDS (`@uswds/uswds` 3.14.0), Shopify Polaris (web components from Shopify's CDN with `@shopify/polaris-types` 1.1.0; the React `@shopify/polaris` 13.9.5 is deprecated), IBM Carbon (`@carbon/react` 1.117.0, `@carbon/styles` 1.116.0, `@carbon/web-components` 2.64.0) and Atlassian (`@atlaskit/*` for Forge Custom UI and Connect, `@forge/react` for Forge UI Kit; `@atlaskit/pragmatic-drag-and-drop` is marked as not the design system). Each row carries its use restriction as the official source states it; Carbon has none. Standing: recorded — no script re-reads the restrictions, and the versions are as of the stamp.
- **`component-libraries`' description names the five systems**, so a brief for such a service reaches the skill before any import exists. Cost: this plugin's always-on context grows 37 tokens (408 → 445), measured by the marketplace repository's budget gate; that baseline moved for this plugin alone.
- **The README names what the router cannot see:** GOV.UK Frontend's Nunjucks templates, Sass entry points (`govuk-frontend`, USWDS's `uswds-core`) and Polaris's CDN script tag carry no quoted package import, so they reach the skill through its description alone. skill-router 0.23.1 routes the quoted imports.
- **Credit and effect.** The rule is adapted from [leonxlnx/taste-skill](https://github.com/leonxlnx/taste-skill) at ce26fc25 (MIT, © 2026 Leonxlnx), rewritten here rather than copied; the package names and restrictions were re-read from the official sources, not taken from upstream. Unmeasured: whether it changes what the model installs. No eval with a control arm covers it.

## 0.1.0 — 2026-09-26

- Split out of `ui-ux`, which had reached the 160,000-byte per-plugin prose cap
  (`pc_plugin_corpus`). Moved unchanged: `mui-best-practices`, `astryx-best-practices`,
  `reui-best-practices`, `aceternity-best-practices`, `component-libraries`. Skill names
  change from `ui-ux:<skill>` to `ui-libraries:<skill>`. Every suite that carries `ui-ux`
  now carries this plugin; a standalone `ui-ux` install needs this one added by name.
- New `primereact-best-practices`: PrimeReact 11 is a rewrite (GA 2026-07-15) — `@primereact/ui` vs the
  unstyled `primereact`, `@primeuix/themes@3` presets on `PrimeReactProvider`, compound parts, the renames,
  folded and Pro-only components, the Tailwind registry mode, and the PrimeUI licence key; v10 projects are
  left alone. A control-arm probe (`evals/primereact-v11-screen`, deterministic re-grade of the written files)
  measured the base model at 1/5 on v11 API and 0/5 on licence handling; with this skill, 5/5 and 5/5.
- MUI X per-major table (Data Grid / Pickers / Charts v8–v9), licence-key regeneration, Joy UI removal;
  `library-map.md` refreshed (HeroUI v3, PrimeVue v5 licence, Vuetify 4; Catalyst, Tremor, PrimeReact
  rows; base detection); ReUI and Aceternity keep only registry-specific lines and cite ui-ux's shared
  registries reference.
