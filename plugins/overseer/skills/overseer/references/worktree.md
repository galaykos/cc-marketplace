# Worktrees — running two milestones at once

A milestone that depends on nothing (or only on a done one) can build in a git worktree
while the main checkout builds another. That is the parallelism `task-runner --tracks`
gives inside one tree, without the two workers fighting one working copy. The
`git-workflow` plugin's `worktree-isolation` skill owns the general pattern; this page is
the checklist that made it work in a Laravel + Vite project, learned the expensive way.

```bash
git worktree add -b <branch> ../<project>-<id> <base-or-dependency-branch>
```

Then, before any worker touches it (**each line cost a failed suite when skipped**):

| Copy or link | Why |
| --- | --- |
| `cp -R vendor ../<wt>/vendor` — a COPY | Composer's PSR-4 map holds absolute paths; a symlinked `vendor/` loads the MAIN tree's `tests/Pest.php` and every test errors ("Call to undefined method …::get()") |
| `ln -s $PWD/node_modules ../<wt>/node_modules` | fine for PHP work and for production builds; a dev server would share the deps cache — do not run one |
| `cp .env ../<wt>/.env` + `touch ../<wt>/database/database.sqlite` + `php artisan migrate` | the worktree is a separate app instance with its own dev database |
| `cp -R public/build ../<wt>/public/build` | gitignored; without it every Inertia page-render test 500s on the Vite manifest, and the worktree's own `npm run build` writes there later |

Record the worktree path in the milestone's brief and in `decisions.md`; a resume must
know where the tree is. Serve it on its own port for the acceptance walk. When the
milestone is accepted and committed: `git worktree remove --force ../<wt>` — the branch
survives, the copies do not.

Workers dispatched into a worktree get its absolute path everywhere and the sentence
"do not touch the main checkout at <path>"; workers in the main tree get "a sibling worker
is active in <path>" so their `git status` is not a surprise. Two workers in ONE worktree
are fine when their file sets are disjoint; say so in both prompts and tell each which
test file the other owns.

Standing: **recorded**. No script checks the copies; the failing suite does.
