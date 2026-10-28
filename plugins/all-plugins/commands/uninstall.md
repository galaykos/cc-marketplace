---
description: Uninstall every leaf plugin of this marketplace from one scope. Without --scope it asks once for local, project or user, and never defaults silently. With --self it removes all-plugins too. It runs the plugin's script and relays its exit code. Exit 0 means done, 1 lists the plugins that failed, 2 names the missing precondition.
argument-hint: [--scope local|project|user] [--dry-run] [--self] [--no-budget]
disable-model-invocation: true
---

**Settle the scope first**, the same question `/all-plugins:install` asks. When `$ARGUMENTS`
carries no `--scope`, ask once with AskUserQuestion before running anything: **local** (this
checkout only), **project** (the committed `.claude/settings.json`) or **user** (every project
on this machine — the off-ramp once `/stack-scan:suggest --sync` has given each project you
use its own set). A `--scope` the user already typed is the answer — never ask over it. No answer
(headless, dismissed): stop and say the command needs `--scope`; never fall back to local.
After a user-scope install, a local default skips every plugin as `skip (not installed)` and
exits 0, removing nothing.

Then run the plugin's uninstall script through the Bash tool, exactly as written, with the
user's arguments passed through unchanged, plus `--scope <answer>` when you asked:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/all-plugins.sh" uninstall $ARGUMENTS
```

Then:

1. Ask nothing else — the scope question above is the only one, and only when `--scope` is
   absent. The script is the decision procedure and prompts for nothing by design.
2. Show the script's output verbatim. It is the record of what was removed, skipped
   and failed; do not summarise it into a count.
3. Read the exit code:
   - **0** — every uninstall succeeded (or `--dry-run` printed the plan). Tell the user
     the removals take effect in a new session or after `/reload-plugins`. A
     `skillListingBudgetFraction … removed` or `… left alone` line is the budget key
     install wrote being undone, or deliberately kept because the value is not the
     script's own; relay it as printed and never edit that key yourself.
   - **1** — at least one plugin failed. List the `FAIL` lines from the output and stop;
     do not retry them.
   - **2** — a precondition is missing. Show the stderr line — it names the fix, usually
     `claude plugin marketplace add galaykos/cc-marketplace`.
4. Never substitute `claude plugin uninstall` calls of your own for the script, on any
   exit code. The script is the one artifact here with a harness; a hand-rolled loop
   has none. `--self` is the script's flag, not yours: it removes all-plugins too, and
   this command is gone with it after the next reload.
