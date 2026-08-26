# Changelog

## 0.2.0 — 2026-08-26

Cuts the interruptions the ask tier was causing and closes three holes found by
probing the guard against its own claims.

- **`CLAUDE_DESTRUCTIVE_GUARD=deny-only`** — keeps every hard stop, drops the
  ask tier. Measured motivation: across 2016 local transcripts the ask tier
  fired in 64 sessions and the deny tier in 69, but only the ask tier costs a
  prompt. A `PreToolUse` ask also *overrides* a host permission classifier, so
  on a host that has one the ask tier converts a silent judgement into a click.
  Not the default — outside such a host nothing replaces the ask tier.
- **`rm -rf <relative path>` no longer asks when git can restore the path.**
  Absent, or tracked with nothing untracked/modified/ignored under it → silent;
  anything else → ask, as before. Ignored content counts as a loss because git
  has no copy of it, which is the `.env`-under-the-directory case. The check is
  skipped entirely when the command contains `cd`/`pushd`, because the process's
  cwd is then not the one the `rm` resolves against. Runs only on the branch
  that was about to prompt, so ordinary Bash calls gain no `git` invocation.
- **Fixed: bare SQL through an MCP SQL tool was never gated.** Every SQL rule
  was conditioned on a client name (`psql`, `mysql`, …) appearing in the string,
  which an `execute_sql_query` payload has no reason to contain — so
  `DROP DATABASE prod`, `TRUNCATE TABLE users` and `DELETE FROM users` all
  passed through the one tool family the plugin advertised as covered. SQL
  context is now declared by the hook from `tool_name`/field, not sniffed.
- **Fixed: the `> .env` deny rule could never fire.** A segment whose lead word
  reads (`echo`, `printf`, `cat`, `true`) was skipped before the rule table ran,
  so `rm .env` was denied but `echo x > .env` was allowed. A segment carrying a
  redirect now skips both the reader and the git-safe exemption — the redirect
  is the effect, whatever the lead word claims.
- **Fixed: `git push origin +main` was allowed.** The force-push rule matched
  only `--force`/`-f`, not the `+refspec` form that does the same thing.
- Harness grows 128 → 158 assertions, including a throwaway git repo fixture for
  the recoverability rules (a mocked git would only test the mock).

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
