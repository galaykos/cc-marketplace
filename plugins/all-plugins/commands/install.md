---
description: Install every leaf plugin of this marketplace at one scope with zero prompts — local by default; runs the plugin's script and relays its exit code: 0 run /reload-plugins, 1 lists the plugins that failed, 2 names the missing precondition.
argument-hint: [--scope local|project|user] [--dry-run] [--no-budget]
---

Run the plugin's install script through the Bash tool, exactly as written, with the
user's arguments passed through unchanged (an empty $ARGUMENTS is the default: local
scope, no dry run):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/all-plugins.sh" install $ARGUMENTS
```

Then:

1. Do not ask any question first — the script is the decision procedure, and it
   prompts for nothing by design.
2. Show the script's output verbatim. It is the record of what was installed, skipped
   and failed; do not summarise it into a count.
3. Read the exit code:
   - **0** — every install succeeded (or `--dry-run` printed the plan). If the output
     ends with the `Run /reload-plugins` line, repeat it: nothing installed this run is
     active until they do. The script prints that line only when something was
     installed or enabled — all skips or a dry run need no reload, so say nothing.
     The `skillListingBudgetFraction` line before it says what the script wrote to the
     scope's settings file and why (the listing overflows the default budget); relay it
     as printed, do not explain it further, and never edit that key yourself.
   - **1** — at least one plugin failed. List the `FAIL` lines from the output and stop;
     do not retry them.
   - **2** — a precondition is missing. Show the stderr line — it names the fix, usually
     `claude plugin marketplace add galaykos/cc-marketplace`.
4. Never substitute `claude plugin install` calls of your own for the script, on any
   exit code. The script is the one artifact here with a harness; a hand-rolled loop
   has none.
