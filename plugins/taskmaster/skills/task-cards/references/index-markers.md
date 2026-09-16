# Index markers — `Ultra:`, `Goal:`, and the upgraded statement

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
tier because goal implies the boost. Also copy the spec header's `**Upgraded statement:**`
verbatim into a `## Upgraded statement` section of `00-INDEX.md` — a single Markdown blockquote
(every line `> `-prefixed, at most ~8 lines) placed near these `Ultra:`/`Goal:` markers; the `>
` prefix guarantees no statement line can start with `Ultra:` or `Goal:`, so exact-prefix
marker parsing stays safe. When the spec header has no labeled `**Upgraded statement:**` pair
(older or hand-written spec), SKIP the section entirely — never derive a statement at card
time.

Under `ULTRA-GOAL ACTIVE (boost=off)` (goal-lean): the same ledger check first, then write
exactly `Goal: true (boost=off) — requires task-runner ≥0.32.0; older runners read a lone
Goal marker as boosted` and NO `Ultra:` line — there is no tier to carry, and an `Ultra:`
line would buy the code red-team the caller declined. The upgraded-statement section is
written as under goal.

## Why the blockquote prefix is load-bearing

Every line of the `## Upgraded statement` section is `> `-prefixed so no statement
line can begin with `Ultra:` or `Goal:`. Marker parsing is exact-prefix; an
unprefixed statement that happened to start with either word would be read as a
tier declaration.
