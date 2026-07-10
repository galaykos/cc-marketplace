---
name: cmd-javascript-review
description: "Use when the user asks to review JavaScript code against javascript-best-practices."
---

_This skill wraps the `/javascript:review` command; pass the command's input as the skill's argument (`$ARGUMENTS`)._


Review the code in $ARGUMENTS (or the current diff if no argument) against the
javascript-best-practices skill from this plugin. Invoke the skill first. Before reporting, read the project manifests (package.json, its lockfile, and any `engines`/`.nvmrc`/`browserslist` constraints) and pin every finding to the installed Node/ES floor — do not flag patterns the floor already solves, and do not suggest syntax or APIs above it. When uncertain about a language feature or runtime behavior, verify against the official docs for the pinned version — https://developer.mozilla.org/en-US/docs/Web/JavaScript — instead of answering from memory. Report findings as
`path:line — problem — fix`, ordered by severity. Skip formatting nits unless
they change behavior.

When findings exist, offer the next step as a selectable choice (AskUserQuestion):
"Apply the fixes now (Recommended)" / "Skip — report only". Print bare
instructions only in headless runs.
