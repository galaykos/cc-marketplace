---
description: Red-team a frozen taskmaster spec — dispatch a blind adversary to attack it for missing edge cases, unstated assumptions, conflicting requirements, and failure/security gaps, then resolve each before cards
argument-hint: [spec-path-or-slug]
---

Run the spec-redteam skill from this plugin on $ARGUMENTS (a
`taskmaster-docs/specs/<name>.md` path or a slug; if empty, use the most recent
spec under `taskmaster-docs/specs/`).

1. Resolve the target spec file.
2. Invoke the spec-redteam skill — apply its blast-radius gate; when met, dispatch
   the blind `spec-adversary` agent on the spec path and present the holes grouped
   by lens.
3. Resolve each hole with the skill's blocking gate (Amend the spec / Accept as
   known risk / Dismiss as non-issue); on a trivial spec, print the skip note.
