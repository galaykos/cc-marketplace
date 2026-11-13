# plugin-updater: why each file exists and what it was measured against (2026-11-13)

Written when the plugin shipped. Each `##` heading is the path a file's header points at with
`# Why, limits, history: rationale/derivations/plugin-plugin-updater.md § <path>`. Standing:
`recorded`. No gate reads this file. Its figures are as measured on the date above, on CLI 2.1.323.

## plugins/plugin-updater/scripts/plugin_updates.py

Origin: a one-off batch run on 2026-11-13 by two throwaway scripts. One compared `claude plugin
list --json` with each marketplace clone's manifest. The other ran `claude plugin update <id> --scope
<scope> --json` for every install that was behind or unresolvable, from the install's folder. 420
installs, 415 of them at local scope across about 16 folders. That run made 273 calls: 159 updated,
98 already current, 14 failed `not_found` (plugins the marketplace had removed: `renames` maps them
to null), 2 skipped (a folder that no longer exists).

- **Latest version.** The plugin's own `plugin.json` wins over the marketplace entry's `version` when
  both are set (host docs, plugins-reference "Metadata precedence", read 2026-11-13). A bare source
  resolves under `metadata.pluginRoot`; a `./` source resolves from the clone root. A remote source
  (github, url, git-subdir) has no local plugin.json, so only an entry `version` resolves it; with
  none, the host uses a commit sha and the script calls `update` to ask.
- **`claude plugin list --json --available` is not used**: it leaves installed plugins out.
- **One at a time**: every update rewrites `~/.claude/plugins/installed_plugins.json`.
- **stdin is /dev/null, never `-y` / `--accept-command`**: `--json` still shows a changed
  marketplace-declared command and refuses without `-y` when stdin is not a terminal. Accepting
  it is the person's call, so the script reports it under "Need you".
- **Linked git worktrees are skipped.** In the batch run, 93 calls made from folders under
  `.claude/worktrees/` returned `up_to_date` with an `oldVersion` equal to the main checkout's
  install (e.g. all-plugins 0.7.8), while `claude plugin list --json` still recorded those worktree
  installs at their old versions (all-plugins 0.2.0). Run from a linked worktree, the CLI resolves
  local scope to the main checkout. The worktree entries cannot be updated this way, so the script
  lists them as skipped instead of counting them current. The `oldVersion` guard in `run_one`
  catches the same mismatch for any other folder the CLI maps elsewhere.
- **`claude` binary**: the one on PATH, else `CLAUDE_CODE_EXECPATH` (set in Desktop sessions, whose
  hook PATH may lack the CLI). A missing CLI is checked in Python, so a background run still
  records its failure for the next session to report.
- **Residual.** The worktree mapping is inferred from those 93 results, not from CLI source. If a
  later CLI updates worktree entries in place, the skip turns needless; delete it then.

## plugins/plugin-updater/scripts/update-all.sh

Entry point the skill and a shell share. It checks `python3` on PATH (exit 2 if missing),
then runs the Python under `-I` so nothing in the working folder can shadow a
standard-library module.

## plugins/plugin-updater/hooks/session-start.sh

SessionStart, `startup` only. The first design (2026-11-13, morning) only counted outdated installs.
The requesting session then widened it the same day: the user's goal is never to update plugins by
hand, so the hook starts the update run itself.

- **Detached, never in-line.** A run makes one CLI call per install (about a second each; 273 calls
  in the batch run). So the hook takes the lock, starts `update-all.sh --background --owns-lock` with
  `start_new_session` and its output in `last-run.log`, and exits. stdout is not the hook's pipe, so
  the host has nothing to wait for. The harness checks the hook returns before a 3 s fake refresh
  ends. Whether the host ever kills a hook's detached child was not tested under the host.
- **Due** means the last *completed* run (exit 0 or 1, not interrupted) is older than
  `CC_PLUGIN_UPDATER_INTERVAL` hours (24). A run that exits 2 records no completion, so the next
  session retries it; the lock keeps that to one at a time.
- **Lock**: `run.lock/` under the data directory, created with `mkdir` (atomic), holding the pid.
  It is held for its first 60 s whatever the pid says (the hook's pid hands over to the child's). After
  that it is stale when the pid is dead, and after 6 h in any case. The on-demand skill passes
  `--data-dir "${CLAUDE_PLUGIN_DATA}"` so it shares the lock (host docs: the variable resolves in
  skill bodies and is exported to hooks, not to the Bash tool).
- **Report once.** A background run leaves `last-run.json` with `reported: false`. The next session
  prints one line and sets it true. Orphaned and worktree entries are in the line because the
  requesting session asked for them; they recur each run until cleaned up by hand.
- **Off switch.** `CC_PLUGIN_UPDATER_AUTO=off` turns back to the check-only line. That line reads
  `installed_plugins.json`, `known_marketplaces.json`, each clone's manifests and each project
  folder's `.git` entry: 25 ms on the 2026-11-13 machine (420 installs, 3 marketplaces). Before the
  worktree skip it counted 90 installs outdated on a machine where every updatable install was
  current.

## plugins/plugin-updater/scripts/__tests__/update-all.test.sh

A shim `claude` on PATH answers `plugin list` from a fixture and logs every call, with a mkdir
lock that records PARALLEL if two updates overlap. The hook cases run `session-start.sh` directly
and wait for the detached run to write its state. Mutation-checked on 2026-11-13: adding `-y` to
the update call fails 2 cases, and removing the worktree skip fails 7.
