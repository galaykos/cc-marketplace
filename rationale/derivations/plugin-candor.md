# candor: the comment text moved out of the code (2026-10-04)

The text below was moved verbatim on 2026-10-04 from the files named in the `##` headings, with only each comment's `# ` leader removed; the lines each file kept are not repeated here. A pointer by name was left in each file, `# Why, limits, history: rationale/derivations/plugin-candor.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

## plugins/candor/hooks/gate.sh

### Header: the shebang

```text
Absolute-path shebang, not `/usr/bin/env bash`: the fail-open guarantee must
hold under a stripped PATH where `env bash` exits 127.
```

### Header: the five clauses

```text
candor-gate — THE Stop gate of this marketplace: five clauses, each falsifiable
on disk or in the transcript, none a tone judgement (tone is measured by
/candor:check and blocked by nothing). Until 2026-09-14 clauses 3 and 4 were two
sibling scripts, code-architecture/hooks/evidence-gate.sh and
task-runner/hooks/completion-gate.sh; each had grown a namespaced disarm so the
others could not spend its enforcement through the SHARED stop_hook_active
flag. One script needs no such protocol: it records WHICH clause blocked and
skips only that clause on its own continuation.

  CLAUSE 1 — FABRICATED CITATION. The final assistant message contains a
  `path/to/file.ext:NNN` reference that does not resolve: no such file under
  cwd or the state root, or the file has fewer lines than the number cited. A file:line citation
  asserts "I read this"; when it resolves to nothing, that assertion is false
  and a script can prove it.

  CLAUSE 2 — UNEVIDENCED REVERSAL. The last user message is BARE pushback —
  challenge-shaped ("are you sure?", "that's wrong", "nope"), carrying no
  correction of its own — and the final assistant message retracts ("you're
  right", "my mistake") while NO tool ran after that pushback and the message
  states no basis for the change. Sycophancy with the evidence step skipped.

  CLAUSE 3 — NAKED COMPLETION CLAIM (was code-architecture's evidence-gate).
  The assistant tail claims completion (done, fixed, implemented, verified,
  passes …), files were mutated this session, and NOTHING was executed after
  the last mutation — no test, no build, no lint, not even running the code.
  The exact shape of the later apology "you're right, I didn't actually do it".
  The escape is honesty: prose naming what is unverified passes.

  CLAUSE 4 — REGISTERED RUN NOT COMPLETE (was task-runner's completion-gate).
  A task-runner run REGISTERED itself (<root>/.claude/task-runner/active-run.json,
  <root> per STATE ROOT below) and is stopping without a recorded behavioral-gate
  pass for the current HEAD, with cards neither done nor parked, with per-card
  negative-control or reviewer records short, with a red-team panel short on a
  boosted run, or with a recorded reduction its closing report never names.
  Dormant outside a registered run, on another branch, and without git — exactly
  as before. The no-gate-pass branch alone also stands down while a worker is in
  flight (IN-FLIGHT WORKERS below).
```

### Header: what no other gate carries

```text
WHAT NO OTHER GATE CARRIES (Admission law — .claude/skills/authoring-skills/SKILL.md
in the marketplace repository, "The four laws"): this repo's scripts/done-gate.sh
is marketplace-specific and gate-status based; this hook ships with the plugin
and works in any project, git or not (clause 4 alone needs git, and stands down
without it).
```

### Header: LIMITATION

```text
LIMITATION (honest scope — the four laws, "Honest limitation"):
  - CLAUSE 1 checks `file:line` ONLY, never a bare path — a bare path is
    routinely a file the turn PROPOSES to create. An invented API name,
    package, flag or function is NOT caught; only an invented location is.
  - CLAUSE 1 fires on an invented FILENAME, not a wrong directory (see the
    ladder in resolve() for the measurement that forced that scope).
  - CLAUSE 1 cannot see intent: a citation into a file the turn itself just
    shortened, deleted or renamed blocks though the model did read it. An
    elided path (`plugins/x/.../SKILL.md:74`) is skipped, never resolved.
  - CLAUSE 2's pushback test is a regex over one message. Pushback phrased
    outside the list is invisible; a user message carrying its OWN correction
    deliberately disarms the clause. ANY tool call after the pushback counts.
  - CLAUSES 1 and 2 judge the FINAL assistant message only (on SubagentStop,
    clause 1 judges the hand-back first — SUBAGENT REPORTS below); clause 3 matches
    CLAIM and ACK over the last 30 lines of assistant text, and that window
    bleeds in BOTH directions (measured; documented in the clause).
  - CLAUSE 3: saying nothing evades it; ANY post-edit execution satisfies it
    (a `git status` counts — it proves something ran, not the right thing); an
    Agent/Task call counts as execution. Edits to PROSE files (.md, .txt, .rst,
    .adoc) do not arm it — nothing executable proves a README right — so a
    docs-only turn that says "done" passes on the claim alone.
  - CLAUSE 4 enforces only a run that REGISTERED itself. A run that never
    writes active-run.json is not enforced (fail-open) — the same residual the
    behavioral-gate skill names. It never executes tests: it is a records check.
  - CLAUSE 4's record counts (nc/, rv/, rt/ lenses and critic, reductions) count
    only files NEWER than active-run.json, so a record left by a previous run
    cannot cover this one — card ids repeat across runs and those dirs are never
    cleared. nc/ was the one count missing that bound until 0.3.7. The residual
    runs the other way: a legitimate record written BEFORE the run registered
    itself is invisible, which blocks rather than passes.
  - Tone — flattery, defensiveness, apology spirals — is NOT gated. No regex
    separates "you're right" said because it is true from the same words said
    to please. /candor:check measures it; the straight-talk skill is where the
    rule lives.
  - Transcript tail only (last 4000 entries).
  - One block per distinct final text (clauses 1-3, state marker) or per HEAD
    (clause 4, nudge marker newer than the sentinel), so no disagreement loops.
```

### Header: fail-open, the exit-2 channel and MODES

```text
FAIL-OPEN on missing jq, an unreadable transcript, or empty text.

A Stop hook reaches the model only via exit 2 with the reason on stderr; this
uses exit 2. Exit 0 prints into a turn that has already ended.

MODES:
  CC_CANDOR_GATE=block (default) | warn (print, never block) | off — the whole gate
  CC_EVIDENCE_GATE=block | warn | off          — clause 3 only (kept from evidence-gate)
  TASK_RUNNER_STOP_GATE=block | warn | off     — clause 4 only (kept from completion-gate)
  Unset, each of these and CC_LOCKFILE_GATE read the /config option of its lower-cased name.
```

### Header: SUBAGENT REPORTS

```text
SUBAGENT REPORTS (SubagentStop, 0.2.0). The same script is wired to
SubagentStop; a subagent's final report goes through CLAUSE 1 before the main
thread quotes it as fact (exit 2 blocks the subagent as it blocks a Stop). On
2.1.284 (two general-purpose subagents, headless; other agent types and interactive
sessions not measured) the report is a SubagentHandback tool_use in the agent's own
transcript (input.message), already written when the hook fires, and last_assistant_message
holds only the closing text after it (rationale/candor-subagent-probe-2026-09-29.md;
2.1.267 put the report in last_assistant_message). So CLAUSE 1 reads, first
non-empty wins: the last SubagentHandback input.message in agent_transcript_path,
then last_assistant_message, then the last assistant text block of the transcript.
Unmeasured: whether that exit 2 withholds a hand-back the tool call already delivered.
Only a hand-back after the tail's last user-text entry counts: on 2.1.286 a resumed agent
appends to the same transcript after one, and none followed a hand-back within a turn
(one run, one post-hand-back window on 2.1.286; the 2.1.284 probe recorded no entry order —
rationale/candor-resumed-subagent-probe-2026-09-30.md). User-text = type "user", string
content or its first text block, no tool_result, not an isCompactSummary entry, and not
starting (after any leading whitespace) <system-reminder>, <task-notification>,
"[SYSTEM NOTIFICATION" or "Stop hook feedback:". isMeta is not consulted — the resume
boundary carries it too. Hook additionalContext lands as "attachment" entries, never "user"
(SubagentStart and PostToolUse, before and after a hand-back; 2.1.286, one run —
rationale/candor-subagent-context-probe-2026-10-01.md), so the type test excludes it.
Residuals: a host or event writing it as a "user" entry after a hand-back would hide it; the file
can lag the payload, so a resume whose boundary is unwritten is judged on the earlier hand-back.
CLAUSES 2-4 disarm for a subagent: it has no user turn to push back, and its
transcript is not the session that edited files or registered a run. Markers
are suffixed per agent so a subagent block never spends the main thread's disarm.
```

### Header: ORDER

```text
ORDER: 4, 1, 2, 3. Clause 4 first because it is the most specific context (a
live run) and needs no transcript, so a run that stops with no transcript_path
in the payload is still held. Only one verdict BLOCKS per stop — but a clause
that has spoken without blocking does not silence the others. Clause 4 bounded
at this HEAD (or in warn mode) prints its nudge and clauses 1-3 still run: on
master these were three independent Stop hooks, each evaluated on every stop,
and the first merge (0.3.0) let clause 4's verdict occupy the only slot for the
rest of a HEAD — every card of a live run went uncovered for fabricated
citations, bare reversals and naked completion claims after its first block.
```

### Header: IN-FLIGHT WORKERS

```text
IN-FLIGHT WORKERS (0.5.0). Clause 4's no-gate-pass branch does not block while this
session has a background worker running. Measured 2026-09-25
(rationale/2026-09-25-session-plugin-usage-review.md, finding 4): 47 completion-gate
blocks in one orchestrated run, almost every one while workers were in flight, each
answered "No card can start yet…" — a turn that bought nothing, and the pressure the
model named ("a hook kept pressing me to close it") before the 2026-09-24 .env
overwrite. A worker's hand-back wakes the orchestrator anyway. Two sources:
  - The host's `background_tasks` array on the Stop payload, entries of type subagent
    or teammate. Probed live on CLI 2.1.282: a Stop taken while a background agent ran
    listed {"id":<agent_id>,"type":"subagent","status":"running",…}; the Stop after its
    hand-back no longer did. When the array is PRESENT it is authoritative — a worker
    killed without a SubagentStop (usage limits killed three in one measured session)
    leaves it at once.
  - Records, when the array is absent (an older CLI; the hooks reference says it is
    present only "when the task registry is reachable"): hooks/preamble.sh writes one
    per SubagentStart, this script removes it on SubagentStop and puts it back when it
    BLOCKS the subagent, which then keeps running. A record older than 180 minutes is
    swept and not counted; the cutoff is what bounds a worker that died silently.
The records are keyed on the hashed session_id under $TMPDIR, not under the state root.
The same probe showed SubagentStart, SubagentStop and Stop carrying ONE session_id and
ONE transcript_path — the parent's. A subagent's cwd need not be the parent's, though
(not measured; a worktree-isolated worker is the obvious case), and a state root
resolved from it would put its SubagentStop's delete where the parent's Stop never reads.
RESIDUAL: on an older CLI a worker running past 180 minutes expires and the gate blocks
once per HEAD as before; a session resumed under a new session_id cannot see the old
records; background shell tasks and workflows are not workers here. Only the no-gate-
pass branch consults any of this: a claimed pass with short nc/rv/bg records, a short
red-team panel or an undisclosed reduction still blocks with workers in flight.
```

### Header: STATE ROOT

```text
STATE ROOT (0.5.0). Every state path and project-root read goes through cc_state_root
(the shared block below). The payload cwd follows the model's `cd` (finding 2 of the
same review). The state dir already anchored at the git toplevel, but clause 4 read
active-run.json from the raw cwd — so, by construction, a stop taken from a
subdirectory found no registered run and enforced nothing — and clause 5 read the
manifest at `$cwd/package.json` against `git status` paths that are repo-relative.
Clause 1 still tries a citation against the shell cwd first (a relative path the model
just used there), then against the root, and walks the tree from the root.
Markers: per project under CLAUDE_PLUGIN_DATA (cc_plugin_state); <root>/.claude/candor/ is only the fallback.
```

### In-flight bookkeeping before the off switch

```text
IN-FLIGHT bookkeeping runs BEFORE the off switch: it is not enforcement, and a record
left behind while the gate was off would hold the no-gate-pass branch silent for up to
180 minutes after it is switched back on. Hashed names — neither id lands raw in a path.
Only a record that existed is restored if the gate then blocks this subagent (bottom).
```

### The payload cwd: -d, not -n

```text
`-d`, not just `-n`. The payload cwd is a STRING the host supplies and the mkdir that
creates the state dir below recreated a project directory the user had just deleted,
three levels deep (live repro, AR 1 of the 2026-09-22 panel). A cwd that is not a
directory degrades to the process cwd, which by construction exists. Residual: a cwd
that IS a directory but not this project's still gets a .claude/candor/ — the check
proves existence, never identity.
```

### PER-CLAUSE DISARM and the state dir

```text
PER-CLAUSE DISARM. stop_hook_active is SHARED across every Stop hook: the host
sets it on the continuation after ANY blocking one. A bare exit on it let a
sibling gate spend this one's enforcement (the old completion-gate header records
that exact bug); deleting the exit wedges the session, because clauses 1-3 bound
on a sha of the final text and a continuation is new prose by construction. So
the record names the CLAUSE that blocked, and only that clause stands down on
the continuation — the others still run. Clause 4 never stands down this way:
its bound is the per-HEAD nudge, which is stable across turns.
STATE DIR. Both markers live in cc_plugin_state "$root" candor (the plugin data dir, else
.claude/candor/), which carries a self-ignoring
.gitignore the first time it is created. Until 0.3.2 they were bare files at
.claude/candor-last and .claude/candor-blocked — and showed up as untracked in
every user's `git status` (observed in a live repo, and named as "other plugins'
scratch" by overseer's own acceptance protocol), one `git add -A` away from being
committed. A directory can ignore itself; a bare file cannot.
Anchored at the state root, so a stop taken from a subdirectory does not scatter a
second .claude/candor/ beside it. Until 0.5.0 this line resolved --show-toplevel on its
own while every clause-4 read used the raw cwd (STATE ROOT in the header).
```

### verdict

```text
citation | reversal | evidence | run — set by whichever clause fires first
```

### Section banners

```text
---------------------------------------------------------------------------
CLAUSE 4 — a registered task-runner run that is not complete
---------------------------------------------------------------------------
---------------------------------------------------------------------------
Transcript — clauses 1-3 read it; without one they stand down.
---------------------------------------------------------------------------
---------------------------------------------------------------------------
CLAUSE 1 — citations that do not resolve
---------------------------------------------------------------------------
---------------------------------------------------------------------------
CLAUSE 2 — a position reversed after bare pushback, with nothing re-checked
---------------------------------------------------------------------------
---------------------------------------------------------------------------
CLAUSE 3 — a completion claim with nothing executed after the last edit
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
Bound, record, report.
---------------------------------------------------------------------------
```

### run_clause: a records check

```text
Everything here is a RECORDS check: it never executes the produced tests (the
completion protocol runs behavioral-gate.sh in isolation and records the pass;
this only verifies that record exists for the final commit). It never mutates
the tree; the nudge marker under .claude/task-runner/ is the only thing written.
```

### inflight_count

```text
inflight_count — background workers this session is waiting on (IN-FLIGHT WORKERS in
the header): the host's background_tasks when the payload carries the array, else the
SubagentStart records younger than 180 minutes. Older records are swept here. `-O`: a
records dir another user created under a shared /tmp is not evidence.
```

### run_clause: notes on the no-run and gate-pass returns

```text
no registered run → nothing to enforce
gate pass for THIS commit → allow
```

### run_clause: BRANCH GUARD

```text
BRANCH GUARD: a sentinel is cleared only on clean completion, so an abandoned run
leaves one behind indefinitely. Enforcing it from a different branch would turn a
dead run into a repo-wide trap. A run registered with a "branch" is enforced only
on that branch; a sentinel without one (pre-0.17 registration) keeps the old
unconditional behaviour.
```

### run_clause: card counts

```text
Gate pass recorded for THIS commit. For an index run, run.md also records card
counts; when those numeric fields are present, refuse a clean stop while any
card is neither done nor parked. ALL fields absent → legacy (allow). Partially
present, non-numeric or inconsistent counts are MALFORMED — never a silent allow.
A run REGISTERED as an index run must record counts: counts-absent is a
bookkeeping failure, not legacy.
```

### run_clause: PER-CARD NEGATIVE-CONTROL COVERAGE

```text
PER-CARD NEGATIVE-CONTROL COVERAGE (opt-in by presence of nc/): a complete run
must have one nc-pass or nc-skip record per DONE card. No nc/ dir → legacy allow.
Bounded the same way as rv/ and rt/ below — only records newer than THIS
registration count, and distinct ids (nc-pass-01 + nc-skip-01 is one card).
Until 0.3.7 this count was unbounded while its three siblings were not, so a
record left in nc/ by a PREVIOUS run (card ids repeat across runs, and the dir
is never cleared) satisfied this run's gate for a card that never had a control.
```

### run_clause: PER-CARD REVIEWER COVERAGE

```text
PER-CARD REVIEWER COVERAGE (rv/): records are written by hooks/rv-observe.sh
when it OBSERVES a reviewer dispatch carrying the RV-CARD marker, so the count is
not model-authored. Only records newer than THIS registration count (card ids
repeat across runs), and distinct ids (rv-seen-01 + rv-skip-01 is one card).
```

### run_clause: BEHAVIORAL-GATE EVIDENCE

```text
BEHAVIORAL-GATE EVIDENCE. gate-pass.json is written by the MODEL; bg-<head>.json
is written by behavioral-gate.sh with the verdict it actually reached. With bg/
present (created at registration) a complete verdict must be backed by a matching
record. `covered` and `no-executable-surface` are BOTH passing verdicts — the
second is an honest doc/lint-only change with nothing runnable to prove.
`no-behavioral-coverage` passes ONLY beside a recorded coverage reduction for THIS
HEAD — reductions/coverage-bg-<HEAD12>.json, newer than the sentinel, which is the
exact file task-runner's `reduction-record.sh --kind coverage --id bg-<HEAD12>`
writes. Measured 2026-09-25 (same review, finding 5): a run whose ~40 changed React
files had no JS runner in the project reached this verdict and could not close; the
user's only exit was deleting active-run.json, after which nothing blocked at all.
The reduction keeps the gap visible instead: the DISCLOSURE step below strips the
`coverage-` prefix and requires `bg-<HEAD12>` in the closing report. empty-suite,
unverifiable-suite and any other verdict still block — a runner that exists and
proved nothing is not the same gap as no runner at all.
```

### run_clause: RED-TEAM PANEL WIDTH

```text
RED-TEAM PANEL WIDTH (boosted runs that shipped code). Refuter dispatches carry
RT-LENS markers, the critic RT-CRITIC; rv-observe.sh records them. The degraded
inline fallback is legitimate but must be RECORDED (reduction-record.sh --kind
redteam). A boosted run that touched no code owes no panel; unknown diff → do
not enforce (a missed check costs a check, a false block costs the run).
```

### run_clause: DISCLOSURE

```text
DISCLOSURE of every recorded reduction: the ID of each one must appear in the
closing report. Presence only — this cannot judge whether the disclosure is
honest. What it removes is a cut that happened, was recorded, and never reached
the person reading the report.
```

### run_clause: no gate pass for HEAD

```text
No gate pass for HEAD → the run is not complete. Mid-run and end-of-run both land
here and the hook cannot tell them apart cheaply, so it names BOTH branches.

The gate branch names the exact command and a pace rule. Until 0.4.11 it said
"run behavioral-gate.sh (isolated)" under a "continue NOW" that read as applying to
both branches. On 2026-09-24 an agent at the end of a 44-card run hand-built the
"isolated" checkout in a rush of chained commands. Its worktree call was denied
whole, it read that as "only the cp failed", and its next `cd /tmp/… && …; cp
.env.example .env && php artisan key:generate` ran in the live repo, overwriting the
developer's .env and APP_KEY. Urgency belongs to the cards branch; the gate branch
has no deadline, and a setup step that fails must stop the sequence.

Workers in flight → print, do not block, and write no nudge: the one block this HEAD
owes is kept for the stop after the last worker hands back (IN-FLIGHT WORKERS).
```

### Clause 4 verdict: ONE BLOCK PER HEAD and the named switch

```text
Clause-specific mode kept from the script this clause came from.
ONE BLOCK PER HEAD. The last HEAD blocked on is recorded, and a second stop at the
SAME commit prints without blocking, so a real run is held at every card boundary
(every commit re-arms) while a stale sentinel costs one extra turn per commit. The
marker counts only while NEWER than the sentinel it was written under: nothing
clears it (the run clears active-run.json, not this), so a marker left by run A
must not eat run B's first block at the same HEAD. A same-tick tie fails toward
blocking, never toward silence. Warn mode never writes it.
NAME THE OFF SWITCH IN THE MESSAGE. A Stop gate reaches the reader only through
this stderr, so a var documented anywhere else is a var the person being blocked
cannot find (UX 1 of the 2026-09-22 panel: every PreToolUse guard here names its
own switch, every Stop gate omitted it). One line at the single print site covers
all eight completion-gate reasons, which is why it is here and not in each printf.
No writable marker → no per-HEAD bound this turn. The shared flag is honoured
only here, so an unwritable state dir cannot block the same stop forever.
Bounded or warn: clause 4 has spoken without blocking. Clauses 1-3 still run —
a run held once at this HEAD does not license an invented citation on the next
stop (see ORDER in the header).
```

### The transcript and the judged text

```text
A subagent's report lives in ITS transcript, not the parent's; fall back to the
parent path only when the host sent no agent path (a pre-2.1 payload).
Only a subagent hands back; the main thread's Stop has no report of its own there.
The text CLAUSE 1 judges: the hand-back, else the FINAL assistant text message, whole and
alone. `-s` slurps the JSONL into
an array so "last" is expressible; a malformed line collapses the slurp, which
is a fail-open path and is why the result is tested for emptiness below.
```

### Clause 1: extraction, _find and resolve

```text
URLs are stripped BEFORE extraction: `https://host/a.php:80` is a port, not a
line. The extension must START with a letter, so `v1.2.3:4` and `10:30` never
match, and a short deny-list drops bare host:port forms (`example.com:8080`).
_find <predicate…> — one pruned, depth-capped tree walk. Bounded so a Stop hook
stays cheap on a large repo.
resolve <relpath> — prints one of:
  FILE <path>   the citation identifies exactly one file on disk
  MISSING       no file anywhere in the tree carries that BASENAME
  AMBIGUOUS     the path does not resolve, but the basename is not unique

A FOUR-STEP LADDER, and the last two steps exist because of a measurement, not a
theory. Run over 47 real session transcripts (~3.3k assistant messages), the
earlier two-step version — cwd-relative, then a full-suffix match — reported 98
unresolved citations, and the overwhelming majority were ABBREVIATED paths, not
invented ones: `craft-layer/asset-sourcing/SKILL.md:10` for a file that really
lives at `plugins/craft-layer/skills/asset-sourcing/SKILL.md`. Blocking those is
the false-positive class that gets a gate switched off. So the ladder falls back
to the basename, and only a basename that exists NOWHERE is treated as
fabrication. A real filename under a wrong directory now passes silently, and
that residual is deliberate.
`~/.claude/settings.json:12` is a real location in the user's home. Before
0.3.2 the `~` was outside the extraction class, so the citation was read as
the absolute path `/.claude/settings.json`, resolved to nothing, and blocked —
on the exact file a settings question is answered from.
```

### Clause 2: the user's evidence, HOLD and what ran

```text
Last real user message. Tool results also arrive as type "user"; they carry
tool_result blocks and no text blocks, so selecting text blocks excludes them.
A pushback that ARRIVES WITH ITS OWN EVIDENCE is not the sycophancy setup —
a user who quotes a path, pastes a snippet, or writes a paragraph of reasoning
has supplied the new information, and agreeing with it is reading, not
flattery. Disarm on any of: a backtick, a path-shaped token, a file:line, or
a message long enough to be an argument rather than a challenge.
HOLD — the message did more than fold. Either it names what it re-checked, or
it keeps part of the position. Both are candour; neither is what this blocks.
Did anything run AFTER that user message? One row per entry keeps order
without line numbers: "USER" for a real user turn, the tool names for an
assistant turn, empty otherwise.
```

### Clause 3: the claim window, ACK and prose edits

```text
CLAIM and ACK are matched over the SAME window (the last 30 lines of assistant
text), and the window bleeds in BOTH directions. Measured:
  * ACK bleed — "not tested yet" two messages back licenses a fresh naked
    "Everything is implemented and verified. Done." in this turn.
  * CLAIM bleed — a previous turn's legitimate "All tests pass, done." still
    sits in the window, so a later small edit ending in text that claims
    nothing can be blocked for a claim it never made.
Narrowing ACK to the final message alone was considered and rejected: it would
block honest reports that state the caveat before the summary, and it fixes no
measured escape — those were all same-sentence.
1. CLAIM (cheap): does the assistant tail claim completion? Whole-word via
grep -w (BSD grep has no \b; unanchored 'done' would match 'abandoned').
HONESTY ESCAPE: a turn that names what is unverified or failing is a status
report, not a false claim. The escape must assert something about THIS turn's
verification state. Bare failure nouns (fail/failing/failed) used to be listed
and disarmed the gate on the most common bug-fix shape: "Fixed the failing
test — should work now". A failure named as the thing that was FIXED is part
of the claim. So the failure vocabulary is phrase-scoped — the subject must be
the check ("tests still fail", "the build failed", "two tests are failing") or
a present-tense failure must carry its cause ("fails with ENOENT").
WHAT THIS DOES NOT CLOSE: a completion claim naming a PAST failure with the
check as its subject still escapes ("The build failed earlier; after my fix it
is all good now. Done.") — the same string is how a genuinely red suite gets
reported, and no pattern separates them. This closes the bare-noun class, not
the tense problem.
2+3. MUTATION AND EVIDENCE ORDER: one row of tool names per assistant entry
(blank when none) preserves order without line numbers; awk finds whether an
execution tool ran after the LAST file mutation.
Each mutation token carries the edited file's extension (`Edit@md`), and a
mutation of a PROSE file — .md/.mdx/.markdown/.txt/.rst/.adoc — does not arm
the clause. There is no command whose failure would prove a README typo fix
wrong, so "run something" bought a `git diff` and a turn, never a check; the
same reasoning clause 4 already applies as its `no-executable-surface` verdict.
A mutation with no file_path, no extension, or any other extension (json,
yaml, sh, code) still arms it. RESIDUAL: a prose edit that lies about content
("documented and verified") passes — there was nothing to execute either way.
```

### Clause 5: LOCKFILE DRIFT

```text
CLAUSE 5 — LOCKFILE DRIFT. A dependency manifest was edited in this turn and the
lockfile it governs is not in the working tree's changes. The install step was
skipped, and the next person to clone gets a tree whose manifest and lockfile
disagree — a CI failure attributed to them, not to the turn that caused it.

WHY A CLAUSE AND NOT PROSE. `stack-scan:package-hygiene` states the rule already:
hand-editing a manifest without running the installer is a defect. The model
agrees and then does it anyway, because adding a dependency line LOOKS complete —
nothing in the edit's own result says a second step is owed. This clause is the
only thing in the tree that reads the pair.

WHY IT CANNOT FALSELY FIRE ON A DELIBERATE MANIFEST-ONLY EDIT: it requires a
dependency-shaped change. Bumping a `version` field, editing `scripts`, or
rewriting a description never touches a lockfile and never arms this.

Last of the clauses because it is the cheapest to satisfy and the least severe:
a citation or a naked completion claim is a false report, this is an unfinished
step.

`$skip` is LOAD-BEARING and was missing in the first version of this clause: without
it the clause re-fires on its own continuation, and because the loop guard keys on the
final assistant TEXT, a second turn with different text blocks again — so the escape
this clause's own message offers ("say plainly that the lockfile is deliberately
unchanged and why") could never be taken, and the turn was unblockable. Found by a
branch review before merge; clauses 1-3 each carry the same term at :387, :470, :537.
[Editor's note (2026-10-04): these $skip tests now live in clause_fabricated_citation, clause_unevidenced_reversal, clause_naked_completion and clause_lockfile_drift.]
manifest -> the lockfile(s) that satisfy it. First match wins per manifest.
A DEPENDENCY-shaped change only. For a JSON manifest this compares the parsed
dependency maps at HEAD against the working tree, because a line diff cannot:
package.json is frequently one line, so bumping `version` rewrites the same
line that holds `dependencies` and every version bump would block. (The
harness caught exactly that; a hand test missed it because the loop guard was
still holding the previous verdict.) Non-JSON manifests keep the line-diff
heuristic — their dependency sections are line-oriented by construction.
Unparseable either side → fall through to the line heuristic rather than
silently allowing: a manifest mid-edit is exactly when this matters.
A DEPENDENCY line, not any line. The first version armed on `^[+-]`, so a
version bump in pyproject.toml, a `[tool.ruff]` edit, or a comment added to
a Gemfile all blocked a Stop — measured in a branch review before merge,
and the exact false fire the header above promises cannot happen. Each
manifest's dependency grammar is line-oriented, so a line test is the right
shape; it just has to test the right lines. Residual, stated: a dependency
written in a form none of these patterns matches arms nothing, which is the
safe direction for a Stop-tier block.
TOML's `key = "value"` is ambiguous at line level: `requests = "^2.28"` is a
poetry dependency and `version = "2.0.0"` is metadata, and a line regex
cannot see which table it sits in. So the metadata keys are excluded by
name — a short, closed list — rather than guessed at.
```

### Bound, record, report

```text
Effective mode for the clause that fired: the whole-gate mode, then the
clause-specific override kept from the script that clause came from.
LOOP GUARD for clauses 1-3: block once per distinct final text. The marker is
state a mid-work turn cannot fake — a genuinely new turn produces new text.
No marker means no per-text bound this turn. THIS is where the shared flag
earns its keep: without both, a gate that blocks on unwritable state blocks
the same turn forever. Honouring it only here costs at most one unenforced
stop on an already-degraded setup.
```

## plugins/candor/hooks/mode.sh

### Header: the shebang

```text
Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
even under a stripped PATH where `env bash` exits 127.
```

### Header: the two jobs

```text
UserPromptSubmit, two jobs:
  1. Level switching — `/candor:level <lite|full|ultra|off>` and the few natural
     phrasings for it. The hook owns the state write, not the model: a mode that
     depends on the model remembering to run a command is not a mode.
  2. Per-turn reinforcement — one compact line while a level is active.
```

### Header: why reinforce the shape and not the wording

```text
WHY REINFORCE THE SHAPE AND NOT THE WORDING. The mode this replaces re-injected
"drop articles/filler/pleasantries/hedging" on every prompt: the one layer that
already worked. Measured over three long sessions of it, mid-turn lines held at
17-265 characters while turn-final messages ran 1,194-4,447 — the drift is in
message SHAPE, so the reminder carries budgets and the report skeleton instead.
```

### Header: LIMITATION

```text
LIMITATION (honest scope):
  - Advisory. `additionalContext` is not a blocking key; this can inform a turn,
    never stop one.
  - Costs ~150 tokens of input per prompt while active — measured 2026-09-15 by
    driving this hook: 596-597 chars at lite/full/ultra, 693 at a wenyan level
    (~173 tok), and nothing when off. It read "~120 tokens (476 chars)" until the
    findings-cap waiver and the wenyan clause were added to the emitted line and
    the figure was not re-measured; a stated cost is a claim, so re-run the hook
    rather than editing the number by eye.
    That is the price of persistence; `/candor:level off` stops paying it.
  - Natural-language switching is a narrow heuristic, not parsing. The slash
    command is the reliable path and the one the docs name.
```

### card

Editor's note (2026-10-04): activate.sh's reason for reading the block at runtime moved with its header, to § plugins/candor/hooks/activate.sh, Header: one source of truth.

```text
the contract block, from the skill body — see activate.sh on why runtime
```

### confirm: off and the switches that outlive the level file

```text
CC_TERSE and the cc_terse option outlive the removed file (see the resolution
below), so "off" cannot promise silence while either still sets a level — say which.
```

### Slash commands

Editor's note (2026-10-04): § 1, § 2 and § 3 named the hook's section banners, cut the same day (below).

```text
---- 1. slash commands -------------------------------------------------------
A slash command suppresses § 2 (natural-language SWITCHING) and nothing else.
It used to `exit 0` outright, which also swallowed § 3 — so every slash-command
turn silently lost the budget reminder. That matters most where it is least
visible: an entry command like /code-architecture:coding-task is exactly what
you type at the START of long work, and § 3 is what refreshes the budget after
the SessionStart block has been summarised out of context. The level itself was
never lost (it is session state, set by activate.sh), only its restatement.
manages its own flow — for switching. § 3 still reinforces.
```

### Natural-language switching: trigger narrowing

```text
---- 2. natural-language switching -------------------------------------------
TRIGGER NARROWING, the reminder hooks' pattern: drop fenced blocks and
backticked spans, read only the head (a pasted transcript buries its keywords
deep), and refuse prompts that are ABOUT this machinery rather than using it.
A slash command starts here already disqualified: its ARGUMENTS are a task
description, not a request to change the mode, and "/coding-task stop being
terse about the docs" must not switch anything.
```

### The hook's own output, echoed back

```text
This hook's own output, echoed back in a pasted transcript. Every shape it
emits must be listed — the confirmation ("TERSE MODE — level: x") and the
far more common per-turn line ("TERSE ultra — chat message only").

Each pattern carries enough context to stay distinct from a user typing the
same words. A previous version guarded on bare `terse mode off`, which is the
documented way to ASK for off — the guard swallowed the request and the off
trigger below became unreachable. The emitted line is always `TERSE MODE OFF.
Normal response…`, so the sentence tail is what separates echo from intent.
```

### The off trigger

```text
OFF. Not a bare noun phrase in any form: "normal mode" belongs to vim and to an
app's boot state, and even "normal length" appears mid-sentence about CSS
line-height. The trigger is a REQUEST shape — back to / resume / return to — or an
explicit terse-off. The reliable switch stays /candor:level off.
```

### The on trigger and the negation guard

Editor's note (2026-10-04): false as moved — the guard reads at most 30 characters of letters, spaces, commas, apostrophes and hyphens between the negator and the keyword, so a negator further back does not disqualify the prompt: "never in a million years would I have guessed it, but please enable terse mode." switches the level on. And any negator before enable, activate or turn on exits the hook, so "don't enable caching" also drops that turn's budget line.

```text
ON, in two shapes. `terse on` is deliberately NOT one of them: "a bit terse
on occasion" is prose about tone, and switching a persistent mode from it
turns an opt-in plugin into an ambient one.

The level form REQUIRES the level word to end the clause — punctuation or
end of prompt. Without that boundary "terse ultra vires doctrine" switched
to ultra and "I prefer terse full sentences" switched to full: the level
word was being read out of the middle of an ordinary sentence.
NEGATION GUARD. "do not enable terse mode, I hate it" and "never turn on terse"
both switched it ON: the trigger saw its own keywords and never looked left. A
negator anywhere in the clause before them disqualifies the whole prompt — a user
arguing about the mode is not asking for it.
```

### Per-turn reinforcement

```text
---- 3. per-turn reinforcement -----------------------------------------------
wenyan levels share their latin counterpart's budgets; only the word layer
differs (skills/terse-output/references/wenyan.md).
```

## plugins/candor/hooks/preamble.sh

### Header: the shebang

```text
Absolute-path shebang, as mode.sh: fail-open must hold under a stripped PATH.
```

### Header: two events

```text
Two events. The job: inject the five working moves BEFORE the first edit. On
UserPromptSubmit, once per session, on the FIRST work-shaped prompt. On SubagentStart,
once per agent_id, unconditionally — a spawn is work by construction. Under 1,000 bytes (878 chars as of 0.6.3).
SubagentStart also records the worker as in flight for the Stop gate (IN-FLIGHT RECORD
below) — silent bookkeeping, no output of its own.
```

### Header: WHY MOVE 1 HAS NO "NOTHING LESS" HALF

```text
WHY MOVE 1 HAS NO "NOTHING LESS" HALF (0.4.7). 0.4.4 added one — averting part of what
the user named is a question before the first edit — after the orchestrating session
briefed a worker to draw "original mascots, not trademarked characters" nobody asked
for. Measured 2026-09-19 with the with/without eval: the with-arm reached 3/3 runs and
all six runs (both arms) still invented creatures without a word. A sentence the model
already knows measured zero, again; the before-half with teeth is hooks/avert.sh, which
fires on the reason being written down. Same rationale file as SubagentStart.
```

### Header: WHY SUBAGENTSTART TOO

```text
WHY SUBAGENTSTART TOO. Measured 2026-09-18 (rationale/fable-distillation-2026-09-18.md):
three Agent-tool workers built a Laravel/React app under 0.4.2 and this text reached
0 of 3 — UserPromptSubmit never fires inside a subagent. A plugin hooks.json
SubagentStart entry does fire there (probed on CLI 2.1.276 with --plugin-dir; the
subagent quoted the injected context and named its source), and the docs say its
additionalContext lands "before its first prompt". No matcher: Explore and Plan spawns
pay the ~878 chars for moves they cannot use; a negative matcher is not expressible.
```

### Header: WHY A PROMPT-TIME HOOK AND NOT A SKILL

```text
WHY A PROMPT-TIME HOOK AND NOT A SKILL. Three passes (PR #105, #114, #132) shipped
working discipline into this marketplace, and every clause of it lives where a plain
session never reads it: the delegation preamble and the worker template are
worker-only by design, the skill-router nudges AFTER a file is edited, and the
discipline skills are command-gated or were absent from the baseline bundle (retired
with the other suites 2026-09-26). Measured 2026-09-17
on the prompt "fix this bug in the checkout total": zero discipline rules reached the
main session (rationale/fable-distillation-2026-09-17.md §3). The Stop gate is the
after-half; this is the before-half.
```

### Header: WHY THESE FIVE AND WHY SHORT

```text
WHY THESE FIVE AND WHY SHORT. Nine Opus 5 runs of one build task, 2026-08: a 535-char
five-move preamble moved three observable process moves from 0/3 (bare prompt) to
6/6, and a 4,362-char catalogue added nothing over the short one (same rationale, §2).
The five lines below are the moves the paired Fable/Opus transcript diff supported,
not the original five verbatim (§4). Vote counts on nine runs, unreplicated — this
is the best-evidenced prompt-time text the repo has, not a proven delta. Move (1)'s
comment sentence (0.6.3) is outside that measured set: unmeasured, admitted for reach
into subagents and into sessions without code-review.
```

### Header: LIMITATION

```text
LIMITATION (honest scope):
  - Advisory. `additionalContext` cannot block; standing is `recorded`. The
    after-half with teeth is gate.sh clause 3.
  - Fires on the trigger taskmaster's remind.sh uses (a making verb in an imperative
    clause of the prompt head); a work session opened with a question never sees it
    until the first imperative prompt. Silence is the cheaper error.
  - Once per session by marker; after a compaction the text is gone and not re-sent.
  - CC_PREAMBLE=off is the off switch. It does not answer to CC_REMIND: this is not a
    tool-routing nudge and claims no rank marker, so on the first work prompt it can
    print alongside one reminder line — bounded, once.
  - CC_PREAMBLE unset: the /config option cc_preamble decides.
```

### Header: IN-FLIGHT RECORD

Editor's note (2026-10-04): gate.sh's IN-FLIGHT WORKERS header moved to § plugins/candor/hooks/gate.sh, and its 180 is now INFLIGHT_TTL_MIN. "The only cleanup" over-states: gate.sh's inflight_count also deletes its own session's expired records whenever clause 4 counts them.

```text
IN-FLIGHT RECORD (0.5.0) — the second job, bookkeeping for hooks/gate.sh. Every
SubagentStart writes ${TMPDIR}/cc-candor-inflight-<hashed session_id>/<hashed agent_id>
holding the raw agent_id; gate.sh deletes it on SubagentStop and, on a main-thread Stop
with a registered run and no gate pass, does not block while one younger than 180
minutes exists and the payload carries no background_tasks array (gate.sh header, IN-
FLIGHT WORKERS: 47 blocks in one run landed while workers were in flight). Written
BEFORE the CC_PREAMBLE check: switching the text off must not blind the gate. Keyed on
session_id, which SubagentStart, SubagentStop and the parent's Stop share (probed on CLI
2.1.282), and kept out of the project tree because a worker's cwd need not be the
parent's. Each SubagentStart also sweeps records older than 180 minutes from every
session's dir — the only cleanup a worker killed without a SubagentStop gets.
```

### One-shot per context

```text
One-shot per context. UserPromptSubmit never reaches a subagent, so session_id
would do; transcript_path is preferred for the same reason the gate exists.
```

## plugins/candor/hooks/activate.sh

### Header: the shebang

```text
Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
even under a stripped PATH where `env bash` exits 127.
```

### Header: the contract

```text
SessionStart: inject the terse contract when — and only when — a level is active.
```

### Header: one source of truth

```text
ONE SOURCE OF TRUTH. The contract text is extracted at runtime from the marked
block in skills/terse-output/SKILL.md, so the skill body and the injected card
can never drift. The path comes from ${CLAUDE_PLUGIN_ROOT}, which Claude Code
exports for hook commands — NOT from a $0-relative guess. That guess is exactly
how the plugin this one replaces silently fell back to a stub ruleset that had
no intensity levels in it at all, in every install where the hook did not sit
one directory below the skills dir.
```

### Header: LIMITATION

```text
LIMITATION (honest scope — the four laws, see
.claude/skills/authoring-skills/SKILL.md (in the marketplace repository) "The four laws"):
  - This injects a contract; it cannot enforce one. Nothing can rewrite a message
    after the model emits it. Per-turn reinforcement lives in mode.sh, and
    after-the-fact measurement in /candor:check. Both are advisory.
  - Level state is machine-local (one file under the Claude config dir), so it
    is shared by every project on this machine and not by a team. Deliberate:
    how terse the user wants their own terminal is a user preference, not a
    repo policy.
  - If the SKILL.md block cannot be read, the hook emits one line naming the
    level instead of a second copy of the rules. A duplicate ruleset is how the
    two copies drift, so the degraded path stays deliberately thin.
```

### Env beats file

```text
Env beats file, the CC_BOOST / CC_REMIND convention: environment is the one
state independently-installed plugins genuinely share, and the only control a
headless run can set.
```

## plugins/candor/hooks/avert.sh

### Header: the shebang

```text
Absolute-path shebang, as the other candor hooks: fail-open must hold under a stripped PATH.
```

### Header: what it does

```text
PreToolUse on Agent, Write, Edit, MultiEdit and Bash: the text the model is about to
hand a worker or write to disk is scanned for a HEDGE the user never raised — a legal
or substitution reason for doing less than what was named. On a hit, the call is
turned into a permission question ("ask"), once per hedge term per session.
```

### Header: WHY THIS EXISTS

```text
WHY THIS EXISTS (2026-09-18). Asked for "a landing page with 2D Sprites … Digimon
themed", the orchestrating session wrote into its sprite worker's brief: "original
mascots in a Digimon-like style, NOT copies of trademarked characters". No prompt of
the user's had said trademark, copyright or original; the project's own library page
already showed the real artwork. The swap surfaced once, in the final message, under
"cut". The user's read: "there was intent for aversion, is it possible to assist with
it?" There was, and it is: the intent left its reason in text the model wrote, and the
reason's vocabulary is small. The preamble's move 1 (0.4.4) says the rule; this is the
one place a script can see the act before a worker starts on it.
```

### Header: WHAT IT CATCHES

```text
WHAT IT CATCHES. A dispatch prompt, file content, edit text or shell command that
names a legal hedge (trademark, copyright, infringe, licensing concern, legal risk) or
declares a substitute (original/invented/made-up mascots|characters|designs,
"not copies of", "look-alike", "inspired by"), when NO human turn in this session's
transcript contains that term. If the user said "trademark" themselves, the hedge is
theirs and the hook is silent.
```

### Header: WHAT IT DOES NOT CATCH

```text
WHAT IT DOES NOT CATCH (honest scope). An avert that never names its reason — a
quietly smaller target with no hedge word — passes; that half is agent-graded
(drift-review clauses c and e, the preamble's move 1). A hedge phrased outside this
vocabulary passes. Inside a subagent the "user" turn is the orchestrator's dispatch,
so a hedge the orchestrator already wrote reads as raised and the hook is silent
there — by design: the guard sits at the dispatch, which is where the avert is made.
```

### Header: STANDING, the switches and fail-open

Editor's note (2026-10-04): false as moved — a missing transcript does not fail open; the call is still asked (avert-hook.test.sh, case 11).

```text
STANDING: gate on the CALL — `ask` hands the decision to the user; in a
non-interactive session it is a deny. CC_AVERT=notify downgrades it to a notification
(the call proceeds, the user and the model both see the line). Vocabulary-bound, so a
guard, not a proof. Off switch: CC_AVERT=off. Fail-open on missing jq, missing
transcript, bad payload.
```

### The hedge vocabulary: three clusters

Editor's note (2026-10-04): false as moved — the precaution cluster matches "to be safe", "to stay safe", "to play it safe" and "as a precaution" with no object; only its "to avoid / sidestep / steer clear of" form needs a legal or rights object.

```text
Three clusters, one act — doing less than what was named for a reason the user did
not give: (a) the reason is legal/IP; (b) a substitute is declared (original, invented,
generic, placeholder, stand-in, look-alike, inspired-by) in place of the real/named
thing; (c) precaution language ("to be safe", "as a precaution", "to avoid any …").
Common engineering phrases ("instead of X use Y", "avoid N+1") are deliberately NOT
matched: the substitute cluster needs a substitute noun, the precaution cluster a
safety/rights object.
```

### Human turns only

```text
Human turns only: string content, or the text items of a content array (tool
results are `tool_result` items and are skipped, so a worker's report cannot
launder a hedge into "the user said it").
```

## plugins/candor/scripts/candor-scan.sh

### Header

```text
candor-scan — report-only measurement of a session transcript against the six
candour axes. Prints; changes nothing; ALWAYS exits 0 by contract, so it can
never be mistaken for a gate.

The Stop hook (hooks/gate.sh) blocks two of these axes because they are
falsifiable against disk and transcript order. The other four are counted here
and blocked nowhere, on purpose: no regex separates "you're right" said because
it is true from the same words said to please, and a gate that cannot tell them
apart would train the model to hide the phrase rather than the behaviour.
usage: candor-scan.sh [--session-file PATH] [--last N] [--examples N]
```

### Transcript discovery

```text
Same discovery as scripts/measure.sh: Claude Code names the transcript
directory after the cwd with separators flattened. Two variants are tried;
guessing wrong silently would measure someone else's sessions.
```

### The role-tagged stream

```text
Role-tagged stream, one record per line. Text is flattened (newlines, tabs and
carriage returns to spaces) so a record cannot span lines.
  U <text>   a real user turn (tool results carry no text block and are dropped)
  T <names>  an assistant turn's tool calls, in order
  A <text>   an assistant turn's prose
```

### Axis patterns: flattery

Editor's note (2026-10-04): false as moved — FLATTERY's noun list includes catch, so a "good catch" in a message's opening counts as flattery.

```text
--- axis patterns ----------------------------------------------------------
Praise directed AT THE USER, in the message's opening. "Good question" is the
canonical flattery opener; "good catch" is not listed here because it is
axis 3's territory (it appears in a retraction, where the reversal test decides).
```

### Axis patterns: defensive

```text
`you asked for` is deliberately NOT here on its own. Measured over a 719-message
real transcript it produced 4 hits and every one was a neutral back-reference
("the writeup you asked for"), which is a noise axis wearing a finding's name.
Only the contrastive forms — the ones that exist to reassign blame — are counted.
```

### Axis 1: citations that do not resolve

```text
--- axis 1: citations that do not resolve ----------------------------------
Same extraction and resolution as the gate; reported instead of blocked, and
across the whole window instead of the final message alone.
Measured: pointing the scan at a session that ran in another project reported 78
"missing" files in one transcript, every one of them real where that turn actually
happened. A measurement that is wrong whenever it is run from the wrong directory
is not a measurement. Falls back to $(pwd) when the field is absent or gone.
```

### Axis 3: unevidenced reversals

```text
--- axis 3: unevidenced reversals ------------------------------------------
Bare pushback (no path, no backtick, no long argument), then a retraction with
no tool call in between and no stated basis. Same test the gate applies to the
final message, run over every turn in the window.
```

### Report

```text
--- report -----------------------------------------------------------------
```

### show

Editor's note (2026-10-04): stale as moved — the second argument is the text to print.

```text
show <label> <file-or-pattern-mode>
```

## plugins/candor/scripts/measure.sh

### Header: the shebang

```text
Absolute-path shebang: same fail-open reasoning as the hooks.
```

### Header: the one number

```text
Measures the one number this plugin exists to move: prose lines in turn-final
messages. Report-only — it never edits, never blocks, and exits 0 on every path
except a usage error.
```

### Header: WHAT COUNTS AS TURN-FINAL

```text
WHAT COUNTS AS TURN-FINAL: an assistant MESSAGE — keyed by `.message.id`, not by
transcript line — that carries text and no tool_use block anywhere in it.

The line-based version of this filter was wrong. Claude Code writes one JSONL
line per content block, so a single assistant message routinely spans several
lines: on a real transcript, 94 of 261 messages were split, and their `text`
block sat alone on a line with no tool_use beside it. Filtering per line scored
every one of those mid-turn narration lines as turn-final, which is exactly the
short-message population the metric must exclude. Grouping by message id first
is the fix; the heuristic itself — text with no tool call is what the user reads
at the end of a turn — is unchanged, and still a heuristic.
```

### Header: WHAT COUNTS AS A PROSE LINE

```text
WHAT COUNTS AS A PROSE LINE: a non-blank line that is not inside a fenced code
block and does not start with `|`. Tables, code and trees are free by contract,
so they are free here too — otherwise the metric would punish the format the
contract asks for.

Lines are counted at RENDERED width, 100 columns per line: a 300-character
paragraph is 3, not 1. Counting source lines instead was the first version of
this script, and on real transcripts it scored a 2,708-character message as
"11 lines, ok" — one wrapped paragraph per source line is the obvious way to
satisfy a line budget while changing nothing the reader sees.
```

### Header: NOT A DUPLICATE

```text
NOT A DUPLICATE of comment-discipline's verbosity hook. That one measures
characters of assistant text per tool call, cumulatively, and warns once per
session while work is happening. This measures prose lines per turn-final
message against the active terse budget, after the fact, only when asked.
```

### Header: LIMITATION

```text
LIMITATION: it cannot tell an answer from a work-done report, so it grades every
message against the larger of the two budgets. A long reply the user explicitly
asked for counts against the numbers exactly like an unrequested one.
```

### Transcript discovery

```text
Locate this project's transcript directory. Claude Code names it after the cwd
with separators flattened; two flattening variants are tried before giving up,
because guessing wrong silently would measure someone else's sessions.
```

### rows_for: two passes and the sentinel

```text
Pass 1 collects every message id that used a tool anywhere in it; pass 2 emits
the text of the messages left, merging the lines that share an id back into one
message. The sentinel is printable on purpose — a control character here works
but makes the script itself unreadable to git and to an editor.
```

### Cross-session mode

Editor's note (2026-10-04): false as moved — find lists the transcripts in directory order, not newest first.

```text
---- cross-session mode ------------------------------------------------------
Aggregates every transcript for THIS project, newest first, optionally limited
by age. No history file is kept: the transcripts are already the record, and a
second ledger would be one more thing to go stale.
```

### Single-session mode

```text
---- single-session mode -----------------------------------------------------
```

### --tokens

```text
--tokens: real usage off the transcript, never an estimate. There is deliberately
no "tokens saved" and no dollar figure — savings would need the same session run
without the mode, which does not exist, and a hardcoded price table goes stale
the week a tier changes. Reporting either as a measurement is the thing this
plugin's own contract forbids.
```

## plugins/candor/scripts/level.sh

### Header

```text
Prints the terse level in force and the layer that set it, "<level> <source>" with source one
of env|file|option|off, by the hooks' rule (cc_option CC_TERSE off <level-file>, hooks/mode.sh):
the first non-empty of CC_TERSE, the level file's first word, the cc_terse option, else off.
A value outside the vocabulary is off; it never falls through to the next layer.

The option is CLAUDE_PLUGIN_OPTION_CC_TERSE where the host exports it — to hooks, not to the
Bash tool (measured on 2.1.286) — else a saved pluginConfigs["candor@*"].options.cc_terse in
managed-settings.json, then in the user settings.json; managed wins, as on the host.
NOT READ: --settings files, managed-settings.d drop-ins, MDM or server-managed policy, and a
symlinked settings file; without jq, no settings file at all.
--sources prints each layer's raw value before the winner. Exits 0, silent on stderr.
```

## plugins/candor/scripts/statusline.sh

### Header

```text
Statusline badge showing the active terse level, e.g. [TERSE:ULTRA].

Opt-in, and deliberately not offered by any hook — a plugin that nags to edit
settings.json on first run is a plugin that edits settings.json. Wire it yourself:

  "statusLine": { "type": "command",
                  "command": "bash ~/.claude/plugins/.../candor/scripts/statusline.sh" }
```

### Header: SECURITY

```text
SECURITY. The level file is user-writable state rendered into a terminal on every
keystroke, which makes it an injection surface: a symlinked level file blanks the
badge (a link pointed at a private key would render its bytes) although the hooks
follow it; level.sh caps the read, and only a whitelisted level renders. Anything
unrecognized renders nothing rather than echoing bytes from a file this script does
not control.
```

## plugins/candor/scripts/__tests__/gate.test.sh

### Header

Editor's note (2026-10-04): stale as moved — gate.sh has five clauses; this harness drives clauses 1, 2 and 5, and clause 4 beside clauses 1 and 3.

```text
Author-time tests for the candor Stop gate.

The hook reads the Stop payload's transcript_path (session JSONL) and blocks a
turn on either of two clauses: a file:line citation that does not resolve, or a
position retracted after bare pushback with nothing re-checked. These cases
drive it with synthetic transcripts plus canned Stop-hook stdin and assert rc +
stderr — including every fail-open, escape and mode the header promises.

The payload carries transcript_path, not session_id: this hook's entire input is
the transcript, and a harness that sent only session_id would grade a branch the
host never takes (scripts/lib/plugin-checks.sh, pc_harness_payload).
```

### The sandbox

```text
This session exports CLAUDE_PROJECT_DIR (the marketplace repo); cc_state_root would read
it for a non-git cwd under it. In-flight records land under TMPDIR — kept in the sandbox.
```

### Fixtures and transcript builders

```text
Real files the citations can resolve against.
Transcript builders: one JSONL line per entry.
```

### Clause 1

```text
---------------------------------------------------------------------------
CLAUSE 1 — citations
---------------------------------------------------------------------------
0.3.2: the block above created the state dir; it must carry a self-ignoring
.gitignore so the markers never appear in the user's `git status`.
0.3.2: a `~/` citation is a real location in the user's home, not the absolute
path `/.claude/...` the old extraction class made of it. HOME is pointed at a
scratch dir so the case is hermetic either way.
The resolver ladder. Measured on 47 real transcripts, an abbreviated path is far
more common than an invented one, so only a basename that exists NOWHERE blocks.
```

### Clause 2

```text
---------------------------------------------------------------------------
CLAUSE 2 — unevidenced reversal
---------------------------------------------------------------------------
Clause priority: a turn that trips both reports the citation.
```

### Modes and fail-open

```text
---------------------------------------------------------------------------
Modes and fail-open
---------------------------------------------------------------------------
Namespaced disarm: this gate's OWN continuation releases the turn; a sibling
gate's block (shared flag set, no record of ours) does not.
```

### SubagentStop

```text
---------------------------------------------------------------------------
SubagentStop — the same gate over a subagent's final report (payload shape
measured live on 2.1.267: agent_id, agent_type, agent_transcript_path,
last_assistant_message, stop_hook_active, plus the PARENT transcript_path).
---------------------------------------------------------------------------
last_assistant_message wins over the transcript: the transcript says src/real.ts:3 (clean) but the payload text fabricates.
Markers are per agent: a subagent block must not consume the main thread's disarm, and vice versa.
```

### Hand-back and resume shapes

```text
2.1.284 hand-back shape (rationale/candor-subagent-probe-2026-09-29.md): the report is the
last SubagentHandback tool_use's input.message; last_assistant_message is closing text.
2.1.286 resume shape (rationale/candor-resumed-subagent-probe-2026-09-30.md): the SendMessage
boundary is a user entry with isMeta true; injected context after a hand-back is not a boundary.
```

### Clause independence

```text
---------------------------------------------------------------------------
CLAUSE INDEPENDENCE — a bounded clause 4 does not silence clauses 1-3
---------------------------------------------------------------------------
On master these were three Stop hooks, each evaluated on every stop. The 0.3.0
merge let clause 4 (a registered run with no gate pass) take the only verdict
slot and exit 0 on its per-HEAD bound, so from the second stop at a HEAD until
the next commit an invented citation or a naked completion claim passed. A live
run is exactly where those happen. These cases pin: clause 4 blocks first and
alone; once bounded (or in warn mode) it prints and the other clauses still bite.
```

### Clause 5

```text
---------------------------------------------------------------------------
CLAUSE 5 — lockfile drift. Needs a real git worktree: the clause reads
`git status --porcelain` and `git diff -U0` on the manifest, so a fixture that
faked either would grade a branch the hook never takes.
---------------------------------------------------------------------------
0.5.0 state root: porcelain paths are repo-relative, so a stop taken from a
subdirectory used to read `sub/package.json`, find nothing and pass silently.
```

### 0.5.0: state root, in-flight workers, coverage

```text
---------------------------------------------------------------------------
0.5.0 — state root, in-flight workers, the no-behavioral-coverage exit.
One throwaway repo, driven through the real hooks: preamble.sh writes the in-flight
record on SubagentStart, gate.sh removes it on SubagentStop and reads it on Stop.
---------------------------------------------------------------------------
--- state root: a subdirectory cwd reads and writes at the repo root -----------------
--- in-flight workers -----------------------------------------------------------------
Only the no-gate-pass branch stands down: a claimed pass short of its records still blocks.
--- no-behavioral-coverage + a recorded coverage reduction -------------------------------
```

## plugins/candor/scripts/__tests__/mode-hook.test.sh

### Header

Editor's note (2026-10-04): stale as moved — the hook was 207 lines at 3887e08c, and "cases 4 and 5" are the two slash-argument checks under the 4-5 banner cut below.

```text
Smoke tests for candor/hooks/mode.sh (terse until 2026-09-14) — the UserPromptSubmit hook that owns both level
SWITCHING and the per-turn budget reinforcement.

WHY THIS FILE EXISTS. The hook shipped with zero coverage and its own comments record
at least three past regressions in the trigger logic: a guard that swallowed the
documented `terse mode off` request, a level word matched out of the middle of an
ordinary sentence ("I prefer terse full sentences"), and a negated prompt ("never turn
on terse") switching the mode ON. Each was found by hand. A 168-line hook with that
history and no fixtures is the recorded-masquerading-as-gate shape CLAUDE.md's
has-teeth convention warns about.

The immediate cause is the slash-command branch: `/*) exit 0` disqualified a slash
prompt from switching AND from reinforcement, so every slash-command turn silently
lost the budget line. Both halves are asserted here, in both directions — the fix
would be trivially "achieved" by deleting the branch, which cases 4 and 5 then fail.

Picked up by the CI step that globs plugins/*/scripts/__tests__/*.test.sh, so it is
enforced from the moment it lands.
```

### The sandbox

```text
The level file lives under CLAUDE_CONFIG_DIR; unpinned, this harness rewrote and deleted
the runner's real ~/.claude/terse-mode. A saved /config option must not leak in either.
```

### Section banners and notes

```text
A level must be active for § 3 to have anything to reinforce.
---- 1-3. the fix: reinforcement survives a slash command ---------------------
---- 4-5. and switching is still disqualified inside a slash command ----------
These are what stop the fix from being "delete the branch". A slash command's
ARGUMENTS are a task description; they must never move the mode.
---- 6. an explicit /candor:level still switches, and does NOT also reinforce --
---- 7-9. the guards the hook's own comments say regressed before ------------
---- 10. off / unset means silence -------------------------------------------
---- 10b. the /config option (cc_terse) sits below the level file --------------
---- 11. fail-open ------------------------------------------------------------
```

## plugins/candor/scripts/__tests__/preamble-hook.test.sh

### Header

```text
Smoke tests for candor/hooks/preamble.sh — the UserPromptSubmit (once per session) and
SubagentStart (once per agent_id) hook that injects the five working moves before the
first edit.

WHY THIS FILE EXISTS. The hook's whole value is its trigger discipline: speak once
on the first imperative work prompt, never again, never on a question, a slash
command, or under CC_PREAMBLE=off. Each of those is a branch a one-character edit
could remove while the happy path stays green. Picked up by the CI step that globs
plugins/*/scripts/__tests__/*.test.sh.
```

## plugins/candor/scripts/__tests__/avert-hook.test.sh

### Header

```text
Smoke tests for candor/hooks/avert.sh — the PreToolUse guard that turns a dispatch,
file, edit or command carrying a hedge the user never raised into a permission
question. Each branch below is one a one-character edit could remove while the happy
path stays green: the user-raised exemption, the once-per-term marker, the tool
routing, the off switch, fail-open. Picked up by the CI step that globs
plugins/*/scripts/__tests__/*.test.sh.
```

## plugins/candor/scripts/__tests__/candor-scan.test.sh

### Header

```text
Author-time tests for candor-scan.sh — the report-only transcript measurement
behind /candor:check.

Two properties matter and both are asserted: the counts are right, and the exit
code is 0 on every path including the ones with hits. A measurement that can
fail a build is a gate wearing a report's name, and this repo's has-teeth
convention makes that the over-claim it forbids.
```

### Case notes

```text
Citations resolve against the transcript's recorded cwd, not the shell's. A
session that ran elsewhere must not report every one of its real paths missing.
Exit code is 0 on every path, including a transcript full of hits.
The standing column is part of the contract: two axes gated, four recorded.
```

## plugins/candor/scripts/__tests__/level-sources.test.sh

### Header

```text
Author-time tests for candor/scripts/level.sh — the resolver behind the statusline badge,
measure.sh, /candor:level and /candor:check — against the hooks' order: CC_TERSE, the level
file, the cc_terse /config option, off; an invalid winner is off, never a fall-through.

A level set only through the option used to be active (the hooks read it) but reported as
unset by every one of those readers. Picked up by the CI step that globs
plugins/*/scripts/__tests__/*.test.sh.
```

### The sandbox

```text
Never the runner's real ~/.claude or managed settings: a level or saved option there would
decide every case.
```

### Section banners

```text
---- level.sh: one layer at a time, then the order between them ----------------
---- statusline.sh -------------------------------------------------------------
---- measure.sh reports the level level.sh resolves --------------------------
```

## plugins/candor/scripts/__tests__/install.test.sh

### Header

Editor's note (2026-10-04): stale as moved — candor ships more harnesses than gate.test.sh and candor-scan.test.sh; recount with ls plugins/candor/scripts/__tests__/.

```text
Install-shaped end-to-end test for the candor plugin.

WHAT THIS CARRIES THAT THE OTHER TWO HARNESSES DO NOT. gate.test.sh and
candor-scan.test.sh invoke the scripts by their in-repo path. That leaves four
things untested, and all four are ways a plugin ships broken through a green
suite:
  1. the hook is reached the way Claude Code reaches it — by expanding
     ${CLAUDE_PLUGIN_ROOT} in hooks/hooks.json, not by a path someone typed;
  2. the plugin is a COPY in a temp dir, so nothing may resolve back into this
     repository (a relative `../` would pass in-tree and fail on every install);
  3. the consumer project is NOT a git repository — this gate claims to be
     portable where the marketplace's own scripts/done-gate.sh is not;
  4. transcript entries carry the full real-world field set (uuid, sessionId,
     timestamp, cwd, gitBranch, message.role, message.id), not the minimal
     shape the other fixtures use.

The payload sends transcript_path, which is the field the hook actually reads
(scripts/lib/plugin-checks.sh, pc_harness_payload).
```

### Case notes

```text
Resolve the hook command the way the host does. A hard-coded path here would
test nothing that the sibling harnesses do not already cover.
The one-shot bound, writing state into a NON-git consumer project.
```

## plugins/candor/evals/configuration-named-in-report/scaffold.sh

### Header

```text
Scaffold for configuration-named-in-report: a stub that must become a real third-party
integration, so the deliverable necessarily needs a credential and a sender address the
user has to configure — the thing the report must say.
Runs in the case's sandbox cwd; writes only the files below.
```

## plugins/candor/evals/limitation-checked-before-stated/scaffold.sh

### Header

```text
Scaffold for limitation-checked-before-stated: a one-function Node package with a failing
test, so "run the tests" is a real, cheap action the prompt then claims is impossible.
Runs in the case's sandbox cwd; writes only the files below.
```

## plugins/candor/evals/unasked-additions-need-a-trigger/scaffold.sh

### Header

```text
Scaffold for unasked-additions-need-a-trigger: a 20-line CLI with one obvious extension
point, so the smallest change is unambiguous and every addition beyond it is visible.
Runs in the case's sandbox cwd; writes only the files below.
```
