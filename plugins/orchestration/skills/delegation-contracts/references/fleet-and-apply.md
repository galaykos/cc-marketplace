# Fleet gaps, delegation retrofit, and the apply-fixes contract

Read on demand from `../SKILL.md`. The runtime half of the former
`agent-conventions` skill; its authoring half (naming taxonomy, PROACTIVE-trigger
arbitration) moved to `claude-authoring/skills/authoring-agents/references/naming-and-triggers.md`.

---

## Mapping the existing fleet

The taxonomy already holds where agents exist; the gaps are where it does not:

| Domain | Engineer (worker) | Reviewer (read-only) |
|---|---|---|
| ui-ux | `ui-ux-engineer` | `ui-ux-reviewer` |
| code | shared executor (task-runner) | `code-reviewer` |
| testing | `test-engineer` | — (code-reviewer covers) |
| security | `security-engineer` | — |
| database | `database-engineer` | — |

Most review-only plugins (a11y, debugging, observability, the reliability trio, the
stack plugins) have **neither** half wired for delegation — their `/…:review`
produces a fix list with nothing to hand it to. That is the review-without-worker
gap; close it with the shared executor, or a domain engineer only where idioms demand.


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
2. **Join the bundles** that advertise it — `everything`, and any `*-suite` whose
   description claims "all worker agents" or the agent's domain — plus that suite's
   uninstall prune list. A bundle promising a set it no longer contains is a silent
   lie the validator cannot catch.
