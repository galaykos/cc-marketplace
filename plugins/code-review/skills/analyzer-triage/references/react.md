# React hook rules: what the analyzer run must report

Read by `code-review`'s `analyzer-expert` when the diff holds `*.tsx`, `*.jsx` and any file calling hooks. Tools: eslint with eslint-plugin-react-hooks and eslint-plugin-react.
The step order is `analyzer-triage`'s; this file adds what is specific to these tools.

## Steps, as they apply here

1. `bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-analyzers.sh" .` — exit 1, or no
   eslint record, means the rules that catch these bugs are not installed: report
   that as the finding and STOP.
2. Read the `ci` records: is the lint enforced, or advisory?
3. Run the printed invocation scoped to the changed files. Skip it when CI already passed it on this HEAD (the skill's step 4 says how to tell).
4. Triage into new defect / suppressed / config gap.

## What only this run can report

- **`react-hooks/exhaustive-deps` severity.** The detector prints it. `warn` and
  `off` both produce a green build while the defect ships, and they are
  indistinguishable from a passing CI log. This is your headline finding whenever it
  is not `error`.
- **`react-hooks/rules-of-hooks` presence.** Absent means conditional and looped hook
  calls are uncaught — a class the type checker also cannot see.
- **Whether the plugin is installed at all.** An eslint config with no React hooks
  plugin lints style and catches none of this. Say so plainly.
- **Bare `eslint-disable-next-line react-hooks/exhaustive-deps` in the diff.** The
  most common way a real dependency bug is silenced. Quote each one; a disable with a
  stated reason is a decision, a bare one is not.
- **`react/button-has-type` (eslint-plugin-react).** The detector prints its severity, or
  `absent`. Absent or off means a `<button>` with no `type` inside a `<form>` submits
  it — a class no type checker sees and code review catches only by luck. Report it
  when eslint-plugin-react is configured; no plugin, no line.
- **React Compiler.** If the project enables it, the dependency rules are enforced by
  the compiler and a demoted lint rule matters less — check before making the headline
  finding, and say which regime applies.

Report what the tools found. Where you add a judgment of your own, mark it as
unverified by any tool, so the reader can weigh it against the lint's evidence.

## Defer rules

- Component and view logic beyond hook rules — data fetching, keys, derived state,
  server/client boundaries → `web-dev`'s frontend-reviewer, which owns that rubric.
- Types, `any`, assertions, compiler strictness → the TypeScript reference (`ts.md`).
- Next.js App Router specifics → the Next.js skill via `/code-review:review`.
- Markup semantics, ARIA, focus order → `/ui-ux:audit`.
- Applying fixes → `task-runner`'s task-executor or `web-dev`'s web-developer.

## Before finishing

- [ ] The detector ran; an absent hooks plugin was reported as the finding.
- [ ] The exhaustive-deps severity is stated explicitly, even when it is `error`.
- [ ] Every lint finding cites the rule id the tool emitted.
- [ ] Any judgment not backed by tool output is marked unverified.
- [ ] Nothing was edited.

Output: findings one line each — `path:line — severity — rule-id — problem — fix` —
severity-ordered, then a `Config gaps` block, then one line naming the config, the
enforced severity of each hook rule, and the lint's exit code.
