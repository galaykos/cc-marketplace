# task-runner

Disciplined task execution: one task at a time, scope locked, bounded verify-fix
inner loop (max three cycles, then park with evidence), no unbounded outer loop,
full-suite completion gate.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install task-runner@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/task-runner:run [tasks-dir-index-or-list] [--tracks[=N]] [--crew] [--sweep]` | Execute a task list — a taskmaster `00-INDEX.md`, a plan's task sequence, or an inline list |
| `/task-runner:plan [task-or-list]` | The computed subagents-vs-inline verdict: dependency levels, agent count, speedup estimate |

## Boundary with Claude Code's built-in `/run` and `/batch`

The host's `/run` launches the project's app to see a change working — unrelated to
`/task-runner:run`, which executes a task list. The host's `/batch` fans work out as
one background subagent per worktree and opens a PR for each; `--tracks` also runs
milestones as worktree tracks but keeps the sole-writer merge rule — one orchestrator
merges every track, no per-track PR.

## Subagent discipline

The orchestration plugin was merged into this one on 2026-09-14: it shipped no
agent, and every one of its readers was already here. Two skills load on demand —
**delegation-contracts** when dispatching subagents, writing an agent prompt or
reading a report back (self-contained prompts, compressed evidence-backed returns,
model/effort tiering, scout-then-fanout, writer isolation, the role-floor registry
in `references/role-floors.md`, the tree-wide gate an orchestrator runs after
fan-in in `references/tree-wide-gates.md`), and **verification-panels** when
deciding whether an agent's findings can be trusted or judging competing attempts
(refuter voting, judge panels, loop-until-dry, completeness critic). The
`ultra-assess` boost hook is armed by writing "ultra-assess" in a prompt: it
injects the Extreme Boost directive for assessment-shaped runs (inventory, audit,
gap-analysis) and points at `verification-panels/references/ultra-assess.md`.

What has teeth there: the four string-checkable prompt-contract elements
(absolute path, scope lock, return shape, data-not-prose closer) are checked by
`scripts/dispatch-lint.sh` — run it over any drafted prompt file before
dispatch; a fixture harness runs in CI. Whether the scope lock locks the RIGHT
scope stays agent-graded. Orchestration's review command, which used to wrap
the lint, was retired with the merge: it reviewed prompts, not code, and the
lint plus the skill's own checklist are what it ran.

Credit: delegation-contracts' done-when bullet (every dispatch states a bar the worker can
check and cannot meet early) adapts a rule from
mattpocock/skills v1.2.3 (MIT, © 2026 Matt Pocock), rewritten here rather than copied; its
effect is unmeasured.

## Which model runs your cards

- **Workers inherit the session model.** Every worker agent ships `model: inherit`, so a card
  is implemented by whatever model you are running — batching does not change that.
- **Some agents carry a tier floor.** An agent listed in the role-floor registry is dispatched
  at `max(marker tier if present ELSE the session model, its floor)` — so a reviewer pinned to
  a stronger tier is never weaker than the session that wrote the code, and never caps it
  either. Registry and full rule:
  `plugins/task-runner/skills/delegation-contracts/references/role-floors.md`.
- **A boost raises further.** An `Ultra: true` / `Goal: true` marker in `00-INDEX.md` carries a
  `(model=…, effort=…)` tier into execution; workers and reviewers are dispatched at it. A
  `Goal: true (boost=off)` marker (taskmaster `goal-lean`, since 0.32.0) raises nothing and
  runs no code red-team: it is hands-off at the standard tier.

Not every agent tracks the session model, and that is deliberate: breadth and mechanical roles
(persona lenses, scouts, index builders) pin a mid tier by design, which can sit above or below
your session. The registry above says which agents floor and which do not.

## Example

```bash
/task-runner:run taskmaster-docs/tasks/2026-07-05-orders-csv-export/00-INDEX.md
/task-runner:run           # picks the most recent taskmaster-docs/tasks/*/00-INDEX.md
```

Each task runs its EXACT verify command; three failed fix cycles park the task
with evidence instead of drifting. After a task's verify passes, a conditional
reviewer pass runs when the review plugins are installed — code-reviewer on
every task; ui-ux, architecture, and security reviewers only when the task's
content warrants them (security as a review-only `security-engineer`, which can run probes a
read-only reviewer cannot). Reviewers have no shell, so each is handed a diff file that
`scripts/review-diff.sh` writes: the card's diff, its untracked files and the blame of the
lines it changes. Critical/high findings re-enter the bounded fix loop. At run close one
`/code-review:review` covers the whole range since the run started, because per-card passes
cannot see what changed across cards.
The run only completes when every task is done or parked AND the project's
full check suite passes — including api-design's doc-drift check when installed.
A green run then asks one question with git-workflow's destinations (open a PR, merge
locally where allowed, keep the branch, stop) and passes the pick to
`/git-workflow:finish --to <pr|merge|keep>`, which still runs every check.

When a milestone's cards touch UI, the orchestrator walks the changed screens in a real
browser before the milestone closes. Workers never do it: they share one browser and
have no MCP tools. The walk serves the built assets and signs in as a walk user the spec
set up, never with your credentials. Each changed screen is shot at 1280 and 375 px with
a horizontal-overflow probe. The walk also tabs through the new controls, checks that
Escape returns focus to the trigger, reads the console, and emulates reduced motion
where motion changed. The closing message then carries a Screens table: screen, width,
before and after shot paths, and what was **not observed** (surfaces that need data or
keys the project does not have). The shots use design-kit's layout, so its
`snapshot.sh review` can pair them on one page. Why: in one measured run, 34 UI
subagents made no browser calls, and eight UI defects surfaced only after the build.
Another run's walk caught a 375 px overflow and a reduced-motion bug that seven reviews
had missed. **Standing: recorded.** Nothing checks that a walk happened. A skipped walk
recorded with `reduction-record.sh` must be named in the report, and the checklist
itself lives in `skills/task-execution/references/ui-walk.md`.

Status lives in the task index and the conversation — no HTML dashboards.
HTML/preview artifacts are reserved for content that needs them: mockups,
interactive walkthroughs, demos.

## Staying near the ask when there is no card

`scope.sh` warns, once per written file outside the set, while a registered run's cards
have declared their file lists — it never blocks. It sees Edit/Write and the files a Bash
command writes by redirect, heredoc, `tee` or `sed -i` (at most 8 per call), and, after an
interpreter, `cp`, `mv`, `install` or `patch` run, each file git reports changed since its
previous call in the run (at most 8), a failed command's too. A `python3 - <<'EOF'` write
outside the set warns, worded apart from an Edit's: the file changed since the previous call
and may not be the command's, so check `git diff` and never revert what you did not write.
That read misses writers it does not name (`make`, `git apply`), gitignored outputs,
`mv`/`cp -p` destinations, anything under `.claude/`, and the first Bash call of a run or of
a session, and takes any other change in that window (an IDE save, a parallel worker, an
unignored cache) for the command's write. It reads the scope files at the project root in
whatever directory the shell sits, and ignores any left over from an earlier run. A scope
file without an `allow` array (`{"allow":["path","dir/"],"task":"<id>"}`) leaves the call
unenforced and says so on stderr; writes outside the project root are not checked. Most
turns have no registered run, and there it exits at once — so
`drift.sh` asks one question, once per request, when a narrow ask has produced a wide
change: **12+** files edited (p90 of 169 measured local edit-turns), no breadth word in
the request, half of them never named in it. Files created under a directory the request
created are not counted: they are the new feature.

Advisory, and it counts **breadth only**: an unasked refactor inside a file you did
name is invisible to it. `CC_DRIFT=off` silences it.

## Counting the subagents a fan-out actually spawned

`spawn-cap.sh` counts subagent dispatches per session and **asks** — a permission prompt,
never a refusal — once the count crosses 20, then at every doubling (40, 80, …). Subagent
turns do not appear in the transcript and they are billed, so a fan-out planned as three
agents and grown to thirty is invisible until the invoice; this is the only place it gets
counted. `ask` rather than `deny` because a large fan-out is sometimes right — the claim is
not that thirty is wrong, only that thirty should be a decision somebody made. Thresholds
double instead of firing every time, because asking at 21, 22, 23 trains reflexive approval.

Inside a run registered on the checked-out branch, or one whose sentinel names no branch, it
**notifies** instead — to you and to the model — and the first threshold is three dispatches
per card in the run's index when that is above the cap. The run is already authorized, and
an ask there left one run idle for 67 minutes while its other agents finished. The notice
names the plan; a run that dispatches past it is told, not stopped.

It counts dispatches, not cost: twenty haiku calls and twenty opus calls are one number
here and not one bill. It cannot see an agent a subagent spawns through another mechanism,
and it says nothing about whether the fan-out was a good idea — that is
`/task-runner:plan`, which is prose. `CC_SPAWN_CAP=<n>` moves the first threshold;
`CC_SPAWN_CAP=off` disables it.

## The run cannot end by narration

A run registers itself at start through `scripts/register-run.sh`, which `/task-runner:run`,
the task-execution skill's first step and `/task-runner:plan`'s "Run now" all call (until
0.47.0 only the command registered, and a handoff straight to the skill ran with every check
below silently off). It also seeds `.claude/task-runner/env-notes.md`, the environment facts
every worker reads before its first command, starting with "never read `.env`". A Stop hook — clause 4 of candor's gate since
2026-09-14, this plugin's `hooks/completion-gate.sh` before that; install candor or
the run can end by narration — refuses to let it end while the work is unfinished — no recorded behavioral-gate pass for the current HEAD, or
cards neither done nor parked. Ending a turn with "starting card 01 now" and no
tool call is blocked and fed back, so an announced next step actually happens
instead of leaving a dead turn the user waits on. An intentional pause is a tool,
not prose: a question via `AskUserQuestion`, or a parked card with a reason.

That sentinel outlives the session that wrote it, so a session opened cold used to meet
the Stop block at the end of its first turn knowing nothing about the run — and the
cheapest-looking escape was deleting the sentinel of a live one. `hooks/announce.sh`
(SessionStart, `startup|resume|clear`) says one line when the project has a registered
run: slug, branch, how many index cards are still open, and the declared arc phase.
**Standing: advisory** — SessionStart context informs a turn and cannot block one; the
teeth are still the Stop gate. It reads three files and writes nothing, is silent when
no run is registered, and leaves compaction to skill-router's capsule. It cannot tell a
live run from an abandoned one, and the card count is the index's bookkeeping rather
than the work.

## Nothing gets quietly dropped

A real run reviewed card 01, dropped the reviewer pass on cards 02-08 to save context,
reported "all 8 done, none parked", and passed every gate; the user found out by asking,
and closing the gap turned up a real bug. The step next to it — the per-card negative
control — could not be skipped that way, because a script writes its record and the gate
counts them. The reviewer pass was prose.

So the mandated passes now leave evidence a run cannot author for itself:

| Mandated step | Evidence | Gate |
|---|---|---|
| per-card reviewer pass | `rv-seen-*` written by a PostToolUse hook that sees the dispatch's `RV-CARD` marker | records ≥ done cards |
| behavioral gate | `bg-<head>.json` written by `behavioral-gate.sh` itself | must exist for the reported HEAD, and its verdict must be a passing one |
| red-team panel (boosted runs that shipped code) | `rt-lens-*` / `rt-critic-*` from the same observer | 3 lenses + 1 critic, or a recorded degradation |
| whole-range review at run close (runs registered by `register-run.sh`) | `range-<sha>` from the same observer, on `RV-RANGE: <HEAD12>` in the `/code-review:review` call | a record for the closing HEAD, or a recorded skip |
| ui-ux-reviewer on a UI card | `rv-agent-<card>@<reviewer>` from the same observer, for each card whose `rv/diff-<card>.patch` names a `.tsx`, `.jsx`, `.vue`, `.svelte`, stylesheet or `.blade.php` file | a ui-ux-reviewer record, or a recorded skip or exemption |

Skips stay possible and stop being silent. `scripts/review-skip.sh` (per card) and
`scripts/reduction-record.sh` (`--kind redteam|dispatch|suite|coverage|other` — a degraded
panel, a downgraded dispatch, a narrowed suite, a dropped coverage pass, anything
else) record the cut with its reason and print it to the transcript at the moment of the
decision. `--evidence <path>` records what was observed instead, for example the UI walk's
shot dir; it must exist inside the repo. In an interactive session a PreToolUse hook asks
you to approve it first. The
completion gate then refuses a clean stop unless the closing report names each recorded
id. Design carve-outs — a track leaf, a reviewer plugin that is not installed — record an
exemption and never prompt.

Records written before the current registration are ignored, so a fresh registration re-arms
every check and last week's run cannot satisfy this one. A second registration of the same
index on the same branch resumes the run instead, keeping the records of its done cards
(`--fresh` starts over).

What this does NOT prove: that a reviewer read carefully, that a reason is honest, that a
range review covered the range its marker names, that a UI card with no diff file got its
ui-ux-reviewer, or anything at all in a run that never registered or was registered by hand
(no `start_sha`, so no range review is owed). Depth is invisible to a parent hook — a
subagent's transcript is a separate file.

The block is bounded twice over: it fires only on the branch the run registered
itself on, and at most once per commit — so a genuine stop costs one extra turn,
each new commit re-arms the gate for the next card, and a sentinel left behind by
an abandoned run cannot nag every stop in the repo. That sentinel is
`.claude/task-runner/active-run.json`; deleting it retires a run that will never
finish. A finished run renames it to `closed-run.json` instead, so the stop after the
closing report is still checked against the run's records; candor's gate removes the file
once they hold. Set `TASK_RUNNER_STOP_GATE=warn` to downgrade the block to a printed
reminder everywhere.

## Receipts

`/task-runner:run` runs the closing suite, after the run's last commit, through
`scripts/check-receipt.sh run --name suite -- bash -c '<whole suite>'`, which runs it from the
repo root and records it in `.claude/task-runner/receipt.json`: the commit, a digest of the
working tree, and the check's command (each argument quoted as given), exit status, time and a
log of its last 60 output lines (`.claude/task-runner/receipts/suite-<commit>.txt`). A run at
another commit or on another tree replaces the receipt; at the same ones, a failed check is
replaced only by the same command run again. `check --name suite [--cmd '<command>']` prints
`fresh: suite passed at <commit> (<command>)` and exits 0 only when the receipt names HEAD, the
suite exited 0, its own log ends `exit 0`, the command is the one `--cmd` names, and nothing
changed since: no tracked file edited or staged, no untracked file added or changed outside
`.claude/` (whose `skills/`, `agents/`, `commands/`, `hooks/` and `settings.json` do count) and
`taskmaster-docs/`, no root `.env*` file changed, no executable bit flipped, no submodule file
edited. Anything else, an unreadable receipt included, prints `stale: <why>` and exits 1. It
never writes the git index.

Who reads it: `/git-workflow:finish` skips a fresh suite, overseer's acceptance may cite its log,
and the task board shows `checks passed at <commit>: suite (<command>)` or `checks stale: <why>`
under its summary, and `suite ✓ <commit>` at the end of the status line while a run's suite is
fresh. The board asks `check` at each turn end and when the receipt, HEAD or the git index moved,
not on every tool call; one that takes over 2 s reads stale. Not seen: other gitignored files
(build output), skip-worktree or assume-unchanged files, untracked files inside submodules, nested
repos that are not submodules, a receipt written by hand; a suite that leaves new untracked files
behind reads stale at once. **Gate** — `scripts/__tests__/check-receipt.test.sh`,
`tests/board.test.ts`.

## Mods (Claude Code ≥ 2.1.291)

Since 0.44.0 the plugin also ships a hooks module, `hooks/mods.ts`, listed under `modules`
in `hooks/hooks.json` beside the classic hooks, which fire with or without it. It carries
four features under three off switches.

- **Subagent model floors** (`hooks/floors.ts`). A new spawn of an agent in
  `role-floors.md`'s registry runs at no less than its floor, and one naming no model (or
  `inherit`) runs at the session's model when that is a higher tier, so the main thread's
  own dispatches are floored too, not only skill-mediated ones. It only raises: a fork, a
  resumed agent (the host keeps the model it started on), an agent outside the registry, an
  explicit model at or above the floor and a model of unknown family are left as given, and
  no spawn is refused. A `Workflow` script's `agent()` is floored from CLI 2.1.300, the first
  that applies a mod's model to it; 2.1.292 to 2.1.299 pass it through untouched, and older
  CLIs never show it to the module. For a workflow agent, a model the session forces on
  every subagent outranks the raise (per the host's 2.1.300 types, not measured). Whenever the tier changes, a
  toast names the agent, what the dispatch asked for (a model, `inherit` or its pin) and
  the model it runs on. The registry is read once, at the first spawn, and kept for the
  session, so an edit to it mid-session is not seen; one that cannot be read or parsed is
  logged once and every spawn passes through for the rest of the session. A spawn of an
  agent from a plugin your organization installed by policy skips this module,
  `allowManagedModsOnly` or not (per sec-default's docs, not measured). Off:
  `CC_SPAWN_FLOOR=off` or the `/config` option `cc_spawn_floor`; the variable wins.
- **Run suggestion** (`hooks/suggest.ts`). After the main loop's `Write` tool writes
  `taskmaster-docs/tasks/<slug>/00-INDEX.md` at the repository root while no run is
  registered on this branch, the idle prompt box offers `/task-runner:run <that index>` at
  the first turn end with no live phase sentinel; Tab accepts it and nothing runs until you
  send it. Not offered for an index whose every card is closed or that `gate-pass.json`
  names, nor again for an index already shown this session. Off: `CC_SUGGEST=off`,
  environment only with no `/config` option, which also silences the next-step suggestions
  of code-review, git-workflow, debugging and testing.
- **Status line** (`hooks/board.ts`). While a run is registered on the current branch, one
  line is pinned under the prompt:
  `task-runner  <phase> <k>/8  card <N>/<total>  <p> parked  <u> unrecognised  <ultra|goal>  check running <m>m`.
  `<phase>` is the live phase file's (`.claude/cc-phase.json`), else `build`, and `<k>/8` its
  place in understand, shape, decide, plan, build, verify, review, ship (a phase outside that
  list shows alone). N counts done cards plus the one in progress, and empty parts are dropped.
  A card's status is the first word of its status cell; a word
  outside `pending`, `in_progress`, `done`, `parked`, `skipped` and `blocked` (a run that wrote
  `committed <sha>`) is counted as `unrecognised`, never silently as pending, and stays open
  for the session-start notice, which names how many there are. A plain run, or an index with no card table, shows `task-runner  <phase> <k>/8`.
  `check running <m>m` shows while the behavioral gate runs in the background, read from
  `.claude/task-runner/bg/running.pid` by candor's Stop check rule: the deadline on its third
  line not yet passed (with no deadline, the file under 240 minutes old), the commit it names
  is the current one, and the process it names is the gate, or on Linux any gate `pgrep` finds
  running from inside the project; without `/proc`, any live process with that number counts.
  `<m>` is the minutes since the file was written; while the check runs the line refreshes on
  its own at each new minute, with no tool call or turn end needed, and stops when it ends.
  With no run registered, a live phase file naming understand, shape, decide or plan shows
  `taskmaster  <phase> <k>/8` (`taskmaster  shape 2/8`); any other phase shows no line.
  It refreshes at session start, at each main-loop turn end and, while a run is registered
  or the pane is open, after every tool call, main loop and subagents, parsing the index
  again only when its modification time moves (an index that cannot be statted, read or
  parsed is read again at every refresh); only the newest of overlapping refreshes paints,
  so a slow one cannot revive an ended run's line. The board's saved state is written only
  when it changed (since 0.46.1). Subagent tool calls refresh it on purpose during a run: a
  delegated executor marking its card done moves the line mid-turn. **Idle** (since
  0.49.0): when the last refresh found no run and no open pane, a subagent's tool call
  refreshes nothing and a main-loop call refreshes at most once every 2 s, so a run that
  registers within 2 s of the last look shows at the next call after that, or at the turn
  end. **Gate** — `tests/board.test.ts`, "an idle board looks again at most every 2 s, never
  on a subagent call" and "a run started within the idle gap shows at the turn end". With no
  run registered on this branch, the line clears unless the planning phase shows.
- **Task board** (`hooks/board-view.tsx`, `/task-board`). A pane of the run's cards:
  `Task board  <slug>  <marker>`, then `<phase>  <done>/<total> done  <p> parked  <u> unrecognised`,
  then `waiting on: background check running <m>m` only while that check runs (as in the
  status line), then a button row, then one row per card (id, title cut to the pane width,
  parallel group, marker), with a header row before each milestone's cards. During a run each
  row adds two columns under a one-line legend: **review**, whether the card's review is
  recorded, and **check**, whether its test was shown to fail without the change. Each reads
  `yes`, `skip` (skipped with a reason), `exempt` (no review owed: a leaf card, or no
  reviewer installed) or `no`. They are the records candor's Stop check counts:
  `.claude/task-runner/rv/rv-seen-`, `rv-skip-` or `rv-exempt-<card>.json`, and
  `.claude/task-runner/nc/nc-pass-` or `nc-skip-<card>.json`, only those written after the run
  was registered. A numeric card id matches without its leading zeros (`1` is card `01`), as candor counts any id. `/task-board` opens or closes
  it; with no run it shows the newest `taskmaster-docs/tasks/*/00-INDEX.md`, labelled
  `not running`. It opens itself once per run in a session, the first time a refresh sees
  that run, when the terminal can place it; a pane you close stays closed for that run
  unless you pin it (next item).
  `r: Run next` puts `/task-runner:run <index>` in the prompt box and `t: Red-team` puts
  `/taskmaster:redteam <spec>` there, replacing what the box held; neither sends anything.
  Red-team is hidden when taskmaster's red-team command is not installed or the index
  names no spec. A plain run shows `plain run — no card index`, and an index that cannot
  be parsed shows `index unreadable: <path>`, both without buttons.
- **Pin (opt-in).** `/config` option `cc_task_board_pin`, off by default, or
  `CC_TASK_BOARD_PIN=on` (`1`, `true`); the variable wins. While a run is active on this
  branch, closing the board by hand lets it close, then opens it again 100 ms later.
  `/task-board` still closes it for good. Below 144 terminal columns the reopened board
  waits undrawn until the terminal is widened or you run `/task-board`, which then shows
  it instead of closing it. The pin reopens rather than refuses because on CLI 2.1.294 a
  hook that refuses a person's close does not keep the pane open. Standing: **recorded** —
  the test kit cannot raise a person's close, so the reopen was measured only with a probe
  plugin on CLI 2.1.294 (marketplace repository,
  `rationale/2026-10-08-mods-ui-survey-and-pane-probe.md` §3), not with this one;
  `tests/board.test.ts` gates the switch's default and override, that `/task-board` closes
  a pinned board, and that it shows an undrawn one.
- **Markers.** `[x]` done, `[>]` in progress, `[ ]` pending, `[-]` parked (a skipped card
  too), `[!]` blocked, `[?]` a status outside the vocabulary. `<NN` names the first unmet dependency and `+N` how many more
  (`<11+5`); only a done dependency is met, so a parked one counts as unmet.
- **Off switch for the line and the pane.** `CC_TASK_BOARD=off` (or `0`, `false`), or the
  `/config` option `cc_task_board` off; the variable wins. Off clears the line, the
  planning-phase `taskmaster` line too, at the next refresh and keeps the pane from opening, and a session started with it off has no
  `/task-board`.
- **CLI floor.** With mods off in the host or on a CLI below 2.1.287 no module loads; on
  2.1.288-2.1.290 the module passes every call through; either way the classic hooks work
  exactly as before. An organization that sets `allowManagedModsOnly` refuses the module
  and leaves only the classic hooks (per the CLI's built-in sec-default mod documentation,
  not measured). On 2.1.287 with mods on the module still registers its hooks (the version
  check runs inside them), and the board's `tool.call` hook matches every tool, not only
  `Write`. So that CLI's own bug — a plugin's `tool.call` hook breaking Bash and file search
  in worktree subagents, fixed in 2.1.288 — applies even with all three switches off:
  upgrade the CLI or turn mods off.

- **Counts** (since 0.49.0). One is added, in this plugin's own `$.store` (key `outcomes`),
  to `floors.raised.<agent>` each time a spawn's tier is raised, and to `suggest.run.shown`,
  then `.accepted` or `.passed`, each time the run suggestion is shown and your next prompt
  sent `/task-runner:run` or something else: counts only, never text, on this machine only.
  The marketplace repository's `scripts/mod-outcomes.sh` prints them. **Gate** for the
  counting (`tests/floors.test.ts`, the shared kit's tests); what a count means is **recorded**.

Residuals, stated:

- **One shared suggestion slot.** The prompt box holds one suggestion, so when several
  plugins offer one at the same turn end the last caller wins, and a suggestion shown and
  then replaced counts as shown. Claude Code's own suggestion is not suppressed.
- **`Write` only.** An index written through `Edit`, `MultiEdit` or a Bash command (a
  redirect, a heredoc) gets no run suggestion.
- **Terminal only.** The pane was verified live in a terminal on CLI 2.1.292, driven
  through pexpect. No other surface (desktop, web) has been verified.
- **Fail-open.** A hook that errors passes the call through as if the module were absent:
  a spawn runs unfloored, no suggestion is made, the line and the pane skip that refresh.
- **Ambiguous width.** `…` (a cut title) and `—` (a milestone header, the plain-run note)
  are ambiguous-width characters; a terminal that draws them double-width, as CJK-wide
  setups do, misaligns that row.
- **An open pane with no run** lists `taskmaster-docs/tasks` and checks every index's
  modification time on each tool call, to find the newest.
- **A git call per tool call during a run.** While a run is registered or the pane is open,
  every tool call waits for a refresh that runs `git` once or twice (twice while
  `.claude/task-runner/active-run.json` names a run on this branch) and reads that file;
  idle, a main-loop call waits for one `git` call at most every 2 s. `CC_TASK_BOARD=off`
  removes all of it. The idle gap is gated (above); the per-run count is not.

Standing: **gate** — `tests/floors.test.ts`, `tests/suggest.test.ts` and
`tests/board.test.ts` run under `claude plugin test` in CI (the marketplace repository's
`scripts/mod-tests.sh`), so a regression in a tested case fails the build, and the host's
validator fails a `$.state` key that `types/index.d.ts` does not declare. A 2.1.291 test
cannot read `$.state`, so the board state's `runActive` and `phase` are asserted only
through the pane's rendered text. Untested here: the drawn screen (the test kit records
text, so the `r:` and `t:` labels were seen only in the live run), whether the host's
prompt box shows a suggestion, and the board's and the suggestion's error paths. The
live-view exemption in task-execution's "No status theater", which lets a board exist, is
**recorded**: nothing checks that a view keeps no status of its own.

## Pairs well with

- **taskmaster** — produces the task cards this plugin executes
- **code-architecture** — its work-verification discipline applies to the whole run
- **code-review / ui-ux / security** — power the per-task reviewer pass when installed; ui-ux's
  a11y-engineer fixes the accessibility items reviewers defer, inside the run
- **design-kit / overseer** — design-kit pairs the UI walk's shots into a before/after page;
  overseer's acceptance protocol is the fuller walk checklist
- **api-design** — its doc-drift check (`/api-design:drift`) joins the completion gate when installed
