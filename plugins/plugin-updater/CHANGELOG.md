# Changelog — plugin-updater

Consumer-facing changes only. Newest first.

## 0.3.0 — 2026-11-21

- **New hook: `accept-guard` denies a model's `claude plugin update` or `install` with `-y`, `--yes` or
  `--accept-command`.** Those flags accept a changed marketplace-declared command no person has seen, and the
  CLI's help suggests `-y` whenever stdin is not a terminal, which is always so for the Bash tool. The deny tells
  the model to hand you the command without the flag for your own terminal. It reads through quotes, `VAR=` and
  wrapper prefixes, `plugins`/`i`, a shell's `-c` string, `eval` and a heredoc a shell reads; it misses a script
  file, a variable, an alias, `$( )` and MCP shell tools. No off switch: commands you type yourself never pass
  through it. Standing: gate (`scripts/__tests__/accept-guard.test.sh`, 37 checks).
- The README's "What has teeth" table gains that row, and one labelling the on-demand rules that rest on the skill
  alone (no `--all`/`--project` unless you typed it, no update calls of the model's own) as **recorded**.

## 0.2.0 — 2026-11-13

- **A run now stays in the folder you are in.** `/plugin-updater:update-plugins` and the
  session-start background run update the current project folder's installs and your user-scope
  ones, nothing else. 0.1.0 updated every project folder on the machine from whichever session
  happened to start first. `--all` brings that back for one on-demand run; the background run never
  uses it. The daily interval is now kept per folder, and the report line names the folder.
  Standing: gate (`scripts/__tests__/update-all.test.sh`).

## 0.1.0 — 2026-11-13

- **First release.** Updates every installed plugin in every scope and project folder, one at a
  time. At session start, once a day by default, the hook starts the run detached and the next
  session shows one line on what it updated or what needs you. `/plugin-updater:update-plugins`
  runs it on demand, with `--dry-run`, `--last`, `--no-refresh`, `--scope`, `--project` and
  `--plugin`. It never passes `-y` or `--accept-command`. It skips orphaned entries, linked git
  worktrees and `managed` installs. `/config` options: background runs, the interval, and the
  outdated-installs line. Standing: gate (`scripts/__tests__/update-all.test.sh`).
