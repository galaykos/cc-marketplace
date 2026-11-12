# TypeScript and JavaScript: what the analyzer run must report

Read by `code-review`'s `analyzer-expert` when the diff holds `*.ts`, `*.js`, `*.mts`, `*.cts`, `*.mjs` outside React hook rules and Vue single-file components. Tools: tsc, eslint, biome, oxlint.
The step order is `analyzer-triage`'s; this file adds what is specific to these tools.

## Steps, as they apply here

1. `bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-analyzers.sh" .` — exit 1 means no
   checker is configured: say so and STOP.
2. Read the `ci` records: which config does CI actually enforce?
3. Run the printed invocation, unless CI already passed it on this HEAD (the skill's step 4). `npx tsc --noEmit` is a whole-program check — its
   output covers files outside the diff, so attribute findings to the diff explicitly
   rather than dumping the full log.
4. Triage into new defect / baselined debt / config gap.

## What only this run can report

Strictness is the deliverable. A type checker's silence means nothing until the
reader knows what it was configured to look at:

- **`strict: false` or absent.** `strictNullChecks` is off with it, so every
  possibly-null dereference in the diff passes the build. This is the single most
  consequential fact you can report and it is invisible without reading the config.
- **`noUncheckedIndexedAccess: false`** — the default. Every `arr[i]` and
  `record[key]` is typed as present when it may be undefined. Name the specific
  indexed accesses in the diff this covers for.
- **`exactOptionalPropertyTypes: false`** — `{ a?: string }` silently accepts an
  explicit `undefined`, which is a different contract from absence.
- **Suppression comments.** `@ts-ignore`, `@ts-expect-error`, `eslint-disable` in the
  diff. One carrying a reason is a decision; a bare one is undocumented debt. Count
  both and quote the bare ones.
- **`any` and `as` in the diff.** An assertion defeats the checker at exactly the
  point the author was least sure. Report each with the type it overrides.
- **Excluded paths.** Files matched by `exclude` or `.eslintignore` were never
  checked. A green run over an ignored file is not evidence.

## Defer rules

- Component and view LOGIC — state, effects, keys, data fetching → `web-dev`'s
  frontend-reviewer. You grade the types; it grades the behaviour.
- Single-file Vue components → the Vue reference (`vue.md`). Plain `tsc` cannot parse
  them; the detector reports `vue-tsc` for that reason.
- Hook-dependency correctness in React files → the React reference (`react.md`).
- Markup, styles and accessibility → `/ui-ux:audit`.
- Applying fixes → `task-runner`'s task-executor.

## Before finishing

- [ ] The detector ran and decided whether to proceed.
- [ ] Every strictness flag from the detector appears in the report, on or off.
- [ ] Whole-program output was attributed to the diff, not dumped wholesale.
- [ ] Suppression comments in the diff were counted and the bare ones quoted.
- [ ] Nothing was edited.

Output: findings one line each — `path:line — severity — rule-id — problem — fix` —
severity-ordered, then a `Config gaps` block listing each off flag with the defect
class it hides, then one line naming the tool, its config and its exit code.
