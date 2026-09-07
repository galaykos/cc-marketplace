---
name: manage-suite
description: "Install or remove the frontend-suite collection with dependency and ownership tracking."
---

Read [the Codex execution contract](../../references/codex.md) before using helpers or delegating.

This suite groups: skill-router, ui-ux, web-dev, code-review.

Installing this package alone does not install its members. Use the bundled
installer to expand membership and track ownership:

```bash
python3 "$PLUGIN_ROOT/scripts/install.py" install frontend-suite
python3 "$PLUGIN_ROOT/scripts/install.py" install frontend-suite --apply
```

The first command previews the plan. Execute the second for an authorized install.
Use `uninstall frontend-suite` with the same preview/apply pattern to remove this suite's
owned installs. Preexisting installs and other suites' dependencies are preserved.
Use this helper for explicit leaf installs too so their ownership is recorded.
Codex's plugin browser cannot expand suite dependencies automatically.
