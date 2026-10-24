---
description: Install every leaf plugin of this marketplace but opt-in prompt-coach at one scope — asks local or project once when --scope is absent, never defaults silently; runs the plugin's script and relays its exit code: 0 run /reload-plugins, 1 lists the plugins that failed, 2 names the missing precondition.
argument-hint: [--scope local|project|user] [--dry-run] [--budget]
disable-model-invocation: true
---

**Settle the scope first.** When `$ARGUMENTS` carries no `--scope`, ask once with
AskUserQuestion before running anything: **local** (this checkout only, not committed — a
linked git worktree starts without it) or **project** (the committed `.claude/settings.json`:
teammates and every worktree get it); `user` (every project on this machine) only when the
user types it — this marketplace installs per project, and `/stack-scan:suggest --sync`
installs a project-matched set instead of all of it. A `--scope` the user already
typed is the answer — never ask over it. No answer (headless, dismissed): stop and say the
command needs `--scope`; never fall back to local. A silent local default once left every
other project bare while the user believed the marketplace was on.

Then run the plugin's install script through the Bash tool, exactly as written, with the
user's arguments passed through unchanged, plus `--scope <answer>` when you asked:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/all-plugins.sh" install $ARGUMENTS
```

Then:

1. Ask nothing else — the scope question above is the only one, and only when `--scope` is
   absent. The script is the decision procedure and prompts for nothing by design.
2. Show the script's output verbatim. It is the record of what was installed, skipped
   and failed; do not summarise it into a count.
3. Read the exit code:
   - **0** — every install succeeded (or `--dry-run` printed the plan). If the output
     ends with the `Run /reload-plugins` line, repeat it: nothing installed this run is
     active until they do. The script prints that line only when something was
     installed or enabled — all skips or a dry run need no reload, so say nothing.
     Under `--budget`, the `skillListingBudgetFraction` line before it says what the
     script wrote to the scope's settings file and why (the listing overflows the default
     budget); relay it as printed, do not explain it further, and never edit that key
     yourself. Without `--budget` the script leaves the key alone and prints no such line.
     Close with one line: this installs only this marketplace's plugins — official
     complements such as the language servers (`php-lsp`, `typescript-lsp`) are matched to
     the project's manifests and printed, never run, by `/stack-scan:suggest`.
   - **1** — at least one plugin failed. List the `FAIL` lines from the output and stop;
     do not retry them.
   - **2** — a precondition is missing. Show the stderr line — it names the fix, usually
     `claude plugin marketplace add galaykos/cc-marketplace`.
4. Never substitute `claude plugin install` calls of your own for the script, on any
   exit code. The script is the one artifact here with a harness; a hand-rolled loop
   has none.
