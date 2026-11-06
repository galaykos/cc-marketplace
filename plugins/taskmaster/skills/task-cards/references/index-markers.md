# Index markers — `Ultra:`, `Goal:` and `Verify:`

Read this when a run is boosted, or when the brief that opened it carries `Verify: range`.
On any other run none of it applies.

## `Verify: range` — copied, never decided here

When the brief `/taskmaster:task` was given (overseer writes one per milestone), or the spec
header, carries a line `Verify: range`, write exactly `Verify: range` near the top of
`00-INDEX.md`, unprefixed, beside any `Ultra:`/`Goal:` line. task-runner then verifies per run,
not per card (overseer's `references/range-verify.md`), and candor's clause 4 reads the same
line. Never add it on your own judgment: whether per-card review is bought is the caller's call.
Overseer re-checks the index for it after task-cards (**agent-graded**); candor reads it (**gate**).

## `Ultra:` and `Goal:`

Under `ULTRA-TASK ACTIVE` (see the `ultra` skill), also write an exact `Ultra: true
(model=auto, effort=xhigh)` line near the top of `00-INDEX.md`, copying the directive's
`model`/`effort` VERBATIM: the tier is FIXED (`ultra/SKILL.md` § Fixed tier, hardcoded in both
hook directives), and the literal `auto` lets a fresh execution session re-resolve it, so the
run inherits the boost at the same tier. Under `ULTRA-GOAL ACTIVE` (the `ultra` skill's Goal mode), FIRST run
`"${CLAUDE_PLUGIN_ROOT}/scripts/goal-ledger-check.sh" --slug <slug>` — exit 2 blocks the stamp
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

Writing `## Upgraded statement` is unconditional, so it lives in `SKILL.md` "Output layout"
beside its blockquote-prefix rule; only the `Ultra:`/`Goal:` markers are boosted-only.
