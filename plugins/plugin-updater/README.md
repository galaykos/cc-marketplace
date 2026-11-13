# plugin-updater

Keeps every installed Claude Code plugin current: every scope (user, project, local), every project
folder, every marketplace. Claude Code updates one install at a time, and a local install lives in
one project folder, so 40 plugins across 15 folders is 600 manual updates. Once a day, at the start
of a session, this plugin runs `claude plugin update` in the background for each install that is
behind, one after another. The next session shows you one line saying what changed or what needs
you.

Install it once, at user scope, so it runs whichever project you open:

```bash
claude plugin install plugin-updater@cc-plugins-marketplace -s user
```

## In the background

At each new session (not a resume or compaction), the session-start hook:

1. **Reports the last background run once**, if it left anything to say, as one line to you (a
   `systemMessage`, never model context):

   ```
   plugin-updater, background run: updated 12, need you 1, failed 2, orphaned 2, in worktrees 96. /plugin-updater:update-plugins --last shows the log. Restart running sessions to load the updates.
   ```

   A run that did not finish says so, with the same pointer to its log.
2. **Starts a run when one is due**: when the last completed run is older than the interval (24
   hours by default). The run is detached, so the hook returns at once and the session never waits
   for it. A lock keeps two sessions from starting two runs.

The run state, the lock and the log live in the plugin's data directory, `${CLAUDE_PLUGIN_DATA}`
(`~/.claude/plugins/data/plugin-updater-cc-plugins-marketplace/`).

| `/config` option | Environment variable | Default | Effect |
| --- | --- | --- | --- |
| Update in the background | `CC_PLUGIN_UPDATER_AUTO` | on | Off: no background runs; the startup line only counts outdated installs. |
| Hours between background runs | `CC_PLUGIN_UPDATER_INTERVAL` | 24 | Minimum hours from the last completed run; 0 runs at every session start. |
| Outdated-installs line | `CC_PLUGIN_UPDATER_HINT` | on | With background runs off, the line counting outdated installs. |

With background runs off, the startup line reads JSON files and each project folder's `.git` entry
only. It never refreshes a marketplace, so it knows only the releases the clones on disk have.

## On demand

```bash
/plugin-updater:update-plugins --dry-run   # list what is outdated; updates nothing
/plugin-updater:update-plugins             # update everything that is outdated, now
/plugin-updater:update-plugins --last      # the last background run's log
```

Or from a shell, with the same flags:

```bash
bash ~/.claude/plugins/marketplaces/cc-plugins-marketplace/plugins/plugin-updater/scripts/update-all.sh --dry-run
```

| Flag | Effect |
| --- | --- |
| `--dry-run` | List the installs that would be updated or checked, and why. Updates no install. |
| `--last` | Print the last background run's log. |
| `--no-refresh` | Skip `claude plugin marketplace update`; compare against the clones as they are. Without it, a dry run also refreshes them. |
| `--scope user\|project\|local` | Only that scope. Repeatable. |
| `--project PATH` | Only installs whose project folder is `PATH`. Repeatable. |
| `--plugin NAME` | Only that plugin, as `name` or `name@marketplace`. Repeatable. |

Exit codes: **0** done, **1** at least one install failed or needs you, **2** a precondition is
missing (`python3`, the `claude` CLI, a readable `claude plugin list --json`) or another run holds
the lock.

## What a run does

1. Refreshes every marketplace (`claude plugin marketplace update`), unless `--no-refresh`.
2. Reads the installs from `claude plugin list --json`.
3. Works out each plugin's latest version from its marketplace clone under
   `~/.claude/plugins/marketplaces/`: the plugin's own `plugin.json` when its source is a path inside
   the clone, else the marketplace entry's `version`. The plugin's own file wins when both are set,
   as it does for the host.
4. Runs `claude plugin update <id> --scope <scope> --json` for each install that is behind, or whose
   latest version cannot be read (a remote source, a plugin versioned by commit, one missing from
   the manifest). It runs from the install's project folder (your home folder for user scope), with
   no terminal on stdin, one at a time: every update rewrites the same `installed_plugins.json`.
5. Prints a summary: updated, already current, skipped, failed, need you. A running session keeps
   the old plugins until it restarts or runs `/reload-plugins`.

## What it never does

- **It never accepts a marketplace-declared command.** It never passes `-y` or `--accept-command`,
  in the background or on demand. If a plugin's install command changed, the update is refused and
  listed under "Need you" with the command to run yourself, so you see it before it runs.
- **It never updates an orphaned entry**, an install whose project folder no longer exists.
- **It never updates an install recorded for a linked git worktree.** Run from a worktree folder,
  `claude plugin update --scope local` checks the main checkout's install, not the worktree's
  (CLI 2.1.323): 93 worktree installs reported `up_to_date` in one run while each still recorded
  its old version. Do not run `claude plugin uninstall` from a worktree to clean them up either; it
  would act on the main checkout's install. If the CLI reports `up_to_date` for a version other
  than the one an install records, the run counts it as a failure, not "already current".
- **It never updates a `managed` install**; policy sets those.

A plugin the marketplace has removed fails with `not_found`; its line carries the
`claude plugin uninstall` command to run in that folder.

## What has teeth

| Rule | Standing |
| --- | --- |
| Updates run one at a time, never with `-y` or `--accept-command`, never with a terminal on stdin | **gate**: `scripts/__tests__/update-all.test.sh` |
| Orphaned, worktree and `managed` installs are skipped; filters, exit codes and the lock hold | **gate**: the same harness |
| The hook returns before the background run ends, starts no run while one holds the lock or before the interval, and reports a run once | **gate**: the same harness |
| How the real CLI resolves a folder to an install, and the exact JSON it prints | **recorded**: the harness answers from fixtures; seen on CLI 2.1.323 |
| That the host lets a hook's detached child outlive the hook | **recorded**: the harness runs the hook script directly, not under the host |

Requires `python3` and the `claude` CLI (on `PATH`, else the one the session runs from).
