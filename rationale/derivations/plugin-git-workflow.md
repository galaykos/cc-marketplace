# git-workflow hooks: the comment text moved out of the code (2026-10-28)

The text below was moved verbatim on 2026-10-28 from the files named in the `##` headings, with only each comment's `# ` leader (and the indentation before it) removed; the lines each file kept are not repeated here. A pointer by name was left in each file, `# Why, limits, history: rationale/derivations/plugin-git-workflow.md § <heading>`. no-ai-trailer.sh's first comment line naming `CLAUDE_AI_TRAILER=` is the sentence `scripts/generate.sh` copies into the README's off-switch table, so the kept header still carries it word for word. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

## plugins/git-workflow/hooks/merge-checks.sh

### Header

```text
Absolute-path shebang: the fail-open guarantee must hold under a broken PATH.

PreToolUse readiness check on `gh pr merge`. Before the merge runs it reads the pull
request's checks (`gh pr checks`, killed after CHECKS_TIMEOUT seconds) and returns
permissionDecision "ask" when any check is pending, failing or cancelled, naming those
checks and the off-switch. All green, no checks reported, or any error: silent, and the
merge proceeds.

The failure it exists for: a session ran `gh pr merge` while CI was still running, CI
then failed on the merged commit, and the user had asked to wait for every check first.
Nothing in the finish protocol reads CI state at the moment of the merge; the command
is the one place that moment is visible.

Tiering (ask, never deny): a pending or red check is usually a reason to wait, but a
known-flaky or non-required check is a legitimate merge, and only the user knows which.
The ask names the checks so that call takes one glance. In a headless run nobody answers
an ask, so the merge does not happen there, which is the outcome this hook wants.

A NETWORK READ IN A HOOK, against the house rule of no network calls: CI state lives only
on GitHub, with no local stand-in. It is bounded (one `gh pr checks` per command, killed
at CHECKS_TIMEOUT, well inside the hooks.json timeout), and every outcome that is not a
parsed pending/failing row is silence: no gh, not logged in, no network, a timeout, no PR
for the branch, no checks reported.

WHAT IT READS: `gh pr merge` at a command position (after `;` `&&` `|` `(` `$(` or a
wrapper such as `sudo`, `env`, `bash -c "…"`; the prefix list is no-ai-trailer.sh's),
outside heredoc bodies (cc_strip_heredoc_bodies all: a body fed to `bash <<EOF` is not read,
and every line after a `<<` it cannot place, such as one inside quotes or `${ }`, is read, so a
`gh pr merge` line in a multi-line quoted string after one is read as a merge). The PR is
the first positional argument (number, `#n`, URL or branch; never a redirection or a
quoted value), else the current branch's; `-R/--repo` and a `GH_REPO=`/`GH_HOST=` prefix
are passed through; gh runs in the payload's cwd.
Silent on purpose: `--help`, `--disable-auto`, and `--auto`, which hands the wait to
GitHub (and is what the ask suggests).

WHAT IT DOES NOT CATCH, stated: a PR or repo held in a variable or a substitution
(`gh pr merge "$n"`); any `gh pr merge` after the first in one command; flags between
`pr` and `merge`; a merge through the API, the web UI or a push to the base branch;
non-required checks that `--auto` does not wait for. A `cd` inside the command does not
move where gh runs, so `cd ../other && gh pr merge 3` reads PR 3 of the session's repo,
and an `export GH_REPO=…` before it is not read; the ask names the PR, so a wrong one shows.

CC_MERGE_CHECKS=off disables it for the session, and the ask message says so.
CC_MERGE_CHECKS unset: the /config option cc_merge_checks decides.
Fail-open: missing jq or gh, unparseable input, any internal error allows the merge.
```

### MERGE_RE

```text
Command position, the same anchor and wrapper tokens as no-ai-trailer.sh's GIT_WRITE_RE,
so the two guards agree on what runs. The tail stops at the next command delimiter
outside a quoted span. A span counts only where a word, a `=` or a one-letter flag opens
it; any other quote closes a wrapper's string (`bash -c "gh pr merge 12"`) and ends it.
```

### parse_merge

```text
Sets sel and repo from the words after `gh pr merge`, gh_repo and gh_host from a
GH_REPO=/GH_HOST= prefix. Returns 1 when the call passes silently: help, --auto,
--disable-auto, or a PR, repo or host this cannot resolve.
```

### run_checks

```text
gh pr checks in <dir>, stdout only, killed after CHECKS_TIMEOUT seconds (status 1).
A polling watchdog rather than timeout(1), which macOS does not ship.
```

### names

```text
Names of the checks whose bucket (gh's non-TTY second column) matches, comma-joined,
at most MAX_NAMES of them.
```

## plugins/git-workflow/hooks/no-ai-trailer.sh

### Header

```text
Absolute-path shebang: the fail-open guarantee must hold under a broken PATH.

PreToolUse guard against AI ATTRIBUTION in git history. It denies a `git
commit` / `git merge` / `git tag` / `gh pr create|merge` / `gh release` whose
message carries a `Co-Authored-By: Claude …` trailer or a "Generated with
Claude Code" line, and a Write/Edit that plants the same text into a git
message file (`COMMIT_EDITMSG`, `MERGE_MSG`, anything under `.git/`).

The failure it exists for: the host setting `attribution.commit: ""` in
~/.claude/settings.json — or `"attribution": false` (2.1.281+; 2.1.280 skips the
whole file that holds it, this plugin's enable included) — is honoured by the host's OWN trailer
injection and by nothing else. The model still writes the trailer from habit — observed on
Claude Code 2.1.266 on 2026-09-09 with the setting present since 2026-09-03 —
and prose in a skill ("never add AI attribution", the since-dropped terse-commit) did not stop
it. A rule with no reader is recorded, not enforced; this is the reader.

Tiering (deny, never ask): the trailer is never what the user wants when they
installed this, the fix is mechanical (drop the lines, re-run), and an `ask`
would hand the human the same click the setting was supposed to remove.

What it does NOT catch, stated: a message read from a file the model wrote
with a tool this hook is not matched on, `git commit -F` on a pre-existing
file, a trailer added by `git config trailer.*` or a `prepare-commit-msg` hook
in the repo, a rewrite via `git filter-repo`, and any commit made outside the
session. Silence means "no known shape matched", not "history is clean".

The one false deny it keeps on purpose: a commit whose own PROSE quotes a full
trailer line verbatim, address included, is denied. That text really does enter
git history, and a later `git log | grep` audit would flag it either way. Paraphrase
it, or use CLAUDE_AI_TRAILER=allow for that one command. Measured identical on the
pre-2026-09-15 guard, so it is inherent to matching text and not a new cost.

CLAUDE_AI_TRAILER, read from the hook's own environment:
  unset   deny, as above
  allow   disabled — for a user who WANTS the trailer (then also clear the
          host setting; this hook and that setting agree by default)

Fail-open by construction: missing jq, unparseable input, any internal error
allows the call. A guard that breaks the session gets uninstalled.

CLI mode for tests and manual checks:
  no-ai-trailer.sh --check '<command>'   exit 0 allow, exit 2 deny
```

### LC_ALL

```text
grep reads one line at a time, so `.*` never crosses a newline here.
LC_ALL=C: the emoji is matched as a byte sequence, locale-independent.
```

### GIT_WRITE_RE

```text
The binary may be spelled with a path. `/usr/bin/git commit`, `./bin/git commit`,
`~/bin/git commit` and `/opt/homebrew/bin/gh pr create` are all ordinary invocations
and all bypassed the command-position anchor, which lists no `/`. The old loose prefix
caught them by accident (a `/` satisfies `[^a-z0-9_-]`), so tightening the anchor
turned the guard OFF for the most obvious wrapper there is — spelling out the path.
The optional prefix must end in `/`, so `/usr/share/digit commit` still does not match.
Between `git` and the write verb, ANY global option may appear — not just -c/-C.
`git --git-dir=… commit`, `git --work-tree … commit`, `git --no-pager commit` and
`git -P commit` all reach a real commit, and every one of them was ALLOWED by this
guard until 2026-09-15. It was never caught because the old loose `[^a-z0-9_-]`
prefix matched the `.git` inside `--git-dir=/repo/.git commit` — the right verdict
for the wrong reason, which survived only while the path happened to end in `.git`.
The option run therefore accepts a dash token, a path-like token (a separated value
for --git-dir/--work-tree/-C) and an assignment token (the value of -c). It does NOT
accept a bare word, so `git log | grep commit` stays allowed. Measured both
directions by fixture in scripts/__tests__/no-ai-trailer.test.sh — no count is
recorded here on purpose. The one that used to sit here was copied from a throwaway
corpus instead of read off the harness, and a second copy of any total is the
stale-number failure this repo keeps paying for: the harness's figure changes with
every fixture added, and only the harness can state it. Run it and read its total.
```

### classify_command: the command position

```text
THE VERB MUST BE AT A COMMAND POSITION. The prefix used to be `[^a-z0-9_-]`, which
a plain space satisfies — so any command whose TEXT merely mentioned both the
trailer and the words "git commit" was denied though no git ran: a heredoc writing
a JSON fixture, a grep for the trailer, an audit script quoting it. Measured
2026-09-15, when this guard denied an audit agent for building its own payload.

ONE OF THOSE THREE IS ONLY HALF FIXED, and saying so is cheaper than pretending:
`(` is a command delimiter, so a `(` ANYWHERE in the text — including inside a
quoted string — restarts command position. `echo "see (git commit -m '<trailer>')"`
is still denied. The tempting fix, dropping `"`/`'` from the prefix tokens, was
tested on 2026-09-15 and is wrong twice over: it opens `bash -c "git commit …"`,
`sh -c`, and `eval "…"` as bypasses, and it does not even clear the false positive,
because the `(` delimiter matches with or without a quote token. Telling the truth
about a residual beats trading a DENY guard's teeth for it. Paraphrase the line,
or set CLAUDE_AI_TRAILER=allow for that one command.
Newlines separate commands too, so normalise them into the delimiter class. The
keyword/assignment prefix is not decoration: without it `if git commit`,
`; do git commit`, `sudo git commit` and `VAR=1 git commit` all escaped, which
the old loose prefix did catch. Each of those four shapes has its own fixture —
the claim said "verified by fixture" for eight days before any of them did.
```

## plugins/git-workflow/scripts/gone-branches.sh

Written with the script on 2026-10-31, not moved from it. Standing: `recorded`.

What shipped that made it exist: `/git-workflow:clean-gone` (through 0.13.6) ran `git
branch -D` on every local branch whose upstream read `[gone]`, on the reasoning that a gone
upstream meant the merge happened remotely. It does not. The remote branch can be deleted
unmerged (a closed PR, a stale-branch sweep, a teammate's cleanup), and a commit made locally
after the last push was never on the remote, whatever happened to the PR. Only dirty
worktrees were excluded. The idea that `[gone]` proves deletion and not landing comes from
Trail of Bits' git-cleanup skill (CC-BY-SA); the idea is used here, none of its text.

Why three tests and not one. `merge-base --is-ancestor` sees a merge commit and a
fast-forward. A rebase merge rewrites every commit, so ancestry fails, but each patch-id
survives: `git cherry <default> <branch>` printing no `+` line is that case. A squash merge
folds several commits into one, so no single branch commit's patch-id matches. The probe
builds one throwaway commit holding the branch's whole tree on top of its merge base (`git
commit-tree`, which writes an object and no ref, so `git gc` prunes it) and asks `git
cherry` whether that one patch is on the default branch. The harness asserts `git cherry`
alone calls all three squashed commits unique, so the probe is what classifies them.

Traps the code guards: a branch whose tree equals its merge base would yield an empty patch,
and an empty patch shares its patch-id with every empty commit on the default branch, so the
probe refuses it. The probe commit carries its own author and committer through the
environment, because `user.useConfigOnly` with no identity makes `git commit-tree` fail and
the squash class would silently vanish; the harness runs the script under exactly that
config. On git 2.53 `git commit-tree` ignores `commit.gpgSign` (checked with `GIT_TRACE`), so
the probe passes no signing flag.

Default branch: `origin/HEAD` first (a fresh fetch moves it), else local `main`, else local
`master`; the first output line says which. A local default that was never pulled reads a
remotely merged branch as unmerged, which the harness asserts as the safe direction.

Limits, each reading unmerged rather than merged: a branch merged into a non-default branch
(a stacked PR); a squash edited on the remote (conflict resolution, review commits pushed by
someone else and never fetched); a default branch on a remote not named `origin`; a branch
that merged the default branch in and was then rebase-merged (the per-commit test is off for
it, below).

Merge commits on the branch: `git cherry` skips them, so content only a merge commit carries
(a conflict resolution, a file added while merging) went uncompared, and a branch whose plain
commits had all landed read content-merged. Found by a probe while writing the script
(2026-10-31) and pinned by the harness's `evil` branch, red before the guard: the per-commit
test now runs only when the branch has no merge commit of its own, and the squash probe,
which compares the whole tree, decides the rest.
