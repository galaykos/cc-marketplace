---
description: Finish a development branch — full-suite verify with state evidence, then merge/PR/keep/discard with cleanup.
argument-hint: [branch]
---

Finish the development branch $ARGUMENTS (or the current branch if no argument
is given) using the branch-completion skill from this plugin. Invoke the skill
first. If a branch was named and is not checked out, switch to it (or its
worktree) before doing anything else.

Write the arc phase sentinel `.claude/cc-phase.json` first, with taskmaster's writer
and never by hand —
`bash "${CLAUDE_PLUGIN_ROOT}/../taskmaster/scripts/phase-sentinel.sh" write ship --owner git-workflow:finish --session "<this session id>"`.
It ships in taskmaster, which may not be installed: if that path does not resolve (an
installed plugin sits at `<marketplace>/<plugin>/<version>/`, so the sibling path
resolves only from a source checkout), run the newest installed copy —
`find ~/.claude/plugins/cache -path '*/taskmaster/*/scripts/phase-sentinel.sh' | sort -V | tail -1`
— and only if that misses too
write the JSON yourself, at the repo root (`git rev-parse --show-toplevel`; outside git,
the project directory), never under a subdirectory the shell has `cd`'d into — the
readers look only at the root —
`{"phase":"ship","owner":"git-workflow:finish","session_id":"<this session id>","started_at":"<ISO-8601 UTC>"}`
— spelling `ship` exactly, because the script exists to catch the typo that makes a
sentinel read to every hook as no sentinel at all. The sentinel is what makes
prompt-channel reminder hooks that own an earlier phase stand down while the branch is
being finished; a clarify-the-requirements nudge on a merge decision is noise.
**Clear it before this command returns — `phase-sentinel.sh clear`, else delete the
file — on every path: merge, PR, keep, discard, and the red-suite stop below.** A TTL
bounds a leaked sentinel, but the clear is this command's responsibility.

Before the gate, run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/scratch-ignore.sh" --check`.
Exit 1 means a marketplace plugin's scratch (a mockup dir, preview state, a scratch
entry) sits on disk unignored and would ride into the branch as `??` noise. Show the
rows it printed and ask via AskUserQuestion: "Add the managed block to .gitignore
(Recommended)" runs `scratch-ignore.sh --apply` and stages `.gitignore`; "Leave it"
continues. Rows marked `left to you` (brain/, design-system/, research/, …) are
per-project state the script never touches — name them in the report, decide nothing.

Run the project's full check suite as the gate — a red suite stops here with
the failures reported; no destination options for broken work. First run
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/receipt-fresh.sh" --name suite --root "<the branch's worktree>" --cmd "<the full suite command you would run>"`.
Reuse only when it prints `fresh: …`, exits 0, and its `<head7>` equals
`git rev-parse --short=7 <branch>`: the suite already passed there on this exact tree, so
do not run it again, put `Reused: suite passed at <head7> (<cmd>)` in the report, and use
the receipt log that line names (`.claude/task-runner/receipts/suite-<HEAD12>.txt` in that
worktree) as the suite output tail. Anything else (`stale: …`, another exit, another
head) runs the suite.

On green, before offering any destination, run the review passes that exist in
this installation — each only if its plugin is installed, none of them fatal on
absence. A pass not run is a `Skipped: <pass> — <reason>` line in the report, never
silence:

- `/code-review:review` on the branch diff — correctness, smells, convention drift.
  Per-card reviews from a task-runner run do not substitute for it: each saw one card's
  diff, so a defect spanning cards, or an edit made after its card's review, reached
  none of them. A branch pass after a run found exactly those.
- `code-architecture:drift-review` on the whole diff — did the work stray from what
  was actually asked, are there weakened tests, left-in stubs, skipped criteria.
- `/secret-scanning:scan` on the diff — a credential reaching a PR is the one
  finding that cannot be fixed by a later commit.

These three passes and the post-merge suite always run: a receipt stands in only for
the suite before them.

A green suite is evidence the code RUNS, not that it should merge; without this
step those three are named nowhere in the path between finishing work and
shipping it. Any `critical` finding drops "merge locally" and "push and open a
PR" from the offered set until it is resolved, or the user explicitly waives it
on the record — record the waiver text in the report, not just the choice.

Then gather the state evidence the skill specifies (diffstat against the base,
ahead/behind counts, commit list, suite output tail), present it together with
the review results, and use AskUserQuestion. The four destinations, each offered
with what it does rather than its label alone: **merge locally** — merge into the
base branch here, no review; **push and open a PR** — push the branch and open a
pull request for review; **keep the branch open** — leave it as it is and come
back to it; **discard the work** — delete the branch and lose the commits. Which
of the four apply — and the default-branch-is-PR-only rule that removes "merge
locally" when the base is the default branch — comes from the skill's destination
protocol: apply it from there, do not re-derive it here. Execute the chosen protocol from the skill end
to end, including post-merge re-verification, worktree removal, and branch
deletion where the protocol calls for them — discard only after the user types
the branch name back.

Headless fallback: if AskUserQuestion is unavailable or the session is
non-interactive, report the verification result, the state evidence, and the
applicable options with the exact commands each would run — omitting any
local-merge or push onto the default branch (PR-only) — and take no destructive
action: no merge, no push, no branch deletion, no worktree removal.
