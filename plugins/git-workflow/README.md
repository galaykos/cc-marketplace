# git-workflow

Git workflow discipline. Each feature branch gets an isolated worktree, in a location
proven to be git-ignored. Deps are installed and the baseline suite runs before any
change. Development branches end with a structured finish: verify, present options,
merge, PR or park, then clean up. Review-exchange rigor applies on both sides of a code
review. A guard keeps AI attribution out of git history. A check asks before
`gh pr merge` while the pull request's CI is not green.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install git-workflow@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/git-workflow:finish [branch] [--to pr\|merge\|keep]` | Verify the full suite, show branch state evidence (diffstat, ahead/behind, commits), ask PR / keep / discard (plus merge-locally only when the base is not the default branch — the default branch is reached via PR only), execute the choice including worktree and branch cleanup; `--to` (passed by task-runner's run handoff) answers only the destination question — every check still runs, and it never discards or merges onto the default branch |
| `/git-workflow:clean-gone [--dry-run]` | Fetch with prune, list every local branch whose upstream is `[gone]` with its worktree, skip the current branch and any dirty worktree, ask once, then remove worktrees and `-D` the branches — the sweep for PRs merged and deleted somewhere other than `/git-workflow:finish` |

## Example

```bash
/git-workflow:finish                            # finish the current branch
/git-workflow:finish feature/orders-csv-export  # finish a named branch
```

The finish command never assumes a destination: a red suite stops it cold, a
green one gets state evidence and an explicit choice. The default branch is
PR-only — "merge locally" is offered only when the base is a non-default branch,
and committing straight onto the default branch routes you to a branch + PR
instead. Merges re-run the full suite on the merged result before any branch or
worktree is deleted; discards require typing the branch name back; headless runs
report options and touch nothing.

When a task-runner run already passed the same suite command at the branch's head on this
exact tree, finish does not run it again, says `Reused: suite passed at <head7> (<cmd>)` and
shows the receipt log as the suite output. `scripts/receipt-fresh.sh --name suite --root <worktree>
--cmd "<suite command>"` decides from task-runner's `.claude/task-runner/receipt.json`: another
commit or command, a changed, staged or new file (outside `.claude/` state and `taskmaster-docs/`;
new `.claude/skills|agents|commands|hooks` files, `.claude/settings.json` and root `.env*` files
count), a failed run, a log task-runner did not write or that does not end `exit 0`, or an
unreadable receipt reads `stale:`, and the suite runs. The review passes and the post-merge suite
always run. Misses: skip-worktree/assume-unchanged files, other gitignored files, untracked files
inside submodules, nested non-submodule repos, a receipt written by hand.

Credit: in `branch-completion`, the no-template PR body's before/after evidence and
reversibility line adapt rules from mattpocock/skills v1.2.3 (MIT, © 2026 Matt Pocock),
and the merge protocol's conflict rule (resolve from each side's intent, never `--abort`
to dodge a hunk) comes from an earlier (2026-09-02) read of mattpocock/skills. Both are
rewritten here rather than copied.

## No AI attribution in git history

A `PreToolUse` hook, `hooks/no-ai-trailer.sh`, denies any history-writing git or
`gh` command whose message carries a `Co-Authored-By: Claude …` trailer or a
"Generated with Claude Code" line — `git commit`, `merge`, `tag`, `notes`,
`rebase`, `cherry-pick`, `am`, and `gh pr` / `gh release` / `gh repo`
`create|merge|edit|comment` — and any `Write`/`Edit` that plants the same text
into a git message file (`COMMIT_EDITMSG`, `MERGE_MSG`, `SQUASH_MSG`,
`TAG_EDITMSG`, anything under `.git/`). It matches at a command position, so a
wrapper (`sudo`, `bash -c`, `VAR=1 …`, an absolute path, any `git` global option)
does not get past it. The deny reason tells the model to drop the lines and run
the same command again.

Why a hook and not a sentence: the host setting `attribution.commit: ""` in
`~/.claude/settings.json` switches off the host's own trailer, and nothing else.
So does `"attribution": false` (Claude Code 2.1.281+), which hides commit and PR
attribution together — but a CLI older than 2.1.281 skips the whole settings file
that holds it, plugins enabled there included (2.1.280 listed this one `disabled`,
measured 2026-10-15), so keep the object form in a file shared across versions.
The model still wrote the trailer from habit (observed on Claude Code 2.1.266,
2026-09-09, setting present since 2026-09-03), and a skill saying "never add AI
attribution" did not stop it. A rule nothing reads back is `recorded`; this is
the reader.

Nothing to configure. To disable it for a session that WANTS the trailer, set
`CLAUDE_AI_TRAILER=allow` in the hook's environment (Claude Code: the `env`
block of a settings file). Check a command by hand:

```bash
bash hooks/no-ai-trailer.sh --check 'git commit -m "x

Co-Authored-By: Claude <noreply@anthropic.com>"'   # exit 2 = deny
```

## No merge while CI is still out

A second `PreToolUse` hook, `hooks/merge-checks.sh`, runs `gh pr checks` before a
`gh pr merge` and asks you to confirm when any check is pending, failing or cancelled,
naming them. It exists because a session merged a pull request while CI was still
running, CI then failed on the merged commit, and the user had asked to wait. It asks
rather than refuses: a known-flaky or non-required check is a legitimate merge, and only
you know which.

- **What it reads.** `gh pr merge` at a command position, with the PR from its first
  argument (number, `#n`, URL or branch; never a redirection or a quoted `--body` value)
  or the current branch, and `-R/--repo` or a `GH_REPO=`/`GH_HOST=` prefix passed
  through; `gh` runs in the session's working directory. `--auto` (GitHub then waits for
  the required checks itself), `--disable-auto` and `--help` pass silently.
- **Fail-open.** No `gh`, not logged in, no network, no PR, no checks reported, or no
  answer within 5 s: silent, and the merge runs. It is the one hook here that makes a
  network call, and only on a `gh pr merge`; every other Bash call exits before reading
  anything.
- **Not caught.** A PR held in a variable (`gh pr merge "$n"`), any merge after the first
  in one command, a merge from the web UI or the API, and non-required checks that
  `--auto` does not wait for. A `cd` inside the command does not move where `gh` runs,
  and an `export GH_REPO=…` before the merge is not read; the ask names the PR, so a
  wrong one shows.
- **Off switch.** `CC_MERGE_CHECKS=off`, or the `cc_merge_checks` option under `/config`.

## What has teeth

Standing markers per the marketplace convention (see
`.claude/skills/authoring-skills/SKILL.md` in the marketplace repository).

| Control | Standing | What actually happens |
|---|---|---|
| AI trailer in a commit/merge/tag/notes/rebase/cherry-pick/am or `gh` pr/release/repo command | **gate** — blocks the tool call | `permissionDecision: deny`; the command does not run |
| AI trailer written into a git message file | **gate** | denied on `Write`/`Edit` whose path is a git message file |
| the matching rules | **gate**, tested | `scripts/__tests__/no-ai-trailer.test.sh`, run in CI with every plugin harness (recount the assertions there; none is quoted here) |
| a human `Co-authored-by:` trailer | **allowed by design** | only trailers naming Claude or Anthropic match |
| `gh pr merge` while a check is pending, failing or cancelled | **gate** — asks, never blocks | `permissionDecision: ask` naming the checks; `scripts/__tests__/merge-checks.test.sh` drives it with a stub `gh` (verdicts, wrappers, silent shapes, fail-open, the switch) |
| a merge whose PR is a variable, a second merge in one command, a merge outside `gh pr merge` | **unenforceable** | the PR cannot be read from the command, or no matched tool call carries it |
| `git commit -F <pre-existing file>`, a repo `prepare-commit-msg` hook, `git config trailer.*`, a commit outside the session | **unenforceable** | the message never crosses a matched tool call; silence means "no known shape matched", not "history is clean" |
| finish / clean-gone / worktree protocols | **recorded** | prose the model follows; nothing reads it back |
| a suite pass reused by finish | **gate** for the freshness rule; **recorded** for the finish step that calls it | `scripts/__tests__/receipt-fresh.test.sh` drives the reader; a change the Misses line above names still reads fresh |

Fail-open, deliberately, both hooks: missing `jq`, unparseable input, any internal error —
the hook stays silent, exits 0, and the command proceeds. Each harness asserts it.

## Mods (Claude Code ≥ 2.1.291)

Since 0.11.0 the plugin also ships a hooks module, `hooks/suggest.ts`, listed under
`modules` in `hooks/hooks.json` beside the classic trailer guard, which fires with or
without it.

- **Finish suggestion.** When a main-loop turn ends and task-runner's
  `.claude/task-runner/gate-pass.json` (at the git toplevel) records a green completion
  gate whose `head` is the current `HEAD` — every card done or parked, or no card counts
  at all (a plain run) — on a branch that is not the default branch (`origin/HEAD`, else
  `main` or `master`) and whose upstream (`@{u}`) is not already at that head, the prompt
  box offers `/git-workflow:finish` as a Tab-to-accept suggestion. It never runs the
  command; nothing happens until you accept and press Enter.
- **Once per gate head per session.** Counted only when Claude Code reports the suggestion
  shown; one not shown is offered again at the next turn end while the gate still matches
  `HEAD`. Nothing is offered while a phase sentinel is live: a `.claude/cc-phase.json`
  under two hours old that this session holds or that names no session.
- **What a finished branch looks like to it.** A pushed upstream at the gate head is read as
  finish's PR path having run. A branch finish kept open (never pushed), or merged locally
  into a non-default base by fast-forward, is still offered once per session; a branch
  pushed by hand without a PR is silenced as if finished.
- **Off switch.** `CC_SUGGEST=off` silences this marketplace's next-step suggestions
  (task-runner, code-review, git-workflow, debugging, testing); there is no
  `/config` option.
  Another plugin's suggestion can take the one slot after this one, a suggestion shown and
  then replaced counts as shown, and Claude Code's own suggestion is not suppressed.
- **Counts** (since 0.13.0). Each time the prompt box reports this suggestion shown, and
  whether your next prompt then sent the suggested command (`accepted`) or something else
  (`passed`), one is added to `suggest.finish.shown`, `.accepted` or `.passed` in this
  plugin's own `$.store` (key `outcomes`): counts only, never the text, on this machine only.
  The marketplace repository's `scripts/mod-outcomes.sh` prints them. **Gate** for the
  counting (the shared kit's tests); what a count says about the suggestion is **recorded**.
- **CLI floor.** With mods off in the host or on a CLI below 2.1.287 no module loads; on
  2.1.287-2.1.290 its turn-end hook passes through. It registers no `tool.call` hook when
  it runs (on CLI 2.1.291, `claude plugin validate --strict` still lists the shared kit's
  conditional one as `tool.call{tool=?}`), so 2.1.287's bug with plugin `tool.call` hooks
  in worktree subagents should not reach it — not measured on 2.1.287; if it does,
  upgrade the CLI or turn mods off.
- **What it trusts.** The gate record, not the tree: edits left uncommitted after a green
  gate do not move `HEAD`, so the suggestion still fires.

Standing: **gate** — `tests/suggest.test.ts` runs under `claude plugin test` in CI (the
marketplace repository's `scripts/mod-tests.sh`), so a regression in a tested case fails
the build; the sentinel's two-hour and no-session clauses rest on the shared kit's own
tests there. Untested here: the real prompt box (the test kit answers whether a suggestion
was shown), a subagent's turn end, and an unparseable gate record.

## Pairs well with

- **taskmaster** / **task-runner** — task-runner's `--tracks` runs milestones in
  worktrees; this plugin's finish protocol closes the run out
- **code-architecture** — its work-verification discipline backs every gate in
  this plugin
