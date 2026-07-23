---
description: Verify a task-card set covers its spec's success criteria — flag gaps, orphans, and drift, and resolve each before execution
argument-hint: [tasks-dir-or-slug]
---

Run the coverage-check skill from this plugin on $ARGUMENTS (a
`taskmaster-docs/tasks/<slug>/` directory or a slug; if empty, use the most
recent `taskmaster-docs/tasks/*/00-INDEX.md`).

<!-- boost-preamble:start — byte-identical across the 5 taskmaster commands; scripts/validate.sh enforces parity and hook-token agreement -->
**Run-status line (always):** print ONE status line as the first visible output of
every run — a boosted run prints the ⚡ banner (owned by the taskmaster `ultra`
skill; the banner IS its status line); a standard run prints
`▷ taskmaster standard run — session <model> · subagents inherit it unless their agent pins a tier · effort: <effort> · boost: off` — substitute `<model>` with the session model and `<effort>` with `$CLAUDE_EFFORT` (resolve via `echo ${CLAUDE_EFFORT:-inherit}`); when the harness does not expose it, that prints the literal `inherit`.

**Boost flags:** Extreme Boost fires ONLY when $ARGUMENTS *begins* with a bare
`ultra` (boost) or `goal` (hands-off) token, or contains the explicit
`ultra-task`/`ultratask` or `ultra-goal`/`ultragoal` token. Only the explicit
tokens cross a command boundary — a bare token owned by an earlier chained
command (e.g. `caveman ultra` preceding this command) NEVER triggers this run.
No tier suffixes: the tier is fixed at model=auto, effort=xhigh (`auto` =
session model or opus, whichever is higher — escalate, never downgrade). On a
match, strip the matched token and apply the taskmaster `ultra` skill
(`skills/ultra/SKILL.md`) — `ULTRA-TASK ACTIVE`, or `ULTRA-GOAL ACTIVE` in Goal
mode for `goal`/`ultra-goal` — ⚡ banner first, `Ultra:`/`Goal:` markers per
that skill.
<!-- boost-preamble:end -->

**Goal in this command:** standalone under goal, auto-resolve every
GAP/ORPHAN/DRIFT WITHIN this command (derive-then-take), writing no execution
marker; only task-cards stamps the `Goal: true` marker.

1. Resolve the target: the `00-INDEX.md` and the spec it links under
   `taskmaster-docs/specs/`.
2. Invoke the coverage-check skill — cross-check the spec's `## Success criteria`
   against every card's `**Acceptance criteria:**` in both directions (coverage
   and traceability), plus the drift check.
3. Present the coverage matrix, then take each GAP / ORPHAN / DRIFT through its
   resolution choice per the skill; block until every finding is resolved or
   explicitly accepted.
4. Write the `## Coverage` section into `00-INDEX.md`. On a clean pass, print the
   matrix and stop.
