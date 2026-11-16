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

### 0.61.0 — the fourth record (2026-11-14)

`card-paths-lint.sh` has called `cardlint_write card-paths` since it shipped (0.52.0), and this
hook checked three records, so a set that skipped the newest lint drew no warning. It checks
four now and names the fourth script in the warning. The harness holds a case with three
records present and one absent (`rationale/taskmaster-consistency-review-2026-11-14.md`, A14).

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

## plugins/taskmaster/scripts/preview-check.sh

### Why it exists (2026-11-13, taskmaster 0.59.0)

Milestone M3 of `taskmaster-docs/specs/2026-11-12-preview-feedback.md` (gitignored), "render checks". Both
preview servers' headers said that nothing proves a browser rendered a page: the model wrote a pass and
showed it, and nothing looked at the result first. This script loads the page in a real headless browser at
three widths, collects what the page's own check found, and prints it to the model before the user sees the
pass. `scripts/find-browser.sh`, the browser lookup this script and `preview-feedback.sh` both source, points
here too.

### How it runs

- **The DevTools pipe, not `--window-size`.** The design was one `--window-size=W,H --screenshot` launch
  per width, as `preview-feedback.sh shot` does. Measured on Chrome 157 (`--headless=new`) and Playwright's
  Chromium 1248: `--window-size=375,900` gives `innerWidth` 500. The new headless mode will not make a window
  narrower than 500 px; `--screen-info` does not change that, and plain `--headless` measured the same.
  So the script starts the browser with `--remote-debugging-pipe` and speaks the
  DevTools protocol from stdlib Python (NUL-terminated JSON on fds 3 and 4).
  `Emulation.setDeviceMetricsOverride` gives exact widths (375 measured as 375); `Page.captureScreenshot`
  with `captureBeyondViewport` gives a full-page PNG while `100vh` stays the 800 px viewport (measured with a
  `100vh` hero); `Runtime.evaluate` awaits the page's check promise, so no virtual-time budget has to guess
  when the check is done. One browser serves every width.
- **Reused from `shot`.** The browser lookup, moved to `find-browser.sh` so the two lists cannot drift; the
  sandbox rule (on, unless root or `PREVIEW_BROWSER_NO_SANDBOX=1`); `timeout` around the browser (90 s, a
  backstop behind the script's own deadline and its limit per width: 60 s and 20 s as first built; each plus
  1 s per state in 0.62.0 as first written, a state being one look a check is run under; and since the review
  fix of 2026-11-15 a width's limit is 20 s again and the run's is 60 s plus the time its states used, 76 s at
  most; see "E2 again under each style and each type option" and "States that do not fit are named" below); a
  throwaway `--user-data-dir`, removed
  on exit. The browser runs in its own session, so a stuck one is killed as a group. The output escaping is
  `preview-feedback.sh`'s `show()`, copied with its blank-character set, because findings carry page text.
- **No network.** `--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE 127.0.0.1` plus
  `--disable-background-networking`, `--disable-sync`, `--no-pings`, `--disable-extensions`. Measured: an
  image at `http://127.0.0.2:<port>/` and one at `http://localhost:<port>/` were both reported as failed
  loads, and the server on 127.0.0.2 logged no request from the browser, so an IP literal does not slip past
  the rule.
- **The page checks, the server keeps the result (as first built; replaced before release, see "The check left the page" below).** The shell's loader `document.write`s
  `<script src="/_check.js">` only with `?_check=1`. A parser-inserted script runs before the shell's own
  scripts, so the check's `console.error` wrapper and `error` listener see their errors; an inserted
  `<script>` element would run after them. The page posts per width to `POST /_check`; serve.py clamps and
  stores the record, and the script reads it back from disk, matched by a run token in the URL. So one
  sanitiser stands between page text and the output. Records live in `.checks/<page>-<sha1 prefix>/` as
  `<width>.json`, the PNGs beside them; the script empties that folder before each run.
- **One line per finding.** The same check, selector, text and detail at several widths print once, with
  `widths`. The badge counts the same way, so the two numbers agree (E6 aside: the script computes it, the
  page never posts it).
- **`?static=1`** keeps the reload client, the feedback controls, the badge and, new here, the version
  picker out of the checked page. The picker names the file, so two passes with the same content never
  screenshot alike.

### What each check measures, its thresholds, and what it misses

**E1 load.** Blank: the body box is under 1 px in either direction, or it holds no text and no
img/svg/canvas/video/picture/iframe/object/embed. Console: every `console.error` call, uncaught `error`
event and unhandled rejection after the loader ran. Every check caps one text at 10 findings per width, so
one defect class cannot crowd the 8 KiB post. Failed loads: an `error` event on an element (captured at the
window, so img, script, link and source), resource-timing entries with `responseStatus` 400 or more, and same-origin entries with no status, no bytes and not fetch, XHR or beacon (no response at all);
the check's own routes are left out. Misses: an error before the loader runs; a cross-origin CSS background
or font that fails (no `error` event, and timing hides its status); a page that loads fine and shows the
wrong thing.

**E2 layout.**
- Sideways scroll: `scrollWidth` over `clientWidth` by more than 1 px (subpixel layout) for the document and
  for each shell `.vd-frame > .vd-content`. That box is `overflow: auto` for its 560 px height cap, and CSS
  turns the other axis to `auto` with it, so sideways scroll there is never intended. Any other scroll box is
  taken to scroll on purpose (a table wrapper). The finding names the outermost element whose box passes the
  edge, skipping elements inside a nested scroll or clip box, else the first element whose own text runs
  past it (an unbroken string). The first version named the deepest element; on the real run that was a
  header cell of a table that a long reference had widened, and outermost names the table.
- Wider than the viewport: the outermost box wider than the viewport by more than 1 px, not inside a
  sideways scroll box and not the sideways-scroll culprit, which leaves the case where an ancestor cuts it
  off instead of scrolling.
- Clipped text: `overflow` `hidden` or `clip` on an axis, a client box of 2 px or more both ways (a 1 px
  visually hidden label is not a clip), scroll size over client size by more than 1 px across or 2 px down
  (some fonts overhang a tight line height), and a rendered text fragment outside the padding box by the same
  margins. Text inside a nested scroll or clip box is cut to that box first. An ellipsis or line clamp passes
  when a `title` on the element or an ancestor, or its own `aria-label`, holds the full text.
- Overlap: each child against its next two siblings, both rendered and in flow (`position` static, relative
  or sticky, no float, block-level display); their rendered text fragments, cut to their clip boxes so text
  scrolled out of a variant box does not count, intersect by more than 2 px both ways. Absolute and fixed
  boxes are skipped as usually intended (badges), inline runs because their bounding boxes share lines.
- Targets: `a[href]`, button, input, select, textarea, summary and focusable elements with an interactive
  role, rendered, not disabled or inert. Flagged under 23.5 px either way (24 less half a pixel of rounding)
  only when WCAG 2.5.8's spacing test fails too: a 24 px circle on its centre meets another target, or another
  small target's centre is under 24 px away. A target inline in a parent that holds more text, and a native
  checkbox or radio with the default appearance, are excepted. axe's `target-size` rule is switched off, so a
  small target is one finding, not one under E2 and one under E3. The shell's callout badges (1.5em) drew no
  finding on the real run.
- Misses: overlap from absolute or fixed boxes, floats and inline runs; another scroll box scrolling
  sideways by accident; clipping inside the margins; a carousel's off-box slides read as clipped; a hit area
  enlarged by a pseudo-element.

**E3 accessibility.** `axe.run(document)` with tags wcag2a, wcag2aa, wcag21a, wcag21aa and wcag22aa,
`target-size` off, violations only; impact serious or critical, one finding per rule: the rule id as the
text, the first node's target as the selector, the impact, help text and node count as the detail. Serious
and critical keep the list to what blocks someone (contrast, names, labels). Misses: moderate and minor
impacts; best-practice rules (landmarks, heading order); what axe marks incomplete (contrast over images and
gradients); states hidden by default, since the shell shows `populated` and axe skips `display: none`.
Vendored: axe-core 4.14.0 from npm, `axe.min.js` (sha256 `20c09fe1…e878`, pinned by the harness), MPL-2.0,
which is file-level copyleft: the file ships unmodified beside its licence and third-party notices. 652 KB,
read from disk on each request and served to loopback only.

**E4 stand-in content.** Text nodes of the whole body, hidden data-state blocks included (script, style,
template and textarea excluded), against: `lorem ipsum`, `dolor sit amet`, `consectetur adipiscing`;
`placeholder`; `TODO`, `TBD` or `FIXME` in capitals (so a "todo list" passes); "your" or "some" plus one of
13 nouns plus "(goes) here", or "text/content/copy/title goes here"; a whole text node that is one of 21
generic words (item, row, card…) plus a number, N or X. One finding per pattern with the count of further
hits. Identical rows: three or more siblings that are `tr`, `li` or `article`, or hold two or more elements,
with the same collapsed text of two or more characters, outside `data-state="loading"` (a loading block
repeats by design); cells are not rows, so three "Paid" chips in a column pass. Empty: a table with no `td`
holding text or a control, or a list with no `li` doing so, rendered or inside a data-state block, outside
`data-state="empty"`. Misses: realistic-looking wrong data; stand-ins in attributes (`alt`, `aria-label`); a
pattern word used on purpose; an unfilled SLOT (a comment renders nothing, outside `<title>`).

**E5 variants (advisory).** Each pair of `.vd-frame > .vd-content`. Identical: the same collapsed
`textContent`, the same element sequence (tag, sorted classes, every attribute but `id`, `class`, `for`,
`headers` and the id-reference ARIA attributes) and the same palette. Several axes: the shared fraction
(Jaccard) of distinct words, of parent>child tag-and-class pairs, and of colour and font values (`color`,
a visible `background-color`, `background-image`, the border colour where a border is drawn, family, size
and weight) are all under 0.5. The shell's own rules set what may differ: a theme-axis pass has identical
content and different token presets (palette differs, so not identical); a motion pass has identical
structure and different `vd-m-*` classes (classes are in the sequence). 0.5, "less than half in common on all
three", is a judgment, not a measurement. On the real run's layout pass (table against cards, the same three
invoices) the shares were words 0.70 and 0.76, tag pairs 0.27, palette 0.96 and 0.97 across the two passes:
one axis, nothing reported, two of three far above the line. Misses: two axes changed with the third close;
whether the variants differ on the axis the header names; anything outside the content box.

**E6 change (advisory).** Only for `current.html` or a ledger pass. The previous pass is the newest entry in
`/_versions.json` that is not the page, not newer than it (1 s slack), and differs from it in bytes, which
skips the pass's own dated copy of `current.html`. The script screenshots that pass at the widest width and
compares the two PNGs in an `about:blank` canvas in the same browser: a pixel changed when alpha differs or a
channel moves by more than 24 of 255 (room for antialiasing; identical renders measured 0 changed). It
reports the share, the count and the bounding box; pages of different heights are compared on the union,
the difference counted as changed. It prints with `"advisory": true` and never counts, since a new pass is
meant to change. Misses: whether the change is the one asked for; a height change shifts everything below
it, so the box covers it (the real run: 7 px taller, box x 0-1279, y 41-818); the previous pass may belong to
another decision; one width only.

**E7 limits (a layout or creative pass).** Runs only when `<body data-vd-pass-kind>` is `layout` or
`creative`; `passKind()` in check.js reads that mark, and later checks call it. No mark, or any other value,
draws nothing: the shell builds no switcher row there either. Every limit is read from the page as loaded,
never from the `#vd-presets` rules: the shell is the one reader of those rules, and what it built is what a
person is shown and what a pick posts. Frames: more than 6 `.vd-frame` elements. Switchers: more than 3
elements carrying `data-vd-switcher`; the shell builds palette, style and type only, so a fourth is markup
written by hand and appears in no preset rule. (As first written E7 counted such elements anywhere in the
document. Since the review fix of 2026-11-15 it reads only those inside the header's look row,
`#vd-header > .vd-look`, and the option limits and names below are read from those switchers alone; see
"States that do not fit are named" below.) Options: more than 4 `[data-vd-option]` in one switcher. A name
repeated in one switcher: one finding per name. A name serve.py's `LOOK_NAME` refuses (not 1 to 24 ASCII
letters, digits, spaces, hyphens or underscores): one finding per switcher, listing the names. That rule is
now written three times (serve.py, the shell, check.js). A kind with one option has no switcher, yet the
shell applies it and a pick posts its name from `<html>`; so for palette, style and type with no switcher,
the `data-vd-<kind>` attribute on `<html>` is read as that kind's one name. These are findings (exit 1), not
advisories: they are the gate behind the count rule. Misses: a preset rule the shell does not list (a
selector list, `:root[…]`, a name holding `"` or `\`), which is an option its author wrote and nobody is
shown; a kind with one option beside three shown switchers (four kinds, three switchers); the floor of 2
frames, the default of 3 and the sixth frame being legal only as one kept plus five new, which need the
passes before this one; a pass-kind mark with a typo, read as another kind; a page whose script stopped
before the shell built its switchers (E1 reports the error).

**E8 palette contrast, and E2 again under each style and type option.** Both were added on 2026-11-15 and
are described under their own headings below, each with what it misses.

### Red, then green

The harness was written first and run against nothing: 48 of 58 failed (`bash: …/preview-check.sh: No such
file or directory`). With the runner, routes and loader in place but `check.js` running no checks, 14
failed. Each of the 11 per-check fixtures was missed, for example `FAIL E2 overflow at 375 only: want exit 1
and [E2|page scrolls sideways|375], got 0 and []` and `FAIL E3 low contrast (axe): want exit 1 and
[E3|color-contrast|375,768,1280], got 0 and []`; the escape case had no detail to decode; and two showed a
bug: E6 ran for a page under `f/`, which is no ledger pass (`FAIL no E6 outside the ledger`), and printed its
box as x0-y0, x1-y1. With the checks wired, one failure was left: `FAIL E4 three identical rows: … got …
E5|variants differ on several axes`. The fixture's variants did differ in data, markup and colours (one
customer against three), so the fixture was wrong, not E5; its B now repeats the same card. Then 58 of 58
in 11 s.

### The real run (2026-11-13)

A two-variant shell page (invoice table against invoice cards, built like the admin-table starter) with an
image that 404s, an unbroken 39-character payment reference, lorem ipsum in one card and grey on grey text
(`#a1a1aa` on `#d4d4d8`). The script started the server itself and printed 7 findings in 0.77 s wall time:
E1 the 404 at all widths; E2 variant A scrolling sideways at 375 and 768 (the reference widened the table to
515 px), variant B at 375 (the reference itself named), and at 1280 the reference spilling over the next card
as overlapping text; E3 `color-contrast`, 2 elements; E4 lorem ipsum. The 375 PNG shows the header controls
wrapped, the table cut at the frame's edge with the broken image's alt text, the grey bar, and the reference
running out of its card. Fixed as pass 2 (initials instead of the image, `overflow-wrap: anywhere`, real
text, `#3f3f46` on `#f4f4f5`) and copied to `current.html`: 0 findings, exit 0, 0.71 s, and E6 against pass
1: 8.67 % of pixels. The badge was driven in Chrome on the same page: "checked: 0 findings" at load, "not
checked" after an edit reloaded the tab, "checked: 0 findings" again after a check run, in the same document.

### Not covered

The macOS and Edge lookup paths; a browser that starts and then hangs (the run's deadline and a group kill
handle it, untested; the deadline was 60 s as first built, 60 s plus 1 s per state in 0.62.0 as first
written, and is 60 s plus the time the run's states used, 76 s at most, since the review fix of 2026-11-15);
what the PNGs show
(one looked at by eye, above); the shell `shot` path still uses `--window-size`, so page script there first
sees a window at least 500 px wide. (Corrected 2026-11-15: this line said such viewports "render 500 px
wide". The PNG is laid out at the row's width; see "Blank rows above the header in a shot" under
preview-feedback.sh's heading.)

### Review fixes (2026-11-13, taskmaster 0.59.0)

A review of the uncommitted tree listed defects; each was reproduced first, the harness case red before the fix and green after (red run: the new `preview-check.test.sh` on the unfixed tree, 47 passed, 23 failed).

**The check left the page (M9, H1, L6).** check.js ran in the page through the shell's `?_check=1` loader and posted to `POST /_check`; the runner trusted `window.__vdCheck`, which page script can replace. Red: a page setting `window.__vdCheck` to an object printed its own `error` raw on stderr (`FAIL forged answer escaped: a raw ESC reached the output`), and a page that swallowed the real post and posted an empty one with the `_run` token from its URL hid lorem ipsum (`FAIL a forged empty post does not hide lorem ipsum: want exit 1 and [E4|lorem ipsum|375,768,1280], got 0 and []`). Now the runner registers check.js with `Page.addScriptToEvaluateOnNewDocument` in a named world (so its load-error listener is in place before the first resource), evaluates axe-core there after `load`, calls `__vdRun()` and reads the findings over DevTools, then writes each width's record itself. Console errors and uncaught errors, which an isolated world does not see (measured: Blink dispatches a script's ErrorEvent only in its own world), come from `Runtime.consoleAPICalled` and `Runtime.exceptionThrown`, ten per width as check.js counted them, events past 200 counted. The shell's loader and the `/_check.js`, `/_axe.js` and `POST /_check` routes are gone, so a page not built from the shell is checked too (red: `got 5`). A width not reported prints `{"not_reported": width, "reason": ...}` on stdout through `show()`, never page text on stderr. Measured on the shell: the browser's own `/favicon.ico` probe of a plain page read as a failed load; it is skipped, as design-kit skips it.

**Nothing leaves the machine (H3, M7, L13).** With `http_proxy` set and no desktop session variables, Chrome sent `GET http://example.com/logo.png` and its own update and time requests to a loopback proxy, since the resolver rule excludes 127.0.0.1; `--proxy-server=http://127.0.0.1:9` wins over the environment and loopback still bypasses it. A page's Blob download was saved to `$HOME/Downloads`; `Browser.setDownloadBehavior {deny}` is now the first command. A STUN address on 127.0.0.1 got a UDP packet; `--webrtc-ip-handling-policy=disable_non_proxied_udp` stops it (the `--force-` spelling did nothing on Chrome 157).

**Failures keep what was collected (M8, L12).** A page busy for 34 s after load: the check timed out at 20 s, the screenshot outside the per-width try then timed out, and the run exited 6 with nothing printed (`FAIL a busy page: got 6`). The shot is now inside the width's handling (the width reads not reported), E6 has its own try and degrades to an advisory, and findings and the summary print before any non-zero exit. The driver is `exec`'d and handles TERM, HUP and INT once (timeout(1) signals the child and then its group): it closes the browser and removes its profile, which is now made in Python. Red: `FAIL TERM: profile: left behind`.

**Thresholds (M11, L7, M14).** Overlap compared raw range rects at 2 px, so the shell's `.vd-display` (32 px, line-height 1.15) above `.vd-t1` read as overlapping by 85x4 px with Noto Sans; it now compares 0.8 em glyph bands, 4 px each way and 35% of the smaller band, design-kit's rule. A FontFace the page starts loading at `load` kept `document.fonts.ready` pending: 20 s and exit 5 on the old code and on the new code without a limit, 4 s with a 3 s race. (A font requested before `load` holds the load event itself; that still times out at 20 s.) Element walks stop at 4000, counted in the summary's `capped`.

**Records (L9).** Folders whose records and `run.json` name only pages no longer in the docroot are removed at each run (red: the folder stayed). Records are runner-written, so the server's shared 2 MiB budget and any-integer width went with the route.

**What a hostile page can still do.** Its script runs while it is measured: change the DOM it is measured on, detect a headless browser, keep the main thread busy so a width reads not reported, log errors, open dialogs (accepted), and reach any loopback service, `POST /_feedback` of this server included. It can no longer read, replace or answer for the check, nor write a record.

### E7: the limits of a layout or creative pass (2026-11-15, taskmaster 0.62.0)

Commit `05e1a1a9`.
The shell had come to draw up to six lettered frames and a palette, style and type switcher from the page's
preset rules, and nothing capped either. Measured on the shell: five rules give five buttons, two rules of
one name give two buttons, and a name serve.py refuses is drawn as a button (serve.py's `_look_name` stores such a
name as null on a pick). E7 is the check behind "never more than 6 frames, 3 switchers, 4 options in one,
each name once and storable". The code E6 was taken, so E7 is the next free one.

Red, then green. The 22 cases were written first and run on the check as it stood: the 15 that expect a
finding failed (`got 0 and []`: the limit pages draw no other finding). With E7 in check.js and no `"E7"` in
preview-check.sh's `CHECK_IDS`, the findings were counted as dropped and never printed (`got 1 and []`).
The harness as a whole on that first run read 32 passed, 15 failed, a total relayed from that run's report
and not run again for this line.

The 7 cases that expect no finding pass on any code without E7. Three were shown to fail under a mutant of
check.js: with the pass-kind guard removed, `FAIL unmarked page clean for all five limits (frames)`; with any
mark value read as a pass kind, `FAIL seven frames under a pass-kind value that is neither layout nor
creative draw none`; with a limit one lower, a name of 23 characters refused, or a name allowed no space,
digit, hyphen or underscore, `FAIL six frames and three four-option switchers clean, …`. The other four are
the unmarked pages of the switcher limits. The shell builds no switcher on a page with no mark, so no change
to check.js makes them fail: they hold only against a shell that starts building switchers there, or a check
that starts reading the rules. A switcher written by hand on an unmarked page is not covered.

Twenty mutants of check.js in all; none survived the final cases. Two survived a first draft and changed
them: reading the `<html>` name for a kind that has a switcher too printed a refused active option twice, so
the refused palette is now the first, active one and the case counts one finding; and the page marked with
another pass-kind value was added.

### Frames named by position (2026-11-15, taskmaster 0.62.0)

Commit `b30b8f6f`. `letterOf` in check.js names the frame a finding sits in, a frame being one of the
alternative designs the page shows side by side. It read the frame's id and knew a to c, so a finding on a
fourth, fifth or sixth frame said "variant ?". It now returns the letter by the frame's position among the
`.vd-frame` elements, A to F, and `?` for a seventh. It reads neither the id nor the `data-vd-letter`
attribute the shell's script stamps on each frame; a harness page of five frames with its third block
deleted and no stamped letter names its third frame C.

### E8: each palette's text contrast, in light and in dark (2026-11-15, taskmaster 0.62.0)

Commit `dfafc4f4`. A palette is a named set of colours that the page's Palette switcher applies to every
frame's content; a page may offer up to four, each in a light and a dark scheme. axe-core (E3) runs on the
page as loaded, so it measures one palette in one scheme. E8 measures each of them. Every number in this
entry is as reported by the agent that made the commit, in that run on its machine; none was measured again
when the entry was written.

- **What it measures.** For each palette, in light and in dark, seven pairs of text and the colour behind
  it, against 4.5:1 with no allowance for large text: body text, soft text, button text, chip text, alert
  text, nav text, and the primary colour used as text. A palette whose rule declares a property and has no
  dark rule is measured in light only; a palette whose rule is empty is measured in both. (Since the review
  fix of 2026-11-15 "its rule" is the palette's first rule, and a dark rule counts only at the top level of
  the presets block or directly inside an `@media screen` block; see "States that do not fit are named"
  below.) The lowest ratio
  among all matching elements in any frame is reported once per palette and scheme. A pair no frame draws is
  measured on a probe element the check inserts. The background is composited down to the nearest opaque
  ancestor.
- **When it runs.** Once per run, in the first width's load, on any page with a palette. It is not tied to
  the pass kind, the mark E7 reads.
- **Cost.** Time for the whole loop, median of 9 runs: 6.1 ms with four palettes, 289 ms with four palettes
  and 4000 chips, 0.2 ms with no palette.
- **Red, then green.** On the code before the change the harness read 109 passed, 39 failed. 22 mutants, all
  killed. A mutant is a copy of the code with one deliberate defect; it is killed when a harness case fails
  on it.
- **Misses.** Text over a background image; text dimmed by opacity; a pair on a background the page does not
  draw it on; text that is none of the shell's own primitives; an alert's accent glyph and its border. A
  pair that fails in the look the page loads with, on a visible element, draws two findings, one from E3 and
  one from E8.

### E2 again under each style and each type option (2026-11-15, taskmaster 0.62.0)

Commit `ac83f20d`. A style option changes radius, spacing and shadow, and a type option changes the font
stack; each is chosen in a switcher and applies to every frame. Layout was checked only under the look the
page loads with, the look being the active option of each switcher. Every number in this entry is as
reported by the agent that made the commit, in that run on its machine; none was measured again when the
entry was written.

- **What runs.** In the 375 px load the layout check runs again under each style option and each type option
  the page did not load with, one kind at a time and never as a cross product. A finding is prefixed `style
  "Name": ` or `type "Name": `. A finding on an element the look at load already drew one on is dropped; the
  match is by element, not by detail.
- **A defect found on the way.** `checkLayout` kept its cache of clip boxes from one run to the next, which
  drew a false "text clipped" blamed on the option. It now clears the cache on each run.
- **Limits that grow.** A state is one look a check is run under: a palette in a scheme for E8, a style or a
  type option at 375 px here. As first written, the run's limit was 60 s plus 1 s per state and a width's was
  20 s plus 1 s per state (`PER_STATE = 1`); a page inside E7's limits has at most 14 states, so 74 s, under
  the 90 s `timeout` around the browser. The summary line gained `"states": N`. (Replaced the same day by the
  review fix: `PER_STATE` is gone, a run's states share 16 s and at most 16 of them run, the run's limit is
  60 s plus the time they used, 76 s at most, and a width's limit is 20 s again. See "States that do not fit
  are named" below.)
- **Measured.** Wall time per state: 1.1 to 3.5 ms on six frames of one paragraph each, 27 to 46 ms on six
  frames of about 1,950 elements, 56 to 131 ms on 5000 paragraphs; 1 s is 7.6 times the slowest. A page with
  four palettes, four styles and four types ran its 14 states in 0.6 s over three widths. Once by hand, not
  in the harness: with every state slowed to 1.6 s the run ended exit 0 in 23.0 s, and exit 5 without the
  1 s per state. (That was the code as first written. Under the review fix's shared 16 s that page would
  have some of its states named and not run: computed, not run, in the entry below.)
- **Red, then green.** On the code before the change the harness read 152 passed, 15 failed. Fifteen
  mutants: 12 killed by new cases, 1 by an existing case, 1 equivalent (it changes no behaviour), and 1
  survives, a state that adds nothing to the limits. So no harness case holds the 1 s per state; only the
  run by hand does. (True of that code. The review fix removed the 1 s per state, and one mutant of the new
  code survives as well: the entry below names it.)
- **Misses.** A CSS transition on a layout property hides an option's overflow: with
  `.vd-nav{transition:gap .5s,padding .5s}` a run gave 0 findings. An element only an option shows is not
  measured. A style together with a type the page did not load with, and an option at any width but 375,
  are not run. A page past E7's limits can raise the run's limit past the 90 s `timeout`. (That last
  sentence held for the code as first written. Since the review fix the run's limit is 76 s at most whatever
  the page lists.)
- **Known and left alone.** The E5 advisory joins the text of touching elements into one word, and six
  frames give it 15 pairs to compare.

### States that do not fit are named; the look row; one dark-set rule (2026-11-15, taskmaster 0.62.0, after the range review)

Commits `706424a0` and `0d8d06d4`, in `preview-check.sh` and `check.js`, after a review of every 0.62.0
commit together. A state is one look a check is run under: a palette in a scheme for E8, a style or a type
option at 375 px for E2. Every number in this entry is as reported by the agent that made the commits, in
that run on its machine; none was measured again when the entry was written. A mutant is a copy of the code
with one deliberate defect; it is killed when a harness case fails on it.

- **One budget for a run's states, and a cap.** As first written each state added 1 s to its width's limit
  and to the run's, however many the page listed. Now a run's states share one budget, `STATE_BUDGET = 16`
  seconds, and at most `MAX_STATES = 16` of them run, counted by position in the plan check.js returns. The
  run's limit is 60 s plus the time its states used, so 76 s at most; a width's own check is held to 20 s
  again, and its states to the budget. A state starts only if the slowest state so far fits in what is left
  of the budget. That time is measured from the Python side; the layout check's time at load is not visible
  there apart from axe and the font wait. A state that has started and outlasts the budget is stopped with
  `Runtime.terminateExecution`, and the page is loaded again before the screenshot.
- **What a state not run prints.** One line:
  `{"not_reported": 375, "state": {"check": "E2", "type": "Mono"}, "reason": ...}`, and for E8 a state of
  `{"check": "E8", "palette": …, "scheme": …}`. The summary gains `"states_not_run"`, and `"states"` counts
  the states that ran. The run exits 5 when any state did not run, and the width keeps its record.
  `PREVIEW_STATE_BUDGET`, in seconds, lowers the budget and never raises it: it is the harness's knob and is
  not in the script's header.
- **Measured by hand**, Chrome 157.0.8103.78, one run each. A page of 18 states: 16 ran, 2 were named,
  0.3 s. Six states held 300 ms each under a budget of 1.5 s: 4 ran, 2 were named, 1.5 s (the code before:
  all 6 in 2.1 s, exit 1). A first state held 8 s under a budget of 0.5 s: stopped, 0.9 s in all, and E6
  read "0% of pixels differ" (the code before: 8.4 s, exit 1). Two widths under a budget of 1.2 s: 4 palette
  states at 1280, then the state at 375 "did not finish in the 0.4 s left". The harness's own run went from
  90 s to 96-97 s.
- **The latest a run can end, by arithmetic only.** 76 s, plus 3 s for `Browser.close`, plus 5 s of process
  wait, is 84 s against the 90 s `timeout`. No run waited that out.
- **E7 reads the header's look row.** It counted every element carrying `data-vd-switcher` in the document,
  so a control a frame drew as its own content with those attributes was read as a switcher. It now reads
  `#vd-header > .vd-look [data-vd-switcher]`, the row the shell builds.
- **So does the state plan** (the second commit). `optionsOf`, which lists the options the states are
  planned from, read the first `[data-vd-switcher]` of its kind in the document, so a frame's control hid the
  page's real palettes from E8. The reproduction: a lone palette Dusk failing in dark at 3.00:1, plus a frame
  control marked `palette`, gave exit 0, no finding and 4 states; it now gives exit 1 and 2 states.
  `switchers()` is the one expression `checkLimits` and `optionsOf` both read. The harness reads the plan
  under `PREVIEW_STATE_BUDGET=0`, where every planned state prints as `not_reported`.
- **One rule for "no dark set".** check.js's `lightOnly` reads the presets sheet's top-level style rules
  (`CSSStyleRule`) plus the direct children of a `CSSMediaRule` whose `media.mediaText` is exactly `screen`,
  in document order. A palette is light only when the first rule with its exact selector has
  `style.length > 0` and no rule has its exact dark selector. A dark rule inside `@media print`, `@supports`,
  `@media screen and (min-width: 1px)` or an `@supports` nested in `@media screen` does not count. Before,
  any rule with the palette's selector that set a value counted, and so did a dark rule one level inside any
  at-rule. shell.html reads the same expression since its own review fix (its heading below).
- **The harness honours `PREVIEW_REQUIRE_BROWSER=1`.** `preview-check.test.sh` printed SKIP and exited 0
  without a browser whatever the environment said. With the variable set, no browser is exit 1
  (`FAIL the browser half`) and so is a missing python3; without it the exit is 0 as before. These were runs
  by hand: no harness case holds them, and no run with curl missing is reported. Commit `66306dfb` makes CI's
  harness step export the variable, which this harness, `shell-controls.test.sh` and
  `preview-feedback.test.sh` read; that setting has not been exercised on a runner.
- **Red, then green.** The harness read 167 passed before the fix. The first commit's finished harness on
  the code before it: 174 passed, 21 failed (12 for the states, 1 for E7, 8 for the dark-set rule), and 195
  passed after. The second commit's harness on the first commit's code: 199 passed, 6 failed, and 205 passed
  after; it added 10 cases on three fixtures, `control-palette`, `control-type` and `control-style`.
- **Mutants.** For the states, 10 seeded and 9 killed. The survivor removes `DEADLINE += share`: nothing
  holds the bookkeeping of the run's limit, and the 60 s has no knob a harness could lower. For the dark-set
  rule, 5 seeded and 5 killed. For the plan, "`optionsOf` reads the whole document" was killed (199 passed,
  6 failed).
- **Residuals.** A state not run shows only on stdout and in the exit code: the width's record has no field
  for it, and the page's badge probably counts the width as checked. A uniformly slow page is held tighter
  than before: the earlier run by hand, 14 states slowed to 1.6 s each, exit 0 in 23.0 s, needs 22.4 s for
  its states and would now run about 10 of them and name the rest (computed, not run). The first state of
  each width has no measurement before it. The cap drops style and type options first, because palette states
  come first in the plan. Nothing bounds the number of state lines printed. An evaluate that errors outright,
  or a plan that cannot be read, still voids the width. A state that cannot be stopped within 3 s would
  likely lose the width. The stop was exercised on Chrome 157 only. A switcher written by hand outside the
  look row and outside the frames draws no E7 finding, and the plan ignores it. Frame content with its own
  `id="vd-header"` and a `.vd-look` child would match the look row's selector.
- **Untested.** A palette whose light rule exists only inside `@media screen`. A palette name holding a
  quote. A switcher written by hand outside the look row and outside the frames. A lone real option beside a
  frame's control of the same kind, for style and for type.

### Second pass: five assertions the red-team round found missing; switchers anywhere in the header (2026-11-16, taskmaster 0.62.0, commit `ccf3e071`)

A red-team round at `e60787e5` asked one question, would the harness fail if the code were wrong, and seeded
11 mutants in a scratch copy: 5 were killed and 6 left every harness green. Five of the six were in this
check; none was a defect in the code, each was an assertion nobody had written. They are written now, and
each was shown to kill its mutant (relayed from the worker's report; the orchestrator re-ran the harness
by receipt only, 237 passed):

- The 4.5:1 threshold: every failing fixture was at or under 3.95:1 and every passing pair at or over
  5.17:1, so `>= 4` passed. Now #777777 on #ffffff (4.478:1) is reported and #767676 on #ffffff (4.542:1)
  is not. Mutants `>= 4` and `>= 4.6` killed.
- E8 runs at the first width given: with `--widths 768,1280` a failing palette is reported at 768. Mutant
  `"E8": 375` killed (it gave exit 0 and no finding).
- The look at load is kept under an option: a style that overflows only with the type the page loaded with
  is reported under that style. Mutant `setLook({ ...state.look })` killed.
- A refused name on a lone style and on a lone type is reported. Mutant `['palette']` killed.
- Two options that each break one element give two findings. Mutant `drawn.add(el)` killed.

Changed behaviour, from the review of the fix round:

- `switchers()` reads `#vd-header [data-vd-switcher]`: anywhere in the header, where the first fix read the
  look row only and so stopped seeing a switcher written by hand beside the header's other controls. Not
  covered: a switcher outside the header; a hand-written and a shell-built switcher of one kind both in the
  header (E7 counts both, the plan takes the first in document order; untested, and which should win is
  undecided); the plan has no pass-mark condition, so such a switcher adds states on an unmarked page too.
- The slowest state time is kept for the whole run, so at a second width a state that cannot fit is named
  "not run" and not started, stopped and reloaded. One run each at a 1.2 s budget, `--widths 1280,375`:
  1.6 s before, 1.2 s after.
- A repeated `--widths` value is dropped when the argument is parsed. The six-width limit still counts
  before repeats are dropped (untested).
- A state that cannot be stopped says ", and could not be stopped in 3 s". No harness case (it would wait
  the 3 s); one hand run with a state blocked in a synchronous request: exit 5, the width recorded, 5.3 s.
- Seven cases run the check on the shell harness's own `scheme-*.html` pages and assert, per page, which
  schemes E8 plans, so an edit to `lightOnly` here fails on the pages the shell's Scheme toggle is tested
  on. The expected table is one more hand-kept copy; an edit to the shell's `lightOnly` alone is still
  caught only by the shell's harness.
- The time-dependent case ("states slower than the time they share") accepts "did not finish" for the first
  state left. It still depends on time through its allowed range of states, and the two-widths case fails on
  a stall of about 250 ms (arithmetic, not observed). Five runs in a row passed, 109 s each.

Harness: 205 cases to 237; with the new cases and the code unfixed, 229 passed and 8 failed.

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

### 0.61.0 — the ledger quoted the marker (2026-11-14)

`real-components.md` tells the model to record a real-component pick as a ledger row "with
`src/__design-preview__/main.tsx` as the source", and grill persists the ledger under
`.cc-artifacts/taskmaster/`. The content grep covered that folder, so from the first pick on
every run printed `artifacts REMAIN` and exited 1, on a tree with no scratch file left.
Reproduced in a scratch directory holding only such a ledger: exit 1 twice. The grep now skips
`.cc-artifacts/` and `taskmaster-docs/`. Not skipped: an older ledger under `.claude/taskmaster/`,
since `--exclude-dir` matches a folder name and `.claude` holds more than ledgers.

`--verify` was read only as the first argument, so `preview-cleanup.sh <root> --verify` took
`--verify` for nothing and ran the deleting mode. Arguments are now parsed in any order and an
unknown option exits 2. Found by reading in `rationale/taskmaster-consistency-review-2026-11-14.md`
(A1, A18); the harness gained a fixture for each.

## plugins/taskmaster/scripts/preview-feedback.sh

### Why it exists (2026-11-13, taskmaster 0.58.0)

Milestone M2 of `taskmaster-docs/specs/2026-11-12-preview-feedback.md` (gitignored): the user picks a
variant, points at an element or leaves a note in the browser, and the model reads it without a chat
message. The spec's decisions 2 and 3 rule out an MCP server, a browser extension and a new per-prompt
hook, so the page writes rows to a file (serve.py's `POST /_feedback`) and this script reads them.
`wait`, run as a background command, is what brings the model back when the user clicks.

- **Rows print as data.** One JSON object per line. After `json.dumps(ensure_ascii=False)`, every
  character in a Unicode `C*` category (controls, format characters such as zero-width spaces, bidi
  overrides and the tag characters used to smuggle hidden text, private use, unassigned) and the line
  and paragraph separators are re-escaped as `\uXXXX`. A page can carry third-party script (decision 4),
  so a row's text must not be able to move a terminal or hide words from the reader. Readable non-ASCII
  text stays as it is.
- **Handed out is a field.** `wait` sets `handed_out: true` on the rows it prints instead of deleting
  them, so the page can still show each note's status, and `list --all` still sees them. `reply` sets it too.
- **Rewrites are a rename under serve.py's lock.** `wait` and `reply` write a dot temp file in the
  docroot and `os.replace` it over `.feedback.jsonl`, holding an `flock` on `.feedback.lock`, the lock
  serve.py holds for each append. The rename alone keeps the file whole but loses a note appended between
  the read and the rename. Red, with the reader unlocked: `FAIL posts racing rewrites (6 rewrites): want 4061
  rows, got 4044` in 3 of 3 runs (60 posts against rewrites of a file padded to 4000 rows, so a rewrite takes
  long enough to be hit; unpadded, 40 posts against 15 rewrites passed 3 of 3 unlocked, so the padding is
  what makes the case able to fail). An unparseable line is kept byte for byte.
- **`shot` loads the page from disk.** `file://<page>?static=1&_outline=<selector>`, so it works with the
  server stopped and the LAN key never matters; `static=1` keeps the feedback controls out of the picture.
  The shell honours `_outline` by outlining the element and scrolling it to the centre. (Both as first
  built. Since 0.62.0 the query also carries the row's look, and the shell places the element below its
  header and, under `static=1`, shifts the page instead of scrolling it: see the two 2026-11-15 entries
  below.) The window is the
  row's viewport, clamped to 320–3840 × 240–2160 (default 1280 × 800). Browser discovery copies design-kit's
  `board-export.sh` order (an override variable, `PATH`, the macOS bundles, Playwright's cache) instead of
  importing it, since each plugin must work installed alone; the override is `PREVIEW_BROWSER`. A temp
  `--user-data-dir` keeps it off the user's own Chrome profile.

Red before the script existed: 31 of 43 harness cases failed (`FAIL list, no file: want exit 0 and no output,
got 127`).

### What `shot` was checked against (2026-11-13)

The harness checks the PNG signature and that its size is the row's viewport, with `/usr/bin/google-chrome`
found on `PATH`, and the no-browser exit through `PREVIEW_BROWSER` pointing at nothing. One PNG of a
shell page was looked at by eye: the noted "Pay now" button in variant B carried the red outline. Not
checked: the macOS paths, the Playwright cache path (Chrome was found first here), Edge, and a browser that
is found but fails to start.

### Not covered

`wait` polls every 0.5 s. The screenshot uses the shell's default state toggles, direction and width preset,
not the ones in the row's context. Until 0.62.0 that held for the theme and scheme too; since then the row's
palette, style, type and scheme are used where the row holds them and the page still has the option (see
"The row's look in a shot" below). A row appended by anything other than serve.py does not take the lock.

### Review fixes (2026-11-13, still 0.58.0)

Each case below was added to `preview-feedback.test.sh` first and run red against the unfixed script (14
of 63 failed), then fixed.

- **Print, then mark.** `wait` saved `handed_out` before printing, so a waiter killed in between, or one
  whose output nobody read, swallowed the rows. It now prints and flushes inside the lock, then saves; a
  failed write exits 1 and marks nothing. `handed_out` holds the time, and a row handed out 15 minutes ago
  that is still open is unread again for `list` and `wait` (a bare `true`, which `reply` still writes, has no
  lease). Red: `FAIL print before mark: a wait whose output failed still marked the row handed out` (stdout
  on `/dev/full`), `FAIL lease: list: want ls01 (handed out 20 min ago, still open), got:`.
- **Parse on change.** `wait` re-parsed the whole file twice a second. It now compares inode, size and
  `st_mtime_ns` and parses only when one moves or a lease runs out. The case edits a row in place and puts
  the mtime back, which only a re-parse can see. Red: `FAIL wait skips an unchanged file: want exit 3 (size
  and mtime unchanged, no re-read), got 0`.
- **More characters escaped.** Variation selectors (U+FE00–FE0F, U+E0100–E01EF, the Mongolian ones), the
  Hangul fillers (U+115F, U+1160, U+3164, U+FFA0) and U+2800 render as nothing but are not in `C*`. Red:
  `FAIL list escapes a variation selector`, `… the Hangul filler`, `… the blank Braille cell`.
- **`shot` over http.** Loaded as `file://`, the page's script had file-scheme reach the http preview never
  gave it. While `.preview.pid` names a live process and `.preview.url`'s port answers 200 for the page,
  `shot` loads `http://127.0.0.1:<port>/<page>?static=1&_outline=…`; otherwise `file://`, which the header's
  Misses names. The first real http shot ran past 30 s: the shell's reload client held `/events` open and
  polled, so Chrome's virtual-time budget never ran out. The shell's reload block now returns on
  `?static=1`, as design-kit's server already does. Red: `FAIL shot, server running: http: want
  http://127.0.0.1:54903/current.html?static=1&_outline=…, got 0: file:///…`.
- **The browser run.** No `--no-sandbox` unless root or `PREVIEW_BROWSER_NO_SANDBOX=1`, `timeout 30` when
  `timeout` exists, and a non-zero browser exit is reported (exit 1, the PNG removed). A stand-in browser
  records its arguments and its parent process. Red: `FAIL shot sandbox`, `FAIL shot time limit: the
  browser's parent is bash, not timeout`, `FAIL shot, browser fails: … got 0`. The "no browser" line moved to
  stderr: `FAIL shot without a browser: stdout`.
- **The race case's padding** dropped from 4000 to 3000 rows (1.71 MB) to stay under serve.py's new 2 MiB
  cap. Re-run with the reader's `flock` removed in a scratch copy, it still fails 3 of 3: `FAIL posts racing
  rewrites (5 rewrites): want 3061 rows, got 3050`.

One http shot of a shell page was looked at by eye: "Pay now" outlined, no feedback controls, and the
server log showed Chrome's `GET /current.html?static=1&_outline=%23plain`.

### Review fixes (2026-11-13, taskmaster 0.59.0)

`find-browser.sh` was sourced through `dirname "$0"` unchecked; run through a symlink in another folder, the source failed and `shot` reported "no Chromium-family browser found" (exit 4). It is now sourced from the resolved script directory, and a failed source exits 1 naming the file. Red: `FAIL find-browser.sh missing: want exit 1 naming it, got 4`. `shot` still uses `--window-size`: measured on Chrome 157, a 390 px window lays the page out at `innerWidth` 500 and writes a 390 px PNG. (Corrected 2026-11-15: this line said "a 390 px PNG of it". 500 is what page script reads at load; the capture then resizes the window, and the PNG is the page laid out 390 px wide. See "Blank rows above the header in a shot" below.) Moving `shot` to preview-check.sh's DevTools driver would mean a second copy of that driver or a shared module, so it is stated in the header's misses instead.

### The row's look in a shot (2026-11-15, taskmaster 0.62.0)

Commit `cd557578`. The look is the active option of each of the page's three switchers, the header controls
that restyle every frame at once: Palette (colours), Style (radius, spacing, shadow) and Type (a font
stack). Since this version a row stores the look it was written under, as `switchers`; the scheme, light or
dark, is the last word of its `context.theme` (serve.py's heading below). (As first written. Since the
review fix of 2026-11-15 a row holds the scheme as its own field, `context.scheme`: see "The scheme is the
row's own field" below.) `shot` rendered the page in its default look, so a picture could show other colours
than the ones the note was about.

`shot` now sends the row's look beside `static=1`, as `_palette`, `_style`, `_type` and `_scheme`, through
`urlencode`. Only string values are sent: a stored null would otherwise select an option named `None`. The
scheme is the text after the last space of `context.theme`, and is sent only when it is `light` or `dark`.
(As first written. Since the review fix the scheme is the row's `context.scheme`, and the theme's last word
is read only for a row whose `context.scheme` is missing or null.)
The shell reads the four parameters only when `static` is exactly `1`, and uses a value only when it equals
one of the page's own options. In static mode the order is the URL's value, else the one authored on
`<html>`, else the first option.

As reported by the agent that made the commit, in that run on its machine: on the script before the change
the harness read 71 passed, 6 failed. Three defects were seeded and each failed a case: a join without
encoding gave `"static": ["1", "0"]`; without the string check, `"_palette": ["None"]`; without the static
guard, `Berry Sharp Serif dark` on the live page.

Not covered: the state toggles, the direction and the width preset in a shot are still the shell's defaults.
The harness changed too: with `PREVIEW_REQUIRE_BROWSER=1` a missing browser, python3 or curl is a failure,
where it used to be a SKIP.

### Blank rows above the header in a shot (2026-11-15, taskmaster 0.62.0)

Commit `6c422888`. A shot's PNG began with a band of blank rows above the page's header, and at 640 by 480
the noted element was not in the picture. Unless a line says otherwise, the numbers are as reported by the
agent that made the commit, in that run on its machine.

- **Cause.** Chrome's `--screenshot` first resizes the window to the row's viewport, then writes the
  document rectangle from its top-left corner, and draws only what the scrolled window holds. The shell's
  `scrollIntoView({block:'center'})` scrolled the window by N px, so the PNG had N blank rows and then the
  header. A probe showed `scrollY` 109 and 109 blank rows at 1280 by 800, and 353 and 353 at 640 by 480; a
  12-line page with `scrollTo(0,200)` gave 200 blank rows. Before the capture, page script sees `innerHeight`
  713 for `--window-size=1280,800`, and a window of 500 by 713 for 375 by 800. The same on Chrome
  157.0.8103.78 and on Playwright's Chromium 156.0.8078.4.
- **The resize, measured again for this entry** (Chrome 157.0.8103.78, the flags `shot` uses, a page with a
  marker at each top corner): at `--window-size=390,800` and at `375,800`, script read `innerWidth` 500 at
  load, and the PNG was 390 and 375 px wide with the right-hand marker ending at its last column. So the
  picture is the page laid out at the row's width, not a cut of a 500 px layout.
- **How old.** Each ref's own `shot` on a page from its own shell, blank rows at 1280 by 800, 900 by 700, 640
  by 480 and 375 by 800: `master` 0, 0, 82, 97 on its harness fixture and 0, 84, 305, 110 on a three-frame
  page; commit `f33723ca`, which added the switcher row, on a page with a look 107, 130, 351, 231 and no
  outline pixel at 640 by 480; the commit before the fix 109, 132, 353, 149. So the band is as old as
  `shot`, and losing the element at 640 by 480 came with the taller header of `f33723ca`. The scroll margin
  added in commit `28fbe99b` is not involved.
- **The fix is in `shell.html`'s `_outline` block.** A scroll margin of the header's height plus 24 px on
  top; `block` stays `center` when the element fits under the header, else `start`; under `static=1` the
  scroll becomes a negative `margin-top` on `body` followed by `scrollTo(0,0)`; and the placement runs again
  on `resize`. After: 0 blank rows at all four sizes. Each of the four parts is needed: removing one fails a
  harness case.
- **Why not in the script.** Any window scroll produces blank rows, so only a DevTools capture would fix it
  there, and the 0.59.0 note above declined a second copy of that driver.
- **Residual.** A page copied from an older shell keeps the defect. A header taller than the window still
  hides the element (320 by 240).

### The scheme is the row's own field; the race case counts its own rows (2026-11-15, taskmaster 0.62.0, after the range review)

Commit `c42c5c3b`, after a review of every 0.62.0 commit together. `shot` took the scheme, light or dark,
from the text after the last space of the row's `context.theme`. serve.py now stores the scheme as a field
of its own, `context.scheme` (its heading below), and `shot` sends `_scheme` from that field. It parses the
theme's last word only when the row has no `scheme` key or holds null there: a row stored before this
change, or one posted by a page that sends no scheme. Every number in this entry is as reported by the agent
that made the commit, in that run on its machine; none was measured again when the entry was written.

- **Red, then green.** The finished harness on the script before the change read 88 passed, 4 failed. After
  it 92 pass, and no SKIP was printed.
- **Two defects seeded in `shot`, both caught.** Falling back to the theme whenever the scheme is not
  `light` or `dark`: one case fails, on the row `lk07`, whose scheme is `Dark` (91 passed, 1 failed). Never
  falling back: 86 passed, 6 failed.
- **The race case counts its own rows.** "Posts racing rewrites" (the 0.58.0 entries above) asserted a fixed
  total. It now counts the rows after the padding and before the 60 posts, requires that count to be at
  least 3000, and asserts that count plus 60. Two losses were seeded and caught: 7 of the 60 posts dropped
  (`got 3056`), and the rewrite without its `flock` (`got 3053`, in one run; how often that mutant fails was
  not estimated). On that machine the file held 3003 rows before the posts, and 5 to 6 rewrites ran during
  them.
- **Residuals.** A scheme that is not null and is neither `light` nor `dark` gets no `_scheme` and no
  fallback. No case reads the scheme from a PNG's pixels: the browser case reads the `<html>` tag. A page
  copied from an older shell never posts the field.
- **The header** now says "the scheme is context.scheme, or the last word of context.theme in a row with
  none". CI's harness step exports `PREVIEW_REQUIRE_BROWSER=1` since commit `66306dfb`, so on a runner with
  no browser this harness is meant to fail where it printed SKIP and passed; that setting has not been
  exercised on a runner.

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

### The race case's port (2026-11-13, harness only)

The concurrent-start case failed once in seven runs: `want 1 serve.py on the docroot, got 0`, then
`preview: nothing running`. The reviewer's reading, not reproduced: both starters exited 4 because the port
`free_port` handed out was taken between its probe's close and serve.py's bind. The harness now redoes a
round once on a new port when both starters fail with serve.py's `unavailable`, and a failed `race N
servers` or `race N exit` prints both starters' output and `.preview.log`. Shown with the round's first port
held by a listener: the old loop gave `FAIL race 1 exit: want 0 and 0, got 4 and 4` and `FAIL race 1
servers: want 1 serve.py on the docroot, got 0`; the new one printed its `NOTE race 1` line and passed. The
launcher is unchanged.

Known residual of `take_lock`, recorded and not fixed: with three contenders, C can read the owner pid of
A's lock, A finishes and its trap removes the lock, B takes the lock and writes its pid, then C finds A's pid
dead and removes B's live lock and takes its own. B and C then both run check-and-start. The same window
exists with a lock that is really stale.

### A running server older than this serve.py is replaced (2026-11-15, taskmaster 0.62.0)

Commit `f3c24a8a`. A start over a live server reused it, whatever copy of `serve.py` it had been started
from. A server from before this version answers 400 to a pick on a fourth, fifth or sixth frame and drops
the two fields a row gained, as unknown keys (both under serve.py's heading below), and the launcher could
not tell such a server from a current one. `serve.py` now carries a number, `SERVER_VERSION` (2), and
returns it as `"server"` from `GET /_feedback`.

- **The rule.** In its already-running branch the launcher asks the running server for its number, with a
  2 s timeout, at `127.0.0.1` and the running process's `--port`. It does not use the recorded URL: under
  `--lan` that is the LAN address, where `/_feedback` does not answer, being loopback-only. A lower number, a
  missing one or no answer: the server is stopped through the script's own stop path, and this `serve.py` is
  started on the old port with the old `--lan`. An equal number: reused. A higher number: left running, and
  the launcher prints that this copy's controls may be refused.
- **A frozen server.** One that survives its stop is exit 4, and the pid and URL files are kept. Without
  that guard a frozen server lost its record while it still held the port.
- **`--lan`.** Asked over an older loopback server, it still exits 5 before any restart. A plain start over
  an older LAN server restarts it in LAN mode; "Why it exists" above says such a start reuses the server,
  which now holds for one of the same or a higher number.
- **Measured**, as reported by the agent that made the commit, in that run on its machine. On the launcher
  before the change the harness read 71 passed, 7 failed. Twelve mutants, each a copy of the launcher with
  one deliberate change, and a harness case failed on every one. Once with the real old code: `git show`
  copies of the launcher and the server from commit `2df6ebcb`, started on a temporary docroot, and this
  checkout's launcher restarted that server on the same port.
- **Not tested.** A browser tab left open across a restart. A restart whose new server fails to start: that
  is exit 4 with no record of the old port. A `server` value that is not an integer.

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

## plugins/taskmaster/skills/visual-decisions/SKILL.md § count rule

### Why 3 by default, up to 5, never more than 6 (2026-11-15, taskmaster 0.62.0)

The count rule is the skill's line on how many frames, alternative designs shown side by side on one mockup
page, a layout or creative pass may hold: "3 directions by default, up to 5, floor 2, never more than 6". It
replaced a cap of three in commit `8295f05c`. **The numbers are a judgment that matches what other tools ship,
not a measured optimum.** The repository owner decided on 2026-11-15, on research run on 2026-11-14.

**What the old cap rested on.** One sentence in the skill's list of failures, with no source: `More than 3
variants — choice overload produces "whichever", not a decision.`

**How far to trust the findings.** The research sent ten claims to one refuter each; `confirmed` was its label
for a claim whose refuter found no counter-evidence. No claim reached it: nine came back contested on a detail
and were corrected, and the tenth passed its refuter and was demoted on a format failure. Details that went to
no refuter are unconfirmed, among those used here Banani, Superdesign and Hanoch. Read every finding as Medium
confidence at best. The report, `.cc-artifacts/ultra-deep-research/ai-design-variant-presentation-2026-11-14.md`,
is gitignored scratch; the URLs are what lasts.

**Tools and agent skills mostly default to 3 and top out at 4 or 5** (Medium: each number has one origin, the
vendor's own page).
- Google Stitch's SDK, `variantCount` 1 to 5, default 3: <https://github.com/google-labs-code/stitch-sdk>
- emilkowalski's `prototype` skill, "Default 3 variants; up to 5" and "More than 5 dilutes the comparison":
  <https://raw.githubusercontent.com/emilkowalski/skills/main/skills/prototype/SKILL.md>
- superpowers' visual companion, "2-4 options max per screen", no default stated:
  <https://raw.githubusercontent.com/obra/superpowers/main/skills/brainstorming/visual-companion.md>
- Superdesign, 1 to 4 iterations: <https://superdesign.dev/docs/features/canvas/branch.md>
- Banani, "up to 5 screen variations": <https://www.banani.co/product/text-to-ui-generator>
- One skill goes higher and contradicts itself. gstack's `design-shotgun` says "default 3, up to 8", limits a
  batch to 7 in the same file and in its code, and advertises "4-6" in its README: nominal 8, effective 7.
  <https://raw.githubusercontent.com/garrytan/gstack/main/design-shotgun/SKILL.md>,
  <https://raw.githubusercontent.com/garrytan/gstack/main/design/src/variants.ts>

**Neither meta-analysis of choice overload locates a threshold at three** (Medium: primary texts read; their
data sets overlap, so the two are not independent). Choice overload is the claim that more options make a
choice worse. The literature mostly compares about 6 options with 24 to 30, and applying it to design options
is the report's extrapolation; the report leaves open whether the effect exists at all.
- Scheibehenne, Greifeneder and Todd (2010): a mean effect of "virtually zero" (D = 0.02) over 63 conditions.
  Five used a small set of three, and four of those five favoured the larger set.
  <https://www.scheibehenne.de/ScheibehenneGreifenederTodd2010.pdf>
- Chernev, Böckenholt and Goodman (2015): set size has a significant effect once four moderators (complexity,
  task difficulty, preference uncertainty, goal) are modelled, with no significant trend as the larger set
  grows.
  <https://chernev.com/wp-content/uploads/2017/02/ChoiceOverload_JCP_2015.pdf>

**Two findings cut the other way** (Medium: neither is about glancing at mockups).
- Nielsen Norman Group: "Each test participant can test 2 or 3 versions. Any more and users get fatigued and
  can't articulate the differences." That is about people using each version in a test; the same page says to
  create "a minimum of 3" designs. <https://www.nngroup.com/articles/parallel-and-iterative-design/>
- Hanoch et al. (2009): comprehension was better with 3 Medicare drug plans than with 10 or 20; nothing in
  between was tested. <https://pmc.ncbi.nlm.nih.gov/articles/PMC2739022>

**The page's shape has no first-party precedent**, meaning none in a vendor's own pages (Medium: a negative
search, three candidate pages unreadable). A switcher is a header control whose options restyle every frame at
once; page-wide switchers over several generated layouts were not found. Nearest: Figma's variable modes,
applied frame by frame. <https://help.figma.com/hc/en-us/articles/15343816063383-Modes-for-variables>

**What each number rests on, and what is left.**
- Raising the cap: nothing found defends three. Default 3, up to 5: the most common numbers above. Never more
  than 6: only gstack's effective 7 as precedent.
- Open: no study was found of how many mockups a person can compare side by side. The report names a small
  within-subjects test of 3 against 5 frames as what would settle it for this page; this change did not run it.
- Deferred, as two briefs in gitignored `.cc-artifacts/taskmaster/followups/`: "Follow-up brief: request
  buttons on the mockup page" and "Follow-up brief: binding the picked look, and the `/ui-ux:theme` page".

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

### Feedback route and the shell's controls (2026-11-13, taskmaster 0.58.0)

- **The route.** `POST /_feedback` appends one row to `.feedback.jsonl`; its guards are `/_restore`'s
  (loopback peer in every mode, a local Host and Origin, a header no cross-origin form can set) plus
  design-kit's `/_decision` body rule (1 to 8192 bytes, a JSON object). Every field is clamped and
  unknown keys dropped; a pick needs a variant A to C (A to F since 0.62.0, see the 2026-11-15 entry below)
  and a note non-blank text, else 400. `GET
  /_feedback?page=` is loopback-only too, so a device on the LAN never sees controls whose post would get
  403. The file is dot-named, so the M1 rule already answers 404 for it and the watcher never names it.
  Red before the route: 32 cases (`FAIL feedback pick: want 200, got 404`); 134 passed after.
  A 33rd case, added at review, posts a 400-digit integer in a rect: `math.isfinite` raised `OverflowError`
  and the handler died (`FAIL feedback huge numbers: want 200 and a zeroed rect, got 000`); an integer
  beyond 10^9 now reads as 0, and 135 pass.
- **The lock.** Each append holds an `flock` on `.feedback.lock`, which `scripts/preview-feedback.sh` also
  takes before it replaces the file; the red case is under that script's heading. Both files are opened
  with `O_NOFOLLOW`. Without `fcntl` (Windows) appends and rewrites go unlocked.
- **The shell.** A third script block probes `GET /_feedback?page=<this page>` and adds the controls only
  when it answers with JSON; `?static=1` skips the probe. Pick and Note per variant, a "Point & note" toggle
  (Alt+Shift+P) with a fixed overlay as the hover outline and the arrow keys plus Enter as the keyboard
  path, a note box anchored to the element, Escape to cancel, and a Notes list with status and reply. The
  selector is built from an id unique in the document, one short `data-*` attribute, the tag and
  `:nth-of-type` when siblings share a tag, rooted at `#vd-<letter> > .vd-content`, and checked to resolve
  to the element (else a tag and `:nth-of-type` chain). Context: viewport, `<theme> <scheme>` (since 0.62.0
  `<palette or "baseline"> <scheme>`), the
  width, compare mode and direction, each frame's shown data-state, and a five-entry ring of
  `console.error` calls and window `error` events.
- **Browser run (Playwright Chromium 1248, headless, a private instance, 2026-11-13).** On a two-variant page
  served through `preview.sh`: Pick on B wrote a pick row and the button showed "Picked" (also after reload);
  the picker on B's "Pay now" wrote a note whose selector resolves to that button, with variant B, the
  viewport and the theme; the content's element boxes were identical with the picker on and off; the
  keyboard path (shortcut, arrows, Enter, Escape) opened and cancelled the box with nothing posted and focus
  back on the toggle; a per-variant note carried tablet width, the dark scheme and a console error;
  `reply` on two notes showed "addressed" and "dismissed" with their replies after reload; `wait` in the
  background returned the pick row about one second after a browser click. On `python3 -m http.server` and
  with `?static=1` the controls were absent and no script error was logged; Chrome logs a network line for
  each 404, 3 with this shell (`/_versions.json`, `/events`, `/_feedback`) against 2 with the previous one.
- **A defect the browser run found.** A pointer resting outside the variants reset the arrow-key target when
  the page scrolled (Chrome fires mouseover after a scroll), so Enter picked nothing. A mouseover now moves
  the target only onto a pickable element.

Residuals: any script on a served page can post a pick or note; note text is unverified; console errors
thrown before the shell's script runs are missed; `python3 -m http.server` serves `.feedback.jsonl` (200,
measured) on that rung. Standing of the shell's part: recorded; no harness runs a browser. (True on that
date. Since 0.62.0 `scripts/__tests__/shell-controls.test.sh` drives these controls in a headless browser;
see shell.html's heading below.)

### Review fixes (2026-11-13, still 0.58.0)

Harness cases added first and run red against the unfixed server (5 of 140 failed), then fixed:

- **A lone surrogate.** The pages cut text at 200 or 300 UTF-16 units, through an emoji, and posted the
  half; `json.dumps(ensure_ascii=False).encode()` raised `UnicodeEncodeError`, which `except OSError` did
  not catch, and the request got no response. Every stored string now goes through `_clean`
  (`encode("utf-8", "replace")`), so the half reads `?`. Red: `FAIL feedback lone surrogate: want 200 and
  each lone surrogate stored as ?, got 000`. The body parse also catches `RecursionError` as 400. On this
  machine's Python 3.14, 8 KiB of `[` is a plain decode error (400 before and after), and 4096 closed levels
  parse fine, so that half of the finding was not reproduced here; it is a guard for older Pythons.
- **Numbers** clamp to ±10^7 instead of 0 for a large integer and pass-through for a large float, and NaN or
  Infinity reads as 0. Red: `FAIL feedback huge numbers: … "w": -1e+308, "h": 1e+308 … "h": 3000000000.0`.
- **A pick** keeps `text: ""` and `anchor: null`: the page shows neither, and `wait` would hand them to the
  agent. Red: `FAIL feedback pick drops text and anchor`.
- **A size cap.** A page script looping posts could fill the disk. An append that would take
  `.feedback.jsonl` past 2 MiB writes nothing and answers 507 with a JSON reason. Red: `FAIL feedback file
  full: want 507 and a JSON reason naming the cap, got 200`.

The shell's page script, run in a private Playwright Chromium (build 1248) before and after on a shell
page served by this server. Before: `console.error('boom', o)` with `o = Object.create(null)` threw
`Cannot convert object to primitive value` into the page; a span whose first `data-*` value held a newline
made `querySelectorAll` throw after the picker turned off, so no note box opened and the hover outline
stayed; an element text and a console entry crossing the cut inside an emoji posted strings ending in a
lone `\ud83d`. After: no throw, the entry reads `boom [object Object]`; the box opened and the selector
`#vd-a > .vd-content > span[data-note="line1\a line2"]` resolved to the element; both strings ended in the
whole emoji (201 and 301 UTF-16 units). The value is now `CSS.escape`d and the query guarded.

### Render-check routes (2026-11-13, taskmaster 0.59.0)

- **Routes.** `GET /_check.js` (this folder's `check.js`) and `GET /_axe.js` (`vendor/axe-core/axe.min.js`)
  are read from disk per request and served to loopback only, so a LAN device never runs a check. `POST
  /_check` takes `/_feedback`'s guards and 8192-byte cap with its own `X-Preview-Check` header; the page must
  name an existing `.html` file inside the docroot with no dot segment, and the width must be a number from 1
  to 10^7, else 400. Findings are clamped (selector 300, text 120, detail 400 characters), check ids other
  than E1 to E5 dropped, at most 60 kept, the rest counted in `dropped`.
- **The record.** One file per page and width, `.checks/<page>-<sha1 prefix>/<width>.json`, written through a
  dot temp file and a rename, so a reader never sees half of one. It carries the page's sha256 when posted;
  `GET /_checks?page=` counts only records whose hash matches the file now, so an edited page reads "not
  checked" (`stale: true`). The folder and its parent must be real directories, not symlinks; a post that
  would take the folder's JSON past 2 MiB writes nothing and gets 507.
- **The event.** A stored record streams `event: checked` with the page path; the shell's reload client
  turns it into a badge refresh without a reload. Stream items became `(event, data)` pairs for it; `change`
  is unchanged.
- Residual: any script on a served page can post findings for any page in the docroot, and the badge counts
  them. Harness: `scripts/__tests__/preview-check.test.sh` (accept, the clamp, five rejects, never served,
  stale), and `serve.test.sh` still passes unchanged (140).

### Render-check routes removed (2026-11-13, taskmaster 0.59.0 review)

`GET /_check.js`, `GET /_axe.js` and `POST /_check` are gone: the check runs in an isolated world that preview-check.sh drives and which writes the records, so no route lets a page plant or overwrite one. `GET /_checks` stays and reads those records. The "checked" event the post used to stream now comes from the watcher: a changed `.checks/<folder>/run.json`, which preview-check.sh writes last, streams `checked` with the page it names. A page key with a control character (a NUL made `Path.resolve()` raise `ValueError`, and the connection dropped with no answer) is no page: 404 with the JSON error. Red: `FAIL checks, a NUL in the page: want 404, got 000`, `FAIL no route takes findings: POST /_check answered {"recorded": true, "findings": 0}`.

### Six letters, pass and look on a row, the repeated pick, a server number (2026-11-15, taskmaster 0.62.0)

The shell (its own heading below) came to draw up to six frames, a frame being one of the alternative
designs a page shows side by side, and to restyle them from three switchers, header controls with named
options for palette, style and type; the active option of each is the page's look. The server stored picks
for three letters, and knew neither the look nor the pass, the numbered round of frames a pick belongs to.
Four commits. Every number in this entry is as reported by the agent that made the commit, in that run on
its machine; none was measured again when the entry was written.

- **Letters A to F, `pass`, `switchers`** (commit `d7e59b6f`). `VARIANTS`, the letters a pick or a note may
  name, went from A, B and C to A through F. Each row gains `pass`, an integer 1 to 9 and otherwise null (a
  boolean and a float are null), and `switchers` with the keys palette, style and type. A name that is not 1
  to 24 ASCII letters, digits, spaces, hyphens or underscores is stored as null; a key not sent is left out;
  a value that is no object is stored empty. A row with neither field is still stored. On the server before
  the change the harness read 141 passed, 19 failed, the 19 being the new cases.
- **A repeat of an unread pick is dropped** (commit `2df6ebcb`), so that a double click stores one row. A
  pick equal in variant, pass and switchers to its page's newest pick is not appended while that newest pick
  is unread, meaning its status is `open` and it was never handed out; the post still answers 200, with the
  stored row's id. The comparison runs under the append's lock, and one harness case holds `.feedback.lock`
  for 1 s and posts two equal picks. Picks on A, B and A again store three rows. Misses: without `fcntl`
  nothing locks; an unread repeat at the 2 MiB cap answers 200, not 507, because the comparison runs before
  the size check; each pick post parses the whole file under the lock, and the cost near the cap was not
  measured (as first written; since the review fix of 2026-11-15 the comparison reads the file from its end
  and parses no line before the page's newest pick, and the cost was measured: see "The scheme as its own
  field" below); "notes are never dropped" has no case of its own.
- **`SERVER_VERSION = 2`** (commit `f3c24a8a`), returned as `"server"` by `GET /_feedback`, for
  `scripts/preview.sh` to compare with its own (that script's heading above). A server that returns no number
  counts as 1.
- **`context.theme` keeps 30 characters, not 16** (commit `6a12c30e`). The page posts `<palette or
  "baseline"> <light|dark>`, and a palette name may be 24 characters. On the old clip `Berry preserve dark`
  was stored as `Berry preserve d`. Residual: a palette name over 24 characters whose 30-character cut ends
  in "light" or "dark" yields that word as the scheme. (Since the review fix of 2026-11-15 that holds only
  for a row with no `context.scheme`: a row that has the field gives its scheme from there.)

### The scheme as its own field; the repeat pick read from the file's end (2026-11-15, taskmaster 0.62.0, after the range review)

Commit `c42c5c3b`, after a review of every 0.62.0 commit together. Every number in this entry is as reported
by the agent that made the commit, in that run on its machine; none was measured again when the entry was
written. A mutant is a copy of the code with one deliberate defect; it is caught when a harness case fails
on it.

- **`context.scheme`.** Until this change a row held the scheme, light or dark, only as the last word of
  `context.theme`. A row's context now has `scheme`, stored as `"light"` or `"dark"` and otherwise as null.
  `context.theme` is unchanged, and so is `SERVER_VERSION`, 2. `preview-feedback.sh shot` reads the field
  (that script's heading above). One mutant, any string kept as the scheme, was caught (178 passed, 1
  failed).
- **The repeat comparison reads the file from its end.** `unread_repeat` parsed every row of
  `.feedback.jsonl` on each pick post, under the append's lock. It now calls `newest_pick`, which reads the
  file in blocks of 64 KiB (`TAIL_BLOCK`) from the end and parses no line before the page's newest pick.
- **Measured** with the committing agent's own bench script (`python3 -I bench.py <serve.py> 21`) on a file
  of 3655 rows and 2,072,182 bytes: the median of 21 pick posts, one TCP connection each, 32 cores, Python
  3.14.4. With the page's newest pick four rows from the end and the post stored: 10.39 ms before, 0.49 ms
  after. The same with the repeat dropped: 11.27 ms before, 0.52 ms after. A page with no pick in the file:
  11.49 ms before, 11.57 ms after, so no gain. Parse calls on the unit case's file of 304 lines: 304 before,
  5 after.
- **One case got slower.** A single line of 2,097,133 bytes with no newline, in process, median of 9:
  1.70 ms before, 6.19 ms after. serve.py never writes such a line: a row is bounded by the 8 KiB body cap.
- **The same answer as a whole read** was shown, not proven: on 17 crafted files, each with 7 page names and
  with block sizes of 1, 2, 3, 7 and 64 bytes.
- **Red, then green.** The finished harness on the server before the change read 171 passed, 8 failed, 6 of
  the 8 being the scheme's cases. After it 179 pass, and no SKIP was printed.
- **Mutants of the walk from the end**, each caught: the remainder not carried across a block (178 passed,
  1 failed); a split on `\n` only (178 passed, 1 failed); the first line never yielded (176 passed, 3
  failed); stopping at the newest pick of any page (176 passed, 3 failed). Two more were seeded on the
  walk's first version only.
- **Residuals.** A page whose newest pick lies far back in the file, or that has none, still parses up to
  the whole file. A line that `json.loads` rejects with something other than `ValueError` (deep nesting)
  still kills the request thread; that is untested. `GET /_feedback?page=` still parses the whole file on
  each poll, with no lock; it was outside the finding. Windows was not run. A server started from this
  version's serve.py before this commit reports the same number, 2, so `preview.sh` reuses it, and it drops
  the field. A page copied from an older shell never posts the field.
- **Headers.** serve.py's header and `serve.test.sh`'s were not changed: neither names the scheme's clamp
  nor the end-of-file cases.

## plugins/taskmaster/skills/visual-decisions/assets/shell.html

The shell is the page every mockup pass is written into. What it did before 2026-11-15 is recorded under
serve.py's heading above ("Feedback route and the shell's controls") and under `preview-check.sh`'s.

### Six frames, a look, and controls that say what was stored (2026-11-15, taskmaster 0.62.0)

Until this version the shell drew up to three frames, a frame being one of the alternative designs shown
side by side, lettered by id, with a Theme toggle for the project's theme. Every number in this entry is as
reported by the agent that made the commit, in that run on its machine; none was measured again when the
entry was written. A mutant is a copy of the file with one deliberate defect; it is killed when a harness
case fails on it.

- **Frames A to F by position** (commit `f8eb36db`). A frame's letter is its place among the frames,
  whatever its id. Number keys move real keyboard focus to the frame. The title's buttons sit in one block in
  the order Focus, Replay, Pick, Note (commit `60a170aa`), each at least 24 px tall and wide (commit
  `e4341322`).
- **The pass number** (commit `0f7d14a5`). A pass is one round of frames shown for a decision, numbered on
  `<body data-vd-pass>`. Every post carries the number, and a frame reads Picked only for the newest pick of
  the page's own pass. Residual: the pass number is a pick's only identity, so a later decision that reuses
  `current.html` at the same pass number opens with the earlier decision's frame marked Picked.
- **The switcher row and its presets** (commit `f33723ca`). A switcher is a header control whose named
  options restyle every frame at once; there are three, Palette, Style and Type, and the active option of
  each is the look. The options are read from the rules an author writes in the `#vd-presets` style block. 17
  mutants killed.
- **The look is kept for the tab** (commit `55843f61`), in `sessionStorage` under the page's path plus its
  title, and only the controls a person changed are stored. 17 mutants killed.
- **One Look control under 600 px** (commit `28fbe99b`). The closed header on six frames at 375 by 800
  measured 304.7 px, 38.1% of the window's height (before: 388.7 px, 48.6%). It needs CSS `:has()`.
- **The project's theme is the palette option `Project`** (commit `0a28f9ed`); the Theme toggle is gone. For
  print, the shell re-inserts each palette's dark rule inside `@media screen` at load, so frames print in the
  light set; that needs the page's script to have run.
- **A refused post is said in words** (commit `f73ec2c0`): `Not recorded: the server answered <status>`
  under the title's buttons. (Since the review fix of 2026-11-15 the line carries the server's own sentence
  with the status where the server sends one, and a post with no answer in 10 s has a line of its own: the
  entry below.)
- **A shot's look and placement.** The `_palette`, `_style`, `_type`, `_scheme` and `_outline` parameters
  are described under `preview-feedback.sh`'s heading above.
- **The option-name rule is written three times**, in `serve.py`, `shell.html` and `check.js`, with nothing
  tying the copies together.
- **A harness that drives the shell live**, `scripts/__tests__/shell-controls.test.sh`: 112 cases at the end
  of the run (146 since the review fix of 2026-11-15, the entry below). It loads pages through `serve.py`
  without `?static=1`. A seventh live page in one tab never loads in headless Chrome, so it opens a fresh tab
  for each page. Without a browser it prints SKIP and exits 0, unless `PREVIEW_REQUIRE_BROWSER=1`: a green
  run on a machine with no browser says nothing about the shell. (CI's harness step exports that variable
  since commit `66306dfb`; the setting has not been exercised on a runner.) What it misses is listed in its
  own header.

### The scheme on a post, worded refusals, a tall header, switchers that wrap (2026-11-15, taskmaster 0.62.0, after the range review)

Commit `4bc19795`: seven changes that followed a review of every 0.62.0 commit together. Every number in
this entry is as reported by the agent that made the commit, in that run on its machine; none was measured
again when the entry was written. Nobody ran Firefox or Safari. A mutant is a copy of the file with one
deliberate defect; it is killed when a harness case fails on it.

- **Every post carries `context.scheme`**, `light` or `dark`: the scheme the frames are drawn in, so `light`
  while a palette with no dark set holds the page light. serve.py stores it as a field of its own (its
  heading above). Untested: a screenshot taken from a row the page itself posted.
- **"No dark set" is read by check.js's rule.** `lightOnly` used a list made once at load. It now reads the
  presets sheet at each call with the expression check.js uses: the top-level style rules plus the direct
  children of a block that is exactly `@media screen`. A dark rule an author wrote inside `@media screen` is
  not wrapped a second time. A harness case computes the rule again from the live sheet and compares it with
  the Scheme toggle on each page. Residual: a dark selector with its two attributes in the other order still
  reads as no dark set.
- **A post gives up after 10 s.** Each post carries `AbortSignal.timeout(10000)`, and the line then reads
  `Not recorded: no answer from the server in 10 s`. serve.py takes a post and then waits for its lock, so
  without a limit the control that sent it stayed as it was, with no message. The harness swaps the page's
  `AbortSignal.timeout` for one of 250 ms and asserts that 10000 was asked for; the stall is the real
  serve.py with `.feedback.lock` held. Residuals: a post the server finishes after the page gave up is
  stored, though the page said "Not recorded" (measured for a pick; that a note sent again would be stored
  twice is inferred, not measured); the reload of rows after a post has no limit; an answer that is not 2xx
  and whose body stalls reads "no answer".
- **A refusal carries the server's sentence.** The line reads `Not recorded: <error> (<status>)` when the
  answer's body is JSON with a non-blank string `error`: its first 200 code points, set as text. Otherwise
  it keeps the earlier form, `Not recorded: the server answered <status>`. serve.py's 403 and 413 are
  `send_error` HTML pages, so they keep that form. The cases answer from a stand-in server with sentences
  copied from serve.py, not from the real server's 507.
- **A header taller than half the window stops sticking** (WCAG 1.4.10 and 2.4.11). When
  `header.offsetHeight > innerHeight / 2` the script sets the class `vd-tall`;
  `@media screen { #vd-header.vd-tall { position: relative } }` unsticks the header, and `--vd-header-h`
  becomes `0px`. It is evaluated again on `resize` and by a ResizeObserver. Print's `position: fixed` is
  untouched. When the header unsticks while a control inside it has focus, that control is scrolled into
  view: with the plain fix the Look control ended at −2949 px on a page scrolled 3010 px.
- **The header's height, measured** on six frames (`look-6.html`), before the wrap change below. At 320 by
  480: closed 395 px (82%), open 517 px. At 375 by 800: closed 305 px (38.1%), open 427 px (53.4%), so
  opening Look on a phone unsticks the header. At 600 by 800: closed 217 px, open 339 px. At 1280 by 800:
  200 px (25%). At 1280 by 500: 200 px (40%). The threshold, with a 305 px header: a window 609 px tall
  unsticks it, 610 px leaves it stuck, and the answer is the same on animation frames 2 to 7. Residuals: such
  a window has no sticky header at all; a `?_outline` screenshot still clears a tall header's height; zoom
  itself was not driven, window sizes were; print has no case.
- **A look change that flips the match with the pick is said** (WCAG 4.1.3). When a change of look makes
  the active look stop matching the picked frame's, or match it again, one sentence naming the frame is
  written to the existing status region. Nothing is written at first render, with no pick, or when the match
  does not flip. Not tested: what a screen reader speaks.
- **Switchers wrap at 600 px and under** (WCAG 1.4.10; the 24 px floor of 2.5.8). Until this change the
  rule there was `overflow-x: auto`, a switcher scrolling sideways inside itself, and a page with four
  24-character names per kind was 714 px wide in a 320 px window. On that page now: 4 lines per switcher at
  320 and at 375, and 2, 3 and 2 lines at 600; an option is 28 px tall, 46 px when its name folds; the open
  header is 814 px at 320, 687 px at 375 and 455 px at 600. Residuals: above 600 px nothing changed (at
  601 px that page is 696 px wide; not measured on the shell before the change); a name with no break point
  folds in the middle of a word; the rules that change only how the wrapped row looks (the fill lines, the
  dropped start border) have no case and were checked by eye.
- **Harness.** `shell-controls.test.sh` went from 112 cases to 146: 35 added and 1 removed, "a switcher too
  wide for 375 scrolls inside itself". It runs in 15.6 s. The finished harness on the shell before the
  commit read 126 passed, 20 failed. Mutants were seeded by hand for each fix, and all were killed but one:
  a rule of the wrap change that only affects its look (no `flex-grow`; 146 passed, 0 failed).
- **Sizes.** shell.html went from 122,413 to 125,240 bytes, and from 2763 to 2798 lines.
- **The render check on a page from the new shell.** Six frames with four palettes, four styles and four
  types, at 320, 375 and 1280: exit 1 with one E2 finding at 320 ("variant A is 284px wide in 278px", which
  is the harness fixture's own table and reads the same on the shell before the commit),
  `"states": 14, "states_not_run": 0`, 0.6 s.
- **Follow-ups, not done.** Nothing guards the fixture folder that this harness's `--emit` shares with
  `preview-check.test.sh`: pages named `dark-*.html` collided (201 passed, 4 failed) and were renamed
  `scheme-*.html`. An existing comment in shell.html holds two U+200B characters.

### Second pass: two thresholds for the header, and what the first fix round broke (2026-11-16, taskmaster 0.62.0, commit `2ea95beb`)

The first fix round made a header taller than half the window stop sticking. A review of that round found
the rule itself was a defect on a phone: `innerHeight` changes each time the URL bar slides in or out, so a
header near half the window stuck and unstuck at every change of scroll direction, and where a tapped
button keeps focus (Chrome and Firefox on Android) each flip to unstuck ran the follow-scroll and threw the
page to its top. Confirmed by a second reader from the code; no phone was used at any point.

- The header unsticks over 55% of the window's height and sticks again at 45% or less
  (`20 * height > (was ? 9 : 11) * innerHeight`); between the two it keeps its state, and a page that
  loads inside the band sticks. Under `?static=1` there is no kept state (55% only), so a screenshot is
  the picture a load at that size gives.
- The page follows a focused header control only when the header itself grew past the threshold (`Look`
  opened), never because the window changed size.
- Orchestrator's browser run on the exported commit (Chrome through Playwright, six frames, 375 px wide,
  header 282 px, a header button focused, page scrolled to 1800 px): window height 628 → 553 → 628 stayed
  stuck with `scrollY` 1800 throughout; 480 (59%) unstuck with `scrollY` still 1800; back to 553 (51%)
  stayed unstuck. At 1280 by 800 the header was 187 px and stuck; a pick, and a look change after it,
  announced as before; console empty.
- A screenshot (`?_outline`) keeps 24 px above the outlined element when the header has stopped sticking,
  where it kept the whole header's height clear.
- The note box is held under the window's height (`max-block-size`, its own scroll) and moves up when a
  refusal makes it taller; a refusal with one long unbroken token wraps (WCAG 1.4.10).
- Where `AbortSignal.timeout` is missing (Chrome before 103, Firefox before 100, Safari before 16) a timer
  aborts the post at the same 10 s. Before this the call threw, a pick posted nothing and Send note stayed
  disabled.
- Harness, from the worker's commit message (its written report had not arrived when this was recorded):
  `shell-controls.test.sh` 146 → 157 cases, each refusal answer with its own status and a wait for the
  stub's post count, a 25-character option name; `preview-feedback.test.sh` 92 → 93, a 320 by 480 shot.
  The orchestrator checked the receipt (fresh at `2ea95be`), not the cases one by one.
- Not covered: a real phone; what happens between 45% and 55% on first load when the user expects no
  sticky header; `matches`, the module-level value the look-change announcement compares against, which a
  later `showPick()` call outside the observer would move (left as it is, recorded).
