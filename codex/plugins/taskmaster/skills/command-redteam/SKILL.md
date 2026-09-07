---
name: command-redteam
description: "Red-team a frozen taskmaster spec — a blind adversary hunts edge cases, assumptions, conflicts, failure/security gaps; resolve each before cards"
---

Read [the Codex execution contract](../../references/codex.md) before using helpers or delegating.

Run the spec-redteam skill from this plugin on the user-supplied arguments (a
`taskmaster-docs/specs/<name>.md` path or a slug; if empty, use the most recent
spec under `taskmaster-docs/specs/`).

For an explicit ultra-task or ultra-goal request, load the native ultra skill. Keep session model settings; goal mode continues only already-authorized work.

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
