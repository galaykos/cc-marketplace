---
name: agent-conventions
description: Use when naming a new subagent, deciding worker vs reviewer, giving an agent a PROACTIVELY trigger, or auditing why several agents fire on one edit — the marketplace's engineer/reviewer naming taxonomy, the one-surface trigger rule, and the shared apply-fixes contract that stops per-plugin fixer sprawl.
---

# Agent conventions

Before minting an agent, decide which of exactly two roles it is, name it so the
role is legible from the name alone, and give it a trigger that fires on ONE
surface — not "after any change". Skipping this is how a marketplace ends up with
a dozen reviewers all auto-firing on a single file edit.

## The two roles — a naming taxonomy

Every agent is a **worker** or a **reviewer**. Encode it in the suffix:

- **`<domain>-engineer`** — the worker. Writes, edits, runs commands, produces a
  diff. Tools: `Read, Write, Edit, Bash, Grep, Glob`.
- **`<domain>-reviewer`** — read-only. Inspects and reports findings; never edits,
  never runs mutating commands. Tools: `Read, Grep, Glob`.

One domain owns at most one of each. The pair — engineer + reviewer — is the unit;
`ui-ux` is the reference (`ui-ux-engineer` builds, `ui-ux-reviewer` audits). A lone
half is fine when only half the work is delegatable, but name it for the half it is:
a read-only agent is never `-engineer`.

Exceptions that keep their established names (do not rename): `code-reviewer`,
`test-engineer`, `security-engineer`, `database-engineer`, `context-scout`,
`spec-adversary`, `transcript-miner`. New agents follow the suffix rule.

## Worker or reviewer — pick by output

- Produces edits, files, migrations, instrumentation → **engineer**.
- Produces a findings list, a verdict, a report → **reviewer**.
- Both? That is two agents, not one. A reviewer that also fixes has no scope lock
  and cannot be trusted to stay read-only when fanned out.

## Proactive-trigger arbitration

`description: Use PROACTIVELY …` means the main thread may dispatch the agent
without being asked. That is a loaded gun when N agents all say "after editing
code": one `.tsx` save nominally wakes ui-ux-reviewer, a11y, the frontend reviewer,
code-reviewer. The fix is at authoring time, in the description:

- **Name one surface.** A PROACTIVELY trigger must state the specific surface —
  a file kind, a pipeline phase, an artifact — not "after any change". "after
  editing a migration or schema", not "after writing code".
- **One surface, one owner.** Two agents that would fire on the same surface must
  differentiate by specificity: the more specific claim wins, the general one steps
  back. `a11y` owns accessibility on markup; `ui-ux-reviewer` owns everything else
  on the same file — the descriptions say so, so both know when to defer.
- **Most-specific-wins at dispatch.** When surfaces still overlap, the main thread
  runs the single most-specific reviewer for that edit, not the whole set. Breadth
  comes from one review pass with several lenses (see verification-panels), not from
  several agents racing on one file.

An agent whose trigger cannot name its surface in one clause is not ready to be
PROACTIVE — ship it as an on-demand `/command` instead.

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

## Anti-patterns

- **`-engineer` that only reads** — a reviewer wearing a worker's name and tools.
- **"Use PROACTIVELY after any change"** — an un-arbitrated trigger; it fires on
  everything and collides with every sibling.
- **Per-plugin fixer** — N `<domain>-fixer` agents instead of one shared executor.
- **Orphan reviewer** — a review command with no engineer and no route to the shared
  executor, so "apply the fixes" falls back inline every time.
- **Silent bundle drift** — a new agent absent from `everything`/its suite, so the
  aggregate install is missing it and no gate notices.
