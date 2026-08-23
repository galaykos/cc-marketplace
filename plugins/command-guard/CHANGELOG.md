# Changelog

## 0.2.0

### Fixed
- The guard denied its own `/command-guard:check` CLI. That command's stated
  primary use is unpacking why a command was blocked, so it was broken for
  exactly the deny-tier targets it exists to explain — and because the deny text
  says "Do NOT retry", the model abandoned the check rather than working around
  it. `bash <path>/hooks/destructive-guard.sh --check '<cmd>'` is now exempt, on
  three clauses: bash/sh lead word, a path ending in `hooks/destructive-guard.sh`,
  and `--check` present. `--check` classifies and exits without ever executing
  its argument; any other flag still falls through to normal classification.

### Added
- A `self-exemption` section in the harness. The previous 128 assertions drove
  CLI mode and hook mode separately and never sent the HOOK a Bash payload whose
  command IS the CLI invocation, so the composition was nobody's case. The new
  section also asserts the exemption does not leak: the bare targets are still
  denied, a non-`--check` flag on the same script is still denied, and a
  lookalike path does not inherit it. Verified against the old code: 3 of the new
  assertions fail on it.

### Known limitation
- The guard still cannot distinguish MENTIONING a destructive command from
  RUNNING one. A heredoc that writes a file quoting `terraform destroy` is denied
  like the real thing (a reader-led quoted write such as `printf ... >> notes.md`
  passes, so the blast radius is heredoc-shaped and multi-line writes). This is
  unfixed: narrowing it means reasoning about whether written text is later
  executed, which this classifier deliberately does not attempt. Documentation
  and audit records must redact the string or use a non-shell write path.

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
