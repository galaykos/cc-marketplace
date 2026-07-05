---
description: Compare 2-3 structurally different approaches to a task — trade-off table, pick, kill-trigger — before any implementation.
---

Run approach deliberation on $ARGUMENTS (if empty, ask for a one-paragraph task
description first). Do not write implementation code.

1. Restate the goal in one sentence and list the binding constraints (stack,
   deadline pressure, compatibility, performance floors) — from the repo and
   the description, not invented.
2. Generate 2–3 approaches that differ STRUCTURALLY (different axis each:
   simplest-possible, incremental/tracer, rework-minimizing, performance-first,
   reversibility-first) — not three variants of one idea. Name each; one-line
   file-level sketch each. Consult the strategy-catalog skill for fits.
3. Trade-off table: effort, risk, reversibility, codebase fit, blast radius.
   Honest entries — no strawman column built to make a favorite win.
4. Pick one. One paragraph why. State the kill-trigger: the concrete discovery
   mid-implementation that would flip this choice.
5. Hand off via selectable offer (AskUserQuestion), not typed commands:
   "Persist as ADR + continue to file-level plan (Recommended)" /
   "Plan only" / "Stop here". ADR = decision-records plugin; plan =
   plan-before-code (code-architecture). If the comparison exposed
   product-shape uncertainty, offer /taskmaster:brainstorm instead.
