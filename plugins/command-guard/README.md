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
| `ask` | destructive but scoped and commonly intended — `git reset --hard`, `git clean -fd`, `rm -rf ./some-dir`, `DELETE FROM`, `kubectl delete pod`, `terraform apply -auto-approve`, `curl … \| sh` | the user gets a permission prompt naming what is lost |
| `allow` | everything else, including `rm -rf node_modules`, `git commit -m "drop the table step"`, `grep -r migrate:fresh .` | silent; normal permissions apply |

It reads through the usual disguises — quotes (`artisan "migrate:fresh"`),
wrappers (`bash -c`, `eval`, `docker compose exec`), extra whitespace, `&&`
chains, heredocs — and skips read-only commands, so searching for a string is
never confused with running it. It also covers MCP tools that shell out or run
SQL, which are the same hole under a different tool name.

Full rule list, the reading algorithm, and the guard's stated limits:
[`skills/destructive-commands/references/rules.md`](skills/destructive-commands/references/rules.md).

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
| `CLAUDE_DESTRUCTIVE_GUARD=ask` | every deny becomes a prompt instead of a block |
| `CLAUDE_DESTRUCTIVE_GUARD=off` | guard disabled |

## Checking a command without running it

```
/command-guard:check "php artisan migrate:fresh"
```

or directly, which is also how the test harness drives it:

```bash
bash hooks/destructive-guard.sh --check 'docker compose down -v'   # exit 2 = deny
```

## What has teeth

Standing markers per the marketplace convention (see the `claude-authoring`
plugin's `authoring-skills` skill).

| Control | Standing | What actually happens |
|---|---|---|
| deny tier on `Bash` | **gate** — blocks the tool call | the hook returns `permissionDecision: deny`; the command does not run |
| ask tier on `Bash` | **gate**, with a human in it | a permission prompt; the user decides |
| agent writes to the allow-file | **gate** | denied on `Write`/`Edit` and on shell redirects/`sed -i` |
| the classification rules themselves | **gate**, tested | 128 assertions in `scripts/__tests__/destructive-guard.test.sh`, run in CI for every plugin harness |
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
