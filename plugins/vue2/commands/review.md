---
description: Review vue2 code against vue2-best-practices
argument-hint: [files-or-diff]
---

Review the code in $ARGUMENTS (or the current diff if no argument) against the
vue2-best-practices skill from this plugin. Invoke the skill first. Before reporting, read the project manifests (composer.json / package.json and their lockfiles) and pin every finding to the installed versions — do not flag patterns the installed version already solves, and do not suggest APIs above it. Report findings as
`path:line — problem — fix`, ordered by severity. Skip formatting nits unless
they change behavior.
