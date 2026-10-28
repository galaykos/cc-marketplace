# task-runner hooks: the comment text moved out of the code (2026-10-28)

The text below was moved verbatim on 2026-10-28 from the hooks named in the `##` headings, with only each comment's `# ` leader (and the indentation before it) removed. Each `###` block is a comment block, or a contiguous part of a header, as it stood; the file kept a short summary in its place (a header of at most three lines, a one-line trap), or nothing where the code already says it. A pointer by name was left in each file's header, `# Why, limits, history: rationale/derivations/plugin-task-runner.md § <path>`. Standing: `recorded` — no gate reads this file, and its dates, measurements, line citations and file names are as they stood on the day it moved.

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
