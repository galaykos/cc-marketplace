---
description: Red-team a frozen taskmaster spec — dispatch a blind adversary to attack it for missing edge cases, unstated assumptions, conflicting requirements, and failure/security gaps, then resolve each before cards
argument-hint: [spec-path-or-slug]
---

Run the spec-redteam skill from this plugin on $ARGUMENTS (a
`taskmaster-docs/specs/<name>.md` path or a slug; if empty, use the most recent
spec under `taskmaster-docs/specs/`).

**Ultra flag:** run in Extreme Boost mode ONLY when $ARGUMENTS *begins* with a
bare `ultra` token (this command invoked as `/taskmaster:<cmd> ultra …`) or
contains the explicit `ultra-task`/`ultratask` token. A bare `ultra` that is not
the first token of THIS command's own arguments — e.g. an earlier command's own
intensity flag in a chained message, such as a `caveman ultra` preceding this
command — is NOT a taskmaster trigger and never boosts this run; only
`ultra-task`/`ultratask`
crosses a command boundary. On a match, strip the matched token and treat the run
as `ULTRA-TASK ACTIVE` per the taskmaster `ultra` skill (an N=3 blind adversary
panel on the Workflow path, opus subagents, and the ⚡ banner).

1. Resolve the target spec file.
2. Invoke the spec-redteam skill — apply its blast-radius gate; when met, dispatch
   the blind `spec-adversary` agent on the spec path and present the holes grouped
   by lens.
3. Resolve each hole with the skill's blocking gate (Amend the spec / Accept as
   known risk / Dismiss as non-issue); on a trivial spec, print the skip note.
