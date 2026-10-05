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
   and what the resulting simpler code looks like). On a directory scope, rank the proposals by
   lines removed, largest first; when code-review is installed, its `reuse-hygiene` deep pass
   supplies dead-symbol evidence. Always, even with no violation, close with
   `net: −N lines, −M dependencies` summed over the proposals, where M counts only a dependency
   every use of which a proposal removes; print
   `net: −0 lines` when nothing was found, and omit the dependency half for a design description.
5. Do not flag genuine handling of current, real requirements (error handling, validation,
   tests) — only flag flexibility with no current caller or need. (Admission law: `.claude/skills/authoring-skills/SKILL.md` (in the marketplace repository, not installed) "The four laws".)

6. When violations were found, ask via AskUserQuestion: "Apply these
   deletions/simplifications now (Recommended)" / "Skip — report only".
   Apply only the listed proposals on acceptance. Headless: report only.
