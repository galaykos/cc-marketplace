---
description: Uninstall the quality-suite bundle AND prune every plugin it auto-installed — one step, no orphans. Manually installed plugins are never touched.
---
<!-- generated from templates/suite-uninstall.md.tmpl by scripts/generate.sh — edit the template or .chassis.json, not this file -->

Uninstall this bundle cleanly.

1. Show what will happen: run `claude plugin prune --dry-run` and summarize — the
   bundle itself goes, auto-installed dependencies that nothing else requires go,
   manually installed plugins stay.
2. Confirm as a selectable choice (AskUserQuestion): "Uninstall bundle and prune its
   dependencies now (Recommended)" / "Cancel". This removes many plugins at once —
   never proceed without the explicit pick.
3. On confirm, run:

   ```bash
   claude plugin uninstall quality-suite --prune -y
   ```

4. Report what was removed and what survived. Note: restart or `/plugin` refresh may be
   needed before the change is fully visible in the session.
