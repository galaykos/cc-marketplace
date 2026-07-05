---
description: Uninstall the taskmaster-suite bundle AND prune every plugin it auto-installed — one step, no orphans. Manually installed plugins are never touched.
---

Uninstall this bundle cleanly.

1. Show what will happen: run `claude plugin prune --dry-run` plus
   `claude plugin list --json` context if useful, and summarize — the bundle
   itself goes, auto-installed dependencies that nothing else requires go,
   manually installed plugins stay.
2. Confirm as a selectable choice (AskUserQuestion): "Uninstall bundle and
   prune its dependencies now (Recommended)" / "Cancel". This removes many
   plugins at once — never proceed without the explicit pick.
3. On confirm, run:

   ```bash
   claude plugin uninstall taskmaster-suite --prune -y
   ```

4. Report what was removed and what survived. Note: restart or `/plugin`
   refresh may be needed before the change is fully visible in the session.
