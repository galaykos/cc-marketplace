---
description: Uninstall every leaf plugin of this marketplace from one scope with zero prompts — local by default; --self removes all-plugins too; runs the plugin's script and relays its exit code: 0 done, 1 lists the plugins that failed, 2 names the missing precondition.
argument-hint: [--scope local|project|user] [--dry-run] [--self]
---

Run the plugin's uninstall script through the Bash tool, exactly as written, with the
user's arguments passed through unchanged (an empty $ARGUMENTS is the default: local
scope, no dry run, all-plugins itself left installed):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/all-plugins.sh" uninstall $ARGUMENTS
```

Then:

1. Do not ask any question first — the script is the decision procedure, and it
   prompts for nothing by design.
2. Show the script's output verbatim. It is the record of what was removed, skipped
   and failed; do not summarise it into a count.
3. Read the exit code:
   - **0** — every uninstall succeeded (or `--dry-run` printed the plan). Tell the user
     the removals take effect in a new session or after `/reload-plugins`.
   - **1** — at least one plugin failed. List the `FAIL` lines from the output and stop;
     do not retry them.
   - **2** — a precondition is missing. Show the stderr line — it names the fix, usually
     `claude plugin marketplace add galaykos/cc-marketplace`.
4. Never substitute `claude plugin uninstall` calls of your own for the script, on any
   exit code. The script is the one artifact here with a harness; a hand-rolled loop
   has none. `--self` is the script's flag, not yours: it removes all-plugins too, and
   this command is gone with it after the next reload.
