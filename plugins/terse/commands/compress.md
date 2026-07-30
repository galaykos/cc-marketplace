---
description: Compress one named prose markdown file (CLAUDE.md, a todo list, preferences) in place to cut input tokens — backs up the original first, preserves code, URLs, paths and numbers exactly, verifies mechanically.
argument-hint: "<path-to-markdown-file>"
---

# /terse:compress

Invoke the `terse-compress` skill on the path in `$ARGUMENTS`.

Stop before doing anything if:

- `$ARGUMENTS` is empty — ask which file; never pick one
- the path is not prose markdown, or is read by a validator or generator
- `<path>.original.md` already exists — a second pass would destroy the only
  human-readable copy

Then follow the skill: read the file whole, back it up, rewrite, run the five
mechanical checks, and report before/after bytes
with the restore command.

This is the only place in this plugin where compression touches a file on disk.
It runs on an explicit path and never on inference.
