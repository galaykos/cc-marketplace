# Index markers — `Ultra:` and `Goal:`

Read this when a run is boosted. On a standard run none of it applies, which is
why it is not in the SKILL body: it was four rules on ONE 1,542-character line
(~380 tokens), loaded on every card-writing run including the unboosted ones, and
a line-count ceiling cannot see a line grow.

Under `ULTRA-TASK ACTIVE` (see the `ultra` skill), also write an exact `Ultra: true
(model=auto, effort=xhigh)` line near the top of `00-INDEX.md` — copy the directive's
`model`/`effort` VERBATIM. The tier is FIXED, not defaulted: `ultra/SKILL.md` § Fixed tier
makes it `model=auto, effort=xhigh` always, the suffix grammar is removed, and both hook
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
body (`SKILL.md`, "Output layout"). It was in this file until 2026-09-22, which put the
write behind the boost gate while `task-runner`'s task-execution skill read the section
on every run: a standard run's index never carried it, and the reader found nothing
where it looked. Only the `Ultra:`/`Goal:` markers are boosted-only, and the blockquote
prefix that keeps exact-prefix marker parsing safe is stated beside the write.
