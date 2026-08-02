# Changelog

## 0.1.0 — 2026-08-02

First release.

- `PreToolUse` hook on `Bash` and on MCP tools that shell out or run SQL
  (`*execute_terminal_command`, `*execute_sql_query`, `*run_command`,
  `*shell_command`, `*run_in_terminal`), classifying the command string into
  `deny` / `ask` / `allow`.
- `deny` covers framework schema resets (Laravel, Rails, Django, Prisma,
  Sequelize, TypeORM, Knex, Alembic, Doctrine, Flyway, Liquibase, Supabase,
  WP-CLI), executed `DROP`/`TRUNCATE`/`FLUSHALL`/`dropDatabase()`, `rm -rf` on
  `/`, `~`, `$HOME`, `.` or a top-level system directory, `rm` of `.env`,
  history-destroying git commands, `docker compose down -v` and volume removal,
  `kubectl delete` of stateful objects, `terraform`/`pulumi destroy`, cloud CLI
  deletes, and raw-device writes.
- `ask` covers scoped destructive commands: `git reset --hard`, `git clean -fd`,
  `git branch -D`, `rm -rf <project path>`, `DELETE FROM`, `kubectl delete pod`,
  `helm uninstall`, `terraform apply -auto-approve`, `npm publish`,
  `curl … | sh`, `find … -delete`, `history -c`.
- Reads through quotes, `bash -c`/`eval` wrappers, whitespace, `&&` chains and
  heredocs; exempts read-only commands, and drops that exemption when output is
  piped into a shell.
- `.claude/destructive-guard-allow` — a user-owned exemption list the agent is
  blocked from writing, via `Write`/`Edit` and via shell redirects.
- `CLAUDE_DESTRUCTIVE_GUARD=ask|off` environment switches, unreachable from a
  command string.
- `/command-guard:check "<command>"` classifies without executing;
  `--check` exits 0/1/2 for allow/ask/deny.
- `destructive-commands` skill: substitution table, the handover protocol for
  when a reset is genuinely needed, and what the guard cannot see.
- 128-assertion harness at `scripts/__tests__/destructive-guard.test.sh`,
  including false-positive controls and fail-open cases; run in CI by the
  repo-wide plugin harness step.
