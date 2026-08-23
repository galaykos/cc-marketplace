# Changelog

## 0.3.1

### Fixed
- `commands/check.md` claimed "ask- and allow-tier targets run fine" after 0.3.0
  removed the self-exemption. Measured: false for **ask**. With no exemption the
  check invocation is itself classified, so checking an ask-tier target draws a
  confirmation prompt worded as though something will be destroyed — for a
  command that only classifies. Allow-tier is genuinely silent. The doc now
  carries a measured tier-by-tier table instead of a claim.

### Added
- **Hook-mode assertions in the `no self-exemption` harness section.** Every
  assertion added in 0.3.0 drove CLI mode (`--check`), which reaches `classify()`
  directly. A reviewer planted the 0.2.0 substring bug one layer up — a `case` on
  the raw command string in the HOOK path, before `classify()` is called — and
  the whole section passed 141/0 with the hole live. That is the same
  CLI-mode/hook-mode composition gap that let the original defect ship,
  reappearing in the tests written to close it. Four vectors now drive the real
  `PreToolUse` entry point; verified against the planted hole, which they fail.

### Changed
- Removed two byte-identical duplicate assertions. The section asserts 9 distinct
  vectors, not the 10 the 0.3.0 changelog claimed. Of the 8 non-control CLI
  assertions, 5 discriminate against a 0.2.1-style exemption and 3 (the `eval`
  form and the two `-c` wrapper forms) deny regardless — kept as regression
  coverage for a re-added 0.2.0-style exemption, which is what they do catch.

## 0.3.0

### Security
- **Reverts the self-exemption entirely.** 0.2.0 added it and 0.2.1 rewrote it;
  both were bypassable, so the convenience it bought is withdrawn rather than
  patched a third time.
  - 0.2.0 matched `bash` / the guard path / `--check` as substrings ANYWHERE in a
    segment. `bash -c PAYLOAD name arg...` executes PAYLOAD and demotes the rest
    to `$0`/`$1`, so appending the magic words to a destructive `bash -c` call
    unlocked it.
  - 0.2.1 matched by argv POSITION, which closed that vector and left three
    others open: command substitution, backticks, and redirection to a raw disk.
    An exemption that `continue`s past classification skips the WHOLE segment,
    and a shell segment carries side effects the shell evaluates independently of
    argv — the payload runs before or beside the classifier that argv claims is
    all that happens.
  - The general rule this settles: an exemption keyed on what a command LOOKS
    like cannot be safe while the shell will evaluate parts of that same string on
    its own terms. A safe version would have to classify the segment anyway and
    suppress only the verdict arising from the `--check` argument, which means
    parsing shell grammar — something this guard deliberately does not do.

### Changed
- `commands/check.md` now states the limitation instead of the plugin trying to
  engineer around it: for a **deny-tier** target the CLI step is itself denied, so
  the command reports `deny` from `references/rules.md` rather than retrying.
  `ask` and `allow` targets are unaffected. Standing: **unfixed by design**.

### Added
- A `no self-exemption` harness section pinning all ten known bypass vectors plus
  two controls as DENY. Verified against both prior releases: 5 assertions fail
  against 0.2.1 and 10 against 0.2.0. If a third exemption is ever added, this
  section is what should stop it.

## 0.2.1

### Security
- **Fixes a bypass introduced by 0.2.0.** That release's self-exemption matched
  its three tokens anywhere in the command segment. But `bash -c PAYLOAD name arg...`
  executes PAYLOAD and turns everything after it into `$0`/`$1`/..., so appending
  the literal words `destructive-guard.sh --check y` to a `bash -c "<destructive>"`
  call satisfied all three substrings while the shell still ran the payload --
  re-opening the exact `bash -c` wrapper hole this guard's own deny text warns
  models not to attempt. Four vectors confirmed allowed, including a `bash -lc`
  filesystem wipe with the magic tail appended.
- The exemption now matches by POSITION: word 1 must be `bash`/`sh`, word 2 must
  be the guard's own path, word 3 must be `--check`. `-c` lands in word 2, where
  only that path is accepted. Seven bypass vectors plus a control are asserted in
  the harness and fail against 0.2.0.

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
