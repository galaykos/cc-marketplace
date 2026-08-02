---
name: destructive-commands
description: Use before running any shell command that can destroy data — database resets and migrations, rm -rf, git history rewrites, docker volume removal, cloud or cluster deletes — and use when command-guard has denied a command. Gives the non-destructive equivalent for each family, and the protocol for when the destructive command is genuinely the right one.
---

# Destructive commands

A destructive command is one whose effect cannot be undone from inside the
session: the rows are gone, the volume is gone, the remote history is
rewritten. The cost is asymmetric and the shapes are few, so the rule is
mechanical rather than a judgement call.

**Never run a destructive command on your own initiative.** Not to unstick a
migration, not to get a clean slate, not because the schema looks wrong. The
data belongs to someone who is not in this session.

## The substitution table

Reach for the right column. The left column is a request to make of the user,
never an action to take.

| Instead of | Run | Why |
|---|---|---|
| `php artisan migrate:fresh` / `migrate:refresh` / `db:wipe` | `php artisan migrate` | applies pending migrations, keeps rows |
| `rails db:reset` / `db:drop` / `rake db:schema:load` | `rails db:migrate` | same |
| `python manage.py flush` | a targeted queryset `.delete()` | scoped, reviewable |
| `prisma migrate reset` | `prisma migrate dev` (local), `prisma migrate deploy` (CI) | no drop |
| `alembic downgrade base` | `alembic downgrade <rev>` | one step, named |
| `DROP TABLE` / `TRUNCATE` | `DELETE … WHERE …` inside a transaction | reversible before commit |
| `DELETE FROM t` (no WHERE) | `SELECT count(*) FROM t WHERE …` first | see the blast radius |
| `rm -rf <dir>` | `rm -rf` on build output only (`node_modules`, `dist`, `.next`, `vendor`) | regenerable |
| `git reset --hard` | `git stash` | recoverable |
| `git clean -fdx` | `git clean -fd` | `-x` also deletes `.env` and local config |
| `git push --force` | `git push --force-with-lease`, on your own branch | refuses if someone else pushed |
| `docker compose down -v` | `docker compose down` | `-v` removes the volume holding the database |
| `kubectl delete <stateful thing>` | `kubectl scale --replicas=0`, or delete one pod | storage survives |
| `terraform destroy` | `terraform plan -destroy`, read it, hand it over | nothing applied |
| any `aws|gcloud|az … delete` | the provider console, by the user | the confirmation names the resource |

## When a schema reset is genuinely needed

Say so and stop. A useful handover names four things:

1. the exact command, in full, including flags and the target;
2. what it destroys, in the user's terms ("every row in the local `app` database");
3. why nothing non-destructive gets there (which specific migration is stuck, what it errors with);
4. what you will do after they run it.

Then wait. Suggesting the command is your job; running it is theirs.

## When command-guard denies a command

The deny is a decision, not an obstacle:

- **Do not rephrase it.** Different quoting, `bash -c`, `eval`, a heredoc, a
  script file, splitting it across two calls — the guard reads all of those, and
  routing around a safety gate is never the task you were given.
- **Do not disable the guard**, edit its allow-file, or suggest the user do
  either as a first move. The allow-file is theirs; propose a line for it only
  after they have asked twice for the same blocked command.
- **Re-read the goal.** A denied command is usually a shortcut to a goal that
  has a longer, safe route. Take the longer route.
- If the goal genuinely requires it, use the handover above.

`/command-guard:check '<command>'` classifies a command without running it —
useful before proposing one to the user.

## What the guard does not catch

Say so out loud rather than treating a silent pass as approval. It reads the
command string only, so it cannot see: what a script file does when you run it,
what a Makefile target or an npm script expands to, a command assembled from
variables set in an earlier call, an ORM `delete_all` inside application code,
or anything running on a remote host through an interactive session. A quiet
guard means "no known shape matched", never "this is safe".

Full rule list and the guard's own limits: `references/rules.md`.
