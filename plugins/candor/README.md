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
| **2 Unevidenced reversal** | the last user message is challenge-shaped pushback carrying no correction of its own, the final message retracts, and no tool ran in between | re-check and report what it showed, or hold the position and say why |
| **3 Naked completion claim** | the assistant tail claims completion (done / fixed / implemented / verified / passes), a non-prose file was edited this session (`.md`/`.txt`/`.rst`/`.adoc` edits do not arm it — nothing executable proves a README right), and nothing was executed after the last such edit | run the check that would fail if the change were broken, or say what was not verified and the command that would verify it |
| **4 Registered run not complete** | a task-runner run registered itself (`.claude/task-runner/active-run.json`) and is stopping with no recorded gate pass for HEAD (not while a background worker of this session is in flight — see below), cards neither done nor parked, short per-card control or reviewer records, a behavioral-gate verdict other than `covered` / `no-executable-surface` (`no-behavioral-coverage` passes only beside a recorded coverage reduction for that HEAD), a short red-team panel on a boosted run, or an undisclosed recorded reduction | continue with a tool call, ask with `AskUserQuestion`, park the card, or run the gate and record the pass |
| **5 Lockfile drift** | a dependency manifest's dependency map changed in the working tree and the lockfile that governs it did not — npm/pnpm/yarn/bun, Composer, Bundler, Poetry/uv/pdm, Cargo, Go. For JSON manifests the parsed dependency maps are compared, not diff lines, so a `version` bump never arms it; the other four test dependency-shaped lines and exclude metadata keys by name | run the installer and commit the lockfile with the manifest, or say plainly that the lockfile is deliberately unchanged and why |

The gate's own state — the one-block-per-text marker and the which-clause-blocked
record — lives in `.claude/candor/`, which carries a self-ignoring `.gitignore`, so
it never appears in `git status`. Since 0.5.0 every state path and every read of the
run's records (`active-run.json`, `gate-pass.json`, `nc/`, `rv/`, `bg/`, `rt/`,
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
The gate prints a one-line note instead of blocking and keeps this HEAD's one block for
the stop after the last worker returns. Every other clause-4 reason still blocks while
workers run: a claimed pass with short records, a red behavioral gate, a short
red-team panel, or an undisclosed reduction.

**No runner for a changed language (0.5.0).** `no-behavioral-coverage` means no test
in the project exercises the changed files, for example React files in a project with
no JS runner. It still blocks, and the message now names the honest exit: from the repo
root, task-runner's `scripts/reduction-record.sh --kind coverage --id bg-<HEAD12>
--reason "…"`. That record, newer than the run's registration, lets the verdict pass.
The disclosure check then requires `bg-<HEAD12>` in the closing report. `empty-suite`,
`unverifiable-suite` and every other red verdict keep blocking.

Clause 4 is dormant outside a registered run, on another branch than the run's,
and without git — a records check, never a test run. On `SubagentStop` only
clause 1 runs, over the subagent's final report; a subagent has no user turn to
push back and no session that edited files, so the rest disarm there. Markers are
suffixed per agent, so a subagent block never spends the main thread's disarm.

Clauses 1 and 2 judge the **final assistant message only**. Clause 3 matches its
claim and its honesty escape over the last 30 lines of assistant text, and that
window bleeds in both directions (measured, documented in the script); narrowing
it to the final message was rejected because it blocks honest reports that state
the caveat before the summary.

Modes: `CC_CANDOR_GATE=block` (default) `| warn | off` for the whole gate;
`CC_EVIDENCE_GATE` and `TASK_RUNNER_STOP_GATE` still downgrade clauses 3 and 4
alone, as they did when those were separate scripts; `CC_LOCKFILE_GATE=off`
disables clause 5. Fails open on missing `jq`,
an unreadable transcript, or empty text. One block per distinct final message
(clauses 1-3) or per HEAD (clause 4), so a disagreement cannot loop — and a clause
that is bounded (or in warn mode) prints without silencing the others: a run held
once at a HEAD is still checked for invented citations and naked completion claims
on every later stop (0.3.1; `scripts/__tests__/gate.test.sh`, clause independence).

## What is measured and not blocked

`/candor:check` runs `scripts/candor-scan.sh` over the session transcript and
prints six counts — the two gated candour axes plus flattery openers, apologies,
defensive phrasing and emotional intensifiers — and, when a terse level is active
or `--brevity` is passed, `scripts/measure.sh`'s prose-line count per turn-final
message against the level's budget. Both always exit 0.

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
/candor:level off       # normal length resumes
/candor:level status    # what is active, and where it came from
/candor:check           # candour axes, plus the brevity measurement while a level is on
```

Installed, the mode does nothing until switched on; there is no ambient mode.
The level persists across every session on this machine
(`~/.claude/terse-mode`; `CC_TERSE=off|lite|full|ultra|wenyan-*` overrides it
for a headless run). Budgets count prose lines only — code blocks, tables and
trees are free:

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

Optional, wire them yourself: `scripts/statusline.sh` (or `.ps1`) renders
`[TERSE:ULTRA]` in a `statusLine` setting — it reads the level **file** only, so a
level set purely through `CC_TERSE` is active but unbadged; `scripts/shrink.mjs` is a stdio proxy
that trims prose out of an MCP server's tool descriptions (`node shrink.mjs
<command> [args…]`), leaving names, schemas and every request untouched.

## The skill

`straight-talk` fires when a claim is challenged or about to be reversed, or when
an honest read of the user's own work is asked for. Its body is six **orderings**,
not sentiments: evidence before claim; the disagreement before the concession; a
reversal treated as a finding that needs its own evidence; "I don't know" shipped
with the command that would settle it; scope honesty stated when decided rather
than in a footnote; correction without performance. It carries its own standing
table naming which of the six have teeth and which do not.

`terse-output` fires when the user asks for shorter, denser replies or a level is
set. Its marked contract block is what the hooks inject — extracted at runtime,
so the injected card and the skill body cannot drift.

## Hooks, all of them

| Event | Script | Does |
| --- | --- | --- |
| `Stop`, `SubagentStop` | `hooks/gate.sh` | the five clauses above; exit 2 blocks |
| `PreToolUse` (Agent, Write, Edit, MultiEdit, Bash) | `hooks/avert.sh` | the text about to reach a worker or disk declares doing less than what was named for a reason the user did not give — a legal/IP reason, a substitute (original, invented, generic, placeholder, stand-in, look-alike, inspired-by) in place of the real thing, or precaution language ("to be safe", "as a precaution") — and no human turn raised that term: the call becomes a permission question, once per term per session. `CC_AVERT=notify` makes it a notification the call proceeds past. Vocabulary-bound — an avert that never names its reason passes; `CC_AVERT=off` silences it |
| `SessionStart` | `hooks/activate.sh` | injects the terse contract once, only when a level is active; silent otherwise |
| `UserPromptSubmit` | `hooks/mode.sh` | owns the level switch (`/candor:level`, and the narrow natural phrasings "terse mode off", "be more verbose"); while a level is active re-injects one line carrying the budgets and the report skeleton (~150 tokens per prompt — measured 596 chars at `lite`/`full`/`ultra`, 693 at a `wenyan-*` level — and nothing when off) |
| `UserPromptSubmit` | `hooks/preamble.sh` | once per session, on the first prompt whose head carries a making verb in an imperative clause: injects the five working moves before the first edit (under 1,000 chars, bounded by the hook's own test); silent on every later prompt, on questions, on slash commands, and under `CC_PREAMBLE=off` |
| `SubagentStart` | `hooks/preamble.sh` | the same five moves, once per `agent_id`, for every subagent the Agent tool spawns — `UserPromptSubmit` never fires inside a subagent, and on 2026-09-18 the text reached 0 of 3 workers building an app; no matcher, so read-only spawns pay the ~640 chars too. Also writes the worker's in-flight record for clause 4 (under `$TMPDIR`, keyed on the hashed `session_id`), even under `CC_PREAMBLE=off` |

`mode.sh` is **not** a `CC_REMIND` reminder hook: a user-selected mode is not a
nudge, so it neither claims the one-nudge-per-prompt marker nor answers to that
switch. Its off switches are the level itself and `CC_TERSE=off`.

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
that would measure it — one for the whole preamble, the rest one per move; recount them
with `ls -d plugins/candor/evals/*/ | grep -v results` — and nothing runs them in CI.

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
  exists nowhere blocks.
- **Any tool call counts as re-checking (clause 2) and any post-edit execution
  counts as verification (clause 3).** A `git status` satisfies both. The gate
  proves something ran, not that the right thing ran.
- **Silence evades clause 3.** A turn that claims nothing is not judged — the lie
  this clause exists to stop was never told.
- **Clause 4 enforces only a run that registered itself.** A run that never
  writes the sentinel is not enforced; what it closes is the honest-but-forgetful
  path.
- **In-flight detection has residuals.** The host's `background_tasks` list is used
  whenever the payload carries it. Without that list, a worker that runs longer than
  180 minutes stops counting, and the gate blocks once per HEAD as it did before 0.5.0.
  A session resumed under a new `session_id` cannot see its earlier records.
  Background shell tasks and workflows do not count as workers.
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
- **Tone is never blocked.** See above.

## Install

```
/plugin install candor@cc-plugins-marketplace
```

Also arrives with `core-suite` and `workflow-suite` — the second because the runs
and the verification skill it ships rely on clauses 3 and 4. Always-on cost: the descriptions of two
commands and two skills; the terse hooks inject nothing until a level is set.

## Author-time checks

```bash
bash plugins/candor/scripts/__tests__/gate.test.sh          # clauses 1, 2, 5, clause independence, modes, SubagentStop, state root, in-flight workers, coverage reduction
bash scripts/smoke/evidence-gate-hook-tests.sh              # clause 3
bash scripts/smoke/completion-gate-hook-tests.sh            # clause 4 (drives task-runner's record writers too)
bash plugins/candor/scripts/__tests__/candor-scan.test.sh   # the six axes
bash plugins/candor/scripts/__tests__/install.test.sh       # install shape, non-git consumer project
bash plugins/candor/scripts/__tests__/mode-hook.test.sh     # level switching and per-turn reinforcement
```

All run in CI: the plugin harnesses through the shared
`plugins/*/scripts/__tests__/*.test.sh` step, the two smoke harnesses as named
steps. `install.test.sh` copies the plugin to a temp dir, resolves the hook by
expanding `${CLAUDE_PLUGIN_ROOT}` the way the host does, refuses a hook that
resolves back into this repository, and drives it against a consumer project
that is **not** a git repository.

## Pairs well with

- **code-architecture** — its `work-verification` skill states the rule clause 3
  enforces; the hook lived there until 2026-09-14
- **task-runner** — writes every record clause 4 reads (`gate-pass.json`, the
  `nc/`, `rv/`, `bg/`, `rt/` and `reductions/` dirs); the hook lived there until
  2026-09-14
