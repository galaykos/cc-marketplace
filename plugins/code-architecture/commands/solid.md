---
description: Audit code or a design for SOLID violations
argument-hint: [file-module-or-design]
---

Invoke the solid-principles skill from this plugin against $ARGUMENTS (a file, module, or design
description), or the current uncommitted diff if no argument is given. Steps:

1. Invoke the solid-principles skill and apply its detection cues per principle: classes edited
   by unrelated feature requests (S), type-code switch chains growing with every feature (O),
   overrides that throw "not supported" or bend the base contract (L), fat interfaces forcing
   stub implementations (I), and domain logic constructing infrastructure directly (D).
2. For each candidate, apply that principle's "not a violation" counterweight to confirm it's a
   real problem rather than cohesive convenience or a missing-second-case abstraction.
3. List each violation found as `path:line — what — why it violates the principle`.
4. For each violation, propose a concrete fix (the responsibility split, extension point,
   contract repair, interface slice, or boundary abstraction, and what the resulting code looks
   like).
5. Do not propose speculative abstractions for code under no current change pressure — that
   trade-off is governed by the yagni-check skill.

6. When violations were found, ask via AskUserQuestion: "Apply these fixes now (Recommended)" /
   "Skip — report only". Apply only the listed proposals on acceptance. Headless: report only.
