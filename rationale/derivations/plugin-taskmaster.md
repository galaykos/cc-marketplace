# taskmaster hooks and scripts: the comment text moved out of the code (2026-10-28)

The text below was moved verbatim on 2026-10-28 from the files named in the `##` headings, with only each comment's `# ` leader (and the indentation before it) removed; the lines each file kept are not repeated here. A pointer by name was left in each file, `# Why, limits, history: rationale/derivations/plugin-taskmaster.md § <heading>`. `plugins/taskmaster/hooks/preview-guard.sh` is the twin of ui-ux's copy and points at `rationale/derivations/plugin-ui-ux.md § plugins/ui-ux/hooks/preview-guard.sh`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

## plugins/taskmaster/hooks/card-lint-observe.sh

### Header

```text
Absolute-path shebang (not `/usr/bin/env bash`): fail-open must hold under a
stripped or broken PATH, like every other hook in this plugin.

card-lint-observe.sh — PostToolUse observer that says out loud when a card set
reached EXECUTION unlinted.

THE GAP IT CLOSES. taskmaster ships four author-time linters — card-shape,
verify-teeth, skills-stamp, spec-ledger. Each is a gate WHEN IT RUNS, and until now nothing
observed that any of them ran: a card set could reach the runner with none of them
invoked and every check in this marketplace green. The linters now append a run
record beside each card (scripts/card-lint-record.sh); this reads them back at the
only moment the omission is still cheap to fix — the first write of the run.

IT WARNS. It never blocks and never denies a tool call: card authoring is
reversible, and the decision behind this path was teeth in a shipped hook, not a
new blocking gate. Standing: `agent-graded` at best — the message reaches the model
as additionalContext and the model chooses what to do with it.

WHY PostToolUse AND NOT Stop. Stop reaches the model only by BLOCKING (exit 2);
an exit-0 Stop hook prints into a turn that has already ended, so a warn-only Stop
hook would be a message nobody acts on (candor's gate.sh clause 4 — where the run
completion gate lives; task-runner ships no hook of its own for it — states the same
constraint from the blocking side).

MAIN THREAD ONLY. PostToolUse also runs inside subagents, and a payload there carries
an agent_id (rationale/candor-subagent-context-probe-2026-10-01.md). Linting the set is
the orchestrator's job, so a worker told to fix one card got a warning about the whole
set it could not act on, once per worker (D2-20, rationale/session-retro-2026-10-13.md).
A payload with an agent_id now exits silent. Residual: in a fully fanned-out run the
first main-thread write may be an index status update after the first card, not before.

THE CONTEXT KEY. The one-shot ("already warned about this set here") is keyed on
transcript_path, never session_id: chosen when subagents were warned too, since a
worker shares its parent's session_id. transcript_path is an ABSOLUTE PATH, so it is
hashed with cksum before it reaches a filename; interpolated raw it would name a
file under directories that do not exist and the bound would silently stop
existing. (pc_context_key / pc_marker_key, scripts/lib/plugin-checks.sh.)

TRIGGER. `.claude/task-runner/active-run.json` carrying an `index_path` — the
registration task-runner/commands/run.md step 1 writes for a taskmaster-index run.
That file existing IS the handoff: cards have been handed to an executor.

HONEST LIMITATIONS, all four real:
  1. Keyed off the run REGISTERING itself, exactly like the completion gate. A
     card set executed without `/task-runner:run` is never observed at all.
  2. It reports MISSING records only. A card whose recorded verdict was `block`
     is not re-warned — the linter already blocked at author time, and the
     accepted contract here is "has a record" (a fixed card is re-linted and
     keeps both rows).
  3. A record proves invocation, not honesty: it can be written by hand, and
     nothing re-reads the card. This closes forgetting, not evasion.
  4. spec-ledger records are written but NOT graded here — the spec is one file
     per set, named in the index in prose, and inferring it from text would be
     guessing. Cards are what this counts.

Off switches: CC_CARDLINT=off (this hook) or CC_REMIND=off (every reminder in the
marketplace). Fail-open on missing jq, malformed input, or an unwritable TMPDIR.
CC_CARDLINT / CC_REMIND unset: the /config options cc_cardlint / cc_remind decide.

WHERE IT LOOKS: active-run.json and a relative index_path resolve at the project root
(state-root block below), not the payload cwd, which follows the model's `cd`
(finding 2, rationale/2026-09-25-session-plugin-usage-review.md). Read from the cwd,
the check went silent for every edit made after a `cd` into a subdirectory.
```

### The handoff test

```text
HANDOFF, cheapest test first: this is a per-edit hook and the overwhelming case
is a session with no registered run, which must cost one git rev-parse (the root)
and one stat, and stop.
```

### The plugin root

```text
Shared identity with the writers. CLAUDE_PLUGIN_ROOT when installed; the
relative path is what makes the harness able to drive this file directly.
The same root is what the warning quotes: "in the plugin's scripts/ dir" left
the reader to hunt for a path this hook already holds.
```

### What counts as a card

```text
A card is a file the index names, by basename or by its number opening a table row, or
one card-shape-lint accepts (a <card> wrapper or a legacy **Verify:** line). A probe-results
or notes file named NN-*.md beside the cards was counted; a card in the wrong shape was not.
```

### Naming the first four

```text
Name the first few and count the rest: a 20-card set must not paste 20 lines
into the turn to make one point.
```

### The one-shot

```text
ONE SHOT per transcript per card set. The key mixes the index path so a second
run against a different set in one transcript still gets its warning.
```

```text
A bound that cannot be recorded means no warning at all — the same rule
comment-discipline/hooks/scan.sh applies to its deny, for the same reason:
a message with no working one-shot repeats on every edit of the run.
```

## plugins/taskmaster/hooks/clarify-gate.sh

### Header

The file keeps the bound-before-deny rule as one line beside the `mkdir` it protects.

```text
Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
hold even under a stripped/broken PATH.

clarify-gate.sh — OPT-IN PreToolUse gate on Edit|Write|MultiEdit. OFF BY
DEFAULT: does nothing unless CC_CLARIFY_GATE=block is set. When enabled, it
denies the FIRST code write of a session in which remind.sh saw a work-shaped
prompt (the cc-workprompt marker), once per session, forcing one turn of
clarify-or-declare-trivial before code exists. The deny is the reflection
mechanism itself — the gate does not (cannot) verify a question round
actually happened; it buys one deliberate turn, nothing more. Standing when
enabled: gate. Standing when disabled (the default): unenforceable, and this
header says so on purpose.

Doctrine note: command-guard reserves deny for irreversible loss; a first
code edit is reversible, which is why this ships OFF and opt-in — the owner
chooses the stricter contract, it is not imposed. Under hands-off goal runs
the model should state assumptions instead of asking (see reason text).
Pattern: comment-discipline/hooks/scan.sh — the once-per-session bound is
recorded BEFORE the deny; a bound that cannot be recorded means no block.
Fail-open everywhere; CC_REMIND=off also silences it. Honest limitation:
hook input cannot distinguish main-session from subagent edits, so when the
main model's first move is to delegate, the one deny can land on a worker's
first write instead of the main session's.
CC_CLARIFY_GATE / CC_REMIND unset: the /config options cc_clarify_gate / cc_remind decide.
```

## plugins/taskmaster/hooks/shape-guard.sh

Added 2026-11-07 (Track 1 item PL5 of the gitignored `taskmaster-docs/integration-roadmap-2026-11-07.md`,
from `rationale/plugin-landscape-comparison-2026-10-31.md` item T2). Until then `commands/brainstorm.md`
called its no-code-before-approval rule `unenforceable`. superpowers' release notes report prose of the same
rule leaking in 24 of 24 runs and 3 of 24 once enforced (relayed by the 10-31 researcher, not re-measured here).

Shape: brainstorm writes a `shape` sentinel through `phase-sentinel.sh` with owner `taskmaster:brainstorm`; the
hook denies Write/Edit/MultiEdit to project files outside `taskmaster-docs/` and `.claude/` while it is live for
this session (or for any session when the sentinel carries none) and younger than the reader's 120-minute TTL.
Keyed on the brainstorm owner only: `/taskmaster:task` also writes `shape`, and some of its runs reach execution
before the sentinel is cleared, so guarding it would deny the build. visual-decisions' real-component rung writes
`__design-preview__` scratch files and one marker-carrying `require` line in `routes/web.php`; both pass.

Residuals: Bash and NotebookEdit writes (no Bash-write block is sourced; adding one is the next step if leaks
show up there); a path whose prefix differs from the logical git root (a symlinked checkout) passes; the model
can run `phase-sentinel.sh clear` itself, which the command forbids in prose only.

## plugins/taskmaster/scripts/card-lint-record.sh

### Header

```text
card-lint-record.sh — the run record the four card linters leave behind, and the
ONE place its location, name and format are decided. Sourced by the writers
(card-shape-lint.sh, verify-teeth-lint.sh, skills-stamp-lint.sh, spec-ledger-lint.sh) and by the reader
(hooks/card-lint-observe.sh). Writer and reader sharing one file is the point: a
drift between them would disable the observation silently, with every gate still
green — which is the failure this whole path exists to make visible.

WHY A RECORD AT ALL. The linters are gates WHEN THEY RUN, and nothing
observed that they ran: a card set could reach execution having had none of them
invoked, with every check in the repo green. The record is what an after-the-fact
reader can count.

WHY THE RECORD IS KEYED ON THE CARD, NOT ON THE CALLING CONTEXT. Cards are linted
in the AUTHORING session and executed later — often another session, and always
another transcript once subagents carry the work. A record namespaced by the
writer's context could never be found by the reader, so the identity has to be the
card itself. The state that IS context-scoped — "have I already warned about this
set in this transcript" — belongs to the hook, and is keyed there on a hash of
transcript_path, never on session_id (a subagent shares its parent's) and never
raw in a path (transcript_path is absolute).

WHERE. A `.lint-records/` directory beside the target, so records travel with the
card set and neither side has to agree on a cwd or a git root. Override with
CC_CARDLINT_DIR (the harness does, to stay out of a real card set).

FORMAT. One tab-separated line appended per invocation:
  <iso8601-utc>  <linter>  <verdict>  <target-basename>
Appended, never truncated: a card linted, fixed and re-linted keeps both rows, and
the last row for a linter is its current verdict.

Standing: `recorded`. Writing a record proves the linter was invoked against that
file and nothing else. It does not re-read the card, and a record can be created by
hand — what it closes is the honest-but-forgetful skip, not deliberate evasion.
Every function here fails silently and returns 0: a linter must never fail because
its bookkeeping could not be written.
```

### cardlint_file: the record name is not hashed

```text
The name is the target's basename, which is already a legal filename by
construction — no hash needed here, and a readable ledger is worth more than
one nobody can grep. (The hook's transcript key is a different thing entirely
and IS hashed; see the header.)
```

## plugins/taskmaster/scripts/card-set-lint.sh

Added 2026-11-07 (Track 1 item PL7 of the gitignored `taskmaster-docs/integration-roadmap-2026-11-07.md`,
from `rationale/plugin-landscape-comparison-2026-10-31.md` item T1, superpowers' cross-card preflight). The
per-card lints cannot see order: `card-paths-lint.sh` accepts a verify path "created by a sibling" whether or not
that sibling runs first, and `card-shape-lint.sh` checks only that an `<interface>` names a consumer. task-runner
schedules by `<depends-on>`, so a consumer with no dependency path to its producer can land in the same parallel
group and run first.

Run on the three card sets under `taskmaster-docs/tasks/` on 2026-11-07: the first version flagged card 30 of
`2026-10-06-ship-claude-code-mods` (a follow-up card editing files card 10 had already created). Such a card is
added after its producer ran, so a path already on disk now skips the create-order check; after that change all
three sets pass. Interface ordering is still checked for those, because an interface is not a file.

## plugins/taskmaster/scripts/card-shape-lint.sh

### Header

The file keeps the reason-code list, the CLI and the exit codes, which `--help` prints.

```text
card-shape-lint.sh — author-time STRUCTURAL lint for a role-tagged task card.

WHY. A card's sections used to be bold labels that named CONTENT (Why, Context,
Out of scope). The role-tagged shape (task-cards `references/card-shape.md`)
names the author's DECISION about each sentence — <goal>, <facts>, <must>,
<must-not>, <proof> — and hangs the decision's evidence on attributes: a
forbidden file carries the reason it is forbidden, an interface names its
consumer, a file to edit names the line. Those attributes are what a bold label
could never demand, and a rule nothing demands is a rule that is skipped when the
author is in a hurry. Measured 2026-09-23 (8 fresh-model runs, 4 per shape): the
READING side showed zero delta between the two shapes — the gain is entirely at
authoring time, and this lint is what turns the authoring rules from `recorded`
into `gate`.
```

```text
WHAT IT DOES NOT CATCH (stated, not hidden): whether a <criterion> describes
behaviour rather than the diff, whether a reason="…" is true, whether the
<change> is the right change. Those stay agent-graded in task-cards. It also does
not grade the <verify> text — that is verify-teeth-lint.sh — nor the <skill>
names against the touched files — that is skills-stamp-lint.sh. A UI card's
<walk> line is optional: present or absent, no finding (its surface shape is checked since 2026-11-06, see walk-surface).

LEGACY SHAPE. A card with no <card> wrapper but a **Verify:** line is the bold-label
shape task-cards emitted before taskmaster 0.45.0. It passes with a NOTE on stderr
and exit 0: in-flight card sets keep executing. task-cards emits only the tagged
shape; the acceptance here is for cards already written, not a second template.
```

### walk-surface (2026-11-06)

```text
The chess-knight baseline (taskmaster 0.53.0, headless, 2026-11-06) emitted
<walk surface="assets/preview/side.png" widths="768"> and every card lint passed.
task-runner walks only browser routes, and only when a UI group closes
(plugins/task-runner/skills/task-execution/SKILL.md:102-107), so that line is never
run; the card's own "Read the PNGs" step was the real look check. The check fails a
surface ending in a listed image/3D/video/audio extension, compared lower-case on the
part before ?/#.
Absolute http(s) URLs are exempt, and .svg/.avif are not listed, because a web route
can legitimately serve them (/opengraph-image.svg). A route serving a listed extension
(Next.js /icon.png, /opengraph-image.png) is blocked too, a known false positive: walk
the page that shows it instead. Read views images only, so a video,
audio or 3D look check depends on the worker rendering a PNG first; nothing checks it.
A route <walk> on a card whose diff touches no UI file is walked only when its
milestone's diff touches UI (task-runner references/ui-walk.md).
```

## plugins/taskmaster/scripts/goal-ledger-check.sh

### Header

The file keeps the two modes and the exit codes, which `--help` prints.

```text
goal-ledger-check.sh — mechanical gate for goal mode's audit precondition.

The ultra skill (Goal audit trail) makes the goal ledger's writability an
ACTIVATION PRECONDITION: no auto-take may proceed unaudited. This script is
the bash form of that rule at the two moments that matter:
```

```text
LIMITATION: proves the file exists, has entries, and is writable — cannot prove
every auto-take was actually logged. It converts "forgot the ledger entirely"
from silent to blocking; entry completeness stays a prose obligation.
```

### State hygiene: the directory ignores itself

```text
STATE HYGIENE. This dir is scratch and belongs in no commit. Three shipped
artifacts called it "gitignored", which is true only of THIS marketplace's own
.gitignore — in a consumer repo it showed up untracked, the same thing
rationale/derivations/plugin-task-runner.md § plugins/task-runner/hooks/scope.sh recorded and fixed. A directory can ignore
itself, so drop a `.gitignore` holding `*` the first time we create it.
`|| :` is load-bearing HERE and nowhere else this idiom appears: every sibling copy
lives in a hook that is fail-open by construction, this script runs under
`set -euo pipefail`, so on a read-only state dir the bare `||` list returns non-zero
and takes the whole precondition check down before it can report anything useful.
```

### The writability probe

```text
writability probe: append + remove one line; a failed append here is the
exact failure mode the precondition exists to catch.
```

## plugins/taskmaster/scripts/phase-sentinel.sh

### Header

The pasted state-root block below the header is unchanged here; its text belongs to `templates/blocks/state-root.md`.

```text
phase-sentinel.sh — the one SCRIPT writer of the arc phase sentinel,
`<project root>/.claude/cc-phase.json`.

WHY THIS EXISTS. The sentinel had four PROSE writers (taskmaster:task,
task-runner:run, code-architecture:coding-task, git-workflow:finish), no script
writer, and seven readers — AR 11 of the 2026-09-22 specialist panel, open since the
endgame review's residual 3. Four hand-written JSON literals in four command bodies
is four chances to mistype a key or a phase name, and the reader
(`templates/blocks/phase-guard.md`) fails SILENTLY on both: an unknown phase scores 0
in its ordering table and every guard proceeds, which looks exactly like no sentinel
at all. Nothing anywhere told you it had happened.

So the vocabulary is checked HERE, once, at write time — the one moment a typo is
still cheap. `write` refuses an unknown phase with exit 3 instead of leaving a file
that reads as absence.

ANCHORED AT THE PROJECT ROOT, not $PWD (2026-09-25). The model's shell follows its
`cd`, and so does every hook payload's cwd (finding 2 of
rationale/2026-09-25-session-plugin-usage-review.md). Written under $PWD, a command run
from app/Models put the sentinel where no reader at the root looked; read from the
payload cwd, a sentinel at the root was invisible to a hook fired from app/Models —
both read as "no sentinel", which silently means every voice is eligible.
Writer and readers now resolve the same root through the shared state-root block
(pasted below, byte-identical to templates/blocks/state-root.md — pc_shared_blocks).

USAGE
  phase-sentinel.sh write <phase> --owner <plugin:command> [--session <id>] [--cwd <dir>]
  phase-sentinel.sh clear [--cwd <dir>]

  <phase>     one of: understand shape decide plan build verify review ship
  --owner     the command declaring the phase, e.g. task-runner:run (required on write)
  --session   this session's id. OPTIONAL and you should pass it: the reader compares
              it before standing down, so without it a sentinel written by one session
              silences reminder hooks in every other session sharing the .claude/ dir.
              Omitting it draws a warning on stderr rather than a failure, because a
              caller that genuinely cannot resolve its session id is better off with a
              session-blind sentinel than with none.
  --cwd       any directory of the project (default: $PWD); must already exist. The
              sentinel lands at its root: the git toplevel, else CLAUDE_PROJECT_DIR
              when the directory is under it, else the directory itself.

Exit: 0 wrote/cleared (clearing an absent sentinel is success), 3 usage.

WHAT IT DOES NOT DO, stated because the finding it closes is about a gap between a
mechanism and what people believe it covers:
  - It does not CLEAR anything on its own. Each entry command still owns removing the
    sentinel it wrote, on every path including abandonment; the reader's 120-minute
    mtime TTL is the only backstop and it is a backstop, not a lifecycle.
  - It does not check that the CALLER owns the phase it is writing, or that the phase
    it is clearing is its own. One writer stamping over another's is invisible here.
  - It is not a gate. No check makes any command call this instead of writing the JSON
    by hand; the four command bodies naming it is the whole of the enforcement.
    **Standing: recorded.**
  - The reader-side half — whether a hook that reads the sentinel actually honours the
    verdict on every branch — is agent-graded, as `pc_phase_guard`'s header says.
```

### The phase list and cc_phase_ix

```text
The arc, in order. Must stay identical to cc_phase_ix in templates/blocks/phase-guard.md
— that function is the reader, this list is the writer, and a phase in one and not the
other is a sentinel that silently means nothing.
```

### An unknown phase is refused

```text
A refusal, not a silent write. An unknown phase scores 0 in the reader's ordering
table and disables turn-taking without saying so — the failure this check exists for.
```

### printf, not jq

```text
Written with printf and %s substitution rather than jq: this runs from a command body
on a machine that may not have jq, and the four values are short flat strings. Quotes
and backslashes in them would break the JSON, so they are stripped — a phase is from a
closed list, and an owner or session id carrying a quote is a caller bug, not a value
worth preserving into a file the reader must be able to parse.
```

### 2026-11-12: one sentinel per session (taskmaster 0.56.0)

Track 7 (Safety) item S5 audited how Stop and UserPromptSubmit hooks leak state between
two concurrent sessions in one repo. The phase sentinel was one repo-wide file carrying a
`session_id`. Three leaks, all advisory (a reminder line printed or withheld):

- a sentinel written without `--session` silenced every session's reminder hooks;
- session B's `write` replaced A's file and B's `clear` removed it (`clear` had no owner
  check), so A's reminders resumed mid-phase;
- `cc_phase_now` was set from the file BEFORE the session check, so B's phase entered A's
  rank key. Two of A's hooks firing around B's write claimed different namespaces and both
  spoke.

The owner decided to make the sentinel per session. Layout:
`<state root>/.claude/cc-phase/<key>.json`, `<key>` = the session id with every byte outside
`A-Za-z0-9_-` dropped (`templates/blocks/phase-file.md`, `cc_phase_file`; the mod kit's
`phaseFile` mirrors it). The path is the ownership: readers no longer compare a
`session_id` field, and a write can only ever replace its own session's file. One file per
session rather than one map file: a map needs a read-modify-write that two sessions race;
a per-session file is a single atomic rename.

`--session` is now REQUIRED on `write` and `clear` (exit 3). The old header argued a
session-blind sentinel beat none; per session there is nowhere to put one that does not
reintroduce the first leak. Callers pass `${CLAUDE_SESSION_ID}`. Probe 2026-11-12, CLI
2.1.322: a plugin command body `SID=${CLAUDE_SESSION_ID}` run with `claude -p` replied with
the session id the JSON output reported, so the host substitutes it in plugin command
bodies. Before this the bodies said `"<this session id>"` and nothing told the model its id.

Migration decision (the brief left it open): the legacy `.claude/cc-phase.json` is IGNORED
by every reader, not read as an owner-less fallback. A fallback would keep the first leak
alive for as long as any old writer exists, and every reader (bash block, mod kit, capsule,
announce, shape-guard) would carry the old branch forever. Cost: a run that declared its
phase before the upgrade loses its stand-down until its next write or the 120-minute TTL.
The writer removes a legacy file on any `write` or `clear` when it names no session, names
the caller, or is past the TTL; one owned by another live (old-version) session is left to
it, since that session's old readers still need it.

The 120-minute TTL is kept. The reader block deletes every expired file in
`.claude/cc-phase/`, any session's, as the old reader deleted the one expired file. Dead
sessions' files would otherwise accumulate. The writer drops a `.gitignore` (`*`) in the
directory, as task-runner's state dir does.

Red on 0.55.0, green on 0.56.0: `scripts/__tests__/phase-sentinel.test.sh` sections 4, 10
and 11 (22 of 45 fail on the old script and reader), `shape-guard.test.sh` (B's clear
leaves A's guard up; an owner-less file guards no session), and
`scripts/smoke/hook-guard-tests.sh` "two sessions: B's phase stays out of A's claim key".

## plugins/taskmaster/scripts/preview-cleanup.sh

### Header

```text
preview-cleanup.sh — mechanical cleanup + verification for design-preview scratch
artifacts. The skill's cleanup guarantee was prose ("a repo-wide search must
come back empty"); this is the command that prose described.

Usage: preview-cleanup.sh [--verify] [project-root]
  --verify  search only, remove nothing; exit 1 if any artifact remains.
Default mode removes every known scratch artifact, strips any line referencing
the marker from routes/web.php, then runs the same verification.

Residual: removes only artifacts carrying the __design-preview__ marker. A
hand-renamed scratch file without the marker is invisible to this script —
which is why the skill forbids renaming scratch artifacts.
```

## plugins/taskmaster/scripts/preview.sh

### Why it exists (2026-11-12, taskmaster 0.57.0)

Until 0.57.0 the skills told the model to start `assets/serve.py` in background Bash, note the PID,
check the port with `lsof -ti :8123`, and stop a stale server with `lsof -ti :8123 | xargs kill`.
That kills whatever holds the port, not just this server. design-kit already had a launcher (`plugins/design-kit/scripts/preview.sh`); this one
follows its shape: pid and URL files in the docroot, an idempotent start, `--stop`.

Differences from design-kit's launcher, each on purpose:

- **`--stop` checks the pid before killing it.** `ps -ww -p <pid> -o args=` must show `serve.py
  --docroot <this docroot> --port`. A pid file that outlived its server (idle shutdown, LAN limit,
  a reboot) can name a reused pid; that process is left alone and only the stale state is removed.
  The same check decides "already running" on start.
- **Readiness is serve.py's own `Serving ... at <url>` line, not a sleep.** The URL (with the LAN
  key when `--lan`) is read from that line, so the launcher never assembles a URL itself and a
  foreign server that happens to answer on the port is not mistaken for ours.
- **`--lan` over a running loopback server exits 5** instead of restarting it: going onto the network
  is a deliberate step, so the caller stops the server first. A plain start over a LAN server reuses
  it and says LAN mode is still on.
- **`umask 077` before the state files**: `.preview.url` and `.preview.log` carry the LAN key.

### The log-truncation race (found by the harness, 2026-11-12)

The first version truncated `.preview.log` only through the `>` redirect on the background
`nohup python3 ...` line. That redirect runs in the child, so the parent's readiness loop could read
the previous run's `Serving` line before the child truncated the file. One harness run on
2026-11-12 printed the old port's URL for a start that had failed on a busy port (exit 0 instead of
4). The launcher now truncates the log synchronously first. The harness seeds a stale `Serving`
line before the busy-port case, but the race is timing-dependent: three runs on the unfixed
launcher passed, so the case catches it sometimes, not reliably. Standing: gate where it fires.

### Not covered

Exit 3 (python3 missing) is not exercised by `scripts/__tests__/preview.test.sh`. Nothing checks
that a model calls the launcher rather than starting serve.py by hand: the skills say so
(agent-graded at best, recorded in practice).

### Review fixes (2026-11-12, still 0.57.0)

- **A lock around check-and-start.** It ran unlocked and every start truncated `.preview.log`. With two starts at once, the harness's three rounds on the unfixed launcher printed `FAIL race 1 URL: … | preview: already running — ` (no URL), `FAIL race 2 stop: preview: nothing running` with one serve.py left (the loser deleted the winner's pid file), and `FAIL race 3 exit: want 0 and 0, got 4 and 4` with no server at all. Now `take_lock` holds `mkdir .preview.lock` (owner pid inside, removed by an EXIT trap; INT, TERM and HUP exit through it) around check-and-start and around `--stop`. A waiter polls for 15 s, takes over a lock whose owner is dead or that named no owner for 2 s, else exits 4. The loser then finds the winner's server and URL and never truncates its log; a failed start removes the pid file only while it holds its own pid. Residual: two waiters that judge one stale lock at the same moment can both take it.
- **No usable `ps`.** `ours()` read a `ps` failure as "not ours", and the start path then deleted a live server's pid file. `/proc/<pid>/cmdline` is now the fallback; a pid alive to `kill -0` that neither names is exit 6, with nothing signalled or removed. Red: `FAIL no ps: live server: rc=4: … Address already in use` and `FAIL unnamed live pid (--stop): want exit 6 and the pid file kept, got 0`.
- **The loopback URL.** The launcher relays serve.py's `On this machine:` line on start and reads it back from the log on reuse. Red: `FAIL --lan loopback URL` and `FAIL plain start over LAN: loopback URL`.

## plugins/taskmaster/scripts/skills-stamp-lint.sh

### Header

The file keeps the CLI and the exit codes, which `--help` prints.

```text
skills-stamp-lint.sh — author-time lint for a task card's skill stamp: its
<skill name="…"/> elements, or the legacy `Skills to apply` bold line.

WHY: the stamp is what makes a framework/stack best-practice skill (laravel,
react, vue, …) reach the card's executor. If a card that touches FRAMEWORK source
is stamped "none detected", every downstream routing silently applies no skill —
the card is implemented framework-blind. This lint refuses that: a framework card
must name at least one skill.

It is deliberately NARROW — it fails ONLY for source extensions that unambiguously
have a best-practice plugin (.php/.blade.php/.vue/.jsx/.tsx). Generic .ts/.js/.py
cards are NOT forced (a "none detected" there is defensible), so false positives
are avoided.
```

### The run record

```text
RUN RECORD. The lint is a gate when it runs, and nothing observed that it ran —
a card set could reach execution with none of the linters invoked and every check in
the repo green. `record_run` appends one line per invocation beside the card; the
reader is hooks/card-lint-observe.sh. Written on BOTH outcomes: the record says the
lint ran and what it said, never that the card is good.
```

### Two card shapes

```text
Two card shapes: role-tagged <skill name="…"/> elements (taskmaster ≥0.45.0, one
per line, `name="none"` is the explicit no-skill stamp) and the legacy
**Skills to apply:** bold label. Tagged first; the value is the comma-joined names.
```

### sibling_plugin

```text
The sibling plugin shipping skills/<name>/SKILL.md, printed by name; status 1 when none.
A second argument narrows the search to that one plugin. Two layouts: a source checkout
keeps plugins side by side (plugins/<p>/), the installed cache one level deeper
(<marketplace>/<p>/<version>/), where `../*` lists this plugin's own versions. A
cached-but-disabled plugin still counts.
```

### The reachability probe

```text
Reachability probe (WARN-only, never blocks): a stamp proves a skill is NAMED,
not that its plugin is installed — a named-but-absent skill executes the card
framework-blind while the lint reads green. Probe the sibling plugin dirs for
each stamped skill's SKILL.md and warn on stderr when none carries it; a qualified
plugin:skill stamp is probed in that plugin alone. Exit stays 0: cross-marketplace
and project-local skills are legitimate. The root is CLAUDE_PLUGIN_ROOT, else this
script's own plugin: the probe used to need the variable, which the Bash tool's
environment does not carry (checked 2026-10-15), so it never ran where task-cards
runs the lint. A "none" stamp is not probed.
```

### The shadow probe

```text
Shadow probe (WARN-only, never blocks): a bare stamp resolves to a same-named PROJECT
skill before a plugin's. Laravel Boost writes .claude/skills/laravel-best-practices
(and its own inertia/tailwind skills) into a repo; one 61-card run stamped bare names,
and its workers read the Boost copies dozens of times and the marketplace skills almost
never. Warn when <project>/.claude/skills/<name>/SKILL.md exists and a marketplace plugin
ships that name, or the name is a known Boost twin, and print the qualified stamp. The
project is the card's git toplevel, else CLAUDE_PROJECT_DIR, else the working directory.
Not caught: a shadow from ~/.claude/skills, and Boost twins missing from the case below.
```

## plugins/taskmaster/scripts/spec-ledger-lint.sh

### Header

The file keeps the check list (without the glosses below), the CLI and the exit codes, which `--help` prints.

```text
spec-ledger-lint.sh — author-time gate for grill's core rule: "no spec while
the ambiguity ledger holds an UNKNOWN row" (skills/grill/SKILL.md). The spec
must embed its final ledger, and that ledger must be fully converged.

LIMITATION (honest scope, same class as verify-teeth-lint):
  This lint proves the spec CARRIES a converged ledger table — it cannot prove
  the interrogation really happened or that the rows are truthful. It converts
  "silently skip convergence" into "must actively fabricate a resolved ledger",
  and makes the final ledger a reviewable audit artifact inside the spec.
```

### The no-source and no-criteria glosses

```text
                  a dash, a "?"). grill promises "decisions (CLEAR rows with sources)";
                  a blank source is a settled claim nothing can be traced back to.
                  LENIENT BY DESIGN: a table with no Source column at all is an
                  accepted header variant, so its last cell is the status token and
                  the check passes. It catches the dropped source, not the absent column.
  no-criteria   : spec has no `## Success criteria` section. coverage-check and
                  spec-redteam both key off that exact heading, so a spec without it
                  degrades both into silent no-ops rather than failing loudly.
```

### The run record

```text
RUN RECORD. The lint is a gate when it runs, and nothing observed that it ran —
a card set could reach execution with none of the three invoked and every check in
the repo green. `record_run` appends one line per invocation beside the card; the
reader is hooks/card-lint-observe.sh. Written on BOTH outcomes: the record says the
lint ran and what it said, never that the card is good.
```

### The ledger section and its data rows

```text
Extract the ledger section: from the `## Ambiguity ledger` heading (any level,
optional "(final)") to the next `## ` heading or EOF.
```

```text
Data rows: pipe-table rows minus the header row and the |---| separator.
Header forms accepted: "Question"-style and grill's canonical "Item"-style
(`| # | Item | Current understanding | Status | Source |`), case-insensitive.
```

## plugins/taskmaster/scripts/theme-axis-check.py

### Module docstring

The docstring's first line is kept; the rest, as it stood:

```text
A theme-axis pass (aesthetic / density / type family) is only honest if the
CONTENT is identical across frames and only the token preset differs. This
extracts each frame's `.vd-content` inner HTML and diffs every frame against
the first. The per-frame preset lives in the shell's `SLOT: custom-css` style
block, OUTSIDE `.vd-content`, so it is stripped by construction.

WHY A FILE AND NOT A HEREDOC. It shipped pasted into
skills/visual-decisions/references/shell-authoring.md, where its 1.5 KB was
counted against the plugin's on-invoke prose corpus (pc_plugin_corpus,
scripts/plugin-corpus-baseline.json) every time an author read the reference —
and a reader had to paste it correctly to run it. Executable code belongs in
scripts/; the reference now cites this path.

Usage:
    python3 theme-axis-check.py taskmaster-docs/mockups/<file>.html

Exit codes:
    0  every frame's .vd-content is byte-identical (honest theme-axis pass)
    1  a frame differs — the pass is varying content as well as tokens
    2  usage error / unreadable file

LIMITATION: proves the CONTENT matched, never that the token preset is a
single axis. "One axis per pass" stays author judgment.
```

### convert_charrefs

```text
convert_charrefs defaults to True: entities resolve into handle_data,
so a frame differing only by &mdash; vs &ndash; still shows up as a diff.
```

## plugins/taskmaster/scripts/verify-teeth-lint.sh

### Header

The file keeps the reason-code list (without the glosses below), the CLI and the exit codes, which `--help` prints.

```text
verify-teeth-lint.sh — author-time DENYLIST lint for taskmaster Verify lines.

LIMITATION (this is a DENYLIST, not a completeness guarantee):
  This lint blocks only KNOWN-WEAK *SYNTACTIC* forms of a Verify line. It does
  NOT — and cannot — detect an empty test suite, a tautological/vacuous
  assertion, or whether a named test actually exercises the target behavior.
  Those are RUNTIME gates (B1 empty-suite / B3b semantic teeth) enforced
  elsewhere. A line that PASSES this lint is only "not obviously toothless",
  never "proven to have teeth".
```

### compile-only: the project-references caveat

```text
                    PROJECT-REFERENCES CAVEAT: on a root tsconfig of
                    `"files": []` + `"references"` (Vite React-TS scaffold,
                    most monorepos) `tsc --noEmit` is not merely weak, it is
                    VACUOUS — tsc gets zero files and exits 0 having checked
                    nothing. `tsc -b` is the check that runs. Printed as a
                    non-blocking NOTE (below), never as a block: this lint
                    reads line text and cannot know which config a build uses.
```

### migration-run-only

```text
                    check is that it ran. Proves the DDL parsed, not that the schema
                    is right. Blocked separately from bare-suite-pass because a
                    migration runner is not a test runner.
```

### bare-suite-pass: the JVM/.NET half and the residual

```text
                    THE JVM/.NET HALF WAS BLIND UNTIL 2026-09-22: the alternation
                    required a literal `mvn test` / `gradle test`, so `./gradlew test`,
                    `mvn -q test` and `dotnet test` all passed as if they named a test,
                    and card-lint-record.sh then recorded "teeth OK" for them.
                    RESIDUAL: the build-tool names (gradle/gradlew/mvn/mvnw) are matched
                    as bare commands, so a non-test invocation used as a whole Verify
                    line (`mvn package`) is also called bare-suite-pass. That reason
                    misnames it; the verdict — a build command proves nothing about
                    behavior — is still right, and widening beats staying silent.
```

### ui-static-only: the measurement, the warn and the residual

```text
                    MEASURED 2026-09-25 (a session review, UI cards): card 39 verified with
                    `npm run types:check && npm run check && grep -c 'data-test="…"' <tsx>`,
                    this lint exited 0 on it, and the UI shipped with no browser check.
                    WHY A WARN, NOT A BLOCK: the lint reads line text and cannot know whether
                    the repo HAS a JS or browser test runner. That run's repo had none, so a
                    static line plus the card's <walk> line (the orchestrator's walk at group
                    close) was the best a card there could carry. The message says whether
                    the card has a <walk> line.
                    RESIDUAL: the static-command list is a closed heuristic. A script named
                    like a runner (`npm run test:types`) reads as a runner and is not warned;
                    an unlisted static tool reads as behavioral and is not warned either.
                    Legacy **Verify:** cards carry no <file> elements and are never checked.
```

### The run record

```text
RUN RECORD. The lint is a gate when it runs, and nothing observed that it ran —
a card set could reach execution with none of the linters invoked and every check in
the repo green. `record_run` appends one line per invocation beside the card; the
reader is hooks/card-lint-observe.sh. Written on BOTH outcomes: the record says the
lint ran and what it said, never that the card is good.
```

### Two card shapes

```text
Two card shapes: the role-tagged <verify>…</verify> element (taskmaster ≥0.45.0,
one line by card-shape-lint's rule) and the legacy **Verify:** bold label.
Tagged first; a card carrying both is linted on the element.
```

### The jest-matcher list

```text
NOTE: the jest-matcher alternative is a CLOSED prefix list, not `\.to[a-z]+` — the
old wildcard also matched ordinary methods (`.toString`, `.toLowerCase`, `.toFixed`,
`.toJSON`), letting a bare `require(...).toString()` masquerade as an assertion.
```

### 1) always-true

```text
1) always-true — an unconditional pass neuters whatever precedes it. The
   trailing boundary is ANY non-word char (or end), so a following `;`, `)`,
   or closing quote cannot smuggle it past the lint
   (`cmd || true;`, `(cmd || true)`, `bash -c "npm test || true"`). Both the
   `true` command and the `:` no-op builtin count as an always-true tail.
```

### 2) existence-only

```text
2) existence-only — proves a path exists, as the whole check. Covers the
   `test -f/-e/-d` command form AND the `[ -f ... ]` bracket form (both are just
   a stat, never a behavior check) unless combined with a real assertion (&&/grep).
```

### 3a) the project-references NOTE

```text
3a) project-references NOTE — advisory, never changes the exit code. `tsc
    --noEmit` against a root of `"files": []` + `"references"` type-checks ZERO
    files and exits 0, so the line is vacuous rather than merely weak; that
    shape ships with the Vite React-TS scaffold and most monorepos. Detection
    is a cheap heuristic on the CURRENT directory's tsconfig.json — the lint
    grades line text and cannot know which config a build really uses, so this
    informs the author and blocks nothing. Fires before the block below so a
    compile-only line carries the reason it is worse than it looks.
```

### 6) migration-run-only

```text
6) migration-run-only — a migration command whose whole check is that it ran.
Distinct from bare-suite-pass: a migration runner is not a test runner, so the
suite-pass reason would misname it. "The migration applied" proves the DDL parsed
and nothing about whether the resulting schema is correct; the honest verify is a
round-trip assertion against the migrated database.
```

### 7) ui-static-only

```text
7) ui-static-only — WARN, never a block (the header says why). The card edits or
   creates a UI component/view, and every segment of the line is static.
```

## plugins/taskmaster/skills/visual-decisions/assets/serve.py

The module docstring is what `--help` prints (argparse's description) and is unchanged; the two-line header above it is new.

### The ledger excludes per-purpose files

```text
The ledger is the dated-pass history ONLY. A per-purpose file is a live
destination, not a past pass of current.html, so offering it as a restorable
version would let one click overwrite the decision page with the theme page.
```

### The restore header

```text
Restore is the one state-changing route, so it demands a header no
cross-origin <form> can set. That forces a CORS preflight, which this server
never answers, so a page on another localhost PORT cannot drive it — the
Host/Origin check alone would let it through, since every port shares the
hostname `localhost`.
```

### The landing and gallery branches

```text
--- ADDITIVE landing/gallery branches ------------------------------
Synthesized session-map and gallery pages. Both are STATIC snapshots:
no SSE and no auto-reload script is injected, and the /events lane
plus the per-purpose-file model (basename filter) stay untouched. A
user-authored index.html always wins. Delete these two branches (and
the serve_landing / serve_gallery / _gallery_captions helpers) to
revert '/' and '/gallery/' to today's stock autoindex.
```

```text
--- end ADDITIVE ---------------------------------------------------
Ledger lane: the dated passes already on disk, as data, so an open
preview can offer them as versions instead of making the user read
the landing map and retype a filename.
```

### The helper region markers

```text
--- ADDITIVE helpers: synthesized static pages (no SSE/reload) ---------
```

```text
--- end ADDITIVE helpers ----------------------------------------------
```

The `_esc` and `_urlenc` docstrings each opened with `ADDITIVE helper:`, naming this region; the prefix went with the markers, the rest of each docstring stays.

### The basename check

```text
Reject anything that is not a plain basename BEFORE touching the
filesystem: Path('a/../b').name would quietly launder a traversal.
```

### No explicit broadcast

```text
No explicit broadcast: the watcher sees current.html's new mtime
and pushes the reload down the same lane every other edit uses.
```

### The gallery scan

```text
Scoped to gallery/ only (not the whole docroot) — same scan_mtimes
helper, just rooted one level down to avoid O(whole-tree) I/O per hit.
```


### Private paths, LAN key, time limits (2026-11-12, taskmaster 0.57.0)

Inventory that triggered it: `taskmaster-docs/research/2026-11-12-preview-server-gaps.md` (gitignored)
found this server served dotfiles and directory listings and had no harness, while design-kit's
server refused both and had one. The harness, `plugins/taskmaster/scripts/__tests__/serve.test.sh`,
was written first and passed on 0.56.1 (35 cases); each change below added cases that failed on the
code before it.

- **Dot names and listings (404).** `is_private()` rejects a request path with any dot-prefixed
  segment; `list_directory()` returns 404. The check splits the raw path the way
  `SimpleHTTPRequestHandler.translate_path` does, because `urlsplit('//.env')` reads `.env` as a host
  and returns an empty path, which would have let `//.env` through. `scan_mtimes()` skips dot names
  too, so the session map, `/_versions.json`, `/_restore` and the event stream never name a dot file:
  before this, `/_restore` would copy a `.private.html` over `current.html` and so publish it. Red on
  0.56.1's server: 29 cases (`/.env` 200, `/sub/` listing 200, the landing listing `.private.html`, the stream
  carrying `.preview.log`).
- **Time limits.** `--lan` exits after `PREVIEW_LAN_MINUTES` (default 60, design-kit's figure); every
  mode exits after `PREVIEW_IDLE_MINUTES` (default 240) with no completed request and no open event
  stream. 240 follows superpowers' 4-hour idle default named in the inventory. An open tab keeps its
  stream open, so a forgotten tab keeps the server up until the tab closes; that is the intent.
  Red on the server with the dot rule in and no limits yet: 7 cases.
- **LAN key.** Before this, `--lan` relaxed the Origin/Host check for every route, `/_restore`
  included: a peer on the network could restore with just the header (red case "remote restore with
  a valid key", 200 before this change). Now a non-loopback peer needs the key, `/_restore` needs a loopback
  peer and a local Origin/Host in every mode, and the key is compared with `hmac.compare_digest`.
  The key is `secrets.token_urlsafe(24)` in `.preview.key` (0600) so a restart keeps the URL; delete
  the file to rotate it. Red on the server with the dot rule and limits in: 20 cases.

What the harness exercises end to end and what only as a unit: the remote-peer cases run against the
machine's own non-loopback address (the peer is then that address, not 127.0.0.1) and skip, printing
SKIP, on a machine with none; `peer_is_loopback`, `lan_access` and `clean_location` are also imported
and tested directly, which covers IPv6 and IPv4-mapped peers no harness request produces.

Residuals, not tested: the cookie is scoped to the host, not the port, so another server on the same
address receives it; the key crosses the network in plain HTTP and stays in the history of the device
that opened the URL; the first cut answered a keyed URL with a 303, and the design-kit twin measured in Chrome the same
day that a keyed link followed from another site then got 403 (the browser withholds a
SameSite=Strict cookie on that redirect), so the grant is a 200 page with a meta refresh; that page
was checked with curl only on this server, not in a browser; a symlink in the docroot is followed
out of it (checked by hand on 2026-11-12, not in the harness).

### Review fixes (2026-11-12, still 0.57.0)

- **Restore from this machine under `--lan`.** `.preview.url` holds the network URL. A page opened from it on this machine reaches the server from the LAN address, so Restore (loopback peer and local Host only) answers 403. serve.py now also prints `On this machine: http://127.0.0.1:<port>/`. Red: `FAIL LAN: loopback URL printed`.
- **A key file that is not UTF-8.** `load_or_create_key` caught `OSError` only, so `UnicodeDecodeError` escaped after the port was bound. Red: `FAIL non-UTF-8 key file: serve.py did not start: … UnicodeDecodeError`.
- **A symlinked key file.** It was read, truncated and chmod-ed through the link. Red: `FAIL symlinked key file: still a symlink`, `… its target was changed: 0o600`, `FAIL dangling key symlink: serve.py created the symlink's target`. Now as design-kit's: an `O_NOFOLLOW|O_NONBLOCK` open whose `fstat` must say regular file, else unlink and create `O_EXCL|O_NOFOLLOW` at 0600. The key is loaded before the port is bound; an error there exits 1.
- **403s and the idle clock.** `handle()` touched the clock after every connection, key-gate 403s included; now only a connection whose request `lan_gate` admitted does. Red: `FAIL LAN: idle clock: 403s from a peer without the key kept the server from its idle exit`.
- **Restore is a rename.** It copied over `current.html` in place, so a kill mid-copy left it truncated. It now copies to a `mkstemp` file `.restore-*.tmp` (dot-named: never served, never pushed), gives it `current.html`'s mode and `os.replace`s it. The kill itself is not reproduced; the harness pins the mechanism: a new inode and no dot file left. Red: `FAIL restore is a rename: current.html was written in place (same inode)`. Residual: a kill mid-copy leaves the temp file.
