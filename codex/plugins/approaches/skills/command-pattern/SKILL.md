---
name: command-pattern
description: "Suggest (or reject) a design pattern for a described problem"
---

Read [the Codex execution contract](../../references/codex.md) before using helpers or delegating.

Invoke the pattern-selection skill from this plugin, then respond to the user-supplied arguments with:

1. The problem, restated in one sentence — without naming a pattern.
2. The simplest non-pattern solution that could work.
3. The skill's **Gate** (three checks): state each verdict. If any fails, stop at the simple
   solution — do not reach the map.
4. A pattern recommendation ONLY if the gate passed AND it clearly beats the simple solution —
   name the trade-offs (indirection, new concepts for readers, testing surface).
5. If no pattern is warranted, say so explicitly.

6. When the problem maps to real code in this repo, ask via a user question using the available interaction tool:
   "Implement the recommended approach now (Recommended)" / "Skip — advice
   only". Headless: advice only.
