# The rule set, and where it ends

Rules live in one place — the `rules()` table and the `check_*` functions inside
`hooks/destructive-guard.sh`. This file explains what is in there and, more
importantly, what is not.

## How a command is read

1. **Normalise.** Whitespace collapses, quotes and backslashes are stripped,
   `>` is spaced out. `php artisan "migrate:fresh"` and `php  artisan
   mig'rate:fresh'` become the same string as the plain form. This is why the
   obvious evasions do not work.
2. **Split.** The raw command is cut on `;`, `&&`, `||`, `|`, newlines and
   brackets — quote-aware, so `grep -E "a|rm -rf /"` does not become a fake `rm`
   segment. Each segment is judged on its own.
3. **Exempt readers.** A segment whose leading word only reads (`grep`, `cat`,
   `rg`, `ls`, `git log`, …) is skipped, so searching for `migrate:fresh` is not
   running it. The exemption is dropped for the whole command when output is
   piped into a shell or `xargs` — there the reader's output is the program.
   A wrapper (`sudo`, `doas`, `env`, `nice`, `ionice`, `time`, `exec`) with its
   options, and `VAR=` assignments, are skipped to find the leading word. Only the
   listed value-taking options have their value skipped too (`sudo -u bob`,
   `nice -n 10`; the list is in `lead_word`, the rest are under **Limits**); when
   skipping a value leaves no word, the value itself is read as the command. git's
   global options (`-C <dir>`, `-c k=v`, `--git-dir`, `--work-tree`, `-p`/`-P`,
   `--exec-path=…`, `--config-env`, … every documented option that still runs the
   subcommand, and `--shallow-file`) are stripped first where git leads the segment,
   so `git -C /x push --force` is judged as `git push --force`; inside another
   command's text only `-C`, `-c`, `--git-dir`, `--work-tree`, `--namespace`,
   `--no-pager`, `--no-optional-locks`, `--literal-pathspecs` and `--bare` are.
   `git clean` with `-n`/`--dry-run` is a reader and skipped, unless that `-n` is
   the pattern `-e`/`--exclude` (or any abbreviation, `--e` too) takes, a path after
   `--`, or cancelled by a later `--no-dry-run`. The `-x` deny reads only a
   short-flag cluster holding `x` or `X` as a flag, so `--exclude=foo` and an `-e`
   pattern are not `-x`.
4. **Match.** First hit wins, `deny` before `ask`. Rules containing an uppercase
   letter match case-sensitively; that is the only way `git branch -D` can be
   distinguished from `git branch -d`.
5. **Release.** A regex in the allow-file downgrades any verdict to allow.

## Tiers

**deny** — irreversible loss whose blast radius is not visible in the command.
Nothing in the command line distinguishes a scratch database from production,
so the guard does not try; the user runs it or it does not run.

Families: framework schema resets (Laravel, Rails, Django, Prisma, Sequelize,
TypeORM, Knex, Alembic, Doctrine, Flyway, Liquibase, Supabase, WP-CLI) ·
executed `DROP TABLE/DATABASE/SCHEMA`, `TRUNCATE`, `dropdb`, `FLUSHALL`,
`dropDatabase()`, `deleteMany({})` · `rm -rf` on `/`, `~`, `$HOME`, `.`, a
top-level system directory, or a temp ROOT (`/tmp`, `/private/tmp`, `/var/tmp`,
and their `/*` spellings — those hold every other process's scratch state, not
just this session's) · `rm` of `.env`; `cp`/`mv`/`install`/`ln`/`rsync`/`tee`
or a truncating `>` onto an existing `.env`/`.env.*` git has no clean copy of
(`.env.example` and its kin excluded), or onto a relative one after a `cd`;
`artisan key:generate` over a set `APP_KEY` · `cd` into an absolute path that
does not exist, not created earlier in the command, whose chain ends in `;` · `git clean -fdx`, `push --force`,
`push --delete`, `filter-branch`, `reflog expire`, `gc --prune=now`,
`update-ref -d` · `docker compose down -v`, `docker volume rm/prune`,
`system prune -a|--volumes` · `kubectl delete namespace|pvc|statefulset` ·
`terraform destroy`, `pulumi destroy` · `aws s3 rb|rm --recursive|sync --delete`,
any `aws … delete-*|terminate-*`, `gcloud|az|doctl|pscale|wrangler|flyctl|heroku
… delete|destroy`, `heroku pg:reset`, `gh repo|release|secret delete` ·
`npm unpublish` · `mkfs`, `dd of=/dev/…`, redirects onto a raw device · fork bomb.

**ask** — destructive, commonly intended, and either scoped or recoverable, so
the user is the right decider: `git reset --hard`, `git clean -fd`,
`git branch -D`, `git stash clear/drop`, `checkout .` / `checkout -- .` /
`checkout -f`, `restore .` (not `--staged`), `push --force-with-lease` ·
`crontab -r` · `artisan migrate --force` · `DELETE FROM` in a SQL client
· `rm -rf` on a project-relative path, a deep absolute path, or a path built
from a variable · `kubectl delete <pod>`, `helm uninstall`, `terraform apply
-auto-approve`, `docker system prune`, `docker rm -f` · `npm publish` ·
`curl … | sh` · a `Write` that replaces an existing `.env` git has no copy
of (an `Edit` stays silent) · `find … -delete`, `shred`, `truncate -s 0`, `history -c`,
`chmod -R 777`.

**allow, deliberately** — `rm -rf` on build output (`node_modules`, `vendor`,
`dist`, `build`, `out`, `target`, `coverage`, `.next`, `.nuxt`, `.turbo`,
`.cache`, `__pycache__`, `.venv`, `tmp`, Laravel's `storage/framework/*` and
`bootstrap/cache`). Prompting on those trains the user to click through prompts,
which costs more than it saves.

Also `rm -rf` on a path **inside** the OS temp directory — under `/tmp`,
`/private/tmp`, `/var/tmp`, macOS's `/var/folders/<ab>/<hash>/T/`, or a resolved
`$TMPDIR`/`$TMP`. The system clears that directory on boot and every `mktemp -d`
on the machine lands there, so a scratch dir under it is regenerable by the same
argument `node_modules` is. **Inside** is the whole rule: the roots themselves
stay on the deny tier above, a `..` anywhere in the path drops it back to `ask`
because the prefix then stops proving containment, and `/tmp/*` is read as the
root rather than as a path in it.

SQL text rules only fire when something in the command speaks SQL (a client
binary, an ORM CLI, `tinker`). Otherwise `git commit -m "remove the drop table
step"` reads as executed SQL.

## Limits — read these as the guard's own statement of what it is not

It is **not a sandbox**. It reads one command string at a time and matches
shapes. It cannot see:

- what a **script or Makefile target does** — `./deploy.sh`, `make reset`,
  `npm run db:reset` are opaque; the destructive command inside them never
  reaches the guard;
- a command **assembled across calls** (`C=migrate:fresh` in one, `php artisan
  $C` in the next) — each call is judged alone;
- **application code** that deletes: an ORM `delete_all`, a seeder that
  truncates, a queued job;
- work on a **remote host** through an interactive SSH session, or anything run
  inside a REPL the agent has already opened;
- a **shape nobody has written a rule for** — a new framework's reset command,
  a CLI released next month;
- **which database a connection points at** — `DROP TABLE` through an MCP SQL
  tool is gated the same whether the session is on localhost or production;
- a git subcommand behind a **`-C`/`-c` value holding a space** — once the quotes
  are stripped the value's end cannot be told from the subcommand — or behind
  `-P`, `--exec-path=…` or any other option outside the short list when git does
  not lead the segment (`bash -c "git -P push --force"` passes): a miss;
- **wrapper options outside the list**. An unlisted value-taking option (sudo
  `-R`/`-c`/`-a`, `--chroot`, `--login-class`; ionice `-P`/`-u`; FreeBSD env
  `-L`) or a spaced long form not listed (`ionice --class 3`) has its value read
  as the command: a refusal when the real command is a reader (`sudo -R /x grep
  "rm -rf /" f`), a miss when the value names one (`sudo -R cat rm -rf /`). A
  wrapper named by path other than env (`/usr/bin/sudo`) is read as the command
  itself and never exempted: a refusal. `env -S'…'` or `--split-string=…` with
  the string glued on is not read as a command: a miss.

Three limits are deliberate rather than accidental. `$TMPDIR` is read from the
**hook's own environment**, so `rm -rf $TMPDIR/build` is silent when that
variable is set there and asks when it is not — unset, that command is
`rm -rf /build`, which is no temp path at all. The braced spelling
`${TMPDIR}/build` always asks: the segment splitter cuts on `{` and `}` before
the token is ever assembled, and loosening it to read braces would weaken a
splitter whose job is `{ cmd; }` groups and the fork bomb. Asking is the
fail-closed side of that trade. `rm -rf` on a relative path is
judged by asking git whether the path is restorable, so its verdict depends on
**working-tree state, not just the string** — the same command can be silent in
a clean repo and ask in a dirty one, and it always asks when the command moves
directory. And under `CLAUDE_DESTRUCTIVE_GUARD=deny-only` the ask tier does not
run at all; the hard stops are then the entire guard.

The `.env` and `cd` checks carry the same two limits. A **relative** `cd` target
is never judged — the hook cannot be sure which directory the Bash tool's shell
is in, and a false deny there would cost a turn on every legitimate `cd sub; make`.
And "created earlier in the command" is read loosely: any earlier segment that
names the path counts, so `echo /tmp/x; cd /tmp/x; …` passes. `||` after the
chain counts as handling the failure. `cp -t DIR` and a `key:generate --env=X`
whose `.env.X` lives elsewhere are not resolved.

A silent pass therefore means "no known destructive shape matched", never "this
command is safe". The guard raises the cost of an accident; it does not make
one impossible.

**On the allow-file.** `.claude/destructive-guard-allow` is the user's opt-out,
and the guard blocks the agent from writing it — through `Write`/`Edit`, and
through any Bash command that names it unless every segment of that command is a
pure read: `cat`, `head`, `tail`, `wc`, `grep`/`egrep`/`fgrep`, `stat`, `ls`,
`file`, `diff`, `cmp`, or `git log`/`show`/`diff`/`blame`/`grep`/`ls-files`/
`cat-file` with the subcommand first and no `--output`, `-o`/`-O`, pager,
`--ext-diff`, `--textconv`, `--filters` or `-c` option. The reader's name must
be typed bare — a quote or backslash in it denies. A redirect may only target
`/dev/null` or a descriptor (`2>/dev/null`, `>/dev/null 2>&1`), with nothing
quoted or escaped beside the target. A backtick, `$`, `~` or `{}` anywhere in
the command denies it, and so do an unquoted `#` or parenthesis, a leading env
assignment (`LC_ALL=C grep …`), and a chained or piped step that is not itself a
pure read (`|| echo none`, `| xargs cp`). The list is closed on purpose, so
inspecting the file with `awk`, `sed -n`, `find`, `jq` or `less` is blocked —
each can write or run a program; use `cat` or `grep`.
**Standing: gate** — the hook denies; pinned by the harness section
`== allow-file: pure readers`.
That closes the obvious loop, not every loop: a command that builds the path from
a variable or a glob, a script that writes the file, or any program git config
names (a diff driver, textconv, clean filter, pager, `core.fsmonitor`,
`gpg.program` via `--show-signature`), set before the command runs, would not be
recognised. Nor, on the write path, would an MCP write tool other than
`*apply_patch` and `*create_new_file`, `NotebookEdit`'s `notebook_path`, or a
non-ASCII spelling the filesystem folds to the name: the Write/Edit match is
case-insensitive for ASCII letters only. The real protection is that a denied
command is visible to the user, not that the bypass is impossible.

**On layering.** This guard is one control, not the control. Backups, a
non-production database URL in the development environment, and least-privilege
database credentials each fail differently, which is the point of having more
than one.

## Tuning it

```bash
# see the verdict without running anything
bash "${CLAUDE_PLUGIN_ROOT}/hooks/destructive-guard.sh" --check 'php artisan migrate:fresh'
```

Project opt-out — one extended regex per line, matched unanchored against the whole normalised, lowercased
command, trailing comment included, `#` comments allowed:

```
# .claude/destructive-guard-allow
^php artisan migrate:fresh --env=testing$
^docker compose down -v$
```

A line here is a standing decision that the command is safe **in this project,
forever**. Write it narrowly. `~/.claude/destructive-guard-allow` does the same
for every project, which is almost never what anyone wants.

Environment (set in the user's shell, before starting the session — a command
string cannot reach it): `CLAUDE_DESTRUCTIVE_GUARD=ask` turns every deny into a
prompt, `=deny-only` keeps every hard stop and drops the ask tier, `=off` disables
the guard entirely. The plugin's other hook — `config-guard.sh`, an `ask` on a write
to an existing settings / `hooks.json` / hook-script / plugin-manifest / lint-config
file — is silenced by `CC_CONFIG_GUARD=off` and by either of the two values above
that mean "no ask tier" (`off`, `deny-only`).
