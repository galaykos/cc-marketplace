---
name: cmd-vue3-review
description: "Use when the user asks to review vue3 code against vue3-best-practices."
---

_This skill wraps the `/vue3:review` command; pass the command's input as the skill's argument (`$ARGUMENTS`)._


Review the code in $ARGUMENTS (or the current diff if no argument) against the
vue3-best-practices skill from this plugin. Invoke the skill first. Before reporting, read the project manifests (composer.json / package.json and their lockfiles) and pin every finding to the installed versions — do not flag patterns the installed version already solves, and do not suggest APIs above it. When uncertain about an API or behavior, verify against the official docs for the pinned version — https://vuejs.org — instead of answering from memory. Report findings as
`path:line — problem — fix`, ordered by severity. Skip formatting nits unless
they change behavior.

When findings exist, offer the next step as a selectable choice (AskUserQuestion):
"Apply the fixes now (Recommended)" / "Skip — report only". Print bare
instructions only in headless runs.
