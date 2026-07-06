---
description: Review Vite config or a Vite-built app against vite-best-practices
argument-hint: [files-or-diff]
---

Review the code in $ARGUMENTS (or the current diff if no argument) against the
vite-best-practices skill from this plugin. Invoke the skill first. Before reporting, read the project manifests (package.json, its lockfile, `vite.config.{js,ts}`, and the `.env` files including mode-specific ones) and pin every finding to the installed vite version from the lockfile — do not flag patterns the installed version already solves, and do not suggest config options or targets above it. When uncertain about a config option or build behavior, verify against the official docs for the pinned version — https://vite.dev/ — instead of answering from memory. Report findings as
`path:line — problem — fix`, ordered by severity. Skip formatting nits unless
they change behavior.

When findings exist, offer the next step as a selectable choice (AskUserQuestion):
"Apply the fixes now (Recommended)" / "Skip — report only". Print bare
instructions only in headless runs.
