# Worktrees — running two milestones at once

A milestone that depends on nothing (or only on a done one) can build in a git worktree
while the main checkout builds another. That is the parallelism `task-runner --tracks`
gives inside one tree, without the two workers fighting one working copy. The
`git-workflow` plugin's `worktree-isolation` skill owns the pattern — location, dependency
install, baseline suite, lifecycle — and this page adds only what a Laravel + Vite project
needs on top, learned the expensive way. Where this page and worktree-isolation differ,
worktree-isolation is right.

Create it as that skill says: `EnterWorktree` when the host offers it, else
`git worktree add -b <branch> .claude/worktrees/<branch> <base-or-dependency-branch>`.
Install dependencies lockfile-faithfully in the worktree — `composer install`, `npm ci` —
never a symlink of `vendor/` (Composer's PSR-4 map holds absolute paths; a symlinked
`vendor/` loads the MAIN tree's `tests/Pest.php` and every test errors with "Call to
undefined method …::get()") and never a blind copy (it drags in the exact drift the
worktree exists to escape). Then, before any worker touches it (**each line cost a failed
suite when skipped**):

| Do | Why |
| --- | --- |
| `cp .env <wt>/.env` + `touch <wt>/database/database.sqlite` + `php artisan migrate` in `<wt>` | the worktree is a separate app instance with its own dev database |
| `npm run build` in `<wt>` (or copy `public/build`, gitignored) | without a Vite manifest every Inertia page-render test 500s |
| no dev server in the worktree | it would share the deps cache with the main tree's; serve the built app on its own port for the acceptance walk |

Record the worktree path in the milestone's brief and in `decisions.md`; a resume must
know where the tree is. When the milestone is accepted and committed:
`git worktree remove <path>` — plain, so a dirty tree refuses and says what it holds;
`--force` only when the discard is a recorded decision. The branch survives the removal.

Workers dispatched into a worktree get its absolute path everywhere and the sentence
"do not touch the main checkout at <path>"; workers in the main tree get "a sibling worker
is active in <path>" so their `git status` is not a surprise. Two workers in ONE worktree
are fine when their file sets are disjoint; say so in both prompts and tell each which
test file the other owns.

Standing: **recorded**. No script checks the install; the failing suite does.
