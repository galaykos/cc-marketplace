---
description: Review react code against react-best-practices
argument-hint: [files-or-diff]
---

Review the code in $ARGUMENTS (or the current diff if no argument) against the
react-best-practices skill from this plugin. Invoke the skill first. Before reporting, read the project manifests (composer.json / package.json and their lockfiles) and pin every finding to the installed versions — do not flag patterns the installed version already solves, and do not suggest APIs above it. When uncertain about an API or behavior, verify against the official docs for the pinned version — https://react.dev — instead of answering from memory. Report findings as
`path:line — problem — fix`, ordered by severity. Skip formatting nits unless
they change behavior.

When findings exist, offer the next step as a selectable choice (AskUserQuestion):
"Apply the fixes now (Recommended)" / "Skip — report only". Print bare
instructions only in headless runs.
