# command-guard

Stops an agent from running a command that destroys data before it runs it.

The failure it was written for: mid-task, a migration looked stuck, so the agent
ran `php artisan migrate:fresh`. That drops every table and re-runs the
migrations. Nothing asked, because it is an ordinary command that happens to be
terminal, and the data was gone before anyone read the transcript.

Claude Code's permission system asks about *tools*, not about *meaning* — once
`Bash` is allowed, `php artisan migrate` and `php artisan migrate:fresh` are the
same tool call. This plugin adds the missing distinction: a `PreToolUse` hook
that classifies the command string itself.

## What it does

| Verdict | When | Effect |
|---|---|---|
| `deny` | irreversible loss whose blast radius is not visible in the command — `migrate:fresh`, `db:wipe`, `DROP DATABASE`, `rm -rf /`, `rm .env` or a `cp`/`mv`/`tee` over a live one, `artisan key:generate` over a set `APP_KEY`, `cd /missing/dir; …` (the rest would run in the live tree), `git clean -fdx`, `git push --force`, `git push origin :branch`, `rm -rf .git`, `ALTER TABLE … DROP COLUMN`, `db.coll.drop()`, `docker compose down -v`, `kubectl delete pvc`, `terraform destroy`, `aws s3 rb`, `gsutil rm -r`, `gcloud … delete`, `firestore:delete --all-collections` | the call is blocked; the model is told not to rephrase it, and to hand the command to the user |
| `ask` | destructive but scoped and commonly intended — `git commit --no-verify` and the other hook or signing bypasses, `gh pr review --approve` / `gh pr comment` and the API posts of review text (see [below](#hook-bypass-and-published-review-text)), `git reset --hard`, `git reset --merge`, `git switch -f`, `git clean -fd`, `git worktree remove --force`, `rm -rf ./some-dir` *when git cannot restore it* (see below), `git checkout -- <file>` / `git restore <file>` / `git rm -f <file>` *when it holds uncommitted changes*, `xargs rm -rf`, `find … -exec rm -rf`, `gh api -X DELETE`, `DELETE FROM`, an `UPDATE` with no `WHERE`, `kubectl delete pod`, `terraform apply -auto-approve`, `curl … \| sh`, a `Write` that replaces an existing `.env` | the user gets a permission prompt naming what is lost — with no interactive prompt (`claude -p`, a headless agent, `dontAsk`) the request is **auto-denied**, see [Running headless / in CI](#running-headless--in-ci) |
| `allow` | everything else, including `rm -rf node_modules`, `rm -rf .playwright-mcp` (the Playwright MCP's scratch dir, unless it is a symlink or the command `cd`s first, in a subshell or through `env -C` too), `rm -rf /tmp/scratch-dir`, `git commit -m "drop the table step"`, `grep -r migrate:fresh .` | silent; normal permissions apply |

`rm -rf` **inside the OS temp directory** is silent — under `/tmp`,
`/private/tmp`, `/var/tmp`, macOS's `/var/folders/…/T/`, or a `$TMPDIR` the hook
can resolve from its own environment. The system clears that directory on boot,
so a scratch dir under it is regenerable in the same sense `node_modules` is.
The roots themselves stay on the deny tier: `rm -rf /tmp` empties every other
process's scratch state, not just this session's. A `..` in the path, or the
braced `${TMPDIR}` spelling, falls back to `ask`.

A variable the same command set from `mktemp` is silent too: `tmp=$(mktemp -d); …;
rm -rf "$tmp"`, where the assignment is a top-level command of its own (not in a
subshell, a function, an `if`, a pipeline, a backgrounded list or a heredoc body, not
after `&&`, and not `local` or `declare -n`/`-i`/`-a`/`-A`). A path under it (`"$tmp"/*`, `"$tmp/sub"`) also needs proof that a failed
`mktemp` cannot leave the variable empty, since `"$tmp"/*` would then be `/*`. Two
proofs count: `${tmp:?}` in the target, or `|| exit` (`|| { …; exit 1; }`) on the
variable's only assignment. `set -e` and `|| return` do not. It asks again when the
command assigns the variable anything else, runs `eval` or `source`, deletes it
before the assignment, walks out of it with `..`, names `HOME` or `TMPDIR`, or hands
the `rm` to another shell that never sees the variable (`bash -c '…'`, `ssh host
'…'`, `bash <<'EOF'`; `trap '…'` runs here).

`rm -rf` on a relative path is decided by **recoverability, not spelling**: if the
path is absent, or tracked by git with nothing untracked, modified or ignored
under it, deleting it is not a loss and there is no prompt. Ignored content
counts as a loss — git has no copy of a `.gitignore`d `.env`. The check is
dropped whenever the command contains `cd`/`pushd`, since the hook's working
directory is then not the one the `rm` resolves against.

A **per-file discard** is judged the same way. `git checkout -- <file>`,
`git checkout <tree> -- <file>`, `git restore <file>` (not `--staged` alone) and
`git rm -f <file>` ask only when `git diff` shows the file holds changes git has no
commit of; on an unmodified file they are silent. They ask without looking after a
`cd`, a `git -C`/`--git-dir`/`--work-tree`, or a `$` in the path. A `git checkout <file>`
with no `--` is read as a branch switch and passes.

A **live `.env`** is judged by state too. `cp .env.example .env` in a clone with no
`.env` is the setup step and passes; the same command over an existing `.env`
that git has no clean copy of is denied, as are `mv`/`install`/`ln`/`rsync`/`tee`
onto it, a truncating `>` onto `.env.*`, and `artisan key:generate` when the file
already holds an `APP_KEY` (`--show` passes — it writes nothing). After a `cd` the
guard cannot tell which `.env` a relative path lands on, so it denies. A
**`cd` that must fail** is denied too: an absolute target that does not exist,
not created earlier in the command, whose chain ends in `;` — the Bash tool keeps
its working directory, so every step after the `;` would run in the live tree.
That deny invites the corrected retry (`test -d` first, then `&&`). Both exist
because of one 2026-09-24 incident: a hand-built worktree was never created,
`cd /tmp/… && …; cp .env.example .env && php artisan key:generate` ran in the
real repo, and the credentials and the key were gone.

It reads through the usual disguises — quotes (`artisan "migrate:fresh"`),
wrappers (`bash -c`, `eval`, `docker compose exec`), extra whitespace, `&&`
chains, heredocs fed to a shell or SQL client — and skips read-only commands, so searching for a string is
never confused with running it. Any other heredoc body (`cat > f <<EOF`, `python3 - <<EOF`)
is data and is not read, unless the guard cannot rule out a shell reading it (rules.md lists
when): judging every body line by line pushed a 21 KB command past the hook's 15 s
timeout. A judgment still running after 12 s now asks instead, on every CLI version; from
Claude Code 2.1.295 a guard that cannot start, or one the host times out, blocks the call (see
[Failure mode](#failure-mode)). It also covers MCP tools that shell out or run
SQL, which are the same hole under a different tool name. It reads through `env` and
every documented git global option before the subcommand, and does not take
`git clean … -e -n` for a dry run (`-n` is the exclude pattern there). It misses a git
subcommand behind a `-C`/`-c` value holding a space; the wrapper and git-option limits
are listed in rules.md.

Full rule list, the reading algorithm, and the guard's stated limits:
[`skills/destructive-commands/references/rules.md`](skills/destructive-commands/references/rules.md).

## Hook bypass and published review text

Two asks that are not about lost data. Both are a prompt, never a block, and both go silent
under `CLAUDE_DESTRUCTIVE_GUARD=deny-only` with the rest of the ask tier. **Under `claude -p`,
a headless agent or `dontAsk`, an ask is a deny**: the command does not run (see
[Running headless](#running-headless--in-ci)).

- **A git command that skips the repository's hooks or signing.** `--no-verify` on `git commit`,
  `push`, `merge`, `rebase`, `am`, `cherry-pick` or `pull`; `-n` on `git commit` or `git am`,
  the two subcommands whose own docs make `-n` mean `--no-verify` (on `push` it is `--dry-run`, on
  `merge`, `rebase` and `pull` `--no-stat`, on `cherry-pick` and `revert` `--no-commit`, so those
  pass); `-c core.hooksPath=…` or `--config-env=core.hooksPath=…` before one of those
  subcommands or `revert`, and `git config` setting or unsetting `core.hooksPath`; `--no-gpg-sign`,
  `-c commit.gpgsign=false`, or `git config commit.gpgsign false`; `HUSKY=0`, `SKIP=…`
  (pre-commit) or `LEFTHOOK=0` in front of one of them. Words are read as the shell reads them,
  so a commit message that mentions `--no-verify` passes, as do `grep -- --no-verify` and
  `git log --no-verify`; a later `--verify` (or `-S`, for signing) cancels the bypass, as in git.
  It reads through an `if`/`then`/`do`/`while`/`!` head, the `sudo`, `env`, `nice`, `timeout`,
  `xargs`, `stdbuf` and `flock` wrappers, `$'…'` quoting, and a `$( )` or backtick substitution,
  quoted or not. Missed: a bypass set by an earlier `export HUSKY=0`, a git alias, `GIT_CONFIG_*`
  variables, `flock -c '…'`, or a script that commits.
- **Review or comment text published under your name.** `gh pr review` with `--approve`,
  `--comment`, `--request-changes`, `--body` or `--body-file` (or `-a -c -r -b -F`);
  `gh pr comment` and `gh issue comment` (not `--web`); `gh api` with POST, PATCH or PUT to a
  pull request's `reviews` or `comments`, an issue's `comments`, a review comment's `replies`, a
  review's `events`, or an existing `pulls/comments/N` or `issues/comments/N` (`gh api` sends
  GET unless `-X` names a method or a `-f`/`-F`/`--input` body makes it POST); and a GraphQL
  `addPullRequestReview…`, `addComment`, `submitPullRequestReview`, `updateIssueComment`,
  `updatePullRequestReview` or `updatePullRequestReviewComment` mutation, to `graphql`, `/graphql`
  or a full URL. A `-R`/`--repo` anywhere is skipped. Silent:
  `gh pr view`, a GET of those paths, `gh pr create`, and `gh pr merge`, which git-workflow's
  merge-checks hook already asks about. Missed: a mutation read from a file (`-F query=@q.graphql`),
  `--input` naming a GraphQL body, and a script or `curl` posting to the API.

Standing: **gate** for both, with a human in it: `destructive-guard.test.sh` holds every
spelling above, the silent neighbours and the payload path (sections `== hook and signing
bypass` and `== publishing review text`).

## The second hook: an ask before the agent edits its own guardrails

`hooks/config-guard.sh` is a separate `PreToolUse` hook on file writes; on a Bash
command it reads only the files the command writes. It returns **`ask`** — never a
deny — when a `Write`/`Edit` (or an MCP `create_new_file`) targets an **existing** file that decides what the
agent may do: `.claude/settings.json` and its variants, any `hooks.json`, any hook
script under a `hooks/` dir, `plugin.json` / `marketplace.json`, and the lint,
type-check and test configs a build fails on (`.eslintrc*`, `eslint.config.*`,
`biome.json`, `.rubocop.yml`, `ruff.toml`, `.flake8`, `setup.cfg`, `pytest.ini`,
`pyproject.toml`, `phpstan.neon[.dist]`, `psalm.xml[.dist]`, `.php-cs-fixer*.php`,
`.golangci.y[a]ml`, `clippy.toml`, `tsconfig.json`, `mypy.ini`, `.stylelintrc*`,
`phpunit.xml[.dist]`, `jest.config.*`, `vitest.config.*`, `.mocharc*`, `karma.conf.*`,
`.coveragerc`, `.nycrc*`, `codecov.yml`), CI config (`.github/workflows/*.y[a]ml`,
`.gitlab-ci.yml`), git hooks (`.git/hooks/*`, `.husky/*`, `.pre-commit-config.yaml`,
`lefthook.yml`), analyzer baselines (`phpstan-baseline.neon[.dist]`,
`phpstan-baseline.php`, `psalm-baseline.xml`, `eslint-suppressions.json`) and this plugin's own
[strictness file](#making-one-project-stricter), `.claude/command-guard-strict`.

It asks on a Bash command that writes baseline entries too: `--generate-baseline` (and
phpstan's `-b` after a `phpstan` word), psalm's `--set-baseline`, eslint's `--suppress-all`
and `--suppress-rule`, read outside quotes, comments and heredoc bodies no shell reads. Shrink-only runs
pass: psalm's `--update-baseline` and eslint's `--prune-suppressions` only drop fixed
entries. A new finding belongs in a fix or a one-line suppression with its reason, not
in a regenerated baseline that turns the run green.

Why: given a gate it cannot satisfy, the cheapest path out is to edit the gate — turn
off the rule, add an ignore, delete the hook — and in a diff summary that reads
"updated config". `ask` and not `deny`, because editing these is often exactly the
task; the point is that it becomes a decision someone made.

What it does not do, stated because an ask reads stronger than it is: it reads the
**path, not the diff**, so adding a rule and deleting one look identical to it and the
prompt says so. A file that does not exist yet is allowed through — creating a config
is not relaxing one. An MCP `apply_patch` names no single path and passes silently.
A Bash write onto one of these files (a redirect, `tee`, `sed -i`)
is asked about too — not a python or php write, a `cp`/`mv` destination or a path held
in a variable — and a plain `rm` of a config other than the strictness file passes both
hooks: the command guard judges only `rm -r` and `.env`. And it self-exempts
inside a marketplace repository — one with `.claude-plugin/marketplace.json` at the git
root — which edits these files as its product.

`CC_CONFIG_GUARD=off` disables it, and so does either `CLAUDE_DESTRUCTIVE_GUARD` value
that means "no ask tier" (`off`, `deny-only`).

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install command-guard@cc-plugins-marketplace
```

Nothing to configure. The hook is active from the next session; it costs ~0
always-on context, and prints only when it fires.

## Opting out of a specific command

`.claude/destructive-guard-allow` in the project — one extended regex per line,
matched unanchored against the whole normalised, lowercased command, every chained
part and a trailing comment included: a line releases any command that contains it, so
`artisan migrate:fresh --env=testing` would also release
`rm -rf /; php artisan migrate:fresh --env=testing`. Anchor a line (`^…$`) to release
only that command, and write lines in lowercase — one with an uppercase letter never
matches:

```
# a scratch database this project resets constantly
^php artisan migrate:fresh --env=testing$
```

**The agent is blocked from writing this file directly.** Writes to it are denied through
`Write`/`Edit`, and a Bash command that names it is denied unless every part of
it, piped or chained, is a pure read: `cat`, `head`, `tail`, `wc`,
`grep`/`egrep`/`fgrep`, `stat`, `ls`, `file`, `diff`, `cmp`, or `git log`/`show`/
`diff`/`blame`/`grep`/`ls-files`/`cat-file` with the subcommand first and no
`--output`, `-o`/`-O`, pager, `--ext-diff`, `--textconv`, `--filters` or `-c`
option. The reader's name must be typed bare, a redirect may only target
`/dev/null` or a descriptor with nothing quoted or escaped beside the target
(`>"/dev/null"` is denied), and a backtick, `$`, `~`, `{}`, an unquoted `#` or
parenthesis, or a leading env assignment (`LC_ALL=C grep …`) denies the command.
So `grep x <file> 2>/dev/null` passes, while `awk`, `sed -n`, `find`, `jq` and
`less` on the file are blocked: each can write or run a program, so use `cat`
or `grep`. An opt-out an agent can grant itself is not an opt-out. Add lines
yourself, and narrowly. What it does NOT catch: a path built from a variable or a
glob, a script that writes the file, or any program git config names (a diff
driver, textconv, clean filter, pager, `core.fsmonitor`, `gpg.program` via
`--show-signature`), set before the command runs; and on the write path, an MCP
write tool other than `*apply_patch` and `*create_new_file`, `NotebookEdit`'s
`notebook_path`, and a non-ASCII spelling the filesystem folds to the name (the
match is case-insensitive for ASCII letters only). The protection is that a
denied command is visible to you, not that a bypass is impossible.

Whole-guard switches, set in your shell before starting the session (a command
string cannot reach the hook's environment, so
`CLAUDE_DESTRUCTIVE_GUARD=off php artisan migrate:fresh` does not work):

| Value | Effect |
|---|---|
| unset (default) | deny + ask tiers as above |
| `CLAUDE_DESTRUCTIVE_GUARD=deny-only` | the hard stops only; the ask tier goes silent |
| `CLAUDE_DESTRUCTIVE_GUARD=ask` | every deny becomes a prompt instead of a block |
| `CLAUDE_DESTRUCTIVE_GUARD=off` | guard disabled |
| `CC_CONFIG_GUARD=off` | the config-file-write ask only; leaves the command guard on |

`CLAUDE_DESTRUCTIVE_GUARD=deny-only` and `=off` silence **config-guard** too, since
both mean "no ask tier". Until 0.6.3 they did not: config-guard read only its own
variable, so the setting recommended for a global install (by the core-suite README,
retired with the suites on 2026-09-26) left an
ask running on every `tsconfig.json`, `pyproject.toml` or `hooks.json` write.

### Running headless / in CI

**An `ask` with nobody to answer it is a DENY, not a pause.** In `claude -p`, in a
headless agent, in a subagent, and in any session started with `dontAsk`, there is no
interactive prompt: the host resolves the permission request by refusing it. The
command does not run and the turn continues with a refusal, so every row of the `ask`
tier above — `git reset --hard`, `rm -rf ./dir`, `DELETE FROM`, `kubectl delete pod`,
`terraform apply -auto-approve`, `curl … | sh`, `git commit --no-verify`, `gh pr review
--approve`, an `ask` line in `.claude/command-guard-strict` — behaves as a hard block there, and
so does config-guard's ask on an existing `tsconfig.json` or `hooks.json`.

That makes `deny-only` the **automation profile**, not merely the quiet one: it keeps
every irreversible-loss block and hands the scoped-and-commonly-intended tier back to
the run, instead of turning it into a silent refusal nobody is present to override.

```json
{ "env": { "CLAUDE_DESTRUCTIVE_GUARD": "deny-only" } }
```

Put that in the `settings.json` the automated run loads (project `.claude/settings.json`,
or your CI image's user settings) — not in your interactive one, where the ask tier is
doing its job.

**Standing: `recorded`.** Nothing here is enforced or even detected: **no hook payload
field exposes whether an interactive prompt can be shown**, so the guard cannot behave
differently headless, cannot warn that it is about to be auto-denied, and no script
checks that an automated run set the variable. The only mechanism is you setting it.

### When another guard also fires

One command can meet **two** hooks. All `PreToolUse` hooks that match the call run, and
the host takes the strictest verdict: **`deny` beats `ask` beats `allow`.** A `deny`
from any hook ends the call, whatever this one returned.

So fixing a command for one guard can land it on a second. The worked case:
`git reset --hard HEAD~3` is this plugin's `ask` tier; rewrite it as
`git reset --hard HEAD~3 && git commit -m "…"` with an AI attribution trailer in the
message and `git-workflow`'s `no-ai-trailer` hook **denies** the whole call — one
payload, two verdicts, and the deny is the one you get. The reason text you are shown
is the denying hook's, which is why a deny reason that says nothing about `rm -rf` is
not this guard changing its mind.

Practical reading: a blocked command is blocked for *every* reason that matched, not
just the one named. Fix the named reason, re-run, and read the next reason if there is
one. Standing: **recorded** — precedence is the host's behaviour, not something this
plugin implements or tests.

### Why you might want `deny-only`

The two tiers cost you very different things. The deny tier is free: it never
prompts, it returns instantly, and it is where the framework knowledge lives
(`migrate:fresh`, `doctrine:fixtures:load`, `flyway clean` — shapes a general
safety check has no particular reason to know). The ask tier is the one that
interrupts, and it is mostly `rm -rf` and `git reset --hard`, which the host's own
checks partly cover. Claude Code's dangerous-`rm` check asks, in auto and
`--dangerously-skip-permissions` mode, before a recursive `rm` of `/`, `~` or another
spelling of the home folder or a drive, or of positional parameters; since CLI 2.1.281
also of a target that is only command-substitution output (`rm -rf "$(pwd)"`, asked
even past a Bash allow rule), of a variable followed by a top-level directory name or
derived from the working directory (`$VAR/etc`), and of a backslash-only target
(`rm -rf \`). Unanswered for 2 minutes, it denies with a rewrite hint. That is the
host's changelog, not measured here. It does not judge a scoped `rm -rf ./dir`,
`git reset --hard`, `find … -delete` or `kubectl delete pod`: in auto mode the host's
classifier does, in default mode its ordinary permission prompt. This guard denies a
backslash-only target outright since 0.9.0 (`rules.md` says why).

It matters more than "one is noisier". Where the host decides permissions with a
classifier of its own, a `PreToolUse` **`ask` overrides that classifier** — so
the ask tier does not add a check, it *replaces a silent judgement with a human
click*. `deny-only` hands that tier back.

Set it wherever your host passes environment to hooks — in Claude Code, the
`env` block of `settings.json`:

```json
{ "env": { "CLAUDE_DESTRUCTIVE_GUARD": "deny-only" } }
```

**The trade is real and it is yours to make.** Outside a host that classifies
commands, nothing replaces the ask tier: `git reset --hard`, `find … -delete`
and `kubectl delete pod` stop being announced. Prefer the allow-file below if
only a few specific commands are noisy — it is narrower than switching a tier
off.

## Making one project stricter

`.claude/command-guard-strict` in the project raises a verdict for the commands it lists and can
never lower one. One entry per line, `ask <regex>` or `deny <regex>`, the regex matched like the
allow-file's (unanchored, against the normalised, lowercased command; write it in lowercase).
The dialect is bash's `[[ =~ ]]`, POSIX ERE: use `[[:space:]]` and `[0-9]`, since `\d` matches a
literal `d` and `\s` works only with glibc. `#` lines and blank lines are skipped.

```
# .claude/command-guard-strict
ask ^npm install
deny git push( |$)
```

- An `ask` line turns a silent command into a prompt; a `deny` line blocks a silent or asked
  one. Under `deny-only` an `ask` line goes silent with the rest of the ask tier, and under
  `CLAUDE_DESTRUCTIVE_GUARD=ask` a `deny` line prompts.
- A line that would loosen (an `allow` line on an asked or denied command, an `ask` line on a
  denied one) is skipped, and the call carries one note naming the line. Only the allow-file
  releases a built-in verdict, and it has the last word over this file too.
- The file is read as data, never sourced. Over 16,384 bytes, unreadable, a line that is not
  `ask`/`deny`/`allow` plus a regex, or a regex that does not compile: the whole file is
  ignored, the built-in verdicts stand, and each command carries one note saying why. The note
  is a `systemMessage` for you, not text for the model; `--check` prints it as a `NOTE` line.
- config-guard asks before a `Write`, `Edit` or Bash redirect, `tee` or `sed -i` changes an
  existing one, and before `rm`, `unlink`, `mv`, `git rm` or `git mv` removes it: removal only
  loosens, and a strict deny's reason names the file. Creating one is silent, since a new file can
  only add strictness. Removing its whole `.claude` directory, or by glob, is not read here.

Standing: **gate** for the raise, the skipped loosening line, the malformed and oversized file
and the protection: `destructive-guard.test.sh` (`== project strictness file`) and
`config-guard.test.sh`.

## Checking a command without running it

```
/command-guard:check "php artisan migrate:fresh"
```

or directly, which is also how the test harness drives it:

```bash
bash hooks/destructive-guard.sh --check 'git reset --hard'   # exit 1 = ask
```

**That direct form does not work from inside an agent session for a deny-tier
target.** The invocation carries the target as an argument and arrives through
the Bash tool, so the guard reads it and denies it — there is no self-exemption,
because both attempts at one were bypassable (see `commands/check.md` for the
tier-by-tier table and the reasoning). From your own terminal it works for every
tier; the harness drives it as a plain script, which is why the tests are
unaffected.

### Checking your permission settings

```
/command-guard:check --settings
```

runs `scripts/settings-lint.sh`, which reads `.claude/settings.json`,
`.claude/settings.local.json` and your user `settings.json` (under `CLAUDE_CONFIG_DIR` when
set) as data, never writes them, and prints `<file>: <key path>: <risk>` for each of:

- a bare `Bash` or `Bash(*)` allow rule;
- an allow rule that matches a command this guard asks on (`Bash(git *)` covers
  `git reset --hard`), tested against a fixed list of those commands with the host's `*` and
  `:*` rule syntax;
- `permissions.defaultMode: bypassPermissions` (from a project file it has had no effect since
  CLI 2.1.257, and the line says so);
- `disableAllHooks: true`;
- `CLAUDE_AI_TRAILER=allow` in an `env` block, where it lets every command through
  git-workflow's trailer check instead of the one it was typed for;
- `permissions.additionalDirectories` holding `/`, `~` or your home folder;
- a guard's off switch (`CC_CONFIG_GUARD`, `CC_SECRET_SCAN`, `CC_DB_GUARD`,
  `CLAUDE_DESTRUCTIVE_GUARD=off`, and the other guard switches the script lists) set to `off` in
  `env`, or set off as a `/config` option in your user file's `pluginConfigs`;
  `CLAUDE_DESTRUCTIVE_GUARD=deny-only` only in the user file, since a project's automated run is
  where this README recommends it.

Exit `0` nothing found, `1` findings, `2` a file is not a JSON object (the others are still read),
`3` no `jq`, `64` a bad argument. Not read: managed settings, `--settings` files, rules spelled
another way than the sample commands, and any guard switch the script does not list. Standing:
**gate** for what it flags and its exit codes (`settings-lint.test.sh`, which also holds every
sample command to this guard's ask tier and every switch name to the marketplace README's
off-switch table); **recorded** for running it, since nothing runs it for you.

## What has teeth

Standing markers per the marketplace convention (see
`.claude/skills/authoring-skills/SKILL.md` in the marketplace repository).

| Control | Standing | What actually happens |
|---|---|---|
| deny tier on `Bash` | **gate** — blocks the tool call | the hook returns `permissionDecision: deny`; the command does not run |
| ask tier on `Bash` | **gate**, with a human in it | a permission prompt; the user decides |
| hook or signing bypass, published review text | **gate**, with a human in it | the same prompt; tested in `destructive-guard.test.sh`; a deny under `-p` |
| `.claude/command-guard-strict` | **gate** | raises a listed command to ask or deny; a loosening line is skipped with a note; tested |
| `/command-guard:check --settings` | **gate** for its rules, **recorded** for its use | prints one line per risky setting when you run it; nothing runs it for you |
| agent writes to the allow-file | **gate** | denied on `Write`/`Edit`; a Bash command naming it passes only when every segment is a pure read (`cat`, `grep`, `git log`, …) |
| agent writes to a settings / hooks / lint config or analyzer baseline file, or runs a baseline regenerate | **gate**, with a human in it — `config-guard.sh` | a permission prompt on an existing listed file or a listed flag; it reads the path or flag, so whether the change *weakens* anything is **agent-graded** |
| the classification rules themselves | **gate**, tested | the assertions in `scripts/__tests__/destructive-guard.test.sh`, run in CI for every plugin harness — recount: `bash plugins/command-guard/scripts/__tests__/destructive-guard.test.sh \| tail -1` |
| `rm -rf` recoverability | **gate**, tested | asserted against a throwaway git repo fixture, not a mock; fails closed to `ask` on any git error |
| "do not rephrase a denied command" | **recorded** | it is instruction text in the deny reason and in the skill; nothing detects a rephrase attempt |
| coverage of destructive shapes | **unenforceable** | the rule table matches known shapes; a command inside a script, a Makefile target, an npm script, or application code is invisible to it |

The last row is the one to keep in view: a silent pass means "no known shape
matched", not "safe". This is one control among several — backups, a
development database URL that does not point at production, and least-privilege
credentials fail in different ways, which is why more than one is needed.

## Failure mode

Fail-open, deliberately. Missing `jq`, unparseable input, an internal error: the
hook stays silent, exits 0, and the command proceeds under normal permissions. A
guard that breaks sessions gets uninstalled, and an uninstalled guard denies
nothing. The tests assert this directly.

One failure is the host's, not the script's: a guard that cannot start or runs past its
15 s timeout. Since 0.9.0 both `destructive-guard.sh` entries in `hooks/hooks.json` set
`onFailure: "block"`, so from Claude Code 2.1.295 the host blocks the call; below it the
command runs unjudged. Two things keep the block off ordinary work. The entries start the
script as `bash "${CLAUDE_PLUGIN_ROOT}/hooks/destructive-guard.sh"`, through the `bash` on
PATH rather than its `#!/bin/bash` line, so a host with no `/bin/bash` (NixOS) still runs it.
And the script stops a judgment still running after 12 s and asks, on every CLI version and
in every mode, `deny-only` included, since it has not ruled out a deny: a huge command gets a
prompt, not a block or a pass. Measured 2026-10-15 against a fake local Messages API, no
model call, one run each: a 109 KB `bash <<'EOF'` body under 0.8.5's guard was blocked at
15 s on 2.1.300 and ran unjudged on 2.1.291, and asks at 12 s on both under this one; in a
sandbox with no `/bin/bash` and `bash` on PATH, running the script by its path blocked a
plain `ls` on 2.1.300, and the `bash` form runs it and still denies
`php artisan migrate:fresh`. What still blocks every Bash, MCP shell, `Write` and `Edit`
call from 2.1.295: no `bash` on PATH at all, or the plugin's directory gone from under a
running session. `CLAUDE_DESTRUCTIVE_GUARD=off` cannot help there, because the script that
reads it never ran; `/plugin disable command-guard` does. An older CLI ignores the key: on
2.1.291, `claude plugin validate --strict` passes, the plugin installs, and
`claude plugin details` lists its PreToolUse hook, where an invalid hook entry keeps the
plugin from loading at all. Standing: **gate** for the key, the `bash` form and the
12 s ask (`destructive-guard.test.sh`); **measured** that 2.1.300 blocks a run that fails or
times out and that 2.1.291 runs the command (the runs above).
