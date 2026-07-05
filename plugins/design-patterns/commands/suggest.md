---
description: Suggest (or reject) a design pattern for a described problem
argument-hint: [problem-description]
---

Invoke the pattern-selection skill from this plugin, then respond to $ARGUMENTS with:

1. The problem, restated in one sentence.
2. The simplest non-pattern solution that could work.
3. A pattern recommendation ONLY if it clearly beats the simple solution — name the
   trade-offs (indirection, new concepts for readers, testing surface).
4. If no pattern is warranted, say so explicitly.

5. When the problem maps to real code in this repo, ask via AskUserQuestion:
   "Implement the recommended approach now (Recommended)" / "Skip — advice
   only". Headless: advice only.
