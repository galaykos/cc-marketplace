---
description: Audit code or a design for speculative generality
argument-hint: [file-module-or-design]
---

Invoke the yagni-check skill from this plugin against $ARGUMENTS (a file, module, or design
description), or the current uncommitted diff if no argument is given. Steps:

1. Invoke the yagni-check skill and apply its red-flag list: unused "for later" parameters,
   single-implementation interfaces, config nobody sets, premature plugin/registry systems, and
   speculative generality in data models.
2. For each candidate, apply the "delete until it hurts" test to confirm it's actually
   speculative rather than serving a real current caller.
3. List each violation found as `path:line — what — why it's speculative`.
4. For each violation, propose a concrete deletion or simplification (what to remove or inline,
   and what the resulting simpler code looks like).
5. Do not flag genuine handling of current, real requirements (error handling, validation,
   tests) — only flag flexibility with no current caller or need.
