---
name: update-plugins
description: Update the Claude Code plugins installed for the current project folder and at user scope, one install at a time, through this plugin's update-all.sh; --all covers every project folder, --dry-run lists what is outdated and updates nothing, --last shows the last background run.
argument-hint: "[--all] [--dry-run] [--last] [--no-refresh] [--scope user|project|local] [--project PATH] [--plugin NAME]"
disable-model-invocation: true
---

# Update plugins

Run the script through the Bash tool with the user's arguments passed through unchanged. Set
`run_in_background: true`: each `claude plugin update` takes about a second, so an `--all` run over
a few hundred installs outlasts the foreground timeout. Wait for it to finish; do not poll it.

Run it from the session's folder. It updates the installs of the nearest project folder at or above
the working directory, plus user scope, and prints that folder on its `Folder:` line. **Never add
`--all` or `--project` yourself**: other project folders are touched only when the user passed the
flag.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/update-all.sh" --data-dir "${CLAUDE_PLUGIN_DATA}" $ARGUMENTS
```

`--data-dir` points the run at the same lock and state as the session-start background run, so the
two never overlap.

Then:

1. **Never substitute your own `claude plugin update` calls**, to retry a failure or to finish a
   run. The script never passes `-y` or `--accept-command`, so a plugin whose marketplace-declared
   command changed is left to the user; neither flag is yours to pass either.
2. **Relay, do not re-derive.** Give the `Folder:` line and the `Summary` counts, then every `Failed` and `Need you`
   line with its reason and the command the script printed for it. Group `Skipped` by reason
   (orphaned entry, linked git worktree) with the folders, not the plugin lists.
3. **Exit code.** 0: done. 1: at least one failure or changed command needs the user; list them
   and stop. 2: a precondition is missing or a background run holds the lock; show the stderr
   line, which names it and the log to read.
4. **Under `--dry-run`**, say nothing was updated and list the `Would run` lines grouped by plugin.
   The run still refreshes the marketplace clones unless `--no-refresh` was passed.
5. **Under `--last`**, relay the last background run's log the same way as points 2 and 3.
6. **If anything updated**, end with the script's restart line: a running session keeps the old
   plugin until it restarts or runs `/reload-plugins`.
