# candor

Candour as a mechanism, not a pep talk.

A plugin that only said *don't hallucinate, don't flatter, don't fold under
pressure, don't claim what you did not run* would be the shape this marketplace
has already measured at zero (`rationale/measured-zero-shapes.md`, shape 2:
canonical-doctrine checklists). So this one ships the clauses a script can
actually prove, and is explicit that the rest is measured and not enforced.

Since 2026-09-14 it is also the home of the **terse reply mode**: chat-message
brevity as a shape contract, one surface over from honesty. The terse plugin was
merged into this one; its crew agents and its commit and compress commands were
dropped (the host's `/commit` covers the first; the second had one user).

## What blocks

`hooks/gate.sh`, wired to `Stop` and `SubagentStop`. **One gate, five clauses**,
each decidable. Until 2026-09-14 clauses 3 and 4 were separate Stop hooks in
`code-architecture` and `task-runner`; three scripts on one event each had to
namespace the host's shared `stop_hook_active` flag so no sibling could spend
another's enforcement. One script records which clause blocked and skips only
that clause on its own continuation.

| Clause | Fires when | Escape |
| --- | --- | --- |
| **1 Fabricated citation** | the final assistant message cites `path/file.ext:NNN` that resolves to no file under the shell `cwd` or the project root (or under `~` for a `~/` path), or to a line past the file's end | re-read and cite what is there, or drop the number and say you are inferring |
| **2 Unevidenced reversal** | the last user message is challenge-shaped pushback carrying no correction of its own, the final message retracts, and no tool ran in between — writing "I re-checked" or "the file shows" is no re-check without a tool call after the challenge (0.10.0) | re-check and report what it showed, or hold the position and say why |
| **3 Naked completion claim** | the assistant tail claims completion (done / fixed / implemented / verified / passes), a non-prose file was edited this session (`.md`/`.txt`/`.rst`/`.adoc` edits do not arm it — nothing executable proves a README right), and no Bash call ran after the last such edit — dispatching an Agent or Task is not execution (0.10.0). On `SubagentStop` it judges the worker's report against the worker's own transcript, and stands down when the payload names none (0.10.0) | run the check that would fail if the change were broken — the block names `code-architecture:work-verification`, which says how when installed (0.11.0) — or say what was not verified and the command that would verify it — a caveat label followed only by none, n/a or nothing ("Not tested: none", "Parked: none") says nothing was left, so it is no escape (0.10.0) |
| **4 Registered run not complete** | a task-runner run registered itself (`.claude/task-runner/active-run.json`, or `closed-run.json` after its closing rename, which the clause removes once every check holds, or silently once HEAD has moved past its gate pass) and is stopping with no recorded gate pass for HEAD (not while a background worker of this session is in flight — see below), cards neither done nor parked, short per-card control or reviewer records, a UI card (its review diff names a `.tsx`, `.jsx`, `.vue`, `.svelte`, stylesheet or `.blade.php` file that is not a test or story) with no ui-ux-reviewer record, no whole-range review recorded for HEAD on a run whose sentinel carries `start_sha`, a behavioral-gate verdict other than `covered` / `no-executable-surface` (`no-behavioral-coverage` passes only beside a recorded coverage reduction for that HEAD), a short red-team panel on a boosted run, or an undisclosed recorded reduction | continue with a tool call, ask with `AskUserQuestion`, park the card, or run the gate and record the pass |
| **5 Lockfile drift** | a dependency manifest's dependency map changed in the working tree and the lockfile that governs it did not — npm/pnpm/yarn/bun, Composer, Bundler, Poetry/uv/pdm, Cargo, Go. For JSON manifests the parsed dependency maps are compared, not diff lines, so a `version` bump never arms it; the other four test dependency-shaped lines and exclude metadata keys by name | run the installer and commit the lockfile with the manifest, or say plainly that the lockfile is deliberately unchanged and why |

The gate's own state — the one-block-per-text marker and the which-clause-blocked
record — lives in the plugin's data directory, `${CLAUDE_PLUGIN_DATA}/<project-key>/candor/`
(`<project-key>` is the repo folder's name plus a checksum of its path), when the host
provides one, else in `<repo>/.claude/candor/`, which carries a self-ignoring `.gitignore`,
so it never appears in `git status`. Since 0.5.0 every state path and every read of the
run's records (`active-run.json` or `closed-run.json`, `gate-pass.json`, `nc/`, `rv/`, `bg/`, `rt/`,
`reductions/`) resolves at the **project root** — the git toplevel above the payload
`cwd`, else `CLAUDE_PROJECT_DIR` when `cwd` sits under it, else `cwd`. The payload
`cwd` follows the model's `cd`; before 0.5.0 a stop taken from a subdirectory looked
for the run there, found none, and clause 4 enforced nothing.

**Workers in flight (0.5.0).** Clause 4's *no gate pass for HEAD* branch does not
block while this session has a background worker running, because the worker's
hand-back wakes the orchestrator anyway. Measured on 2026-09-25: one orchestrated
run collected 47 of these blocks, nearly all while workers were running, and each one
was answered with a turn that did nothing. The gate uses the host's `background_tasks`
list on the Stop payload whenever the payload carries it (probed on CLI 2.1.282).
Otherwise it uses in-flight records: `preamble.sh` writes one on `SubagentStart`, and
`gate.sh` deletes it on `SubagentStop`. Records older than 180 minutes are swept and
not counted, which is how an agent that died without a `SubagentStop` stops counting.
Since 0.8.0 task-runner's behavioral gate running in background Bash counts as one
worker: it writes `.claude/task-runner/bg/running.pid` (its PID, the HEAD it tests and,
from task-runner 0.48.0, the deadline its own `BEHAVIORAL_GATE_TOTAL` ends it by), and the
gate holds while that PID is live, the sha is the current HEAD and the deadline is ahead,
or, in a file with no deadline, while the file is under 240 minutes old; a dead
PID or another HEAD is ignored. With `/proc` (Linux) live means the PID's command line
names `behavioral-gate.sh`, or else some live `behavioral-gate.sh` runs from under the
repo root: a gate in sandboxed Bash (`bwrap --unshare-pid`) records the sandbox's own PID,
which names another process or none outside it. The gate prints a one-line note instead of blocking and keeps this HEAD's one block for
the stop after the last worker returns. Every other clause-4 reason still blocks while
workers run: a claimed pass with short records, a red behavioral gate, a short
red-team panel, or an undisclosed reduction.

**No runner for a changed language (0.5.0).** `no-behavioral-coverage` means no test
in the project exercises the changed files, for example React files in a project with
no JS runner. It still blocks, and the message now names the honest exit: from the repo
root, task-runner's `scripts/reduction-record.sh --kind coverage --id bg-<HEAD12>
--reason "…"`. That record, newer than the run's registration, lets the verdict pass.
The disclosure check then requires `bg-<HEAD12>` in the closing report. A `red-suite`
whose failing tests predate the run has the same exit with `--kind red` (0.9.1). Every
other red verdict keeps blocking, its message naming that verdict's own repair.

Clause 4 is dormant outside a registered run, on another branch than the run's,
and without git — a records check, never a test run. On `SubagentStop` clauses 1
and 3 run over the subagent's final report (its hand-back): since 0.10.0 a worker
that edited a non-prose file, ran no Bash after its last edit and reports done,
fixed or verified is blocked and told to re-send its complete report. A subagent
has no user turn to push back and registers no run, so clauses 2, 4 and 5 disarm
there. Markers are suffixed per agent, so a subagent block never spends the main
thread's disarm.

Clauses 1 and 2 judge the **final assistant message only**. Clause 3 matches its
claim and its honesty escape over the last 30 lines of assistant text, and that
window bleeds in both directions (measured, documented in the marketplace repository's
`rationale/derivations/plugin-candor.md` § `plugins/candor/hooks/gate.sh`, which an
install does not contain); narrowing
it to the final message was rejected because it blocks honest reports that state
the caveat before the summary.

Modes: `CC_CANDOR_GATE=block` (default) `| warn | off` for the whole gate;
`CC_EVIDENCE_GATE` and `TASK_RUNNER_STOP_GATE` still downgrade clauses 3 and 4
alone, as they did when those were separate scripts; `CC_LOCKFILE_GATE=off`
disables clause 5; `CC_RELAY_GATE=warn` (default) `| block | off` and
`CC_READ_LEDGER=warn` (default) `| off` set the two warnings below. The `warn` modes of the
first three still print to stderr, which Claude never sees and you see only in verbose mode.
Fails open on missing `jq`,
an unreadable transcript, or empty text. One block per distinct final message
(clauses 1-3) or per HEAD (clause 4), so a disagreement cannot loop — and a clause
that is bounded (or in warn mode) prints without silencing the others: a run held
once at a HEAD is still checked for invented citations and naked completion claims
on every later stop (0.3.1; `scripts/__tests__/gate.test.sh`, clause independence).

## What warns

Both warnings are for you, not for Claude: a stop that passes shows them as one
`systemMessage` line in your session, naming the switches. When clause 1, 2, 3 or 5 blocks
the same stop, their text is appended to the block reason Claude reads instead; clause 4
blocks before either runs, so both lists wait for a later stop.

**Relay (0.10.0).** `hooks/relay.sh` reads each worker report as it arrives — a
foreground `Agent`/`Task` result (`PostToolUse`), a subagent hand-back or a
`<task-notification>`'s `<result>` (`UserPromptSubmit`) — and records its caveat lines:
a line that opens, after any bullet, `#` or `**label**`, with *not done, partial, not tested,
untested, not checked, not run, residual, known miss, blocked, could not, did not,
unverified* or *not verified*. A heading of one ("Residuals:", "## Not done") records the
lines under it, past a blank line directly beneath it, up to the next blank line, `#`
heading, bold heading (`**Summary**`, `**Files changed:**`; a line opening with a bold id
such as `**A2**` stays an item) or other heading ("Files changed:"); "none", "n/a" and
"nothing", after the label or as the first line under a heading, are no caveat, and lines
inside fenced code are skipped. At most 40 per context, kept
under `$TMPDIR` (keyed on the hashed transcript path, so a `cd` into a nested repo cannot
lose it). At the next main-thread stop the gate lists each item the final message does not
carry — carried means it names the item's id token (`A2`, `T2-C`, `W6`), or two of its
words of five letters or more that are not stopwords (one, if the item has only one), or,
for an item with none, its text after the label as whole words (two characters at least)
— and clears the list.
`CC_RELAY_GATE=warn` (default) shows you the list and never blocks; `block` holds the
turn once so Claude relays them (behind another clause's block it reports them on that
block instead and clears the list; under `CC_CANDOR_GATE=warn`, or on a repeat stop the
one-block bound lets through, it shows you the list); `off` records nothing.
**Standing:** `gate` for the extraction, the accounting, the modes and the output channel
(`relay-hook.test.sh`); whether the warning changes what gets relayed is unmeasured.

Measured on 92 reports from two sessions of this repository, under the first extraction
and accounting rules (the derivation file has the method; not re-run since the review's
changes): 2.09 caveat items a report (max 9), 29 of 30 sampled items a true caveat,
and 54 reports (59%) followed by a final message that would have warned — in an
orchestrated run the turn after a hand-back is usually an interim status line. That
rate is why block stays opt-in.

**Partial reads (0.10.0).** `hooks/reads.sh` records the top of a file read and left: a
slice that starts at line 1 — a `Read` with a `limit` and no `offset` (or `offset` 1), a
Bash `head -n N`, `head -N` or `sed -n '1,Np'` on one existing file — when the file is
longer than the slice. A later slice of that file (`tail -n N`, `sed -n 'a,bp'`, a `Read`
`offset`) merges into the entry, and a `Read` with neither `offset` nor `limit`, or slices
that together cover the file, clear it; a slice that starts past line 1 of a file with no
entry is ignored. Within one command the slices from line 1 apply first, so
`sed -n 30p f; sed -n 1,9p f` records both. At the next main-thread stop the gate lists each recorded `path:ranges`
whose basename the final message never mentions, and the record clears at every stop.
`CC_READ_LEDGER=warn` (default) shows you the list, or `off`; it never blocks.
**Standing:** `gate` for the recording, merging, clearing and the warning
(`reads-hook.test.sh`); whether a named file was actually discussed is unread — the
basename is enough.

Measured by replaying the main-thread `Read` and Bash calls of three sessions of this
repository against today's tree, under the first rule (any partial slice): 38 of 131 turn
ends (29.0%) would have warned, at most 13 files at once. Most hits were a section read
after a search (`sed -n 214,231p gate.sh`), so the shipped rule counts only a slice from
line 1; on that replay it would have warned on 14 of 131 (10.7%). That figure is the
earlier replay's; it was not re-run against the shipped hook.

## What is measured and not blocked

`/candor:check` runs `scripts/candor-scan.sh` over the session transcript and
prints six counts — the two gated candour axes plus flattery openers, apologies,
defensive phrasing and emotional intensifiers — and, when a terse level is active
or `--brevity` is passed, `scripts/measure.sh`'s prose-line count per turn-final
message against the level's budget. Both always exit 0. The citation count uses the
gate's own lookup, `hooks/cite.sh`, sourced by both (since 0.8.0), so a citation the
report counts is one clause 1 would block.

The four extra axes are deliberately ungated. No regex separates "you're right"
said because it is true from the same words said to please, once the evidence
question is already answered — and a gate that cannot tell them apart trains the
model to drop the phrase rather than the behaviour. Standing: **recorded**.

## The terse reply mode

Brevity modes usually compress **words**. Measured across three long sessions
running a word-compression mode at its strongest setting, mid-turn lines held at
17–265 characters while every turn-final message ran 1,194–4,447. What grows is
**shape**: the last message narrates its own process, re-summarizes the files it
just wrote, re-prints an unchanged inventory. So the mode budgets and shapes the
message instead of shortening its sentences.

**The one law: fewer words in the message, never less work in the turn.** Code,
commits, files written, subagent prompts, tool calls, tests and verification
depth are out of scope at every level. A finding that does not fit goes into a
file and gets cited by path.

```bash
/candor:level full      # the default working level
/candor:level ultra     # answers in 3 prose lines, reports in 6
/candor:level off       # clears the level file; names CC_TERSE or the option if either still sets one
/candor:level status    # every source, and which one wins
/candor:check           # candour axes, plus the brevity measurement while a level is on
```

Installed, the mode does nothing until switched on; there is no ambient mode.
The level persists across every session on this machine
(`~/.claude/terse-mode`; `CC_TERSE=off|lite|full|ultra|wenyan-*` overrides it
for a headless run), and the `cc_terse` /config option sets one when neither does —
that order holds in the hooks, both badges and both commands. **Standing:** the `.sh`
badge and `scripts/level.sh` — `gate` (`level-sources.test.sh`); the hint-line badge —
`gate` (`tests/badge.test.ts`); the `.ps1` badge and the commands — `agent-graded`. Budgets count prose lines only — code blocks, tables
and trees are free:

| Turn kind | lite | full | ultra |
|---|---|---|---|
| progress, mid-turn | 1 | 1 | 1 |
| answer or explanation | 10 | 6 | 3 |
| work-done report | 18 | 12 | 6 |

Work-done reports take one skeleton: verdict → artifact table → at most 5
findings as `path:line — problem → impact` → **skipped** (printed as `none`) →
blocker → next. The cap does **not** apply when findings are the deliverable. The
word layer (dropped articles at `full`, abbreviations and arrows at `ultra`)
yields to a host that bans telegraphese; the budgets and skeleton bind
everywhere. `wenyan-*` levels swap the word layer for classical Chinese
(`skills/terse-output/references/wenyan.md`); verdicts stay in English because
this gate's clause 3 greps the assistant's own words.

**Running another brevity mode?** Remove it first; two always-on compression
prompts on the same turn are not designed to coexist.

**The badge needs no setup.** On Claude Code 2.1.291 or later, the plugin's hooks module
(`hooks/badge.ts`) appends the active level — `[TERSE:ULTRA]` — dim at the end of the hint line
under the prompt, and nothing while terse is off. It follows `scripts/statusline.sh`'s rule:
`CC_TERSE`, then the level file, then the `cc_terse` option; a value outside the vocabulary or a
symlinked level file shows no badge. The option comes from the plugin configuration the host
hands the module, so a `cc_terse` saved through `--settings` shows too (measured once on 2.1.294).
It re-reads at session start, at each turn start (after `/candor:level` wrote the level) and
after every tool call; a level another session changes shows here at the next of those. Another
plugin's text on the same line stays, the badge after it. Terminal only — the desktop app does
not draw the line's tail yet. Off: `cc_terse_badge` in `/config`, or `CC_TERSE_BADGE=off`.
**Standing:** `gate` for the level order, the tail composition and both switches
(`tests/badge.test.ts`, run by `claude plugin test`); the drawn line itself is `recorded` — the
test kit drives the hook, never the terminal's paint, and one live 2.1.294 terminal showed the
badge from `CC_TERSE` and from the option, and none under `CC_TERSE_BADGE=off`.

Older CLI, or want it in your own status line: wire `scripts/statusline.sh` (or `.ps1`) as a
`statusLine` command. The `.sh` badge runs the same `scripts/level.sh` the commands run —
`CC_TERSE`, the level file, the option — and the `.ps1` twin re-implements that order; in both a
symlinked level file blanks the badge.
The scripts read the option from user and managed settings only: a `cc_terse` saved through a
`--settings` file, managed drop-ins or policy, or in a symlinked settings file is applied by the
hooks but unseen by the scripts, and with `jq` missing the `.sh` badge and the commands read no
settings file at all. `/candor:level` asks `claude plugin configure` first (CLI 2.1.285+), which
also sees drop-ins and symlinked files, never the session's own `--settings` — `gate`
(`level-sources.test.sh`, against a stub replaying the shapes measured on 2.1.300 and 2.1.284). `scripts/shrink.mjs` is a stdio proxy
that trims prose out of an MCP server's tool descriptions (`node shrink.mjs
<command> [args…]`), leaving names, schemas and every request untouched.

## The skill

`terse-output` fires when the user asks for shorter, denser replies or a level is
set. Its marked contract block is what the hooks inject — extracted at runtime,
so the injected card and the skill body cannot drift.

## Hooks, all of them

| Event | Script | Does |
| --- | --- | --- |
| `Stop`, `SubagentStop` | `hooks/gate.sh` | the five clauses above; exit 2 blocks; then the relay and partial-read warnings |
| `PreToolUse` (Agent, Task, Write, Edit, MultiEdit, Bash) | `hooks/avert.sh` | the text about to reach a worker or disk declares doing less than what was named for a reason the user did not give — a legal/IP reason, a substitute (original, invented, generic, placeholder, stand-in, look-alike, inspired-by) in place of the real thing, or precaution language ("to be safe", "as a precaution") — and no human turn raised that term: the call becomes a permission question, once per term per session. A Bash call's `git commit` message and `gh pr create`/`edit` title and body are not read: they record a hedge already made (a heredoc opened beside them, or text after a `;`, `&` or `|`, still is) `CC_AVERT=notify` makes it a notification the call proceeds past. Vocabulary-bound — an avert that never names its reason passes; `CC_AVERT=off` silences it |
| `PostToolUse` (Agent, Task), `UserPromptSubmit` | `hooks/relay.sh` | records the caveat lines of a worker report (a foreground result, a hand-back, a task notification's `<result>`) for the relay clause; prints nothing; not from inside a subagent; `CC_RELAY_GATE=off` or `CC_CANDOR_GATE=off` records nothing |
| `PostToolUse` (Read, Bash) | `hooks/reads.sh` | records a slice from line 1 (a `Read` with a `limit`; `head`, `sed -n '1,Np'` on one file) of a file longer than the slice for the partial-read warning, and merges a later `tail`, `sed -n` or `Read` `offset` slice of it; prints nothing; not from inside a subagent; `CC_READ_LEDGER=off` or `CC_CANDOR_GATE=off` records nothing |
| `SessionStart` | `hooks/activate.sh` | injects the terse contract once, only when a level is active; silent otherwise |
| `UserPromptSubmit` | `hooks/mode.sh` | owns the level switch (`/candor:level`, and the narrow natural phrasings "terse mode off", "be more verbose"); while a level is active re-injects one line carrying the budgets and the report skeleton (~150 tokens per prompt — measured 596 chars at `lite`/`full`/`ultra`, 693 at a `wenyan-*` level — and nothing when off) |
| `UserPromptSubmit` | `hooks/preamble.sh` | once per session, on the first prompt whose head carries a making verb in an imperative clause: injects the five working moves before the first edit (under 1,000 bytes, bounded by the hook's own test); silent on every later prompt, on questions, on slash commands, on a harness frame (a hand-back, a notification), and under `CC_PREAMBLE=off`; a making verb only inside a pasted span does not count |
| `SubagentStart` | `hooks/preamble.sh` | the same five moves, once per `agent_id`, for every subagent the Agent tool spawns — `UserPromptSubmit` never fires inside a subagent, and on 2026-09-18 the text reached 0 of 3 workers building an app; under 1,000 bytes too. Since 0.8.0 an agent that cannot edit gets no text — this marketplace's agents whose `tools:` holds neither `Write` nor `Edit` (reviewers, `*-expert`, scouts, `researcher`, `verifier`), matched by qualified name (`ultra-deep-research:verifier`, never a bare `verifier`), and the built-in `Explore`, `Plan` and `claude-code-guide`; `preamble-hook.test.sh` derives that set from every `agents/*.md` and fails on one the list misses; another source's read-only agent still gets it. Also writes the worker's in-flight record for clause 4 (under `$TMPDIR`, keyed on the hashed `session_id`), even under `CC_PREAMBLE=off` |

`mode.sh` is **not** a `CC_REMIND` reminder hook: a user-selected mode is not a
nudge, so it neither claims the one-nudge-per-prompt marker nor answers to that
switch. Its off switches are the level itself (the level file and the `cc_terse`
option) and `CC_TERSE=off`.

## What fires before the first edit

`hooks/preamble.sh` is the before-half of the Stop gate: clause 3 refuses a completion
claim after edits with nothing executed since, and the preamble is the one line that
reaches the model *before* it edits. **Standing: `recorded`** — `additionalContext`
cannot block; the text is advice the model may ignore, and only the Stop gate has teeth.

Why a prompt-time hook and not a skill: three passes shipped working discipline into
this marketplace (delegation preamble, worker template, `work-verification`,
`drift-review`, `coding-entry`), and measured on an ordinary "fix this bug" prompt not
one clause of it reached the main session — the preamble is worker-only by design, the
router nudges after a file is edited, and the skills are command-gated
(`rationale/fable-distillation-2026-09-17.md` §3). Why five short lines: nine Opus 5
runs of one build task moved three observable process moves from 0/3 to 6/6 with a
535-char preamble, and a 4,362-char catalogue added nothing over it (§2 there). Vote
counts on nine runs, not a replicated delta; the cases under `evals/` are the fixtures
that would measure it — one for the whole preamble, two for move (1) (one of them for a
"nothing less" half the move no longer carries), one each for moves (4) and (5), none for
(2) or (3); recount them with `ls -d plugins/candor/evals/*/ | grep -v results` — and
nothing runs them in CI.
Move (1)'s last sentence, *add no code comment unless it states what the code cannot; a CLAUDE.md house style wins*
(0.6.3), is outside that measured set and no case covers it: its effect is unmeasured. It
is there for reach — into every subagent, and into sessions without `code-review`, whose
hooks judge a comment only as it is written.
Move (2)'s last sentence, *if the user said they will test it themselves, name what is
untested and stop* (0.8.0), is outside it too: in a reviewed session the model built
throwaway containers three times to prove a config change the user had said they would test
in production. **Standing: agent-graded**, no case covers it.

Running them takes two operator grants the case files cannot give themselves:

```bash
claude plugin eval ./plugins/candor --allow-tools Write Edit Bash --scaffold --ablation with-without
```

`execution.allowed_tools` declares what a case may use; only `--allow-tools` grants it,
so without that flag `Write`, `Edit` and `Bash` are withheld from the model and the
`ran-a-command` grader on `limitation-checked-before-stated` cannot pass — no call, not
even a refused one, can appear in the trace. `--scaffold` is off by default and runs
author-supplied bash as you; three of the five cases build their workspace with it, and
without the flag they score whatever happens to be in your working directory. Add
`--max-cost-usd 0` to check that the suite loads without spending anything — that is what
`scripts/eval-cases.sh` does on every CI run.

## What this does not carry

Stated because a gate reads stronger than it is:

- **Only `file:line` is checked, never a bare path.** A bare path is routinely a
  file the turn proposes to create. An invented API name, package, flag or
  function is not caught by anything here — only an invented *location* is.
- **Only an invented FILENAME is caught, not a wrong directory.** Measured over
  47 real transcripts, an abbreviated path is far more common than an invented
  one, so the resolver falls back to the basename and only a basename that
  exists nowhere blocks. A basename found only under `node_modules/` or `vendor/`
  (6 levels deep) counts as real but is not line-checked; one only under `dist/`,
  `build/` or `.venv/` still blocks. A `file:line` whose extension is a dev host
  name (`.localhost`, `.test`, `.local`, `.example`…) is read as `host:port` and
  not checked.
- **Any tool call counts as re-checking (clause 2) and any post-edit Bash call
  counts as verification (clause 3).** A `git status` satisfies both. The gate
  proves something ran, not that the right thing ran. Since 0.10.0 a dispatched
  agent is not a run, and a re-check the message only claims is not a re-check.
- **Silence evades clause 3.** A turn that claims nothing is not judged — the lie
  this clause exists to stop was never told.
- **Clause 4 enforces only a run that registered itself.** A run that never
  writes the sentinel is not enforced; what it closes is the honest-but-forgetful
  path.
- **In-flight detection has residuals.** The host's `background_tasks` list is used
  whenever the payload carries it. Without that list, a worker that runs longer than
  180 minutes stops counting, and the gate blocks once per HEAD as it did before 0.5.0.
  A session resumed under a new `session_id` cannot see its earlier records.
  Background shell tasks and workflows do not count as workers, except the behavioral
  gate's `bg/running.pid`; without `/proc` (macOS) a recycled PID at the same HEAD
  holds the block until the file's deadline (about 111 minutes by default, longer with a
  raised `BEHAVIORAL_GATE_TOTAL`) or, with none, until it is 240 minutes old; on Linux any
  process naming `behavioral-gate.sh` from under the repo root holds it while the file is
  current. A gate that outlives its deadline, possible only where no `timeout`, `gtimeout`
  or `perl` caps its suites, draws one block at its HEAD.
- **Pushback detection is a regex over one message.** Phrasing outside the list
  is invisible, and a user message carrying its own evidence disarms clause 2 on
  purpose.
- **`/candor:check`'s citation count is backward-looking.** It resolves a whole
  session's citations against today's tree; use `--last N` for a reading about
  the current session. The gate judges one message against the tree at that
  moment.
- **The shape contract is unenforceable at write time.** Nothing can rewrite a
  message after it is emitted; the mode is reinforced per turn and measured after
  the fact. Nor can any script measure work that did not happen — the
  no-less-work rule is stated in every injection because that is the only lever.
- **The relay and partial-read warnings read words and commands, not intent.** A
  caveat phrased outside the list, not at a line or bullet start, or inside fenced code is
  not recorded;
  a final message that repeats two of an item's words counts as carrying it. Caveats a
  nested worker hands to a subagent, and what a subagent reads, are not tracked. The
  `tool_response` and hand-back shapes come from transcripts of CLI 2.1.295–2.1.296,
  not from a live hook probe. A slice that starts past line 1 of a file not already
  recorded, a pipe (`cmd | head`), `tail -n +N`, `awk`, `less` and a `Read`'s own
  2,000-line cap (a `Read` with no `limit` counts as whole) are not seen as partial reads.
- **Tone is never blocked.** See above.

## Install

```
/plugin install candor@cc-plugins-marketplace
```

Install it by name — nothing brings it in for you since the suites were retired on
2026-09-26. It matters most beside `task-runner` and `code-architecture`, whose runs and
`work-verification` skill rely on clauses 3 and 4. Always-on cost: the description of one
skill (both commands are typed, not listed); the terse hooks inject nothing until a level is set.

## Author-time checks

```bash
bash plugins/candor/scripts/__tests__/gate.test.sh          # clauses 1, 2, 5, clause 3's dispatch and SubagentStop cases, clause independence, modes, state root, in-flight workers, coverage reduction
bash scripts/smoke/evidence-gate-hook-tests.sh              # clause 3
bash scripts/smoke/completion-gate-hook-tests.sh            # clause 4 (drives task-runner's record writers too)
bash plugins/candor/scripts/__tests__/relay-hook.test.sh    # the relay ledger and its Stop clause
bash plugins/candor/scripts/__tests__/reads-hook.test.sh    # the partial-read ledger and its Stop warning
bash plugins/candor/scripts/__tests__/candor-scan.test.sh   # the six axes
bash plugins/candor/scripts/__tests__/install.test.sh       # install shape, non-git consumer project
bash plugins/candor/scripts/__tests__/mode-hook.test.sh     # level switching and per-turn reinforcement
bash plugins/candor/scripts/__tests__/level-sources.test.sh # level.sh's layer order, the sh badge, measure.sh's level
claude plugin test plugins/candor                           # the hint-line badge: level order, tail composition, switches, CLI floor
```

All run in CI: the plugin harnesses through the shared
`plugins/*/scripts/__tests__/*.test.sh` step, the two smoke harnesses as named
steps, the module's tests through `scripts/mod-tests.sh`. `install.test.sh` copies the plugin to a temp dir, resolves the hook by
expanding `${CLAUDE_PLUGIN_ROOT}` the way the host does, refuses a hook that
resolves back into this repository, and drives it against a consumer project
that is **not** a git repository.

## Pairs well with

- **code-architecture** — its `work-verification` skill states the rule clause 3
  enforces; the hook lived there until 2026-09-14
- **task-runner** — writes every record clause 4 reads (`gate-pass.json`, the
  `nc/`, `rv/`, `bg/`, `rt/` and `reductions/` dirs); the hook lived there until
  2026-09-14
