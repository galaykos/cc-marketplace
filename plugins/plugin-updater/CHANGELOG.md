# Changelog — plugin-updater

Consumer-facing changes only. Newest first.

## 0.1.0 — 2026-11-13

- **First release.** Updates every installed plugin in every scope and project folder, one at a
  time. At session start, once a day by default, the hook starts the run detached and the next
  session shows one line on what it updated or what needs you. `/plugin-updater:update-plugins`
  runs it on demand, with `--dry-run`, `--last`, `--no-refresh`, `--scope`, `--project` and
  `--plugin`. It never passes `-y` or `--accept-command`. It skips orphaned entries, linked git
  worktrees and `managed` installs. `/config` options: background runs, the interval, and the
  outdated-installs line. Standing: gate (`scripts/__tests__/update-all.test.sh`).
