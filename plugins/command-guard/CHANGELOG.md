# Changelog

## 0.6.6

### Changed
- **Both refusals name `CLAUDE_DESTRUCTIVE_GUARD`.** The deny reason named the
  `.claude/<allowfile>` opt-out and not the environment switch; the ask reason named
  neither. Each now states the value that silences it (`off`, and `deny-only` for the ask
  tier), and the deny adds the fact that makes the difference in practice: the variable is
  read from the hook's own process, so prefixing it to the command does nothing. The
  person who needs that fact is the one reading the refusal (panel finding UX 1).

## 0.6.5

### Fixed
- **`destructive-guard.test.sh`'s "guard touched nothing" assert failed on other
  people's edits.** It snapshotted `git status --porcelain` over the whole working tree
  before and after the run, so any concurrent change anywhere in the repo — a parallel
  worker, a generator run, an unsaved-then-saved file — reported the guard as having
  mutated the tree. The snapshot is scoped to `-- plugins/command-guard` now; the assert
  keeps its intent and states its residual (a write outside this plugin's directory is no
  longer seen, and the guard's only filesystem reach is reading `.claude/<allowfile>`).
  221 asserts, 0 failed.

## 0.6.4

### Fixed
- **`config-guard` was undocumented in the README.** The plugin has shipped a second
  `PreToolUse` hook since 0.6.1 — an `ask` on a write to settings, any `hooks.json`, a
  hook script, a plugin manifest or a lint/type-check/test config — and the README named
  it only in the environment-variable table. An installer met the prompt before they met
  the feature. It now has its own section (what it matches, why `ask` and not `deny`, the
  self-exemption, and the three things it does not catch) and a row in "What has teeth".
- **`config-guard.sh`'s header listed one file set and its code matched another.**
  `pyproject.toml` has been in the `case` since 0.6.1 and absent from the header comment
  that enumerates the covered files; `phpstan.neon.dist`, `psalm.xml.dist` and
  `.golangci.yaml` were missing the same way. The header is the list now.
- **`rm -rf ./some-dir` was given as an `ask` example in two places that the
  recoverability check contradicts.** Since 0.4.0 a relative path git can restore is
  `allow`, and the README's own tier table and the hook header both used the bare form
  as the canonical ask. Measured: `rm -rf ./tracked` → allow, `rm -rf ./untracked` →
  ask, `rm -rf ./absent` → allow. Both now say "when git cannot restore it".
- **`references/rules.md`'s "Tuning it" section listed two of the four switches.**
  `deny-only` was argued in the limits paragraph above it and absent from the list, and
  `config-guard` and `CC_CONFIG_GUARD` appeared nowhere in the file the command sends a
  reader to for "the guard's stated limits". Both are named now.

## 0.6.3

### Fixed
- **`config-guard` now honours `CLAUDE_DESTRUCTIVE_GUARD=deny-only`.** core-suite's README tells installers that variable buys the click-free half of this plugin, but config-guard read only its own `CC_CONFIG_GUARD` — so the documented setting left an ask tier running on every config write. Both values that mean "no ask tier" (`off`, `deny-only`) now silence it.

## 0.6.2

### Fixed
- **The allow-file guard now covers MCP file writes.** 0.6.1 widened the matcher to
  `*apply_patch|*create_new_file` but left the script gating on the four host tool
  names, so the matcher fired and the script exited — silent coverage, and the file
  that disarms this guard stayed editable through any MCP server while the host tools
  were blocked. `create_new_file` is read from `pathInProject`; `apply_patch` carries
  no single path, so its patch body is checked for the basename. Four assertions.

## 0.6.1

Two releases shipped under this one version number — `config-guard` landed after the
MCP allow-file fix without a bump, so the entries are merged here rather than split
across two `0.6.1` headings that a consumer could not order or tell apart.

### Added
- **`config-guard`: an `ask` before the agent edits its own guardrails.** Settings
  files, any `hooks.json`, any hook script, plugin manifests, and lint/type-check/test
  configs (eslint, biome, rubocop, ruff, phpstan, psalm, golangci, pytest, tsconfig,
  clippy). Given a gate it cannot satisfy, the cheapest path out is to edit the gate —
  turn off the rule, add an ignore, delete the hook — and it reads in a diff summary as
  "updated config". `ask`, not `deny`, because editing these is often exactly the task;
  the point is that it becomes a decision someone made. It reads the PATH, not the
  diff: it cannot tell adding a rule from deleting one, and says so in the prompt. It
  self-exempts inside a marketplace repository, which edits these files as its product.
  `CC_CONFIG_GUARD=off` disables it; `scripts/__tests__/config-guard.test.sh` drives
  21 cases.

### Fixed
- **The allow-file cannot be edited through an MCP file tool.** The second matcher
  protecting `.claude/destructive-guard-allow` covered the four host write tools only;
  an IDE-MCP write bypassed the protection on the file that disarms this guard.
- **"187 assertions" in the README is 217** — the harness has printed the larger number
  since 0.6.0 added thirty.

## 0.6.0

### Fixed
- **`git push -f` was allowed.** The deny rule ` git push .*(--force( |$)| -f( |$))`
  could not match `-f` as the first word after `push`: the pattern's own literal
  space consumed the only space, so `git push -f origin main` — the commonest
  spelling of a force push — fell through to allow while `git push origin main -f`
  denied. The rule is now ` git push( [^ ]+)* (--force|-[a-eg-z]*f[a-z]*)( |$)`, which
  also catches clustered short flags (`-uf`, `-fu`). `--force-with-lease` stays on
  the ask tier. Found by classifying a corpus of common commands through `--check`.
- **git global options bypassed every git rule.** Each rule is written
  ` git <subcommand> …`, so `git -C /path push --force`, `git -c core.pager=cat
  reset --hard` and `git --git-dir=… clean -fd` matched nothing. `-C`, `-c`,
  `--git-dir`, `--work-tree`, `--namespace`, `--no-pager`, `--no-optional-locks`,
  `--literal-pathspecs` and `--bare` are now stripped from the normalised segment
  before matching. `-C` is the form an agent reaches for whenever it works outside
  its cwd, so this was the live gap, not a theoretical one.

### Changed
- **`git clean -n` / `--dry-run` no longer asks.** A dry run deletes nothing; it is
  the preview the ask tier's own alternative text recommends, so prompting on it
  trained a click-through on the one command that makes the real one safe.
  `-fdxn` and `-fdx --dry-run` are dry runs too and skip the `-x` deny.
- `git checkout .` now asks, as `git checkout -- .` already did — same act, different
  spelling. `git checkout -f` / `--force` (throws away local changes to switch) and
  `git restore --source=<rev> .` / `--worktree .` join the ask tier; `git restore
  --staged .` (index only) stays allowed.
- `crontab -r` asks: it removes every cron job for the user with no confirmation and
  no backup, one key away from `crontab -e`.
- The `DELETE FROM` ask reason no longer claims "no WHERE on this line": the rule
  asks on every shell-run DELETE and always did. The message now says so.
- `GUARD_VERSION` 0.6.0. 30 new classification assertions in the harness cover each
  of the above in both directions.

## 0.5.3

- `lane.tsv` comment names `approaches:consult-remind` as the prompt-time nudge on
  irreversible tokens — fresh-take merged into approaches on 2026-09-14. No
  behaviour change.

## 0.5.2

### Added
- `lane.tsv`: the hook, `/command-guard:check` and the `destructive-commands` skill
  now declare their territory, phase and trigger in the marketplace's lane graph
  (`scripts/lib/plugin-checks.sh`, `pc_lanes_*`). All three are `any`-phase guards —
  a command can be about to run in every phase. Declaration only; no behaviour change.

## 0.5.1

### Changed
- Citations of the four-laws / has-teeth doctrine now point at
  `.claude/skills/authoring-skills/SKILL.md` in the marketplace repository — the
  authoring plugin was demoted to a tracked project skill on 2026-09-03. Prose only;
  no behaviour change.

## 0.5.0

### Changed
- **`rm -rf` on a path inside the OS temp directory no longer asks.** Reported
  case: `rm -rf /tmp/pintcheck && echo cleaned` drew a permission prompt. Every
  absolute path was classified "outside the project" and sent to the ask tier,
  so the guard interrupted on the one directory the operating system itself
  clears on boot and every `mktemp -d` on the machine writes into. Recognised
  roots: `/tmp`, `/private/tmp`, `/var/tmp` (and their `/private` prefixes),
  macOS's `/var/folders/<ab>/<hash>/<T|C>/`, and `$TMPDIR`/`$TMP` resolved from
  the hook's own environment.

  Three boundaries are deliberate, and each is a paired assertion in the harness
  so that loosening one shows up as a failing test rather than as a wider
  exemption:
  - **The roots stay denied.** `rm -rf /tmp`, `/tmp/`, `/tmp/*`, `/private/tmp`
    and `/var/tmp` are hard stops — emptying the shared temp directory destroys
    other processes' state, not just this session's. `/private/tmp` and
    `/var/tmp` are new denies; they are multi-component spellings of the same
    directories that the single-component system-directory rule never reached.
  - **`..` disqualifies the path.** `/tmp/../etc` asks, because a prefix stops
    proving containment once the path can walk back out of it.
  - **An unresolvable variable asks.** `$TMPDIR/build` is silent when `TMPDIR`
    is set in the hook's environment and asks when it is not, since unset makes
    that command `rm -rf /build`. The braced `${TMPDIR}/build` always asks: the
    segment splitter cuts on `{`/`}` before the token forms, and it is not worth
    weakening a splitter that exists for `{ cmd; }` groups and the fork bomb.

  No other tier moved: the rule table, the recoverability check for relative
  paths, and the evasion and fail-open behaviour are untouched.

## 0.4.1

### Changed
- **Every hook entry now declares a `timeout`.** `destructive-guard.sh` 15s. Before this release the
  plugin expressed no opinion about how long its own hook may hold a turn and
  relied entirely on the host default; a hook that blocks — a slow network mount,
  a large transcript — stalled the user with no per-hook ceiling. Sizes are per
  script, not one house number: 5s for a jq-only classifier, 10s for git/find
  work, 15s where the script shells out to the network, a package manager or
  node. No hook logic changed.

## 0.4.0 — 2026-08-26

Cuts the interruptions the ask tier was causing and closes three holes found by
probing the guard against its own claims. (Written as 0.2.0 on a branch cut
before 0.2.1–0.3.1 landed; renumbered on merge, so the entries below are older
than this one despite the collision in the branch's own history.)

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
  was conditioned on a client name (`psql`, `mysql`, …) appearing in the string, <!-- removed-ok -->
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
- Harness reaches 173 assertions, including a throwaway git repo fixture for
  the recoverability rules (a mocked git would only test the mock).

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
  vectors, not the 10 the 0.3.0 changelog claimed. Measured against the real
  historical guards, those 9 split three ways: **5** discriminate against a
  0.2.1-style positional exemption; **3** (the `-c` wrapper forms) fail only
  against a 0.2.0-style substring exemption; **1** (the `eval` form) catches
  NEITHER prior release, because both required a `bash`/`sh` lead word — it pins a
  hypothetical looser exemption only. Kept deliberately, and labelled rather than
  counted as coverage it does not provide.

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
