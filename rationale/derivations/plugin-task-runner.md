# task-runner hooks and scripts: the comment text moved out of the code (2026-10-28)

The text below was moved verbatim on 2026-10-28 from the hooks and scripts named in the `##` headings, with only each comment's `# ` leader (and the indentation before it) removed. Each `###` block is a comment block, or a contiguous part of a header, as it stood; the file kept a short summary in its place (a header of at most three lines, a one-line trap), or nothing where the code already says it. A pointer by name was left in each file's header, `# Why, limits, history: rationale/derivations/plugin-task-runner.md § <path>`. Standing: `recorded` — no gate reads this file, and its dates, measurements, line citations and file names are as they stood on the day it moved. A script whose `--help` prints its comment header kept its usage lines (synopsis, flags, exit codes) in place; only description and history left it.

## plugins/task-runner/hooks/announce.sh

### Header

```text
Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must hold
under a stripped or broken PATH.

SessionStart, matcher `startup|resume|clear`. Says ONE line when this project has a
REGISTERED task-runner run on disk, so a session that opens cold already knows the
run exists before it does anything else.

THE GAP IT CLOSES. `.claude/task-runner/active-run.json` survives the session that
wrote it; the model's knowledge of it does not. candor's Stop gate (clause 4) reads
that sentinel and refuses a clean stop until the run is closed, so a fresh session
that has never heard of the run meets the block at the END of its first turn with no
idea what it is about — and the cheapest-looking escape is deleting the sentinel of a
run that is still live. skill-router's compact-capsule.sh covers the same files after
a COMPACTION (matcher `compact`); this covers the cold session, and the two matchers
do not overlap, so a project with both installed hears it once.

WHAT IT READS, all three pure reads, nothing is written, from the project root (the
state-root block below; a session started in a subdirectory still finds the run):
  .claude/task-runner/active-run.json  slug, branch, index_path (run.md step 1)
  .claude/cc-phase.json                phase and owner, when a phase is declared
  <index_path>                         the card table's status column, for the count

STANDING: advisory. SessionStart `additionalContext` informs a turn; it cannot block
one, and nothing checks that the session acts on it. The teeth for an unclosed run
are candor's Stop gate, not this line.

HONEST LIMITATIONS, all four real:
  1. It cannot tell a LIVE run from an abandoned one. There is no TTL on the sentinel
     and this hook adds none: it reports the branch the run registered so a reader can
     see at a glance whether the run belongs to the tree in front of them, and leaves
     the judgement there.
  2. The card count is the INDEX's bookkeeping, not the work. A row is "remaining"
     when its status cell does not begin done/parked/skipped, so a run that never
     updated its index reads as zero done, and a card marked done by hand reads as
     done. It counts what was written down.
  3. It parses the `| NN | … | status |` table task-cards writes. An index in some
     other shape yields no counts and the line still names slug and branch.
  4. Matcher-scoped to startup|resume|clear. A run registered DURING a session is
     never announced in that session — the session that registered it knows.

Off switch: CC_REMIND=off (every reminder in this marketplace). Fail-open on missing
jq, malformed payload, an unreadable sentinel or an unreadable index.
CC_REMIND unset: the /config option cc_remind decides.
```

### The branch read with symbolic-ref

```text
symbolic-ref, not --abbrev-ref: a tag with the branch's name made that print `heads/<branch>`,
read as another branch. Exit 1 is a detached head; any other failure is never compared.
```

## plugins/task-runner/hooks/drift.sh

### Header

```text
Absolute-path shebang (not `env bash`): the fail-open guarantee must hold even under a
stripped or broken PATH, where `env bash` itself exits 127.

PostToolUse. The AD-HOC complement to scope.sh, which is a provable no-op on most turns:
scope.sh exits unless a run is registered (`[ -f "$sentinel" ] || exit 0` — grep it, a
line number here went stale once already), so when there is no task-runner run — a
one-line request typed straight into a session, which is the common case — nothing in
this marketplace watches whether the work stayed near the ask. This is the only surface
here that is stack-agnostic by construction: it counts FILES against a REQUEST, so it
reads a Dockerfile turn, a SQL turn and a React turn identically.

THE THRESHOLD IS MEASURED, NOT CHOSEN. 400 local transcripts, 169 turns that edited at
least one file: p50=2, p75=5, p90=12, p95=21, p99=40, max=157. DRIFT_FLOOR is p90, so
roughly one edit-turn in ten can reach it before the two filters below apply. An earlier
draft of this hook proposed 4 — that would have fired on about a third of all turns,
which is the "a number someone wrote down" non-trigger the lean plugin's cost-model
skill rejected (lean was removed 2026-09-14; the rule stands), and is why this hook was refused the first time it was proposed rather than
shipped with a guess. Re-derive from your own transcripts before changing it.

STANDING: advisory. additionalContext is not a blocking key and this exits 0 on every
path. It asks a question; it never renders a verdict. Breadth is not wrongness.

LIMITATION (honest scope — the four laws, see
.claude/skills/authoring-skills/SKILL.md (in the marketplace repository) "The four laws"):
  - BREADTH ONLY, NEVER DEPTH. 300 lines of unasked refactor inside the one file the
    request named is completely invisible here, and that is probably the commoner way to
    stray. This measures the axis that is countable, not the axis that matters most.
  - A legitimately wide mechanical request IS a false positive. The breadth-marker list
    below ("everywhere", "rename", "migrate", …) exists to cut the obvious cases, and it
    is a word list, so it will miss phrasings nobody thought of.
  - It reads the LAST typed user message only. A request built up over three turns is
    scored against its final sentence.
  - It cannot see a fan-out's total: each subagent context counts its own edits, the same
    aggregate blind spot code-review/hooks/density.sh names for itself.
  - Whether a given extra file was NECESSARY needs a reader. That judgment stays
    agent-graded, and is why the message ends in a question.

Off switches: CC_REMIND=off silences this and the other reminder hooks; CC_DRIFT=off only
this. scope.sh, the run-scoped tripwire, reads only the run's scope file and is not muted.
CC_REMIND / CC_DRIFT unset: the /config options cc_remind / cc_drift decide.

FAIL-OPEN: missing jq, unreadable transcript, unwritable state, or any error exits 0.
```

### The payload cwd tested with -d

```text
`-d`, not just `-n`: the payload cwd is a STRING the host supplies, and the mkdir
below happily recreates a project directory the user has just deleted, three levels
deep (live repro, AR 1 of the 2026-09-22 panel). A cwd that is not a directory now
means "no state to keep" — exit, never create. Every state path below is anchored at
the project root (the state-root block above), so a turn run from a subdirectory
neither scatters a second .claude/task-runner/ beside it nor misses the run's sentinel.
```

### State hygiene: .claude/task-runner/ ignores itself

```text
STATE HYGIENE (0.34.4). .claude/task-runner/ is written by the run itself
(active-run.json, rv/, bg/, gate-pass.json) and by this plugin's scripts; none of
it belongs in a commit, and it showed up as untracked in every repo a run touched
(overseer's acceptance protocol names it as "other plugins' scratch"). A directory
can ignore itself, so the first hook to see it drops a `.gitignore` holding `*`.
```

### A registered run hands the turn to scope.sh

```text
A registered run means scope.sh owns this turn; two voices on one territory is the
collision plugins/*/lane.tsv exists to prevent. The run, not a scope file: since
0.41.0 scope.sh ignores scope files while no run is registered (a finished run's
leftovers flagged the next task's edits), so yielding to a bare scope.json would
leave a leftover muting BOTH hooks.
```

### The transcript tail, and why fromjson is not used

```text
Only the tail is read: a long session's transcript is large, and everything this needs
sits after the last typed user message.
Transcript lines are JSON OBJECTS, one per line — not JSON-encoded strings. An
earlier draft piped them through `fromjson`, which wants a string, so every line was
discarded and the hook was silent on every input including the ones it exists for.
It looked exactly like correct suppression: three silence fixtures passed and the one
positive fixture did not, which is why a positive case is not optional.
```

### Files in a directory the request created

```text
Files created under a directory this request created are the ask's new feature, not
strays: "build a homepage" wrote 12 new files under a new components/welcome/ and was told
12 of 12 were unnamed (2026-10-13 retro). A directory is new when every file in it is one a
Write since the request created (the transcript's toolUseResult.type "create"). Residual: a
new file in a directory that already held files still counts, and so does a new directory
anything else wrote into (a generator, a cache).
```

### The breadth word list

```text
A request that ASKS for breadth is not drift. Cheap word list, and its misses are
named in the limitation above.
```

### One question per user message: the hashed key

```text
One question per user message, not per edit. Keyed on the transcript AND the ask, both
hashed: the raw key is an absolute path, and pasting one into a filename names a file
whose parents never existed — see authoring-hooks, references/one-shot-state.md.
```

## plugins/task-runner/hooks/rv-consent.sh

### Header

```text
Absolute-path shebang: fail-open must hold under a stripped PATH.

PreToolUse consent gate — a DISCRETIONARY skip of a card's reviewer pass must be
approved by the human before it is recorded, not disclosed afterwards.

WHY HERE. PreToolUse is the only hook event that can put a question to the user
(`permissionDecision: "ask"`); a Stop hook can refuse a stop but cannot ask, and
AskUserQuestion is model-initiated so nothing can force it. A hook cannot see an
ABSENCE — no event fires for a review that never happened — but it can see the one
action a gated skip must take: writing the skip record. So the record write is the
chokepoint, and the completion gate is what makes writing it unavoidable.

WHAT IT ASKS ABOUT: a DISCRETIONARY reduction — a reviewer pass skipped
(review-skip.sh --reason) or any other promise narrowed (reduction-record.sh: a
degraded red-team panel, a downgraded fan-out, a narrowed suite). rv-seen-* (a real
dispatch, observed) and rv-exempt-* (the DESIGN carve-outs — a parallel-group/track
leaf, a reviewer plugin that is not installed) are routine and never prompt.
Prompting on routine records would train the reflex this gate exists to prevent.

HONEST LIMIT: what happens under auto-accept, bypassPermissions, or a headless `-p`
run is NOT verified here — an unanswerable permission request may be denied rather
than allowed, which would refuse the record write itself. Either way consent is
structurally impossible without a human, so the ceiling in those modes is
disclosure-plus-gate: the reason still lands in the transcript via the recorder's
stderr, and candor's Stop gate (clause 4) still refuses a clean stop whose report omits it. A
denial is bounded — the completion gate blocks at most once per HEAD — but do not
read this comment as a claim that the prompt silently passes headless.

FAIL-OPEN: missing jq, unreadable input, any error → exit 0 (allow, no prompt).
```

### Only inside a registered run

```text
ONLY INSIDE A REGISTERED RUN. Without this the hook prompted in every session of
every repo with the plugin installed — on `grep -r rv-skip- .`, on deleting a stale
record, on editing this plugin's own scripts. A permission prompt that fires on
reading about a skip trains exactly the click-through reflex it exists to prevent.
The sentinel is read at the project root (block above): after a `cd` into a
subdirectory the payload cwd has no .claude/ of its own, and the ask went silent.
```

### Two ways a discretionary skip reaches disk

```text
TWO WAYS a discretionary skip reaches disk, and the sanctioned one does not
mention the filename at all: `review-skip.sh --card X --reason "..."` writes
rv-skip-X.json itself. Matching only the record name missed the primary path
entirely — the gate would have prompted on nothing in normal use.
```

### A record written, not mentioned

```text
A record being WRITTEN, not merely mentioned. `grep -r rv-skip- .` and `rm` of an old
record both name the path without creating one; only a write or a recorder invocation
with a reason is the act that needs consent.
```

### A shell redirect into a record file: span

```text
A shell redirect straight into a record file is the same act by another route. Any
expansion can build the name (`${H:0:12}`, `$(git rev-parse …)`, a backtick), so the
name runs to `.json` short of a pipe or command separator; an id class missed each.
The path before it stops there too: `2>/dev/null; ls …/rv-skip-*.json` only reads.
A `$(…)` or backtick span may hold one (`$(git rev-parse HEAD | cut -c1-12)`): it read
as the redirect's end. Residual: a name held in a variable (`> "$f"`) and a nested `$(…)`.
```

### --exempt never prompts

```text
An exemption is a design carve-out, never a judgment call: it must not prompt,
even when the same command mentions the record directory.
```

### De-escaping the tostring blob: flat

```text
`tostring` renders the command with its inner quotes backslash-escaped, so the
reason reads as --reason \"...\". Match against a de-escaped copy; the prompt
shown to the user is the one place this hook must get the text right.
Unescape only the quote escapes `tostring` added; a blanket backslash strip mangled
legitimate ones (a Windows path, a regex) inside the reason shown to the user.
```

### The card id class

```text
The id class takes `$ { } :` so a shell-built id such as `bg-${H:0:12}` is shown as
written; without them the prompt named card `bg-`.
```

### The reason interval {1,201}

```text
{1,201}, not {1,300}: BSD grep rejects an interval above 255 with "maximum
repetition exceeds 255" — on stderr, which this hook sends to /dev/null, so the
reason silently came back empty and every prompt read "no reason given".
No closing quote in the pattern: requiring one within the interval made any reason
over 200 characters read "no reason given". The 201st character only marks a cut,
shown as "…". Residual: an unterminated quote shows the rest of the command.
```

## plugins/task-runner/hooks/rv-observe.sh

### Header

```text
Absolute-path shebang: fail-open must hold under a stripped PATH.

PostToolUse observer — records that a reviewer pass was actually DISPATCHED for a
card. Writes nothing else, blocks nothing, and is silent on every path.

WHY A HOOK AND NOT A RECORD THE RUN WRITES. The per-card negative control is
enforceable because a SCRIPT's exit writes nc-pass-<card>.json — the model cannot
author it. The reviewer pass had no such artifact: it is mandated in prose
(`skills/task-execution/SKILL.md` § Reviewer pass, "every task's diff, no
condition") and nothing observed it, so under context pressure a real run reviewed
card 01, skipped cards 02-08, reported "all 8 done, none parked", and passed every
gate. Closing that gap afterwards found a real bug and six over-claims.

A model-written rv-pass-<card>.json would not have helped: the same run wrote
cards_done:8 into gate-pass.json while skipping the reviews, and would have written
pass records with the same conviction. What has teeth is evidence the ORCHESTRATOR
could not fabricate without lying in a tool call: this hook sees the dispatch itself.

WHAT IT PROVES, EXACTLY: that an Agent/Task dispatch carrying one of the markers below
was made while a run was registered. Not that the reviewer or refuter read anything,
not that its findings were acted on, not that the right one was chosen. DEPTH stays
unenforceable — a subagent's transcript is a separate file the parent hook cannot
see. This closes "the pass never happened", which is the failure that occurred.

STATE ROOT: the sentinel is read and records are written at the project root (the block
below), not under the payload cwd — a dispatch made after a `cd app/Models` used to look
for app/Models/.claude/task-runner/active-run.json, find none, and record nothing, which
the completion gate then reads as a review that never ran.

FAIL-OPEN: missing jq, no registered run, unwritable dir, any error → exit 0 silently.
```

### Only inside a registered run; closed-run.json

```text
Only inside a registered run. Outside one there is nothing to be complete about,
and the completion gate is fail-open there for the same reason. A closed-run.json is a
run between its closing rename and candor's last read: a review that read asks for counts.
```

### The markers, read from the whole tool_input

```text
Markers ride in the dispatch prompt. Read the whole tool_input rather than a single
field: the Agent tool names it `prompt`, and a future dispatch shape carrying it
elsewhere should still count.

  RV-CARD: <card>   a card's reviewer pass      (reviewer-routing.md § Coverage marker)
  RV-RANGE: <sha>   the run-close range review  (run.md step 4); a Skill call counts too
  RT-LENS: <lens>   one red-team refuter        (code-redteam § The N=3 refuter panel)
  RT-CRITIC: <id>   the completeness critic     (same)

One observer, several kinds: a second hook per mandated dispatch would be four
copies of this file, and the marketplace's admission law forbids that.
```

### record: idempotent by id

```text
Idempotent by id: several reviewers dispatch per card (code-reviewer plus the tag
route) and one record per card is what the gate counts.
```

### One file per card and reviewer type: rv-agent

```text
Also one file per card and reviewer type, beside the count: the completion clause asks
for ui-ux-reviewer by name on a UI card, since the count alone let any reviewer stand in.
```

## plugins/task-runner/hooks/scope.sh

### Header

```text
Absolute-path shebang: fail-open must hold under a stripped PATH.
PostToolUse scope-lock tripwire. When a REGISTERED run (.claude/task-runner/active-run.json
at the project root) has declared its allowed files in .claude/task-runner/scope*.json,
this warns (non-blocking) if a write landed OUTSIDE the union of those sets — the "touch
only files the task lists" discipline made mechanical. The warning is emitted as the
PostToolUse stdout JSON envelope
({"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":...}},
exit 0) — the one non-blocking channel the executing model actually receives;
plain stdout text with exit 0 never reaches it (same channel reasoning as
candor's gate.sh clause 4, whose Stop event reaches the model only through exit 2).
No registered run, or no live scope file → no-op (the discipline is opt-in per run).
A Bash call that exits non-zero fires PostToolUseFailure instead, registered for Bash too;
the envelope then names that event. Such a command may have stopped before its redirect, so a
named target the previous call's marker post-dates is skipped, and on a call with no marker
(the run's first) a named target takes the effects wording below, never "revert". Fail-open.

WHAT IT SEES (0.41.0). Edit/Write/MultiEdit through `.tool_input.file_path`, AND Bash:
the files a command writes by `>`/`>>`, heredoc, `tee` or `sed -i`/`perl -i`, parsed by
cc_bash_write_targets below, resolved against the Bash call's cwd, kept only when they
are existing regular files under the project root, at most 8 per call (MAX_BASH_TARGETS).
Measured 2026-09-25 (rationale/2026-09-25-session-plugin-usage-review.md, finding 1): with
the host's `bashFirst` auto mode, 233 of 238 main-thread writes in one session were
`cat > file`, so an Edit/Write-only tripwire was blind on the default write path.

INTERPRETER WRITES (0.47.0). After a command naming python, node, php, ruby, perl, deno,
bun, cp, mv, install or patch, also each file git reports changed or untracked since this
hook's previous call in the run (the bash-write-effects block below), at most 8
(MAX_BASH_EFFECTS), judged against the scope as an Edit of it is. In four sessions of the
2026-10-13 retro, 40-85% of code writes went through interpreter heredocs (python3 - <<'EOF'
… open(p,'w')), which the parser cannot name. Such a path is worded apart from a named
target: it changed since the previous tool call and may not be this command's write, so
the warning sends the agent to `git diff` and never tells it to revert what it did not
write. The marker is dated on every Edit, Write and Bash call of a registered run, so an
Edit's file is not read again by the next Bash call; outside a run nothing is written. A
marker older than active-run.json, or dated by another session, reads nothing.
Everything under .claude/task-runner/ is the run's own state (active-run.json,
gate-pass.json, the scope files) and is never checked — a run commonly writes those
with `cat >`, and no card lists them.

STATE ROOT (0.41.0). Scope files are read from the project root, not the payload cwd,
which follows the model's `cd` (same review, finding 2): a run whose shell sat in
app/Models looked for app/Models/.claude/task-runner/, found nothing, and was silently
disarmed.

COVERAGE: every LIVE scope file in the run's state dir — the inline path's scope.json AND
the per-card scope-<cardId>.json files routing.md writes for delegated and tracked
cards — read as ONE UNION. An edit outside the union warns; an edit any live card
declared does not. Union, not per-file, because this hook cannot tell WHICH card an
Edit belongs to: the payload carries a path, not a card id, and charging an edit
against the wrong card's list would warn on correct work.

LIVE means: active-run.json exists, and the scope file is not older than it. Measured
(same review, finding 8): a finished run's scope-*.json files, left on disk, flagged the
NEXT task's spec edit as scope creep — the union was read whether or not a run was live.
A scope file from an earlier registration is now ignored, so re-registering a run
retires every stale file without deleting it.

WHAT IT STILL DOES NOT CATCH:
  - A WORKER IN ANOTHER WORKTREE. A subagent's Edit fires in ITS session with ITS
    cwd; a track worktree is a different tree with no active-run.json of its own, so
    its edits arm nothing here. That path is enforced by the prose diff-vs-declared
    check on return.
  - Scope-file drift INSIDE a live run. A card whose scope file is never written is
    unbounded here, and a finished card's scope-<cardId>.json written after this
    registration still WIDENS the union — the union fails toward silence, which is the
    right failure for an advisory tripwire and the wrong one for a gate. This is not a
    gate. mtimes compare at whole seconds under macOS's bash 3.2, so a stale file
    written in the same second as the registration counts as live.
  - Bash writes neither the parser nor git can name: a path held in a variable, a target
    past the eighth; after an interpreter run, a writer the effects block does not name
    (make, git apply, npx prettier --write), a gitignored output, a repo with no git, a
    file written then reverted, a mv or cp -p destination (it keeps the source's mtime),
    files past the eighth, and every write of the first Bash call after a registration
    (no marker newer than active-run.json) or of the first call of a session. A file that
    does not exist after the call is skipped.
  - Writes the command did not make: after an interpreter run, any file changed since this
    hook's previous call in the session (an IDE save, a cache or test output git does not
    ignore) warns, in the effects wording above. Every agent of a session in the tree
    shares one marker per root, so a parallel worker's write can be reported to another
    agent's call, or dated past by that call and missed by the worker that made it.
  - Any malformed scope file — invalid JSON, or no `allow` array — disarms the whole
    call, not just its own card: a partial union would warn about paths a card it could
    not parse had actually allowed.
  - A Write/Edit to an absolute path outside the project root: skipped on purpose, as a
    Bash target there always was. The run's own card index under the root is not
    exempt, so updating its status column still warns unless a card lists it.

fd 3 = the caller's real stderr, saved before the block so the two fail-open
warnings below (D7: missing jq / a malformed scope file) reach stderr — the block's
`2>/dev/null` is there only to silence incidental jq/grep noise and would eat a
plain `>&2` warning. (Honest limitation law: .claude/skills/authoring-skills/SKILL.md (in the marketplace repository) "The four laws".)
```

### State hygiene: .claude/task-runner/ ignores itself

```text
STATE HYGIENE (0.34.4). .claude/task-runner/ is written by the run itself
(active-run.json, rv/, bg/, gate-pass.json) and by this plugin's scripts; none of
it belongs in a commit, and it showed up as untracked in every repo a run touched
(overseer's acceptance protocol names it as "other plugins' scratch"). A directory
can ignore itself, so the first hook to see it drops a `.gitignore` holding `*`.
```

### No registered run

```text
No registered run → every scope file on disk is a leftover (header, LIVE).
```

### The effects marker and the registration

```text
Effects are read against the marker the previous call of this run left, then the marker is
dated, on every call from here on. A marker older than active-run.json was dated before
this registration, so the window would span calls between runs: it reads nothing.
```

### A scope file with no allow array

```text
Valid JSON of the wrong shape is malformed too. Orchestrators wrote {card, allowed};
`.allow // []` read that as an empty list, and every edit of the run was "scope creep".
```

### Written paths, repo-relative

```text
Written paths, repo-relative. The run's own state dir is never in a card's scope and
never checked (header, WHAT IT SEES).
```

### bash_rel

```text
bash_rel <path> [marker]: keep a written path repo-relative when it is an existing regular file
under the root, outside the run's state, not older than [marker] and not kept already; status 1 otherwise.
```

### Relative targets and the Bash call's cwd

```text
Relative targets resolve against the Bash call's cwd: that is where the shell
wrote them, which is the one place the payload cwd is the right anchor.
```

### A failed command's named targets

```text
A failed command may have stopped before its redirect: a named target older than the previous
call's marker was not written, and with no marker to tell, a target takes the effects wording.
```

### An absolute path outside the root

```text
Normalize the edited path to repo-relative for comparison. An absolute path outside
the root (/tmp, the user's memory dir) is no card's file and was told to "revert
this edit"; it is skipped, as the Bash branch already skips one.
```

### The allow test: equality or a directory boundary

```text
Allowed if the edited path equals an allow entry, or sits under it as a
DIRECTORY. The boundary matters: a raw startswith made every entry a prefix of
unrelated siblings — "src/util.ts" admitted "src/util.tsx", "app/Models"
admitted "app/ModelsBackup/X.php" — so the lock leaked silently on the exact
near-miss paths a drifting edit produces.
-s slurps every scope file into one array, so `allow` is the UNION of all of them.
```

### The envelope built with jq

```text
jq builds the envelope so the message stays valid JSON whatever $rel contains.
jq presence is guaranteed here by the guard at the top of the block.
```

## plugins/task-runner/hooks/spawn-cap.sh

### Header

```text
Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
even under a stripped PATH where `env bash` exits 127.

PreToolUse spawn budget. Counts subagent dispatches per session and returns `ask`
once the count crosses a soft cap (default 20), then again at every doubling.

WHY THIS EXISTS. `scripts/turn-cost.sh` in the marketplace repo states the fact this
guard acts on: subagent turns are invisible in the transcript and they are billed.
A fan-out that was planned as three agents and became thirty is not visible anywhere
until the bill — not in the transcript, not in a summary, not in `parallel-planning`'s
estimate, which is prose the dispatcher reads once at the start and not again at
dispatch number twenty-six. Nothing in this marketplace counts.

WHY `ask` AND NOT `deny`. A large fan-out is sometimes right — a tracks run over a
dependency wave, a review panel over a big diff. The cap is not a claim that thirty is
wrong; it is a claim that thirty should be a decision someone made. A deny would make
the plugin wrong about the legitimate case; an ask makes the count visible exactly
once per threshold and costs one keystroke.

WHY IT DOUBLES RATHER THAN ASKING EVERY TIME. Asking at 21, 22, 23… trains the user to
approve reflexively, which is the same as not asking. Thresholds at 20, 40, 80 keep the
signal rare enough to read.

INSIDE A REGISTERED RUN (.claude/task-runner/active-run.json at the state root, naming
the checked-out branch or none) it NOTIFIES instead (2026-10-14), and its first threshold is
max(cap, cards x 3), cards counted from the run's index_path (a worker plus reviewers
per card). The run was already authorized, and the ask at #20 left one run idle for 67
minutes, then 25 at #40, while its sibling agents finished; neither approval changed
the plan. The notice goes to the user (systemMessage) and the model
(additionalContext), and names the plan.
Residual: a run that dispatches past its plan is told, not stopped. The branch is read with
`symbolic-ref`: a tag with the branch's name made --abbrev-ref print `heads/<branch>`, so the
run read as another branch's and the cap asked. A detached HEAD (exit 1) reads `HEAD`; any other
failure leaves the branch unknown, which matches the run.

WHAT IT DOES NOT CATCH, stated because the README tiers this:
  - Agents a SUBAGENT spawns. The count is keyed on the session, and a nested dispatch
    carries the parent's session id, so nesting inflates the same counter rather than
    escaping it — but a subagent that spawns through a different mechanism is invisible.
  - Cost. It counts dispatches, not tokens or dollars; a cap of 20 haiku calls and 20
    opus calls are the same number here and are not the same bill.
  - Anything about whether the fan-out was a good idea. That is
    `task-runner:parallel-planning`, which is prose and stays prose.

CC_SPAWN_CAP=<n> moves the first threshold; CC_SPAWN_CAP=off disables it.
CC_SPAWN_CAP unset: the /config option cc_spawn_cap decides.
Fail-open on every error path.
```

### One marker per dispatch, by mkdir

```text
One marker per dispatch, created with mkdir — atomic, no read-modify-write, so two
dispatches racing cannot lose a count. `$$-$(date +%s)-$RANDOM` alone can collide:
same PID, same second, and $RANDOM repeats within a seeded shell, which silently
undercounts. mkdir FAILS on collision, so the loop retries instead of losing the
count; ten attempts then give up (fail-open) rather than spin.
```

### The sentinel's branch

```text
A sentinel names the branch it was registered on; one left behind on another branch
turned this ask into a notice for unrelated work. Read as candor's clause 4 reads it: a
run differs only when both names are known and differ.
```

### The doubling thresholds

```text
Threshold at the first one, then every doubling: 20, 40, 80, 160…
```

## plugins/task-runner/scripts/behavioral-gate.sh

### Header

```text
behavioral-gate.sh — B1 completion gate: classify + own-tests + empty-detect + zero-check.

Deepest root cause this closes: the repo completion gate is a *static* linter — no
stage ever RUNS the produced artifact's own tests, so a code-producing run that
ships zero runnable check sails through green. This gate:
  (a) CLASSIFY   the touched files -> languages -> a real test runner.
  (b) OWN-TESTS  run that runner non-interactively, under a hard timeout, applying
                 per-runner EMPTY-DETECTION.
  (c) ZERO-CHECK a needs-coverage run that ships no runnable own-test FAILs.
  (d) HONEST report to stderr of what ran / was skipped / the verdict label.

Per-runner empty-detection recipe: references/runners.md — the table there mirrors
the EMPTY-DETECT logic below; THIS SCRIPT is the source of truth.

Exit contract:
  0  covered  OR honest  no-executable-surface
  2  fail:     empty-suite | no-behavioral-coverage | unverifiable-suite (fail-closed)
             | entrypoint-error (crash-on-invoke) | dead-affordance (flag is a no-op)
  3  usage

SAFETY: this gate RUNS code (the artifact's own tests) IN the directory it runs in —
a misbehaving suite CAN write there (runner cache dirs, coverage files, test-created
artifacts). Three modes decide which directory that is:
  --isolate   the gate builds the disposable checkout ITSELF: a detached `git worktree`
              of HEAD under <repo>/.claude/task-runner/iso/ (gitignored), verified to
              exist and to be a different toplevel than the live repo BEFORE anything
              runs (refuses, exit 3, otherwise — it never falls back to running in
              place), removed by the EXIT trap. It never reads or writes the live .env;
              when one exists and the tree has no .env.example, .env.dist or
              .env.sample to copy, the tree root gets an empty .env, so a loader
              walking up parent directories stops there.
              Inside the repo, not $TMPDIR (2026-10-14): a suite that only runs in a
              container (docker exec, sail, ddev, lerd) sees the repo's bind mount and
              nothing in /tmp, so a 119/119-green suite could not be run against the
              isolated tree at all. BG_TREE_REL (exported) is the tree's path relative to
              the repo, for `docker exec -w <mount>/$BG_TREE_REL`. Residuals: while it
              exists, a scanner run in the live tree (a watch-mode test runner, an IDE
              indexer, a test run whose discovery enters dot-directories) can see the
              copy; a tree a crash left behind is swept after a day, but a non-empty
              directory a container created in it as root fails the trap and the sweep
              alike, silently (`|| true`); BG_TREE_REL is from the git toplevel, so a
              container that mounts only a subdirectory of the repo cannot reach the
              tree; any other config found by walking up parent directories resolves to
              the live repo's copy.
  --in-place  the caller has already isolated (a temp fixture, a scratch clone); run
              in cwd. The dogfood harnesses do this and assert `git status --porcelain`
              (and a fixture-dir checksum) is byte-identical before/after.
  neither     as --in-place, EXCEPT inside a registered run's live tree
              (.claude/task-runner/active-run.json at the toplevel), where it refuses.
WHY --isolate exists (2026-09-24): the header used to say "tree isolation is the
CALLER's responsibility", so every run improvised worktree + symlink + env steps. One
such hand-built `git worktree add` was rejected with the rest of its Bash call, the
next call's `cd /tmp/<dir>; cp .env.example .env && php artisan key:generate` ran in
the live repo after the cd failed, and a developer's .env and APP_KEY were destroyed.
RESIDUAL --isolate does not close: vendor/ and node_modules/ are SYMLINKED from the
live tree (a fresh install per gate run is minutes), so a suite that writes into its
dependency dirs writes live, and Composer's autoloader, which resolves its own path
through the link, loads the app's PHP classes from the live tree; and the worktree is
HEAD, so uncommitted changes to tracked files are not what gets tested, except through
that autoloader (warned, not refused — the record is keyed by HEAD anyway).
```

### MACHINE EVIDENCE: bg_record

```text
MACHINE EVIDENCE. gate-pass.json is written by the MODEL, so on its own it records a
claim, not a run: a run can write {"head":...} having never invoked this script. This
writes what THIS script actually concluded, for the HEAD it concluded it at, and
candor's Stop gate (clause 4) cross-checks the claim against it.

Armed by the directory existing (created at run registration), so a plain non-run
invocation writes nothing. Called on EVERY exit path, including the honest
no-executable-surface pass: a legitimate run that produced no runnable surface would
otherwise leave no record, and the completion gate would block it forever for a pass
it actually earned. Failure to write is never fatal — verdict and exit code are
unchanged either way, so this can only ever add evidence, never withhold a result.
```

### bg_record: where the record lands

```text
--record-dir names the LIVE repo's bg dir. run.md runs this gate from a disposable
checkout so it cannot mutate the tree it is judging, which means $(pwd) here is the
temp copy: without the flag the record landed in a directory about to be deleted and
the completion gate then blocked an honest run for a pass it had actually earned.
Without the flag it is anchored at the git toplevel, not $(pwd), like
reduction-record.sh: run from a subdirectory, the gate looked for sub/.claude/…/bg,
found it unarmed, and left no record.
```

### TIMEOUT_SECS: 1800 s, and the suffix

```text
1800 s, not 60 (2026-10-14). The cap turns a hang into a verdict; it is not meant to
bound a healthy suite. At 60 a 1,926-test Pest suite and a docker-exec suite both read
TIMED OUT -> unverifiable-suite while green, and a gate that cannot be earned trains
hand-written gate-pass.json. Too high costs only the wait on a real hang. The Bash
tool's foreground ceiling is 10 minutes and its kill leaves no verdict, so run the
gate in the background. Entrypoint probes (--help, differentials) keep 60 s: a hung
--help is a crash, not a slow suite.
A suffix is read as GNU timeout reads it: `30m` reached `timeout` intact, but the tests on
the cap below errored on it, so the total and the 137 mapping were skipped.
```

### TOTAL_SECS: the whole gate, 6600 s

```text
The whole gate, isolate build included: 6600 s. From CLI
2.1.285 the host stops a background Bash call at its `timeout` (30 min default, 2 h max;
from 2.1.288 only in -p, SDK, CI and cloud sessions), and a stopped gate writes no verdict
(measured 2026-10-15). Seven suites at 1800 s ran 210 minutes. Each run starts with what
is left, so the gate concludes about 10 minutes inside the 2 h; one that finds nothing
left reads unverifiable-suite. SECONDS is reset: one inherited from the environment
started the clock there. 10#: a leading zero read as octal, and `08` ended the gate with exit 1.
```

### The portable hard-timeout wrapper

```text
---- portable hard-timeout wrapper -----------------------------------------
Prefers coreutils `timeout`/`gtimeout`; falls back to a perl alarm+fork (rc 124 on
timeout, GNU-compatible); last resort runs uncapped with a logged warning.
```

### run_with_timeout: -k

```text
-k: a suite that ignores TERM held `timeout` past its cap (a 1 s cap ran 6 s, measured
2026-10-15), and no total holds then. The KILL exits 137; at the cap that is a timeout.
```

### Arg parse: repeatable flags

```text
---- arg parse: --changed accepts a space/newline list OR repeated flag -----
--entrypoint <bin> and --differential 'flag::with::without' are BOTH repeatable
(card 07: shell-entrypoint smoke + differential dead-flag detection).
```

### --runner-for replaces, --runner adds

```text
--runner-for <lang> '<cmd>::<regex>' REPLACES that language's built-in runner; --runner
only adds one. A PHP suite that runs only through `docker exec` passed 119/119 as a
--runner while the built-in host phpunit beside it timed out, so the gate read
unverifiable-suite on a green suite. Stored as RF_<lang>: bash 3.2 has no assoc arrays.
```

### unset RF_*

```text
Only the flag sets these: one inherited from the environment replaced a runner unasked,
and an RF_custom<N> was called as parse_custom<N>.
```

### ISOLATION

```text
---- ISOLATION (see the SAFETY header) ---------------------------------------
Every step that can fail refuses with exit 3 and runs NOTHING: the failure this
exists for was a setup step that failed silently while the steps after it ran in the
live repo. Cleanup is one function so the WORKTMP trap below can call it too — a
second `trap … EXIT` would replace this one.
```

### isolate: the sweep of dead trees

```text
A reboot empties /tmp, not this directory, and a suite that exhausts memory kills the
gate before its trap runs (one session crashed a machine twice). A tree older than a
day is a dead gate's.
```

### isolate: the tree is verified

```text
Verified, not assumed: the directory exists AND git inside it names IT as the
toplevel. A tree that resolves to the live repo is the incident, so it refuses.
```

### isolate: dependency dirs

```text
Dependency dirs are symlinked, not installed: the residual named in the header.
Relative when the tree sits at the expected depth, so the link also resolves inside a
container that mounts the repo at another path; an absolute host path dangles there.
```

### isolate: the environment

```text
Environment: built from the tree's OWN committed example, by absolute path into the
verified tree. The live .env is never read — it holds the developer's credentials.
.env.dist too: Symfony's Dotenv reads it only while .env is absent, so an empty .env hid it.
```

### isolate: the empty .env

```text
The tree sits inside the live repo, so a loader that walks up parent directories for a
.env (python-dotenv's find_dotenv) found the live one. An empty one at the tree root
stops the walk; the live file is only tested for existence.
```

### isolate: APP_KEY

```text
Laravel: tests take their env from phpunit.xml, but the app still boots with
APP_KEY. Exported for this process only — `artisan key:generate` writes a .env
file, which is the command that destroyed a live key.
```

### IN FLIGHT: bg/running.pid

```text
IN FLIGHT. run.md runs this gate in the background, and candor's Stop gate (clause 4)
blocked a stop while it was still running for want of a verdict. bg/running.pid holds
`$$` and the HEAD being judged, so the Stop gate can tell "running" from "never run".
Written into the same bg dir as the record, and only where that dir already exists
(run registration creates it): creating it would arm bg_record outside a run. Removed
on exit only while it still names this process, so a second gate's file survives the
first one's exit. Residual: a SIGKILL leaves the file, naming a dead PID (or, once the
PID is reused, a live stranger beside the right HEAD).
Line 3 is the deadline, epoch seconds: start, total, then 60 s for the 10 s KILL grace
and the steps no cap covers. candor holds a stop until then, so a raised total moves it;
a fixed hold on candor's side was outlived by a raised total or an older gate's 210 minutes.
```

### (a) CLASSIFY

```text
---- (a) CLASSIFY: touched files -> language flags --------------------------
php/rs/rb/java+kt were added 2026-09-22 (SW 1 of the specialist panel). Before that
the classifier knew py/js/go and nothing else, so a PHP, Rust, Java or Ruby run fell
to HAS_OPAQUE=1 -> no-behavioral-coverage -> exit 2 with no flag to escape it, and
candor's Stop gate then refused every close: a gate that could not be passed rather
than a rule that could be followed. Measured on four fixtures with green suites:
EXIT=2 all four.
```

### --runner and the opaque surface

```text
--runner is the escape for the FIFTH language — anything the classifier still calls
opaque. Declaring one satisfies the opaque surface: the caller has named a command
and the output that means "it ran nothing", which is the only thing the classifier
was ever supplying.
```

### ZERO-CHECK helpers

```text
---- ZERO-CHECK helpers: is a runnable own-test statically present? ---------
`-print -quit`, never a bare `-print | grep -q .`: grep -q exits on the first line, and
once the path list outgrows the pipe buffer (64 KB) find dies of SIGPIPE, exit 141,
which pipefail makes the probe's verdict. Every repo large enough to matter read as
"no runnable own-test", so the closing gate could not be earned there. Residual: an
unreadable directory find reaches before the first match still exits non-zero.
```

### rs_has_tests

```text
Rust tests are USUALLY inline `#[test]` fns in the same file, not a separate naming
convention, so the static zero-check greps for the attribute as well as tests/. The
pattern is deliberately loose (anywhere on the line, any `#[<path>test…]` attribute:
`#[test]`, `#[tokio::test]`, `#[rstest]`, `#[test_case(..)]`) and deliberately not
`#[cfg(test)]`, which is a module gate and not a test. Over-matching — a commented-out
attribute — costs nothing: cargo then runs and the empty-suite branch renders the
verdict. UNDER-matching is the expensive direction, because it reports
no-behavioral-coverage for a crate that does have tests.
```

### run_capture: the temp dir

```text
---- run a runner, capture combined output + exit code ----------------------
All captures land in one script-scoped temp DIR removed by an EXIT/INT/TERM trap,
so a signal between mktemp and the read can never leak a temp (mirrors
negative-control.sh's isolation). run_capture is ALSO called inside the
`$(verdict_*)` command-substitution subshells below: those inherit WORKTMP but do
NOT fire the parent's EXIT trap, so the dir survives until the parent cleans it —
and the trap's `rm -rf` returns 0, so it never clobbers the script's exit code.
```

### run_capture: terminal codes

```text
Terminal codes off: Pest (colors="true"), jest (FORCE_COLOR, `docker exec -t`) and vitest
(CI set) colour a file too, splitting `Tests` from its count. Probes compare raw output.
```

### Per-runner verdict banner

```text
---- (b)+(c) per-runner verdict: covered | empty-suite | no-behavioral-coverage | unverifiable-suite
```

### parse_<lang>

```text
---- parse_<lang>: CAP and RUN_RC -> verdict, after a run that started and did not time out.
The built-in runner and --runner-for share them, so a replacement must show the evidence the
built-in would have: a `docker exec` into a stopped container exits 1 with no count, and read
covered while --runner-for skipped this. Each also takes the count line of the language's
sibling runners (unittest, minitest, nextest, gotestsum, bun, Playwright), which a
replacement is often for.
```

### parse_py: pytest -qq

```text
`pytest -qq` prints no summary line, only its progress line (`....F  [100%]`): a pass or
fail letter there is the count.
```

### verdict_js: tests N

```text
'tests N' alone is not trustworthy: some node versions count an empty file or a
skip-only suite as 'tests 1'. Cross-check the executed counts (pass+fail+todo)
from node's summary — zero executed assertions => empty, whatever 'tests N' says.
```

### verdict_pkg: --passWithNoTests

```text
--passWithNoTests disables the very empty-suite signal this gate relies on:
jest then prints a GREEN "Test Suites: 1 passed" line while running zero tests.
A suite whose runner is invoked with it cannot be verified — fail closed.
```

### parse_js: the jest Tests: label

```text
The jest "passed count" must follow jest's own 'Tests:' label with only counts between,
so a "Test Suites: 1 passed" line (printed even for an empty --passWithNoTests run)
can NEVER satisfy coverage, and a workspace prefix (`web:test: Tests: …`) still can.
Mocha's "N passing", node/TAP "tests N", bun's "Ran N tests" and a line that opens
with "N passed"/"N pass" (Playwright, bun) remain.
```

### parse_go: build failed

```text
A build/setup failure runs ZERO tests yet prints 'FAIL pkg [build failed]';
route it to unverifiable-suite BEFORE the covered check so it never reads green.
```

### parse_go: covered before empty

```text
COVERED is checked BEFORE empty: in a multi-package module one package can have
passing tests ('ok') while another has none ('[no test files]'). Any real result
line proves tests ran, so empty is declared ONLY when no result line exists.
Result lines only: a bare `^---` or `^ok` also matched a wrapper's own banner
("--- :go: unit tests") above a docker error, and read covered.
```

### php / rs / rb / java

```text
---- php / rs / rb / java (SW 1, 2026-09-22) --------------------------------
Each follows the SAME three-step shape as py/js/go above and must: (1) declare
no-behavioral-coverage when no own-test exists statically, (2) declare
unverifiable-suite when the runner binary is absent — never a silent pass, and
(3) check its EMPTY signal BEFORE its covered signal wherever the empty output is
unambiguous, and AFTER it wherever a multi-target runner can print both (rs, like go).
Unparseable output is unverifiable-suite. The table in
skills/behavioral-gate/references/runners.md mirrors these; this script is the
source of truth.
```

### parse_php: the covered signal

```text
PHPUnit green: "OK (5 tests, 9 assertions)". PHPUnit red and Pest both print a
"Tests:" summary line carrying a non-zero count.
```

### parse_rs: compile error

```text
A compile error runs ZERO tests while printing a non-zero exit; route it to
unverifiable BEFORE anything else so it never reads green (same trap as go's
'[build failed]').
```

### parse_rs: covered before empty

```text
COVERED before EMPTY, as with go: a crate has one 'test result:' line per target
(lib, each bin, each integration test, doc-tests), so a 0-passed line sits beside
a real one routinely. Empty is declared only when NO target passed anything.
```

### parse_rb

```text
"0 examples, 0 failures" is the empty signal and it is unambiguous — rspec prints
exactly one summary line per run — so it is checked first.
```

### verdict_java: --rerun-tasks and wrapper order

```text
--rerun-tasks on the Gradle path, measured 2026-09-22: a plain `gradle test` on an
already-built tree prints `> Task :test UP-TO-DATE` and executes NOTHING, and the
gate is run from a copied checkout that carries build/ — so the second invocation of
an honest green suite failed. Forcing the task is what makes the Java arm passable
at all. Cost: the compile is redone (0.6s on the probe fixture; minutes on a large
module, which is what BEHAVIORAL_GATE_TIMEOUT is for). Maven's surefire always runs.
BOTH wrappers before EITHER system binary. A project that ships ./mvnw is a Maven
project, and a `gradle` that happens to be on the developer's PATH has no business
building it — checking the system binary first ran the wrong build system whenever
both were present.
```

### parse_java: the empty signals

```text
Surefire's empty signal is "Tests run: 0"; Gradle's is a test task that found no
source. A task reported UP-TO-DATE executed nothing THIS invocation, which is not
a pass either — name --rerun-tasks rather than guess.
```

### parse_java: defensive UP-TO-DATE

```text
Defensive: --rerun-tasks above should make this unreachable on the Gradle path, but a
wrapper or init script can still skip the task, and a skipped task is not a pass.
```

### parse_java: Gradle's weak signal

```text
GRADLE'S WEAK SIGNAL, stated rather than hidden. `gradle test` prints no counts at
all on a green run — only "BUILD SUCCESSFUL" (verified against Gradle 9.7.1,
2026-09-22) — so for that one path the gate falls back to "test sources exist
(checked above) and the test task did not fail". That is weaker than every other row
in this file. Two ways past it, both named in runners.md: a suite whose tests are all
filtered out by a --tests selector, and a build that sets failOnNoDiscoveredTests to
false (on Gradle 9 the default TRUE turns a zero-discovery run into the build failure
matched as empty-suite above — that default is doing the empty-detection here).
Only for the built-in run, which checked test sources first: a --runner-for command's success
line can come from a build that never ran a test, so a replacement must print a count.
```

### verdict_custom

```text
--runner '<cmd>::<empty-output-regex>'. The CALLER owns the empty signal here, which
is the whole point and also the whole residual: a regex that never matches turns an
empty suite into a green one, and nothing in this script can tell. What the gate
still owns is the pair of failures a declaration cannot paper over — a command that
never started (126/127/signal) and one that hung (124). Under --runner-for, parse_<lang>
then decides.
```

### Entrypoint smoke and differential dead-flag

```text
--- entrypoint smoke + differential dead-flag (card 07) --------------------
Own-tests + zero-check above establish that a runnable behavioral suite EXISTS
and is NON-EMPTY. Card 07 hooks in HERE: for each declared shell entrypoint,
 (a) SMOKE it in a non-destructive form (--help) and assert it boots — a
     crash-on-invoke is exit 2 entrypoint-error.
 (b) DIFFERENTIAL: for each --differential 'flag::with::without', run the
     entrypoint WITH the flag and WITHOUT it and assert the observable output
     differs AS DECLARED (with-marker only-with, without-marker only-without).
     A flag whose presence changes nothing is exit 2 dead-affordance. This is a
     DIFFERENTIAL check, not "assert not error" — a silent no-op flag boots fine.
 (c) A .md entrypoint is a command/skill prompt doc, NOT a shell binary: it is
     reported (not-shell-smokable -> routed to B2/review) and NEVER executed,
     NEVER silently passed, NEVER failed.
Reuses the card-06 isolation/timeout helpers (run_capture / run_with_timeout).
```

### smoke_entrypoints: markdown

```text
(c) markdown prompt doc — do NOT execute; report + route (not a silent pass)
```

### smoke_entrypoints: (a) SMOKE

```text
(a) SMOKE: non-destructive probe under hard timeout; assert it boots (non-error)
```

### smoke_entrypoints: usage exit vs crash

```text
A hard crash — killed by signal (>=128), not-executable (126), not-found
(127) or timeout (124) — is a genuine entrypoint-error. But a conventional
--help/usage handler may print usage and exit with a SMALL non-zero code;
that is not a crash. Distinguish by whether usage/help text was printed.
```

### smoke_entrypoints: empty markers

```text
An empty with/without marker makes 'grep -qF -- ""' match every line, so an
unwired flag would spuriously read as observable — reject it as a usage error.
```

### smoke_entrypoints: marker direction

```text
with-marker must appear WITH the flag and NOT without it; without-marker vice-versa
```

## plugins/task-runner/scripts/check-receipt.sh

### Header

```text
check-receipt.sh — `run` runs a check from the repo root and records it in .claude/task-runner/receipt.json; `check` says if it still holds.
Fresh: same HEAD, exit 0, its own log ending `exit 0`, and an unchanged digest of tracked changes, untracked files and root .env* files.
```

## plugins/task-runner/scripts/code-redteam-diff.sh

### Header

```text
code-redteam-diff.sh — deterministic core for the code-redteam skill.

Two modes:
  --base <git-ref> [--paths <glob>...]
      Print `git diff <git-ref>..HEAD`, optionally scoped to the given paths.
      This is the exact code slice the refuter panel is fed.
  --dedup <seen-file>
      Read a findings list on stdin (one per line, format: file:line<TAB>title)
      and print only the NOVEL findings — those whose file:line plus normalized
      title does not already appear in <seen-file> (same format). SEEN means
      seen, so <seen-file> holds every previously confirmed finding.

Exit codes: 0 normal, 3 usage error.
```

### normalize_title

```text
Normalize a finding title: lowercase, collapse whitespace runs, trim ends.
Keeps dedup stable across trivial title rewording between rounds.
```

### key_of

```text
Turn a raw "file:line<TAB>title" line into its dedup key
"file:line<TAB>normalized-title". A line with no tab keys on itself.
```

## plugins/task-runner/scripts/dispatch-lint.sh

### Header

```text
dispatch-lint.sh — mechanical contract check over ONE drafted subagent prompt.
Usage: dispatch-lint.sh [file]   (reads stdin when no file is given)

delegation-contracts § Prompt contract names six elements; four are
string-checkable and this lint checks exactly those:
  1. an absolute path            (fresh context — relative paths are coin flips)
  2. a scope lock                (what NOT to touch, stated)
  3. a required return shape     (format/cap stated, not hoped for)
  4. the closing data instruction ("final message is data", no-preamble)
The other two (constraints/conventions, the done-when) are not string-checkable — judgment owns them.

Exit 0: all four present. Exit 1: each missing element printed.
Residual: presence-of-phrase, not quality-of-contract — a scope lock that
locks the wrong scope passes. The delegation-contracts skill's reader judges that part.
```

## plugins/task-runner/scripts/reduction-record.sh

### Header: THE POINT, the three traces, standing

```text
THE POINT. Every one of these is legitimate sometimes. None of them is legitimate
silently: the failure this exists to prevent is the one that already happened —
reviewers dropped on 7 of 8 cards to save context, reported as "all 8 done", found
only because the user asked afterwards.

So a reduction leaves three traces: this record (which candor's Stop gate counts and
whose existence makes the closing report's disclosure mandatory), the reason echoed
to stderr at the moment of the decision so it lands in the transcript where it
happened, and — in an interactive session — a permission prompt from
hooks/rv-consent.sh before the record exists at all.

The reviewer pass has its own recorder (review-skip.sh) because it is counted per
card against cards_done; this one covers the reductions that are not per-card.

Standing: recorded. The reason is model-authored and nothing here can check it. What
is mechanical is that the reduction cannot be invisible.
```

### ROOT_DIR

```text
Anchored at the repo ROOT, not the shell's cwd: a `cd sub && ...` invocation wrote the
record where the completion gate never looks, so the count came up short and blocked
the run.
```

### The evidence check

```text
Checked before anything is written: a record naming evidence that is not there reads
as proof to whoever opens it later. Relative paths resolve against the shell's cwd,
like any argument; both sides are compared physically (pwd -P), so /tmp vs
/private/tmp on macOS cannot fail a path that is inside the repo.
```

### The state root's .gitignore

```text
The run's state root ignores itself (see hooks/scope.sh); only when this record
lands under the default .claude/task-runner/, never under a --record-dir override.
```

### esc

```text
Strips control characters as well as escaping: a newline in --reason wrote a record
that is not valid JSON, which nothing reads back today but breaks the first tool that does.
```

## plugins/task-runner/scripts/register-run.sh

### Header

```text
register-run.sh — register a task-runner run; the one writer of
.claude/task-runner/active-run.json.
```

### Header: WHY A SCRIPT, WHAT IT DOES

```text
WHY A SCRIPT. Registration was prose in /task-runner:run step 1 only. A handoff that
invoked the task-execution skill directly skipped it: no active-run.json, so the review
observer recorded 0 of 22 reviews, candor's completion clause never armed, and the run
closed over a red behavioral-gate verdict. /task-runner:run step 1, the task-execution
skill's step 1 and /task-runner:plan's "Run now" all call this now;
scripts/__tests__/register-run.test.sh pins the three call sites.

WHAT IT DOES:
  1. RESUME. An index run's active-run.json on this branch with the same slug and index is
     kept untouched: its mtime is the cutoff every completion-gate record is counted from, so
     re-registering a run already under way would discard the records of its done cards.
     --fresh registers anew anyway. An inline run (no --index) always registers anew: its
     slug is only a name, `run` when none is given, and a match would adopt an abandoned
     run's records.
  2. FRESH. Deletes gate-pass.json, bg/bg-<HEAD>.json and closed-run.json (candor's gate
     trusts the first two when they name HEAD, whatever their age), creates rv/ rt/ bg/
     nc/ reductions/ (each arms one completion-gate check by existing) and a .gitignore of
     `*`, then writes {"slug","base","branch","start_sha"[,"index_path"]}. base is the
     merge-base with the default branch; start_sha is HEAD now, the range a stacked branch
     actually adds, which the run-close range review reads.
  3. Writes the arc phase sentinel `build` with taskmaster's phase-sentinel.sh (the
     source-checkout sibling, else the newest installed copy), else by hand.
  4. Seeds env-notes.md when absent, kept across runs: the environment facts every worker
     reads first (the discipline preamble names it). Dispatches each re-pasted a ~1.5k-char
     environment block, and four that lacked "never read .env" grepped it (2026-10-13 retro).
```

### Header: misses

```text
Misses: whether the model runs the line it reads (agent-graded); a sentinel written by
hand, which carries no start_sha and so does not arm the range-review check.
```

### The branch read with symbolic-ref

```text
symbolic-ref, not --abbrev-ref: a tag with the branch's name made that print `heads/<branch>`.
Exit 1 is a detached head; any other failure records no branch, which every reader takes as a match.
```

## plugins/task-runner/scripts/negative-control.sh

### Header

```text
negative-control.sh - B3(b) isolated red-before-green control.

Proves a Verify command CAN fail (goes RED by an ASSERTION failure) against a
targeted disabling of the feature, in an ISOLATED COPY so the live working tree
is never mutated. A red caused by a build / collection / import error is NOT a
valid control (the check never reached an assertion) and is rejected.
```

### classify_red

```text
classify_red: read a run's combined stdout+stderr on stdin; print one of
  collection | build | assertion | unknown
Precedence is ASSERTION-MARKER-FIRST so a genuine assertion failure whose
*message* merely contains a build/collection word (e.g. a test asserting on
the string "SyntaxError") is NOT swallowed by the build/collection substring
match:
  1. HARD assertion markers that never appear in a pure build/collection run
     (AssertionError, ERR_ASSERTION, go `--- FAIL:`, pytest `^E +assert`, TAP
     `not ok`, jest expect()/Expected:/Received:) -> assertion.
  2. else collection/import substrings -> collection.
  3. else build/compile/syntax substrings -> build.
  4. else generic per-test fail glyphs (✖ / ✗) that runners such as
     `node --test` ALSO print for build failures -> only here, with no
     build/collection signature present, do they mean assertion.
  5. else unknown (still a valid discriminating red - see the caller).
Signatures verified against real output of `node --test` and `pytest`.
```

### classify_red: tier 1, hard assertion markers

```text
1) HARD assertion markers FIRST: these strings never appear in a pure
   build/collection error, so matching them here cannot misfile a build red.
   `not ok ` is deliberately NOT here — see tier 4. TAP prints it for ANY
   failing subtest, a load/build failure included, so it is a generic fail
   glyph and not a hard assertion marker.
```

### classify_red: tier 2, collection

```text
2) collection / import errors (pytest ERROR collecting, python ImportError,
   node MODULE_NOT_FOUND / Cannot find module, go missing package)
```

### classify_red: tier 3, build

```text
3) build / compile / syntax errors
```

### classify_red: tier 4, generic fail glyphs

```text
4) generic per-test fail glyphs, meaningful ONLY once build/collection are
   ruled out. `node --test` prints ✖ for build failures too, and under its TAP
   reporter (the non-TTY default on older Node) the same failure prints
   `not ok 1 - <file>` — which is why the reporter node happens to pick must
   not change the verdict. Both live here, after the build/collection checks,
   never before them.
```

### Per-card record support

```text
Per-card record support: when --record-dir + --card are given, a PASS (exit 0)
writes nc-pass-<card>.json mechanically — a record authored by this tool, not
the model. --skip records a documented non-run (manual/visual card) as
nc-skip-<card>.json; the reason is model-authored, but at least it is an
auditable artifact the completion gate can count. Card ids are path-safe only.
```

### SRC

```text
SRC is the subtree that gets copied+isolated; --target is resolved under it. With
the default --root '.', SRC is CWD and behavior is byte-identical to the old form.
```

### Isolate banner

```text
---- isolate: copy the working tree (minus .git) into two fresh temp copies ----
```

### Mutate banner

```text
---- mutate the RED copy's impl only ----
```

### Run Verify banner

```text
---- run Verify in each copy ----
```

### Decide: exit 4

```text
exit 4 is reserved STRICTLY for a red POSITIVELY identified as a
build/collection/import error - the check never reached its behavior.
```

### Decide: an unknown red

```text
unknown red: a discriminating failure whose runner signature is outside the
allowlist (TAP `not ok`, a plain `exit 1` with a diff, a bespoke shell
assert). It is NOT a build/collection error, so the Verify DID discriminate
(mutated RED, unmutated GREEN). Treat it as a valid assertion-style red
rather than parking a working control. (Fix 2)
```

## plugins/task-runner/scripts/review-diff.sh

### Header: WHY

```text
WHY. The reviewer agents hold Read, Grep and Glob: no shell. Dispatches said "review the
diff" and never delivered one, so reviewers re-read whole files (1.4M to 16M cache-read
tokens a review), compared against memory or another checkout, and skipped the history
pass their rubric asks for; a hand-made patch file then drew patch-line citations.
The orchestrator runs this before each RV-CARD dispatch and names the printed path in it.
(The run-close range review is /code-review:review, which writes its own.)
```

### Header: misses

```text
Misses: a rename reads as a delete and an add; a binary file is named, not shown; a path
git quotes (spaces, non-ASCII) gets no blame; lines a hunk only adds have no history.
```

## plugins/task-runner/scripts/review-skip.sh

### Header: the reason is model-authored

```text
The reason is MODEL-AUTHORED and this script cannot check it. What it does buy: the
reason is echoed to stderr the moment the skip happens, so it lands in the transcript
at the point of decision instead of being reconstructed later — the disclosure the
original incident never made. Standing: recorded.
```

### ROOT_DIR

```text
Anchored at the repo ROOT, not the shell's cwd: a `cd sub && ...` invocation wrote the
record where the completion gate never looks, so the count came up short and blocked
the run.
```

### The state root's .gitignore

```text
The run's state root ignores itself (see hooks/scope.sh); only when this record
lands under the default .claude/task-runner/, never under a --record-dir override.
```

### esc

```text
Strips control characters as well as escaping: a newline in --reason wrote a record
that is not valid JSON, which nothing reads back today but breaks the first tool that does.
```

### The stderr disclosure

```text
Loud on purpose: this line is the mid-run disclosure. A skip the user only learns
about when they ask is the failure this whole mechanism exists to prevent.
```

## plugins/task-runner/scripts/sweep-residual.sh

### Header

```text
Sweep-migration residual gate. Freezes the target set of an at-scale mechanical
change, then RE-MEASURES it after the edits and fails while occurrences survive.

WHY. Given "migrate every axios call to fetch" on a tree with twelve occurrences
— three behind an aliased import, one built dynamically, one in a CI YAML, one in
a test fixture — a competent model greps `axios.`, edits what it found, runs a
green suite (the alias path has no test), and reports the migration complete. The
failure is not knowledge. Nothing forces a SECOND measurement after the edits,
and nothing demands that a surviving occurrence be justified in writing. This is
that second measurement.
```

### Header: the state root

```text
the git toplevel of --dir (else --dir itself), like reduction-record.sh: `--dir src` or a
run from a subdirectory used to leave a stray src/.claude/ state dir beside the code.
```

### Header: HONEST LIMITATIONS

```text
HONEST LIMITATIONS. The freeze records the file list and a tree hash, not file
contents, so a file edited between freeze and measure is expected — that IS the
work. Detection is one ERE over text: a call constructed entirely at runtime from
pieces no regex spans is invisible here, which is exactly why the enumeration
step below asks for FOUR passes rather than one, and why the allowlist demands a
written reason instead of a suppression comment.
```

### default_find: non-code carriers

```text
Non-code carriers are IN SCOPE on purpose. A migration that leaves the old name
in a CI workflow, a fixture, a doc example or an i18n catalogue is not finished —
and those are precisely the files a code-shaped grep skips.
```

### Target set moved

```text
Target set moved: new files carrying the pattern that were not frozen. A file
added mid-run is the case a one-shot grep cannot see at all.
```
