# Shared blocks and chassis templates: the comment text moved out of the code (2026-10-04)

The text below was moved verbatim on 2026-10-04 from the files named in the `##` headings, with only each comment's `# ` leader removed; the lines each file kept are not repeated here. A pointer by name was left in each file, `# Why, limits, history: rationale/derivations/templates-and-blocks.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

## templates/blocks/option-resolver.md

### Banner and canonical copy

```text
--- option resolver -----------------------------------------------------------
Canonical copy: templates/blocks/option-resolver.md. Every hook defining cc_option must
carry this block byte-for-byte (pc_shared_blocks); generated hooks include it.
```

### cc_option: contract and why the shell wins

```text
cc_option <ENV_NAME> <default> [<level-file>] prints one line, the first non-empty of: the
variable ENV_NAME; the first word of <level-file>, if given and readable; the userConfig
option CLAUDE_PLUGIN_OPTION_<ENV_NAME>, true/false read as on/off; <default>. The shell wins
because the environment is the one state independently installed plugins share (CC_REMIND
or CC_BOOST there mutes every plugin at once); the option gives one plugin a /config row.
```

### cc_option: status

```text
Status 0, no stderr: a malformed name, an expansion error that exits bash 5, yields <default>.
```

### cc_option: what it does not catch

```text
WHAT IT DOES NOT CATCH: a caller passing a variable instead of a literal name, or a value
outside the switch's vocabulary — each hook still validates the value it gets.
```

## templates/blocks/state-root.md

### Banner and canonical copy

```text
--- state root ----------------------------------------------------------------
Canonical copy: templates/blocks/state-root.md. Every hook defining cc_state_root must
carry this block byte-for-byte (pc_shared_blocks); generated hooks include it.
```

### cc_state_root: the measurement and the resolution order

```text
The payload's `cwd` is the SHELL's cwd and follows the model's `cd` — measured
2026-09-25: app/Enums, then app/Models, then the repo root in one session, each leaving
its own `.claude/` state dir and each re-firing a "once per session" nudge. State lives
at the project root instead (pc_state_root refuses a raw `$cwd/.claude` path in a hook):
the git toplevel reached by walking UP from cwd (`--show-cdup`, so a symlinked /tmp keeps
the caller's spelling and path-prefix comparisons still hold); outside git,
CLAUDE_PROJECT_DIR when cwd sits under it; else cwd. A cwd that no longer exists yields
nothing and status 1 — the caller exits rather than resurrect a deleted project.
```

## templates/blocks/plugin-state.md

### Banner and canonical copy

```text
--- plugin state --------------------------------------------------------------
Canonical copy: templates/blocks/plugin-state.md. Every hook defining cc_plugin_state must
carry this block byte-for-byte (pc_shared_blocks); generated hooks include it.
```

### cc_plugin_state: contract, key and host constraint

```text
cc_plugin_state <root> <name> prints the directory holding a plugin's own per-project hook
state, <root> being the hook's cc_state_root result: ${CLAUDE_PLUGIN_DATA}/<key>/<name> when
the host sets that variable, else <root>/.claude/<name>, the path hooks used before it.
<key> is the root's basename with every character outside [A-Za-z0-9_-] turned into -, a -,
and the root's cksum: the host gives one data dir per plugin id, not per project (measured
2.1.282), and a raw path inside a filename names parents that never exist. tr runs under
LC_ALL=C because a UTF-8 tr stops at the first invalid byte. Status 0, no stderr; it
creates nothing, so the caller keeps its own mkdir -p.
```

### cc_plugin_state: why it exists

```text
WHY: state read by no one but the plugin's own hooks does not belong in the user's repo —
the 2026-09-29 review found .claude/code-review/ and .claude/skill-router/ created by one
prompt and one edit in a fresh repo.
```

### cc_plugin_state: what it does not catch

```text
WHAT IT DOES NOT CATCH: state another plugin, a skill or the user reads must not use it; the
fallback path is still in the repo; the data dir is keyed by plugin id, so install scopes of
one plugin share it (inferred from the docs' id rule), while a --plugin-dir copy gets its
own `-inline` directory and never sees the installed copy's state. The variable was measured
only in a SessionStart hook; other events are doc-stated. An event that lacks it falls back
to the repo path, which splits a writer from a reader running on another event.
```

## templates/blocks/bash-write-targets.md

### Banner and canonical copy

```text
--- bash write targets --------------------------------------------------------
Canonical copy: templates/blocks/bash-write-targets.md. Every hook defining
cc_bash_write_targets must carry this block byte-for-byte (pc_shared_blocks).
```

### cc_bash_write_targets: why it exists

```text
The host steers file writes through Bash (auto mode `bashFirst`); in one measured session
233 of 238 main-thread writes were `cat > file <<EOF`, invisible to a hook matching
Write|Edit.
```

### cc_bash_write_targets: contract

```text
Prints one target path per line, as spelled in the command (relative or absolute).
Heredoc BODIES are dropped and quoted text is masked before matching, so PHP `->`/`=>`,
HTML `>` and a sed script's `s|a|b|` never read as redirects or pipes; a here-string
(`<<<`) is not a heredoc. Catches `>`/`>>` onto a path (cat, echo, printf, any command),
`[sudo] tee [-a] <paths>`, and every file operand of `sed -i`/`-I`/`--in-place` / `perl -i`
after the script or its `-e`/`-f` arguments, never a redirect word or its target. BSD's
`-I` always takes the next word as its backup suffix; a `''` or a `.`-led word with no `/`
right after sed's bare `-i` is read as one too, unless it would be the only file.
```

### cc_bash_write_targets: what it does not catch, and what it reads too much

```text
Does NOT catch: sed/perl/tee operands after a `&` in `$(( ))` or `${ }` (it ends the command),
interpreter writes (python open(), php file_put_contents), cp/mv/install destinations,
`{ …; } > f` groups, a path held in a variable (`> "$f"` is skipped, never guessed),
a globbed operand (`sed -i … tests/*.js`: a word with `*`/`?` is dropped), a `\` line
continuation, sed/perl behind another command word (`gsed`, `/usr/bin/sed`, `env`,
`xargs`, `command`, `sudo -u x`, `find … -exec sed -i`), a digit- or `&`-led redirect onto
a file (`2> f`, `&> f`) and `>&` onto one (`cmd >& f.json`), a `-`-led sed/perl operand
with no `/` or `.` in it. Reads too much: a `-`-led perl script argument that has one.
```

### cc_bash_write_targets: caller contract

```text
The caller filters to existing files under its root.
```

## templates/blocks/bash-write-chunks.md

### Banner and canonical copy

```text
--- bash write chunks --------------------------------------------------------
Canonical copy: templates/blocks/bash-write-chunks.md. Every hook defining
cc_bash_write_chunks must carry this block byte-for-byte (pc_shared_blocks).
```

### cc_bash_write_chunks: contract and the two sources

```text
cc_bash_write_chunks <command> — what a Bash command puts INTO files: the text a content
guard reads on Bash where its Write path reads tool_input.content. Prints chunks: a line that
starts with \036 and carries the WRITER — the pipeline (split on ; && || and a `&` outside
`&>` `>&` `<&` `|&`, never inside quotes) whose targets the caller resolves with
cc_bash_write_targets — then the chunk's text lines. Two sources, and only two:
  - a heredoc BODY: the lines between `<<TERM` (`<<-`, quoted or `\`-escaped TERM too)
    and TERM; writer = the pipeline holding the `<<` (`cat > f <<EOF`,
    `cat <<EOF | tee -a f`);
  - the ARGUMENTS of an `echo`/`printf` segment, as written: the rest of the segment after
    the command word, quotes, escapes and any `> file` redirect kept (so match inside the
    text, never anchored at its start); writer = its pipeline
    (`echo "K=v" >> .env.example`, `printf '%s\n' v | tee f`).
```

### cc_bash_write_chunks: over-read, accepted

```text
A chunk whose writer names no file is dropped by the caller, so `git commit -F - <<EOF`
and `echo x | grep y` yield nothing. The body of ANY heredoc whose pipeline writes a file
is read, whatever consumes it — `python3 - <<PY > out.txt` included, where the script is
not what lands in out.txt. Accepted: the text sits in a file-writing command either
way.
```

### cc_bash_write_chunks: not read, stated

```text
NOT read, stated: a `{ echo …; } > f` group (the redirect sits on the closer, not on
the echo's pipeline); a here-string `<<<`; printf's format substitution (`printf
'K=%s' v` is read as written: the format and the argument, never the substituted
line); a quoted string or a `\` continuation spanning lines; a second heredoc opened
on one line; text in a command that a `&` inside `$(( ))` or `${ }` ends early.
```

### cc_bash_write_chunks: why mask() is duplicated

```text
mask() copies the one inside cc_bash_write_targets: the block is byte-locked and its
awk functions are not reachable from outside it.
```

## templates/blocks/phase-guard.md

### Banner

```text
--- phase guard -------------------------------------------------------------
```

### Why the block file is named .md

```text
NOTE ON THE EXTENSION: this block is shell, not markdown. It is named .md because
template-engine.sh:50 hardcodes `<blocksdir>/<name>.md` for every include directive.
Teaching the engine other extensions is a change to a gated shared component and
is not worth it for one file — the engine only ever copies raw bytes.
```

### No directive in the block's comments

```text
Do NOT write a literal include or substitution directive in this file's comments:
includes are expanded once and not rescanned, but substitution runs over the whole
rendered text afterwards, so a directive quoted here becomes a missing-key error.
```

### cc_phase_guard: why the sentinel only narrows

```text
Stand down when the arc is in a phase this artifact does not own. The sentinel
only ever NARROWS: absent, foreign, stale or malformed all mean "everyone is
eligible", which is byte-for-byte today's behaviour. That is deliberate — the
plain-prompt path is the overwhelming case and must not change, so turn-taking
engages only once an entry command has actually declared a phase.
```

### cc_phase_guard: where the sentinel lives

```text
WHERE IT LIVES: <state root>/.claude/cc-phase.json, the root cc_state_root resolves
from the payload cwd. That function comes from the state-root block
(templates/blocks/state-root.md), which the reminder template includes just above
this one; a hand copy of this guard must paste it too, or the call fails and the
guard proceeds as if no sentinel existed. It read `<payload cwd>/.claude/` until
2026-09-25, and the payload cwd follows the model's `cd` (finding 2 of
rationale/2026-09-25-session-plugin-usage-review.md): a sentinel written at the root
was absent to a hook whose cwd had drifted into a subdirectory, and absent means
proceed. taskmaster/scripts/phase-sentinel.sh writes at the same root, so writer and
reader agree from any directory of the project.
```

### cc_phase_guard: reader contract

```text
Reader contract, in order:
  absent .............. proceed (no sentinel, no turns)
  jq missing .......... proceed (fail open, as every hook here does)
  unparseable ......... proceed
  session_id differs .. proceed (several sessions share one .claude/ dir)
  older than TTL ...... proceed, and unlink — a run that died mid-way must not
                        mute this project's channel in every future session.
                        The cited precedent .claude/task-runner/active-run.json
                        is cleared by a MODEL INSTRUCTION, which is why
                        candor's gate.sh (clause 4) says of it "Nothing clears it";
                        that gate survives only because it SPEAKS when it
                        blocks. A silent reader has no such remedy, so the TTL
                        is the whole of this one's safety.
  phase == our lane ... proceed
  lane is `any` ....... proceed (guards are not phase steps)
  otherwise ........... stand down, silently
```

### cc_phase_guard: why the TTL is short

```text
TTL is deliberately SHORT. Expiring early degrades to the status quo (the nudge
fires when it maybe should not); expiring late mutes a real channel. Those costs
are not symmetric, so this errs toward speaking.
```

### cc_phase_guard: how often it engages

```text
HOW OFTEN THIS ACTUALLY ENGAGES — state it plainly, because the answer is "less
often than the word turn-taking suggests". Four commands write a sentinel:
taskmaster:task (shape), task-runner:run (build), git-workflow:finish (ship), and
code-architecture:coding-task on its `trivial` verdict (build). A BARE PROMPT writes
none. So on the plain-prompt path — which this design's own notes call the
overwhelming case — no phase exists, every voice stays eligible, and what arbitrates
is the rank tiebreak, not the arc. That is collision-avoidance, not turn-taking.
Turn-taking engages once work enters through a command that declares a phase.

This is a real limit, not a defect to route around: nothing can observe "the arc"
without something declaring it, and inferring a phase from prompt text would be the
routing-table-in-shell that route-prompt.sh's own header refuses. The honest claim is
the narrow one — say the guard engages on the pipeline path, never that the
marketplace takes turns everywhere.
```

### cc_phase_guard: standing

```text
Standing: the GATE (pc_phase_guard) proves a hook READS the sentinel. No gate
can prove an artifact HONOURS it in every branch — that half is agent-graded.
```

### cc_phase_now: why it is published

```text
Also publishes cc_phase_now — the phase in force, or empty. The rank marker key
includes it, which is what lets a voice that stood down at one phase
claim a FRESH key and speak when its own phase arrives. Without it a rank claim
written on turn 1 outlives the eligibility that produced it and permanently gags
whichever hook is later the highest ELIGIBLE one.
```

### cc_phase_guard: why staleness is read from mtime

```text
Stale? mtime, not started_at — no ISO-8601 parsing in portable shell, and the
file is rewritten whenever the phase changes, so mtime IS the phase's age.
```

### cc_phase_guard: why the session test is nested ifs

```text
Nested ifs: a conjunction of two bracket tests here once tripped
chassis-template-tests.sh's "hook(plain): no extraGuard when null" assertion,
then a substring match over the whole rendered file. Since 2026-09-25 it pins the
trigger line instead — the state-root block carries that shape legitimately — so
the nesting is no longer load-bearing. It stays; it reads the same either way.
```

### cc_phase_guard: why it reads its own lane.tsv

```text
Our own lane, read from the plugin's OWN lane.tsv — never a sibling's, so this
works when the plugin is installed alone (spec S2b).
```

### cc_phase_guard: why phases are compared by position

```text
ORDERED, not equal. Exact equality was the first cut and it was a global mute: the
phases COMMANDS write (shape, build, ship) and the phases ADVISORIES declare
(understand, decide) are disjoint sets, so `want = have` was unreachable and every
phase-owning voice stood down whenever any sentinel existed. Only `any` lanes spoke.
The two vocabularies are disjoint for a real reason — "what phase is this command"
and "what phase does this advice belong to" are different questions — so the fix is
to compare position, not string.

An advisory speaks while the arc is AT or BEFORE its phase, and stands down once the
arc has moved PAST it. Clarify-the-requirements is useful at understand and shape; on
turn 40 of an executing build it is the defect this guard exists to kill.
```

### Closing banner

```text
--- end phase guard ---------------------------------------------------------
```

## templates/reminder-hook.sh.tmpl

### Off switch

```text
OFF SWITCH. CC_REMIND=off silences every reminder hook in the marketplace —
the reminder twin of the boost hooks' CC_BOOST. Environment is the one state
independently-installed plugins genuinely share. The cc_remind option in /config
silences only this plugin's reminder hooks; a set CC_REMIND still wins over it.
```

### Trigger narrowing

```text
TRIGGER NARROWING (the boost hooks' C17 pattern, applied to reminders). The
keyword used to be grepped from the WHOLE prompt, so a pasted transcript, a
task notification, or a request to change the hook itself fired the nudge.
In order: drop fenced code and backticked spans; read only the head of the
prompt (a pasted log buries its keywords deep); refuse prompts that are
ABOUT the reminder machinery; refuse this hook's own output echoed back.
LIMITATION (honest scope): heuristic, not parsing — an unquoted keyword in
the head still fires, a real request past the head no longer does.
CC_REMIND=off is the reliable control, this is the cheap one.
```

### is_about_hooks: why the noun must start a word

```text
The noun must START a word: `[ -]` before it, or the verb abutting it directly.
Without that separator `fix the webhook handler` matched `...web`+`hook` and
silently disarmed the nudge on any webhook/API prompt — measured 2026-09-15.
```

### is_own_echo

```text
own suggestion quoted back = transcript, not intent
```

### is_question_only: question-shaped prompts

```text
QUESTION-SHAPED PROMPTS (misfire regression, live transcript 2026-08-25). The
trigger is a bare verb list matched anywhere in the head, so "can I BUILD a
tool on Claude Code?" and "if we needed to BUILD from scratch, what would you
do?" both scored as work-shaped. Asking WHETHER to do the work is not asking
for it, and a clarify nudge on a question is pure noise: the deliverable is
prose, and there is no edit for the nudge to sit in front of.

CLAUSE-LEVEL, not prompt-level, because one prompt can do both ("that looks
wrong. fix the parser"). Split the head into clauses, keep only those actually
carrying the trigger, and stand down only when EVERY one of them is
interrogative — a clause counts as interrogative when it ended in `?` or opens
with a question word. A single imperative trigger clause is enough to speak.

LIMITATION (honest scope): heuristic, not parsing. "how do I add caching?" is
refused even though the user may well want it built; the nudge returns on their
next, imperative, prompt. A delayed nudge is the cheaper error than a false one,
and CC_REMIND=off remains the reliable control.
```

### Turn-taking

```text
TURN-TAKING. Evaluated only after the prompt already matched this
hook's own trigger, so an out-of-phase artifact costs one lane.tsv read and
nothing else. sid is needed by the guard's session check, so resolve it first.
```

### claim_rank and best_rank: monotonic precedence, flat markers, the phase key

```text
MONOTONIC PRECEDENCE. Rank arbitrates only between hooks that
share a phase; the phase sentinel does the real turn-taking. Guaranteed:
among hooks eligible THIS TURN, the best rank always speaks, in every
invocation order. NOT guaranteed: exactly one line — a worse-ranked sibling
that reads before its better-ranked peer claims will also print. Output is
bounded at one line per eligible hook. Claiming determinism here would be an
over-claim; hooks launch in parallel and single-voice needs a settle window,
which would cost latency on every prompt.

Markers are FLAT (cc-remind-<key>-rank-<NN>), never nested under a per-key
directory. Nested claims fail ENOENT without an -p, so no hook would ever
yield and ALL would print; and the shipped sweep below uses rmdir with
-maxdepth 1, which can neither remove a non-empty directory nor descend into
it, so every prompt would leak a marker forever and each leak is a permanent
gag. Flat markers are cleaned by that same sweep unchanged.

The key carries the PHASE, so a voice that stood down earlier gets a fresh
claim namespace when its own phase arrives instead of meeting a stale claim.
```

### The clarify-gate marker: a cross-plugin signal

```text
CROSS-PLUGIN SIGNAL, deliberately outside the yield decision. This marker is
the sole producer for taskmaster's optional clarify gate (PreToolUse, off by
default); it must be dropped whenever this hook's trigger matched, even if a
better-ranked sibling speaks instead, or retiring the old budgetExempt branch
would silently disarm that gate for everyone who set CC_CLARIFY_GATE=block.
Gated on an explicit manifest flag, not on rank, so exactly one plugin arms
it — making it unconditional would widen a deny gate's trigger to five hooks.
```

## templates/boost-hook.sh.tmpl

### Off switch

```text
OFF SWITCH. CC_BOOST=off disables every boost hook in the marketplace;
{{envVar}}=off disables this one. Environment is the only state three
independently-installed plugins genuinely share, so this works cross-plugin
even though a co-activation GUARD does not (see the skill's residual note).
Either switch's option in /config silences only this plugin's boost hook; a set
environment variable still wins over the option.
```

### Trigger narrowing

```text
TRIGGER NARROWING. The token used to be grepped from the WHOLE prompt, so a
pasted log, a quoted transcript, or the sentence "don't use <token> here"
injected the directive — before the model could read the skill's claim that
such a mention is inert. Three narrowings, in order:
  1. drop fenced code blocks and inline backticked spans (quoted text)
  2. only look at the first 200 characters — a real invocation is typed at
     the top of the prompt; a pasted log buries the token deep
  3. do not fire when the token is negated
LIMITATION (honest scope): heuristic, not parsing. It converts "any mention
anywhere fires the boost" into "a mention that reads like an invocation
fires it". A quotation in the first 200 chars with no negation still fires,
and an invocation past 200 chars no longer does — the off switch above is
the reliable control, this is the cheap one.
```

### Self-echo: why the boost tokens are enumerated

```text
  4. do not fire on this hook's OWN output echoed back. The injected directive
     opens "ULTRA-<X> ACTIVE"; a prompt quoting that is a transcript paste, not
     an invocation. Catching the self-echo is worth a line because the commonest
     way a boost banner reaches a prompt is a previous run's output.
     The boost tokens are ENUMERATED here, not `ultra-?[a-z]+`: the loose form
     also matched Claude Code's own vocabulary, so "ultracode active — now
     <token> X" (and "ultrathink active, …") silently suppressed the boost the
     user had just typed. Regression cases: scripts/smoke/hook-guard-tests.sh.
     This list is shared by every boost hook the chassis renders — a new boost
     token is added HERE, in the template, or the sibling hooks will not
     recognise its banner and will fire on a pasted one.
```

### Why a quoted heredoc

```text
The directive is emitted through a quoted heredoc: no expansion, so the
manifest text is the wire text — backticks, quotes and $ are all literal.
```
