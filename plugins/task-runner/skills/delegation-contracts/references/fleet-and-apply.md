# Fleet gaps, delegation retrofit, and the apply-fixes contract

Read on demand from `../SKILL.md`. The authoring side (naming taxonomy, PROACTIVE-trigger
arbitration) lives in `.claude/skills/authoring-agents/references/naming-and-triggers.md`
(in the marketplace repository).

---

## Mapping the existing fleet

Recount it; do not read it from here. `ls plugins/*/agents/` IS the map — a copied
inventory goes stale and sends a reader to build what already exists.

A domain with a reviewer and no
worker has the **review-without-worker gap**: its `/…:review` produces a fix list with
nothing to hand it to. Close it with the shared executor — a domain engineer only where
the fix carries idioms a generic executor lacks.


## Adding delegation to a review-only plugin

1. Decide: does the fix need domain idioms a generic executor lacks? **No** → wire
   the review command's "apply the fixes" to the shared task-runner executor; add no
   agent. **Yes** → author one `<domain>-engineer` worker.
2. If a reviewer is also missing and the review currently runs inline, author one
   `<domain>-reviewer` with a single-surface PROACTIVELY trigger.
3. Apply the standing rider below to every agent added.


## The apply-fixes contract

Reviewers report; they do not each grow a fixer. Every `/…:review` that ends with
"Apply the fixes now" routes to the ONE shared executor in `task-runner` — scope-
locked, bounded verify-fix, evidence-returning. Do not add a `<domain>-fixer` per
plugin: that is the review-without-worker anti-pattern inverted into fixer sprawl,
and it re-creates the cross-plugin-ownership orphan (install one plugin, its fixer
lives in another). Domain **engineers** exist only where the fix carries real domain
idioms a generic executor lacks (backend dialects, instrumentation, a11y remediation);
everything else is the shared executor's job.


## Standing rider: bundle membership + version

A new agent is not done when its file is written. It must also:

1. **Bump** its plugin's `plugin.json` version (`check-version-bumps.sh` gates CI).
2. **Join the bundles** that advertise it — any `*-suite` whose
   description claims "all worker agents" or the agent's domain — plus that suite's
   uninstall prune list. A bundle promising a set it no longer contains is a silent
   lie the validator cannot catch.

## Fan-out doctrine — who owns which rule

Each fan-out rule has exactly one full statement; every other site keeps a one-line restatement plus a
pointer, because a SKILL body is not always-on and a bare pointer degrades a rule to
one the model may never follow.

| Rule | Owner |
|---|---|
| Never two writers on one file | `task-runner:delegation-contracts` |
| Topo-sort into levels, then group disjoint file sets | `task-runner:parallel-planning` |
| The fresh-session test | `taskmaster:task-cards` |
| A subagent's "done" is a claim, not evidence | `task-runner:task-execution` |
| Panel WIDTH (how many refuters) | `task-runner:verification-panels` § Panel width |

The split is by ACT, not by plugin convenience: delegation mechanics to delegation-contracts,
execution-time scheduling to task-runner, card authoring to taskmaster.

`taskmaster/skills/ultra/references/dispatch-tiers.md` owns recon lenses and the coverage loop — pipeline phases no other plugin runs.

Standing: **recorded**. No script checks that a new fan-out rule picks an owner.
