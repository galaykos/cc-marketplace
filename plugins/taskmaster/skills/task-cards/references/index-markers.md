# Index markers — `Ultra:` and `Goal:`

Read this when a run is boosted. On a standard run none of it applies.

Under `ULTRA-TASK ACTIVE` (see the `ultra` skill), also write an exact `Ultra: true
(model=auto, effort=xhigh)` line near the top of `00-INDEX.md` — copy the directive's
`model`/`effort` VERBATIM. The tier is FIXED, not defaulted: `ultra/SKILL.md` § Fixed tier
makes it `model=auto, effort=xhigh` always, and both hook
directives hardcode it — so those two values are the only ones that can ever appear. `auto`
stays the literal `auto` so execution
re-resolves it in its own session. That is how a fresh-session execution run inherits the boost at the
same tier. Under `ULTRA-GOAL ACTIVE` (the `ultra` skill's Goal mode), FIRST run
`${CLAUDE_PLUGIN_ROOT}/scripts/goal-ledger-check.sh --slug <slug>` — exit 2 blocks the stamp
(an unaudited goal run may not hand itself off); then ALSO write an exact `Goal: true
(model=<model>, effort=<effort>) — requires task-runner ≥0.11.0; older runners fall back to
interactive execution` line with the resolved tier (ultra-task tier when both tokens are
present); when only goal is active, write BOTH lines — the `Ultra:` line carries the resolved
tier because goal implies the boost. Both markers go near the top of `00-INDEX.md`,
beside the `## Upgraded statement` section when the SKILL body's unconditional rule
wrote one.

Under `ULTRA-GOAL ACTIVE (boost=off)` (goal-lean): the same ledger check first, then write
exactly `Goal: true (boost=off) — requires task-runner ≥0.32.0; older runners read a lone
Goal marker as boosted` and NO `Ultra:` line — there is no tier to carry, and an `Ultra:`
line would buy the code red-team the caller declined.

## The upgraded statement is NOT here

Writing `## Upgraded statement` into the index is unconditional and lives in the SKILL
body (`SKILL.md`, "Output layout"), because task-execution reads it on every run. Only
the `Ultra:`/`Goal:` markers are boosted-only, and the blockquote
prefix that keeps exact-prefix marker parsing safe is stated beside the write.
