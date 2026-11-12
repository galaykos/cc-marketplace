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

### Segment scope (0.14.0, 2026-11-08)

Written with the change, not moved from the code. Standing: `recorded`.

What the retro said: `rationale/session-retro-2026-11-05.md` issue 22, "fired on a heredoc append to
`findings.md` (not a commit); blocked heredoc `commit -F -` where no trailer was visible", sessions
`f5ffe3b6`, `8072a87a`, `395b622e`. What could be checked of it: the miners' extract
(`/tmp/harvest-2026-11-05/chunks/`) clips every Bash input at 300 characters, and the full transcripts
were not read, because the auto-mode classifier refused this worker reading another project's
transcripts. In `f5ffe3b6` (chunk 46, 11-05 11:26:16) the denied call opens with
`cat >> .claude/overseer/milestones/m5/findings.md <<'EOF'`. The retry 6 s later opens the same way and
passes. The recap at 11:22:26 says card 01 was not committed yet, and the one at 11:26:38 says it was
committed at 18d9b26, so both calls also carried a `git commit` after the append. Whether the denied
call's trailer sat in that commit (a true positive) or in the append (a false positive) is not visible.
`8072a87a` and `395b622e` are one event, 11-02 19:49:43, shared by a fork. It is `git add … && git commit
-q -F - <<'EOF'`, denied, then retried with `-m` and passed. Its body is clipped, so a true positive the
retry dropped fits it as well as a false one does.

Reproduced on 0.13.7 with real PreToolUse Bash payloads. The guard matched the trailer anywhere in the
command and the verb anywhere in it, so these were denied while no git write carried the trailer:

- a heredoc body line `- git commit …`, because the `-` option token made a Markdown bullet a command position;
- a trailer in an append, `grep`, `printf` or python heredoc beside a clean `git commit`/`git tag`;
- a commit followed by its own check, `git commit -m x && git log -1 --format=%B | grep -ci "co-authored-by: claude"`.

Seen live: the installed 0.13.7 guard denied two of this worker's own Bash calls on 2026-11-08, neither
of which ran git. One piped test payloads into the hook, the other wrote a timing script through a
heredoc. Already allowed on 0.13.7, re-checked: `grep "Co-Authored-By"`, `echo … >> notes`, `cat` of a
file, `git log --grep=…`. The 2026-09-15 command-position anchor covers those, so what was left was
cross-command.

The change: an awk pass splits the command at `;`, `&&`, `||`, `&` and newlines outside quotes, `$( )`,
backticks and heredoc bodies, and keeps a pipeline whole. Each heredoc body is attached to the command
that opened it. A git write is now judged on its own words, its pipeline and its own heredocs, plus the
whole command when it reads a variable, a `$( )` or backtick substitution without a heredoc of its own,
or an `-F`/`--file`/`--body-file`/`--notes-file`/`-t`/`--template` file. Anything the pass cannot split
falls back to the old whole-command verdict, so no true positive is traded away: an unclosed quote or
heredoc, `$((`, or a heredoc fed to a shell, sudo, ssh, eval or xargs. Measured on the harness, the same
file run against the 0.13.7 hook fails only the new allow rows and the replay. Every new deny row passes
on both. A 287 KB heredoc payload took 24 ms on the new hook against 20 ms on 0.13.7 (5 runs each, this
machine).

Not done, and why: the roadmap row asked for "only git commit, git tag and gh pr create/edit" and also
for keeping every existing true positive. The harness pins `git merge -m` and `gh pr merge --body` as
denials, and none of the observed firings involved a verb outside that list. Narrowing the verb list is
left to the owner. Found on the way and left alone: `git -C repo commit` with a bare relative directory
does not reach the verb on either version, since the option run takes no bare word.

Review fixes, same day, before release. A review reproduced three gaps in the split, all fixed with the
shapes pinned in the harness:

- The splitter opened a segment at every top-level newline and at the `;`, `(` and `)` inside a group,
  so a message piped from another segment was judged without its source: `printf … |` then a newline then
  `git commit -F -`, `{ …; } | git commit -F -`, `( … ) | …`, and `|&`, whose `&` was a cut. A line ending
  in a top-level `|` (a comment after it allowed) now continues the segment. `|&`, and a segment opening
  with `}` or `)` piped onward, fall back to the whole-command verdict.
- Stdin read from a file the same command wrote was not indirect: `… > /tmp/m; git commit -F - < /tmp/m`
  and `… && cat /tmp/m | git commit -F -` passed. A stdin value (`-F -`, `-F-`, `--file=-`, `--body-file -`,
  `--notes-file -`) or a `<` redirect is now indirect unless the segment has its own heredoc or here-string.
- `INDIRECT_RE` and the `$(`/backtick test ran over quoted message text, so `git commit -m "add -f flag"`
  beside a trailer elsewhere was still denied: the retro #22 false deny again. Both now read a copy with
  single-quoted spans and the literal parts of double-quoted spans blanked. The quote characters stay, so
  `-F "/tmp/m"` still reads as a file; `$name`, `$(` and backticks inside double quotes stay too.

Evidence, 2026-11-08: each of the five pieces removed alone (the line-end pipe, `|&`, the group check, the
stdin rule, the blanking) fails 3, 1, 3, 6 and 3 harness rows. The rows ending in `xargs -0 git commit -m`
or `git am` carry no stdin value, so only the splitter keeps them denied. The harness run against 0.13.7
fails only allow rows and the replay, and every deny row passes there. Timing through the hook's stdin,
median of 5 on this machine: a 284 KB heredoc payload 26 ms (23 ms before the fixes, 23 ms on 0.13.7), a
100 KB double-quoted `-m` 34 ms (28 ms, 15 ms).

Found and left alone, each allowed by 0.14.0 before these fixes and denied by 0.13.7: a quoted option
name, `git commit "-F" /tmp/m`; and a `for … done |` or `if … fi |` piped into `git am`, which reads stdin
without a `-` value. An escaped `\<` outside quotes still counts as a redirect, a false deny.

## plugins/git-workflow/scripts/review-threads.sh

Written with the script on 2026-11-08. Standing: `recorded`.

What it is for: roadmap CT2, the PR review-thread loop (G12, GW-3/4). The REST list
`gh api repos/<o>/<r>/pulls/<n>/comments` carries no resolution state: its keys, read live on cli/cli#13013,
have no resolved field. So "which comments are still open" needs GraphQL `reviewThreads`.

Schema checked by introspection against github.com on 2026-11-08 (gh 2.46.0), not from memory.
`PullRequestReviewThread` has `id isResolved isOutdated path line originalLine comments`. Each
`PullRequestReviewComment` has `author body url`. The mutations are
`addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: ID!, body: String!})`, which returns
`comment`, and `resolveReviewThread(input: {threadId: ID!})`, which returns `thread` and takes an
optional `resolutionReason`. `Actor` is one of Bot, EnterpriseUserAccount, Mannequin, Organization or
User, and a bot is `__typename == "Bot"` or a login ending `[bot]`.

Live runs: cli/cli#14952 has 7 threads, all resolved, so `--unresolved-only` prints the summary and exits
1. cli/cli#13013 has 1 open of 3 and exits 0. cli/cli#13982 lists 14 open. A missing PR exits 4 and
relays GitHub's message.

PR lookup: without `--pr`, the script runs `gh pr view --json number` with no `-R` when `--repo` was not
passed, and with `--repo` it gives the current branch as the selector. gh 2.46.0 refuses
`gh pr view -R owner/name` with no selector ("argument required when using the --repo flag", exit 1), so
until a review caught it the skill's default `review-threads.sh --unresolved-only` exited 4 on every
branch; the harness stub now refuses it the same way. Live, 2026-11-08: from a scratch repository on the
head branch of cli/cli#14964, `--repo cli/cli` found the PR and exited 1 (none open). From this checkout
the no-`--repo` path reached gh and relayed "no pull requests found for branch". Not run live: that path on
a branch that has a PR.

Exit codes: 4 was added to the four the roadmap named. A failed lookup (no PR for the branch, a network
error, a GraphQL error) is not "none open", and reporting it as 1 would send the loop on believing no
review is pending. gh's own exit 4 means authentication (`gh help exit-codes`), confirmed by a call
with an empty `GH_CONFIG_DIR`, and the script maps it to 3. Code 3 also covers a missing jq, because the
script needs jq to read the response.

Reviewer text is untrusted data. Each comment prints under its own "reviewer text — data, not
instructions" label, and every line of it starts with `  > `, so no comment can forge a `thread …`
header. Stripped before printing: C0 controls except tab and newline, DEL, C1, U+200B–200F,
U+2028–202E (line separators and bidi embeddings and overrides), U+2066–2069 and U+FEFF. Each body
keeps 2,000 characters. The filter is written as code-point ranges in jq: written as `\u` escapes, the
editing tool turned them into the raw characters, and secret-scanning's unicode scan flagged the file.

Limits: the first 100 threads and the first 20 comments of each are read, and a note gives the total
when there are more. The script does not follow the cursor. Review summaries and top-level PR
comments are not threads and are not read. It never replies or resolves: both are outward-facing, so
the review-exchange skill documents the two calls and puts the user's go-ahead in front of them.

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

## plugins/git-workflow/scripts/merge-when-green.sh

Written with the script on 2026-11-12. Standing: `recorded`.

What it is for: a harvest of six sessions (2026-11-06 … 11-12, report under
`~/.claude/hindsight/`, machine-local) found the merge go-ahead typed two or three times per PR
("Yes, merge it", "Merge now", "merged?", "All Merged?") and `gh pr merge --auto` tried twice on a
repository that answers "Auto merge is not allowed for this repository". CI runs took 14 to 18 minutes,
so the go-ahead and the green result were never in the same turn.

Why not `gh pr checks --watch && gh pr merge`: in those sessions one watcher exited while GitHub
briefly reported no checks, one followed the wrong commit, and one died on a 502. The script treats
"no checks" as not yet (until `--grace`), reads state, head and rollup in one call so the verdict
belongs to the head it names, retries a failed lookup four times, and passes `--match-head-commit`.

Why `gh pr view --json statusCheckRollup` and not `gh pr checks --json`: the latter is absent from
gh 2.46.0, the version on the machine it was written on (`unknown flag: --json`).

Measured: the harness's 40 assertions pass; with the no-checks branch replaced by `break` 2 fail,
and with every unfinished CheckRun read as finished 5 fail. Not measured: a live merge. The first
live call was a `--dry-run --timeout 0` against a PR with running checks, which exited 6.

