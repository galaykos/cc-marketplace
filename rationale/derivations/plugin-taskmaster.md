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
<walk> line is optional and unchecked: present or absent, no finding.

LEGACY SHAPE. A card with no <card> wrapper but a **Verify:** line is the bold-label
shape task-cards emitted before taskmaster 0.45.0. It passes with a NOTE on stderr
and exit 0: in-flight card sets keep executing. task-cards emits only the tagged
shape; the acceptance here is for cards already written, not a second template.
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

