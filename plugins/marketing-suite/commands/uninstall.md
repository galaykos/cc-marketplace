---
description: Uninstall the marketing-suite bundle AND prune every plugin it auto-installed (marketing-capture, marketing-copy, marketing-image-ops) — one step, no orphans. Manually installed plugins are never touched.
---

Uninstall this bundle cleanly.

1. Show what will happen: run `claude plugin prune --dry-run` and summarize —
   the bundle itself goes, auto-installed dependencies that nothing else
   requires go (marketing-capture, marketing-copy, marketing-image-ops),
   manually installed plugins stay.
2. Confirm as a selectable choice (AskUserQuestion): "Uninstall bundle and
   prune its dependencies now (Recommended)" / "Cancel". This removes several
   plugins at once — never proceed without the explicit pick.
3. On confirm, run:

   ```bash
   claude plugin uninstall marketing-suite --prune -y
   ```

4. Report what was removed and what survived. Note: restart or `/plugin`
   refresh may be needed before the change is fully visible in the session.
