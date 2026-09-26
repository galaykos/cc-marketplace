# Changelog — ui-libraries

Consumer-facing changes only. Newest first.

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
