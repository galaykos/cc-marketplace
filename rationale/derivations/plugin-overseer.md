# overseer hooks and scripts: the comment text moved out of the code (2026-10-28)

The text below was moved verbatim on 2026-10-28 from the files named in the `##` headings, with only each comment's `# ` leader (and the indentation before it) removed; the lines each file kept are not repeated here. A pointer by name was left in each file, `# Why, limits, history: rationale/derivations/plugin-overseer.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved. The usage text `program.sh` and `skill-path.sh` print from their own comment lines stayed in the files.

## plugins/overseer/hooks/announce.sh

### Header

```text
Absolute-path shebang: the fail-open guarantee must hold under a stripped PATH.
SessionStart announcer for the `overseer` plugin. Prints ONE line when the project
has an open program (a milestone that is neither done nor parked) so a fresh session
knows to /overseer:resume instead of starting cold. Resolves the project the same way
program.sh does — the git toplevel of the session cwd, else the cwd itself — so a
session opened in a subdirectory is still announced. Silent when no program exists,
when every milestone is done or parked (that program is closed; `program.sh close`
archives it), or on any error. Pure read — writes nothing.
Killed (timeout 10s): prints nothing; the resume command still works, so a missed
announcement costs one manual /overseer:status, never state.
```

## plugins/overseer/hooks/track-read.sh

### Header

The `# context-key-ok:` marker and its reason stay in the file unchanged.

```text
Absolute-path shebang: the fail-open guarantee must hold under a stripped PATH.
PostToolUse on Read for the `overseer` plugin — the read ledger behind the read-before-record
gate. While a program is open in the session's project, every Read of a regular file appends
one row, "<epoch>\t<session_id>\t<physical path>", to <project>/.claude/overseer/.reads.
`program.sh evidence add --file X` then refuses a file no Read in THIS session touched since
X last changed: a screenshot nobody opened proves nothing, and before this ledger "the file
exists, not what it shows" was the plugin's own unenforceable row. Lifted from the
verify-gate in anthropics/cwc-long-running-agents (a PreToolUse deny unless the evidence
file was Read first); here the deny sits in program.sh, which is where accept already lives.
Prints NOTHING on stdout — zero context cost per Read. Silent when no program is open in
the project (every non-overseer project pays nothing), on a relative path that does not
resolve, on a missing file, and on any error. Killed (timeout 5s): the row is lost and
program.sh says the gate is inactive for the session, never that the file was read.
LIMITATION: a Read proves the bytes reached a context, not that a judgment was made on
them; that half stays agent-graded. A subagent shares the parent's session_id, so a
browser-tester's Read counts for the session that dispatched it — intended: the walk may
be delegated, the look must happen somewhere in this session.
```

### IDE reads

```text
`.*read_file` covers an IDE-MCP read, which uses the same `file_path` key (JetBrains
MCP schema, read 2026-09-14). A session reading every artifact through the IDE would
otherwise satisfy no evidence kind that requires the artifact to have been opened.
```

## plugins/overseer/scripts/program.sh

### Header

```text
program.sh — the overseer's state machine. The ONLY writer of .claude/overseer/program.json
(serialised by an O_EXCL lock file, so two invocations of this script cannot lose each other's write).

What it gates: a milestone cannot reach `done` without the evidence kinds its KIND's evidence
profile requires (kinds.tsv column 4 — `ui`, the default: the nine-kind browser walk; `headless`:
`tests` + `run-log`, for a kind with no screen); accept exits 2 and lists them; every file kind
must carry a --file that exists at add time AND at accept time (a deleted screenshot
un-accepts); every required
evidence row must be newer than the last worker/follow-up dispatch that passed `dispatch check`
(a walk recorded before the last fix cycle is a walk of older code); at least one dispatch
under the milestone passed `dispatch check` unchanged since (recorded in dispatch/.gated —
a file that never went through the check is not a gated dispatch, whatever it pins); the
kind's skill groups are pinned by paths that EXIST; a hands-off program must carry at least
one ASSUMED decision before its first accept; statuses, kinds, sizes and rigour profiles come
from fixed vocabularies. What it does NOT check: that the evidence is true — a screenshot of
the wrong page still passes; the acceptance reference says why that residual stays.
```

### Evidence profiles

```text
Evidence profiles (kinds.tsv column 4) — what `accept` demands of a milestone of that kind.
`ui` is the default and the original nine: a milestone with a screen is proven in a browser.
`headless` exists because that list is impossible for a kind with no screen — a research pass or a
CLI/script/library change can never record a viewport, so every such milestone ended `parked`
(measured 2026-09-16, a program run over this marketplace itself). Its two kinds are the two a
script CAN check: the suite ran, and the command the milestone exists to make work ran and was
captured. Both are file kinds, so `accept`'s "every row points at one file" WARN still bites.
```

### The recordable vocabulary

```text
the recordable vocabulary is every profile's kinds plus the optional ones: a headless milestone
that did open a browser may record the screenshot, and a `ui` one may record its run log
```

### lock

```text
lock: bash's noclobber creates the lock file with O_EXCL inside the shell itself. Not mkdir(1): uutils
coreutils (Ubuntu 26.04's /usr/bin/mkdir) stats first and exits 0 when its mkdir(2) loses the race, so two
writers held the lock at once and 20 concurrent `evidence add` kept 14-19 rows (measured 2026-10-07).
Not flock: macOS does not ship it.
```

### kind_profile

```text
kind_profile <kind>: column 4 of the kind's row — its EVIDENCE profile. Absent (every row written
before profiles existed) reads as `ui`, so the nine browser kinds stay the default for a kind with
a screen; `milestone add` refuses any other word, or a typo here would silently demand a browser
walk of a headless milestone — the failure this column was added to fix.
```

### session_root_check

```text
session_root_check: this Claude session's transcript lives under ~/.claude/projects/<encoded cwd>/;
when that cwd is not this project, the pipeline commands (taskmaster, task-runner, craft) are
unreachable and both simulations ran on hand-dispatch without noticing. Fail-open when the
session id or transcript is unknown (plain terminal, other harness); refuse when it is known and foreign.
```

### pinned_groups_status and pins_in

```text
pinned_groups_status <kind> <files...>: one line per group: "ok <group>" / "missing <group>" / "uninstalled <group>".
A pin counts only when the path EXISTS — a review found the text match alone let /nowhere/…/SKILL.md close an
auth milestone. `stack` is installed only when a project skill or a laravel/web-dev cache skill really is there.
pins_in <files...>: every …/SKILL.md path in the files that EXISTS, one per line. Two passes per line: the strict
match stops at a space, the lenient one allows spaces inside the path (a project under "…/my proj" could never pin
its own skill); a lenient over-capture across two pins on one line is a path that does not exist and drops out.
```

### gated_files

```text
gated_files <id> [kind-filter]: the dispatch files under milestones/<id>/dispatch/ whose current checksum matches the one
`dispatch check` recorded at its last exit 0 — a file edited after the check, or never checked, is not gated
```

### record_gated

```text
record_gated <file> <kind>: the row accept reads — checksum, kind, basename (the last row per file wins). Only a file
under its milestone's dispatch/ dir is recorded; a prompt checked elsewhere passes but is not a milestone dispatch
```

### evidence add: read-before-record

```text
read-before-record: hooks/track-read.sh appends "epoch\tsession\tphysical path" per Read while a
program is open. A file kind needs a row from THIS session at or after the file's last change —
a screenshot nobody opened proves nothing, and one re-captured after the look is unread again.
No session id (plain terminal) or no row at all for this session (hook not loaded) → WARN and
record, fail-open said out loud; a session that read other files but not this one → refused.
```

### accept: gated dispatches only

```text
only dispatches that passed `dispatch check` and are unchanged since count: a review closed an auth milestone
with zero dispatch files and a hand-written pin to a path that did not exist
```

### accept: stale evidence

```text
a walk recorded before the last worker or follow-up dispatch walked older code (simulation 4 ran three fix
cycles after its first browser pass); the newest gated worker file's mtime is the line every required row must be after
```

### accept: sized vs actual

```text
the size was a roadmap guess; print what it actually took next to it so the next milestone's guess has an anchor
(nothing scores the miss — the bands would be invented; the reader compares)
```

### accept: the process-cost line

Written 2026-10-29 when it shipped (0.7.4), not moved from code. After the `actual:` line, accept prints the shared block's line (`rationale/derivations/templates-and-blocks.md` § `templates/blocks/process-cost.md`), pasted above the command dispatch.

One start, computed once, feeds both the cost line and the `actual:` minutes: the earliest of the milestone's `briefed` and `building` history times and the gating times stored in `dispatch/.gated`. `queued` is when the roadmap was written, which can be days before any work, and a reader dispatch can come before the brief. The times are compared as `%Y-%m-%dT%H:%M:%SZ` strings. Until fix cycle 1 the `actual:` minutes counted from `briefed`/`building` only and the cost line also read dispatch files' modification times, so the two lines could disagree, and an edit to a dispatch file moved the start.

`dispatch check` appends the gating time as the fourth field of its `.gated` row (`<checksum> <kind> <file> <time>`). A row written before 0.7.4 has three fields and still gates: `gated_files` strips a trailing time before it names the file, and the `awk` that keeps the last row per file keys on field 3 in both shapes. With no history time and no stored gating time the line says the start is unknown, and the `actual:` minutes read `-`.

Accept's exit status does not depend on the line. It reads only the session that runs accept, so a milestone delivered across sessions shows that session's part; the line says nothing about other sessions, and that is the residual.

### accept: the next step

```text
the moment after accept is where simulation 4 stopped (m1 of 3 done, "resume later", nobody there): say the
next step here, at the decision point, not only in the skill text the model read two hours earlier
```

### resume: the five lines

Written 2026-10-29 when it shipped (0.7.5), not moved from code. The program this repository ran (`marketplace-ux-dx-ax`, 19 milestones) needed a hand-written `RESUME.md` to be picked up across sessions; m1's audit filed a suggestion to generate that note from the state files instead. On demand only, by the user's check-in answer of 2026-10-29 (decisions.md): `program.sh resume` and `/overseer:resume` print it, and the SessionStart hook stays one line, so nothing is added to every session's context.

- **Now** prefers a milestone in progress (briefed, building, accepting) over `NEXT_FILTER`'s pick. `NEXT_FILTER` takes the first open milestone in roadmap order whose dependencies are done, which can be a queued one ahead of the one being built; `milestone set` does not check dependencies, so a milestone in progress may not be runnable at all.
- **100 characters** are counted as code points by jq (`length`, string slices), not bytes, so a goal in a non-Latin script is not cut early. The last line names paths relative to the project root: the absolute path to `suggestions.md` in this repository's worktree is 117 characters on its own.
- **A bad `program.json` still prints five lines and exits 0.** Lines 4 and 5 read their own files, so the reader keeps the last decision and the suggestion count; `program.sh status` exits 5 with the parse error, which is where to look next. The validity check also requires every milestone to be an object, because jq stops with an error, not a line, on a milestone that is not one.
- The newest decision is the last row by position in `decisions.md`, read the way `program.sh log` reads it (` | ` separates the columns), so a decision text holding ` | ` is cut there.

### dispatch check: the preamble's path

```text
resolved like a skill pin (skill-path.sh: the CLI's enabled install, else the newest cache dir that has the file) —
`find | sort -V | tail -1` across two marketplaces picked the alphabetically later marketplace's older version
```

### dispatch check: followup

```text
a message to a worker that is still alive: the preamble is already in its context, so the
follow-up must SAY it still binds, keep the scope lock, verify and return shape, and name the
dispatch file it continues — simulation 2 sent two of these with none of that recorded
```

### dispatch check: the preamble is worker discipline

```text
the preamble is worker discipline — implement, verify, full suite. A reader/reviewer carries none of it: gating
it in put "run the full check suite" verbatim into every prompt that also had to say "you write no file"
```

### dispatch check: every clause line

```text
every line of every numbered clause, not only its first: clauses 2-9 of the canonical file span two to ten lines,
and "skip diagnosis and guess" on clause 2's second line passed the first-line check. Whitespace is folded so a
reflowed paragraph still counts as verbatim; a changed word does not.
```

### dispatch check: MODEL

```text
MODEL: the seat's model, bound by the program tier — a dispatch that names none inherits the session
model silently, which is how simulation 3 ran its card workers on the most expensive tier without a decision
```

### dispatch check: size routes the pipeline

```text
size routes the pipeline: S may go straight to a worker; M+ is briefed to taskmaster, and the proof it was
is a card index newer than the brief. "The brief is so complete grill would ask nothing" is not a reason —
both earlier simulations said exactly that for every milestone they hand-dispatched
```

### dispatch check: the card index

```text
the index must name this milestone (its dir or heading: 2026-09-12-m2-landing, "# m2 landing") and be newer than
the milestone's registration — not newer than the brief: amending the brief mid-milestone (normal) made the
index look stale and swapped the boost WARN for a false "pipeline skipped" one. Newest such index wins.
```

### dispatch check: the boost marker

```text
the Ultra:/Goal: marker is taskmaster's Extreme Boost. What it buys on top of a standard run: the spec red-team
unconditionally (a standard run already runs it past three criteria or an ASSUMED row), coverage loop-until-dry,
a code red-team over the shipped diff, and tier escalation; `goal` adds autonomy. Reviewers per card and the
negative control are task-runner's baseline, boosted or not — 0.2.1 charged them to the boost and priced it wrong.
The rigour profile says whether the code red-team is worth buying here; the marker says whether it was.
`Goal: true (boost=off)` is taskmaster's goal-lean (≥0.42.1, task-runner ≥0.32.0): hands-off without the boost.
```

### close: divergence

```text
divergence: two done branches that contain neither the other were never seen in one tree
(simulation 2 closed with the homepage from master and the board from m1 never combined)
```

### close: other plugins' scratch dirs

```text
other plugins' hooks (candor, comment-discipline) key their scratch dir on the edited file's directory and
leave .claude/ dirs under dispatch/; they are never overseer's and do not belong in the record
```

### close: evidence paths

```text
evidence rows hold absolute paths under $dir/milestones; the archive is the record a reader
follows, so every path is rewritten to where the file now lives (checked by the harness)
```

## plugins/overseer/scripts/capability-scan.sh

### Header

```text
capability-scan.sh — which installed plugins cover which pipeline phase, for THIS project,
plus the CI facts the Discover step kept missing.

Unions three sources because each alone lies: `claude plugin list --json` filtered to
user scope or this project's path (the CLI is machine-wide); `enabledPlugins` in
.claude/settings.json, .claude/settings.local.json and ~/.claude/settings.json (a
--persist or hand-edited entry the CLI does not always report). Without the `claude`
CLI the installed column reads `unknown` and every preferred plugin is listed as missing
with its install command — the scan never guesses. The preferred column names only
plugins this marketplace ships; official plugins (playwright) are not install hints.
The CI block lists every workflow file, the branches it triggers on, and flags a trigger
that does not name the base branch — the mismatch that made one simulation's CI never run.
Exit 0 always; report-only.
```

## plugins/overseer/scripts/skill-path.sh

### Header: resolution

```text
Resolves through `claude plugin list --json` (installPath of the ENABLED install) so the pinned file
is the one the CLI would load; falls back to the newest cache directory only when the CLI is absent,
and says so on stderr. A `sort -V` over full cache paths is NOT a version sort of the middle
segment — that shortcut pinned database 0.4.2 while 0.7.0 was installed (simulation 2, lesson 12).
The CLI list is NOT cwd-scoped: it carries every project's local/project installs, each with its
`projectPath`. Taking the first enabled row pinned another project's taskmaster 0.41.7 while THIS
project had 0.41.9 (simulation 3 pinned ui-ux 0.20.3 against an installed 0.21.0). So the row must
belong to this project (`projectPath` = --project root, else the git toplevel of the cwd, else the cwd)
or be a user-scope install; a row from another project is never a candidate.
```
