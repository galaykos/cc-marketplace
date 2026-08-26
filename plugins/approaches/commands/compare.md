---
description: Compare 2-3 structurally different approaches to a task — trade-off table, pick, kill-trigger — before any implementation.
---

Run approach deliberation on $ARGUMENTS (if empty, ask for a one-paragraph task
description first). Do not write implementation code.

1. Load the approach-deliberation skill from this plugin and run its INLINE SLATE
   mechanism (the single-context comparison, not the blind panel): its rules for
   structural difference, the trade-off table, honest entries, and the pick +
   kill-trigger are stated once there — apply them, do not restate them here.
2. Surface the pick, never self-approve it. Proceed without asking only under
   CC_AUTOPROCEED=on or a hands-off goal run.
3. Hand off via selectable offer (AskUserQuestion), not typed commands:
   "Proceed with <pick> — continue to the file-level plan (Recommended)" /
   "Proceed with <runner-up> instead" / "Stop here". Plan =
   plan-before-code (code-architecture) when that plugin is installed, else
   outline the file-level plan inline. If the comparison exposed product-shape
   uncertainty, offer /taskmaster:brainstorm only when taskmaster is installed.
