---
description: Red-team a frozen taskmaster spec — a blind adversary hunts edge cases, assumptions, conflicts, failure/security gaps; resolve each before cards
argument-hint: [spec-path-or-slug]
---

Run the spec-redteam skill from this plugin on $ARGUMENTS (a
`taskmaster-docs/specs/<name>.md` path or a slug; if empty, use the most recent
spec under `taskmaster-docs/specs/`).

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

**Goal in this command:** standalone under goal, auto-resolve every hole WITHIN
this command (derive-then-take Amend/Accept/Dismiss) — security/auth/data-loss
holes are NEVER auto-accepted — writing no execution marker; only task-cards
stamps the `Goal: true` marker.

1. Resolve the target spec file.
2. Invoke the spec-redteam skill — apply its blast-radius gate; when met, dispatch
   the blind `spec-adversary` agent on the spec path and present the holes grouped
   by lens.
3. Resolve each hole with the skill's blocking gate (Amend the spec / Accept as
   known risk / Dismiss as non-issue); on a trivial spec, print the skip note.
