# Vue single-file components: what the analyzer run must report

Read by `code-review`'s `analyzer-expert` when the diff holds `*.vue`. Tools: vue-tsc, eslint-plugin-vue.
The step order is `analyzer-triage`'s; this file adds what is specific to these tools.

## Steps, as they apply here

1. `bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-analyzers.sh" .` — exit 1 means no
   analyzer: say so and STOP.
2. Read the `ci` records: which config is enforced?
3. Run the printed invocation, unless CI already passed it on this HEAD (the skill's step 4). The detector reports `vue-tsc` in place of `tsc`
   whenever the project has it, because the two are not interchangeable here.
4. Triage into new defect / suppressed / config gap.

## What only this run can report

- **The SFC typecheck hole.** If the project runs plain `tsc` in CI and has single-file
  components, those components' scripts and templates are **not type-checked at all** —
  the compiler cannot parse the file format. A green typecheck job is not evidence
  about any component. Check the CI invocation, not just the installed packages, and
  make this the headline finding when it holds.
- **Template type coverage.** Template expressions are checked only when the project
  has that turned on. Untyped templates mean a renamed prop or a misspelt field in a
  template fails at runtime with the build green.
- **`eslint-plugin-vue` presence and preset tier.** The presets differ sharply in what
  they catch — an `essential`-tier config catches far less than the stronger tiers.
  Report the configured tier, not just that the plugin exists.
- **Reactivity-loss rules.** Whether the config enables the rules covering lost
  reactivity from destructuring, and unstable `v-for` keys. When they are off, these
  bugs are invisible to the build and must be found by a reader.
- **Suppressions in the diff.** `@ts-nocheck` at the top of a component script, or
  `eslint-disable` on a template rule. Quote each bare one.

## Defer rules

- Component and view logic beyond what the tools check — data fetching, prop flow,
  store usage, Inertia page props → `web-dev`'s frontend-reviewer, which grades Vue in
  its own vocabulary.
- Types outside single-file components → the TypeScript reference (`ts.md`).
- Markup semantics, ARIA, focus order → `/ui-ux:audit`.
- Styles and design tokens → `ui-ux`'s ui-ux-reviewer.
- Applying fixes → `task-runner`'s task-executor or `web-dev`'s web-developer.

## Before finishing

- [ ] The detector ran and decided whether to proceed.
- [ ] The CI invocation was checked for the plain-typecheck hole, not just the manifest.
- [ ] The configured lint preset tier is named.
- [ ] Every finding cites the rule id or compiler code the tool emitted.
- [ ] Nothing was edited.

Output: findings one line each — `path:line — severity — rule-id — problem — fix` —
severity-ordered, then a `Config gaps` block, then one line naming the tool, its
config and its exit code.
