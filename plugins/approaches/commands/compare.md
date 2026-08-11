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
   file-level sketch each. Consult approach-deliberation's references/strategies.md for fits.
3. Trade-off table: effort, risk, reversibility, codebase fit, blast radius.
   Honest entries — no strawman column built to make a favorite win.
4. Pick one — and surface it, never self-approve it. One paragraph why, the
   kill-trigger (the concrete discovery mid-implementation that would flip the
   choice), then fold pick approval into the handoff ask below. Proceed without
   asking only under CC_AUTOPROCEED=on or a hands-off goal run.
5. Hand off via selectable offer (AskUserQuestion), not typed commands:
   "Proceed with <pick> — continue to the file-level plan (Recommended)" /
   "Proceed with <runner-up> instead" / "Stop here". Plan =
   plan-before-code (code-architecture) when that plugin is installed, else
   outline the file-level plan inline. If the comparison exposed product-shape
   uncertainty, offer /taskmaster:brainstorm only when taskmaster is installed.
