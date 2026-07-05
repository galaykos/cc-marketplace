---
description: Review php code against php-best-practices
argument-hint: [files-or-diff]
---

Review the code in $ARGUMENTS (or the current diff if no argument) against the
php-best-practices skill from this plugin. Invoke the skill first. Before reporting, read the project manifests (composer.json / package.json and their lockfiles) and pin every finding to the installed versions — do not flag patterns the installed version already solves, and do not suggest APIs above it. When uncertain about an API or behavior, verify against the official docs for the pinned version — https://www.php.net/manual — instead of answering from memory. Report findings as
`path:line — problem — fix`, ordered by severity. Skip formatting nits unless
they change behavior.
