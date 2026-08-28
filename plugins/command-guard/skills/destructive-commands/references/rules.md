# The rule set, and where it ends

Rules live in one place — the `rules()` table and the two special cases inside
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
just this session's) · `rm` of `.env` · `git clean -fdx`, `push --force`,
`push --delete`, `filter-branch`, `reflog expire`, `gc --prune=now`,
`update-ref -d` · `docker compose down -v`, `docker volume rm/prune`,
`system prune -a|--volumes` · `kubectl delete namespace|pvc|statefulset` ·
`terraform destroy`, `pulumi destroy` · `aws s3 rb|rm --recursive|sync --delete`,
any `aws … delete-*|terminate-*`, `gcloud|az|doctl|pscale|wrangler|flyctl|heroku
… delete|destroy`, `heroku pg:reset`, `gh repo|release|secret delete` ·
`npm unpublish` · `mkfs`, `dd of=/dev/…`, redirects onto a raw device · fork bomb.

**ask** — destructive, commonly intended, and either scoped or recoverable, so
the user is the right decider: `git reset --hard`, `git clean -fd`,
`git branch -D`, `git stash clear/drop`, `checkout -- .`, `push
--force-with-lease` · `artisan migrate --force` · `DELETE FROM` in a SQL client
· `rm -rf` on a project-relative path, a deep absolute path, or a path built
from a variable · `kubectl delete <pod>`, `helm uninstall`, `terraform apply
-auto-approve`, `docker system prune`, `docker rm -f` · `npm publish` ·
`curl … | sh` · `find … -delete`, `shred`, `truncate -s 0`, `history -c`,
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
  tool is gated the same whether the session is on localhost or production.

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

A silent pass therefore means "no known destructive shape matched", never "this
command is safe". The guard raises the cost of an accident; it does not make
one impossible.

**On the allow-file.** `.claude/destructive-guard-allow` is the user's opt-out,
and the guard blocks the agent from writing it — through `Write`/`Edit` and
through a shell redirect or `sed -i`. That closes the obvious loop, not every
loop: a command that builds the path from a variable, or a script that writes
the file, would not be recognised. The real protection is that a denied command
is visible to the user, not that the bypass is impossible.

**On layering.** This guard is one control, not the control. Backups, a
non-production database URL in the development environment, and least-privilege
database credentials each fail differently, which is the point of having more
than one.

## Tuning it

```bash
# see the verdict without running anything
bash "${CLAUDE_PLUGIN_ROOT}/hooks/destructive-guard.sh" --check 'php artisan migrate:fresh'
```

Project opt-out — one extended regex per line, matched against the normalised
command, `#` comments allowed:

```
# .claude/destructive-guard-allow
artisan migrate:fresh --env=testing
^docker compose down -v$
```

A line here is a standing decision that the command is safe **in this project,
forever**. Write it narrowly. `~/.claude/destructive-guard-allow` does the same
for every project, which is almost never what anyone wants.

Environment (set in the user's shell, before starting the session — a command
string cannot reach it): `CLAUDE_DESTRUCTIVE_GUARD=ask` turns every deny into a
prompt, `=off` disables the guard entirely.
