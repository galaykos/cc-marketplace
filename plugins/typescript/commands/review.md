---
description: Review TypeScript code against typescript-best-practices
argument-hint: [files-or-diff]
---

Review the code in $ARGUMENTS (or the current diff if no argument) against the
typescript-best-practices skill from this plugin. Invoke the skill first. Before reporting, read the project manifests (package.json, its lockfile, and tsconfig.json including the `extends` chain) and pin every finding to the installed typescript version from the lockfile — do not flag patterns the installed version already solves, and do not suggest syntax or compiler options above it. When uncertain about a compiler option or language behavior, verify against the official docs for the pinned version — https://www.typescriptlang.org/docs/ — instead of answering from memory. Report findings as
`path:line — problem — fix`, ordered by severity. Skip formatting nits unless
they change behavior.
