# task-runner prose derivations moved out of skills (2026-09-26)

The second move of this kind; the first is `rationale/2026-09-25-task-runner-prose-derivations.md`.
task-runner's on-invoke prose corpus sat at 158,056 B against `pc_plugin_corpus`'s
160,000 B cap when the UI walk gained its composite, non-drag and live-region checks
(272 B: inside a composite Tab enters once and arrows move, every drag also finishes
through its non-drag route, a live region announces a summary). The rules stayed in the
skills; the observations below moved here verbatim so the addition is offset rather
than spent from the headroom. Each heading names the file the text came from; a pointer
to this file was left in place.

## plugins/task-runner/skills/task-execution/references/reviewer-routing.md

§ UI diffs, why nothing deferred leaves the run:

> Measured 2026-09-25: reviewers deferred focus-loss items "→ /ui-ux:audit" or to the
> backlog. The audit never ran, no `ui-ux-reviewer` or `a11y-engineer` was spawned, and the
> items were never fixed.

## plugins/task-runner/skills/delegation-contracts/references/tree-wide-gates.md

Failure mode 1, the observed case:

> Observed: one agent's green scoped grep came with a PROSE caveat about the rest of the
> tree, and that caveat was the only reason the tree was ever checked — the next agent will
> not write it.

Failure mode 2, the observed case:

> Observed: one agent's typecheck failed on a sibling's transient
> mid-save file (`'project' is declared but its value is never read`) and cleared on retry.
> The scope lock held perfectly — the file sets were disjoint — but the verify command was
> never scoped, so it reported on somebody else's half-written work.
