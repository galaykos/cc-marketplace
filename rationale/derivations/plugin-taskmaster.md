# taskmaster hooks: the comment text moved out of the code (2026-10-28)

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
