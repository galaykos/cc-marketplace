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
| `deny` | irreversible loss whose blast radius is not visible in the command — `migrate:fresh`, `db:wipe`, `DROP DATABASE`, `rm -rf /`, `rm .env`, `git clean -fdx`, `git push --force`, `docker compose down -v`, `kubectl delete pvc`, `terraform destroy`, `aws s3 rb`, `gcloud … delete` | the call is blocked; the model is told not to rephrase it, and to hand the command to the user |
| `ask` | destructive but scoped and commonly intended — `git reset --hard`, `git clean -fd`, `rm -rf ./some-dir` *when git cannot restore it* (see below), `DELETE FROM`, `kubectl delete pod`, `terraform apply -auto-approve`, `curl … \| sh` | the user gets a permission prompt naming what is lost — with no interactive prompt (`claude -p`, a headless agent, `dontAsk`) the request is **auto-denied**, see [Running headless / in CI](#running-headless--in-ci) |
| `allow` | everything else, including `rm -rf node_modules`, `rm -rf /tmp/scratch-dir`, `git commit -m "drop the table step"`, `grep -r migrate:fresh .` | silent; normal permissions apply |

`rm -rf` **inside the OS temp directory** is silent — under `/tmp`,
`/private/tmp`, `/var/tmp`, macOS's `/var/folders/…/T/`, or a `$TMPDIR` the hook
can resolve from its own environment. The system clears that directory on boot,
so a scratch dir under it is regenerable in the same sense `node_modules` is.
The roots themselves stay on the deny tier: `rm -rf /tmp` empties every other
process's scratch state, not just this session's. A `..` in the path, or the
braced `${TMPDIR}` spelling, falls back to `ask`.

`rm -rf` on a relative path is decided by **recoverability, not spelling**: if the
path is absent, or tracked by git with nothing untracked, modified or ignored
under it, deleting it is not a loss and there is no prompt. Ignored content
counts as a loss — git has no copy of a `.gitignore`d `.env`. The check is
dropped whenever the command contains `cd`/`pushd`, since the hook's working
directory is then not the one the `rm` resolves against.

It reads through the usual disguises — quotes (`artisan "migrate:fresh"`),
wrappers (`bash -c`, `eval`, `docker compose exec`), extra whitespace, `&&`
chains, heredocs — and skips read-only commands, so searching for a string is
never confused with running it. It also covers MCP tools that shell out or run
SQL, which are the same hole under a different tool name.

Full rule list, the reading algorithm, and the guard's stated limits:
[`skills/destructive-commands/references/rules.md`](skills/destructive-commands/references/rules.md).

## The second hook: an ask before the agent edits its own guardrails

`hooks/config-guard.sh` is a separate `PreToolUse` hook on file writes, not on
commands. It returns **`ask`** — never a deny — when a `Write`/`Edit` (or an MCP
`apply_patch` / `create_new_file`) targets an **existing** file that decides what the
agent may do: `.claude/settings.json` and its variants, any `hooks.json`, any hook
script under a `hooks/` dir, `plugin.json` / `marketplace.json`, and the lint,
type-check and test configs a build fails on (`.eslintrc*`, `eslint.config.*`,
`biome.json`, `.rubocop.yml`, `ruff.toml`, `.flake8`, `setup.cfg`, `pytest.ini`,
`pyproject.toml`, `phpstan.neon[.dist]`, `psalm.xml[.dist]`, `.php-cs-fixer*.php`,
`.golangci.y[a]ml`, `clippy.toml`, `tsconfig.json`).

Why: given a gate it cannot satisfy, the cheapest path out is to edit the gate — turn
off the rule, add an ignore, delete the hook — and in a diff summary that reads
"updated config". `ask` and not `deny`, because editing these is often exactly the
task; the point is that it becomes a decision someone made.

What it does not do, stated because an ask reads stronger than it is: it reads the
**path, not the diff**, so adding a rule and deleting one look identical to it and the
prompt says so. A file that does not exist yet is allowed through — creating a config
is not relaxing one. A weakening applied through Bash (`sed -i` on `.eslintrc`, `rm` of
a hook script) is the command guard's matcher, not this one's. And it self-exempts
inside a marketplace repository — one with `.claude-plugin/marketplace.json` at the git
root — which edits these files as its product.

`CC_CONFIG_GUARD=off` disables it, and so does either `CLAUDE_DESTRUCTIVE_GUARD` value
that means "no ask tier" (`off`, `deny-only`).

## Install

```
/plugin marketplace add <this marketplace>
/plugin install command-guard
```

Nothing to configure. The hook is active from the next session; it costs ~0
always-on context, and prints only when it fires.

## Opting out of a specific command

`.claude/destructive-guard-allow` in the project — one extended regex per line,
matched against the normalised command:

```
# a scratch database this project resets constantly
artisan migrate:fresh --env=testing
```

**The agent cannot write this file.** Writes to it are denied through
`Write`/`Edit` and through a shell redirect or `sed -i` — an opt-out an agent
can grant itself is not an opt-out. Add lines yourself, and narrowly.

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
variable, so the setting core-suite's README recommends for a global install left an
ask running on every `tsconfig.json`, `pyproject.toml` or `hooks.json` write.

### Running headless / in CI

**An `ask` with nobody to answer it is a DENY, not a pause.** In `claude -p`, in a
headless agent, in a subagent, and in any session started with `dontAsk`, there is no
interactive prompt: the host resolves the permission request by refusing it. The
command does not run and the turn continues with a refusal, so every row of the `ask`
tier above — `git reset --hard`, `rm -rf ./dir`, `DELETE FROM`, `kubectl delete pod`,
`terraform apply -auto-approve`, `curl … | sh` — behaves as a hard block there, and so
does config-guard's ask on an existing `tsconfig.json` or `hooks.json`.

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
interrupts, and it is mostly `rm -rf` and `git reset --hard`, which any
general-purpose command-risk check already covers.

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

## What has teeth

Standing markers per the marketplace convention (see
`.claude/skills/authoring-skills/SKILL.md` in the marketplace repository).

| Control | Standing | What actually happens |
|---|---|---|
| deny tier on `Bash` | **gate** — blocks the tool call | the hook returns `permissionDecision: deny`; the command does not run |
| ask tier on `Bash` | **gate**, with a human in it | a permission prompt; the user decides |
| agent writes to the allow-file | **gate** | denied on `Write`/`Edit` and on shell redirects/`sed -i` |
| agent writes to a settings / hooks / lint config file | **gate**, with a human in it — `config-guard.sh` | a permission prompt on an existing listed file; it reads the path, so whether the edit *weakens* anything is **agent-graded** |
| the classification rules themselves | **gate**, tested | 221 assertions in `scripts/__tests__/destructive-guard.test.sh`, run in CI for every plugin harness |
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
