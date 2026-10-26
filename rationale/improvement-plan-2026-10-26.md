# Improvement plan — speed, cost, results and calm, 2026-10-26

**Question:** how do we make these plugins faster and cheaper to use without losing result quality? How do we make them calmer: less ceremony, visible progress, one obvious place to start, plain words, only necessary comments? Run under `/overseer:start` (program `marketplace-ux-dx-ax`, milestone m1). Branch `overseer/m1-improvement-plan`, base `master` at `5b79d05e`, CLI 2.1.310.

**Standing: `recorded`.** Nothing reads this file back. Each item says how it will be enforced once built.

**The user's choices (2026-10-26):**

- Plan first, then build one milestone at a time, with a check-in between milestones.
- Cover four kinds of text: code comments, skill and README text, runtime messages, repo docs.
- When goals conflict: results first, then speed, then calm.
- Fix all four task-management pains: too much ceremony, no visible progress, too slow, "which command?".

**Inputs:** `rationale/landscape-ux-dx-ax-2026-10-26.md` (50 repos); four internal audits run on this tree (runtime messages, code comments, task flow, language); the history in `rationale/`. Audit returns are machine-local under `.claude/overseer/milestones/m1/returns/`. Rows marked ✓ were re-checked against the tree; the rest are the audit's figures.

## Words used here

| Word | Meaning |
| --- | --- |
| Stop check | a hook that runs when the model tries to end its turn and can send it back to work (candor's and ask-ledger's) |
| card | one task card from `/taskmaster:task`, built by `/task-runner:run` |
| negative control | task-runner's check that a card's test fails when the change is removed |
| drift review | a review of whether the work strayed from what was asked |
| shape phase | everything `/taskmaster:task` does before cards exist: scout, questions, spec, red-team, cards |
| receipt | a small file saying "these checks passed at this commit" |
| enforced by | **CI** = a script fails the build (`gate`); **WARN** = a script prints, never fails; **reviewer** = an agent judges, with variance (`agent-graded`); **written** = nothing checks it (`recorded`) |

## What the audits found

| Area | Finding | Source |
| --- | --- | --- |
| Ceremony | A ~5-file feature through `/taskmaster:task` → run → finish asks the user 5-12 questions and spawns ~15-30 subagents. It reads ~266 KB of instruction files (file sizes, not measured context) | task-flow audit |
| Ceremony | `/code-architecture:coding-task` reads 70,472 bytes of instructions before the first edit, even for a one-file fix | task-flow audit, ✓ |
| Speed | The full test suite runs 6-8 times per milestone. The whole-diff review and drift review run at run close and again at `/git-workflow:finish` | task-flow audit, ✓ `finish.md:39-55`, `run.md:113-121` |
| Speed | candor's run-completion clause blocks once per commit. A run that commits per card meets it card after card; one run hit 47 blocks | task-flow audit, ✓ `candor/hooks/gate.sh:404-412`; `session-plugin-usage-review` |
| Progress | The shape phase shows no live status. Card sub-steps and the background behavioral check (up to 6,600 s) are invisible | task-flow audit, ✓ `behavioral-gate.sh:125` |
| Progress | When a Stop check blocks, only the model sees why. The user sees the turn carry on | task-flow audit |
| Which command? | 17 typed commands and 23 auto-loading skills start or steer task work. Of 11 confusable pairs, a new user can tell 8 apart from nothing written. Six mode words (ultra, goal, goal-lean, ultra-task, ultra-goal, ultra-assess) and overseer's "rigour" set one dial | task-flow + language audits |
| Which command? | Typing any slash command silently switches off the prompt reminders, including the auth-risk line | ✓ `taskmaster/hooks/remind.sh:213`, `skill-router/hooks/route-prompt.sh:185` |
| Runtime text | The first work prompt injects 3,066 bytes; 1,769 of them are one skill-router note. 10 of 14 prompt hooks print nothing; the chain takes ~213 ms | runtime audit |
| Runtime text | The ten worst hook messages use internal words (sentinel, RV-CARD, confessed, take/wrap/write) and incident history | runtime audit |
| Comments | 13,663 comment lines in non-test code: 22.6% of all 60,540 code and comment lines. `scripts/lib/plugin-checks.sh` is 54% comments. None of the 30 heaviest files has the house 3-line header | comments audit, ✓ plugin-checks.sh |
| Comments | ≈5,700 comment lines (42%) can go: history narration and multi-line reasoning. 1,223 lines sit in byte-locked shared blocks | comments audit |
| Language | README openings average 27.9 words per sentence, 38% of sentences over 30. Skill descriptions: 28.8, 51% over 30. "standing", "gate", "ledger" and "tier" each have several meanings and no definition an installer reads | language audit |
| Language | Root README calls candor "the marketplace's one blocking Stop gate"; ask-ledger's Stop check also blocks | ✓ `README.md:372`, `ask-ledger/hooks/gate.sh:96` |
| Repo docs | CLAUDE.md is 446 lines. About 25% is incident history, which the file itself says not to add back | language audit, ✓ line count |
| Results | 34 UI workers made 0 browser calls in one measured session | `2026-09-25-session-plugin-usage-review.md` |
| Results | candor's five-move preamble moved a bare run from 0/3 to 3/3 on "render and read the page before claiming done"; a 535-character five-move version did as well as a 4,362-character catalogue | `fable-distillation-2026-09-17.md:70-82` |

## What we will not do

- **One prompt hook instead of many.** Declined 2026-09-14: installs without skill-router would lose their reminders, and the logic would be rebuilt inside one script (`marketplace-consolidation-plan-2026-09-14.md:166-182`). The chain costs ~0.2 s today.
- **One edit hook instead of many.** Declined the same day: it gave identical bytes for a new script and harness churn (same file, :154-163).
- **Trim skill descriptions to save tokens.** 1.8% saved, specificity lost. Item 7 rewrites for plainness at the same length.
- **Cut per-card reviews or use a cheaper reviewer.** Blockers were found on upgrade cards.
- **Merge overseer into taskmaster.** Over the size cap. Item 4 merges only the front door.
- **More keyword reminders or auto-spawned reviewers.** Measured as noise.
- **A new loop-breaker for Stop checks.** It exists: ask-ledger ends the turn after two blocks (`gate.sh:86-89`); candor stands a clause down on the retry (`gate.sh:115-125`). The 47-block run is handled by item 2's preflight.

## The plan

The order is a judgment, not a formula. Each position has its reason in "Order of delivery". No item may lower result quality.

| # | Item | Plugins it improves | What changes | Measure: before → target (command) | Enforced by | Size | Builds on |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | **Measure first** | protects every item below | Extend `scripts/turn-cost.sh` to count, per task in a transcript: questions asked, subagents spawned, Stop-check blocks, full-suite runs, browser calls. Commit the comment-share and readability counters the audits used. Record before values from this project's own past transcripts. | every number below gets a committed command | written (maintainer tool) | S | `turn-cost.sh` |
| 1 | **Plain runtime messages, one name per concept** | skill-router, candor, taskmaster, ask-ledger, approaches, task-runner, command-guard, code-review | First, settle one name each for the effort dial, the Stop checks and the "ledger" files, as a decision. Then rewrite hook messages: what happened, why, what to do next; no internal words or incident history; detail in a file. The skill-router note becomes one line. `consult-remind` names an action or goes. candor's preamble keeps all five moves and is only reworded. | dynamic-channel tokens, skill-router 583 + candor 262 + taskmaster 79 → ≤400 total (`context-budget.sh`); worst-ten list cleared | CI: `context-budget.sh` fails on regrowth past the new baseline; harnesses assert the new strings; with/without run on the preamble before it ships | M | gh-axi, i-have-adhd, open-steps; `session-retro-2026-10-21` prose caps |
| 2 | **Progress you can see** | task-runner, taskmaster, overseer, candor | The task board reads records already on disk. It shows phase k of n, each card's steps, and "waiting on: you / agent / check (12 min)". The shape phase gets a status line. A Stop-check block also shows the user one line. Before a run closes, a preflight lists every missing record at once. Without mods, the SessionStart line and the card index stay the views. | Stop-check blocks per run: 47 → ≤3 (item 0's counter) | CI: board and gate harnesses | M | herdr wait states, open-steps report |
| 3a | **Check once per commit** | git-workflow, task-runner, overseer | A receipt records which checks passed (suite, behavioral check, whole-diff review, drift review). It is keyed on HEAD, base and a clean tree, and goes stale on any change. Finish and overseer accept reuse a fresh receipt instead of re-running. Per-card reviews, negative controls, the final behavioral check and the post-merge suite stay. The board gains a receipt row. | full-suite runs per milestone 6-8 → ≤3; whole-diff reviews 2 → 1 (item 0's counter) | CI: receipt harness | M | flow-next stage lines |
| 3b | **Ask at two checkpoints** | taskmaster, task-runner | The approach pick, red-team holes, coverage findings and "run now?" become one step: accept the recommended answers, or walk through them. Every blocker-severity hole is still its own question, whatever its kind. | questions per medium feature 5-12 → ≤4 (item 0's counter) | reviewer | M | shinpr, agentops |
| 4 | **One front door** | code-architecture, taskmaster, overseer, task-runner | One command sorts the ask into quick, spec or program. It prints the lane and a numbered step list, and `--explain` shows the route without running it. The quick lane reads only what it needs. Other entry points become steps or aliases. A slash command no longer switches off the auth-risk reminder. | typed entry points 17 → ~8 (`ls plugins/*/commands`); bytes read before the first quick edit 70,472 → ≤15,000 (`wc -c` of the loaded set) | reviewer (sorting is judgment); with/without run on the quick lane, since dropping the five discipline skills matches a shape that measured zero or negative (`measured-zero-shapes.md` § 2) but is not yet measured itself | M | flow-next, shinpr |
| 5 | **UI work is checked in a browser** | ui-ux, web-dev, candor | A Stop check: a UI file edited and not rendered since, with a screenshot at named widths and the console read, sends the turn back once. Off-switch `CC_UI_CHECK=off`. With no browser tool installed it warns and never blocks. It reuses overseer's evidence kinds. | browser calls by UI workers: 0 of 34 (2026-09-25) → ≥1 per UI task (item 0's counter) | CI: gate harness | M | plugin87 render receipt; overseer `acceptance.md` |
| 6 | **Comment diet** (three slices) | every plugin with scripts; `scripts/` | Headers of at most 3 lines: what it catches, what it misses, a pointer. History moves verbatim to `rationale/derivations/`. Reasoning paragraphs become one line. Slice a: `scripts/` and `scripts/lib` (no plugin bumps). Slice b: plugin hooks. Slice c: plugin scripts, shared blocks, templates. | comment share 22.6% → ≤15% (item 0's counter; ≤12% only if the audit's high band holds); top-30 files with the header 0 → 30 | WARN: a header-shape check | 3 × M | the user's override of the 2026-10-05 call (decisions.md, 2026-10-26); `session-retro-2026-10-21:280-295`; comment-discipline |
| 7 | **One vocabulary for installers** | all plugins (README text), candor, taskmaster, overseer, ui-libraries, stack-scan | A "words we use" glossary in the root README, about 25 terms, one plain line each. Fix the two contradictions. Rewrite the worst README openings and skill descriptions plainly, at the same length. Run the prompt-route harness and a listing check before and after each description change. The jargon check flags undefined glossary terms. | README openings 27.9 → ≤20 words per sentence (item 0's counter); undefined glossary terms in installer text → 0 | WARN: jargon check; CI: prompt-route harness | M | humanizer, as an authoring aid only; `marketplace-taskforce-review-2026-10-11:63-73` glossary |
| 8 | **Review findings carry checked evidence** | code-review, candor | A script checks every line a reviewer quotes. An unfinished review reports "incomplete", never "clean". Each finding ends as fixed or contested. The review also reads the changed code's callers and tests. | quoted lines that do not match the file: measured in item 0 → 0 | CI: quote-check harness; a with/without eval | M | openqodex, elephant-goldfish, code-review-graph |
| 9 | **CLAUDE.md for day one** | protects every gate it describes: validate.sh, check-version-bumps.sh, context-budget.sh, generate.sh, official-validate.sh | Keep what a contributor needs today; move history to `rationale/claude-md-incident-log.md`. | 446 → ≤200 lines (`wc -l CLAUDE.md`) | written | M | `claude-code-best-practice` (CLAUDE.md under 200 lines) |

**Deferred** (recorded as suggestions; built only if the user asks):

- a "cost of the process" line beside each run's result: extra agent calls, tokens, wait;
- a five-line human resume generated from state files;
- a script-backed "AI look" detector for craft-layer;
- vetted third-party tools (rtk, SkillSpector, design-extract) offered by `stack-scan`'s scout;
- a "who is reading" setting for reply length and jargon across plugins;
- each check's failure message naming its own escape-hatch marker, so CLAUDE.md need not list them.

## Order of delivery

```
m2   Measure first                              (0)   S
m3   Plain runtime messages, one name per concept (1) M
m4   Progress you can see                       (2)   M
m5   Check once per commit                      (3a)  M
m6   Ask at two checkpoints                     (3b)  M
m7   One front door                             (4)   M
m8   UI work checked in a browser               (5)   M
m9   Comment diet — scripts/                    (6a)  M
m10  Comment diet — plugin hooks                (6b)  M
m11  Comment diet — plugin scripts and blocks   (6c)  M
m12  One vocabulary for installers              (7)   M
m13  CLAUDE.md for day one                      (9)   M
m14  Review findings carry checked evidence     (8)   M
```

- **Measure first:** every later target needs a before value taken the way the after value will be.
- **Messages and names next:** every later milestone prints text, so names are settled once, before anything is rewritten.
- **Board before receipts:** the board reads records that exist today; receipts add one row later.
- **Receipts before checkpoints:** fewer re-runs is a pure saving; batching questions changes what the user sees.
- **Front door after the lanes it routes to:** the lanes must be cheaper first.
- **UI check:** strong evidence (0 browser calls in 34 workers), independent of the rest.
- **Comment diet late:** it touches nearly every plugin and would conflict with items 1-5. Slice a can run any time; it touches no plugin.
- **Review evidence last:** it needs the item 0 counter for a before value and an eval budget.

## Every milestone keeps

- The repo gates green: `validate.sh`, `check-version-bumps.sh` (re-run after commit), `context-budget.sh`, `generate.sh --check`, `official-validate.sh`, every smoke and plugin harness, `mod-tests.sh`.
- A version bump for each touched plugin, and a changelog entry where the plugin has a CHANGELOG.md.
- A before and after number from the table above, taken with the same command.
- No new always-on text unless it replaces more than it adds.

## Before values (m2, 2026-10-26)

Taken on branch `overseer/m2-measure-first` with the commands named in each row; an after value must use the same command. Transcript rows read only this repo's own transcripts (13 sessions, 2026-10-07 to 2026-10-26, including the live session running this program), never another project's.

| measure | value | command |
| --- | --- | --- |
| comment share, all code but tests (item 6) | 22.3%: 13,438 comment lines of 60,179, 260 files | `bash scripts/comment-stats.sh` |
| comment share, plugin hooks | 20.8% (95 files) | `bash scripts/comment-stats.sh` |
| comment share, plugin scripts | 16.9% (80 files) | `bash scripts/comment-stats.sh` |
| comment share, scripts/ (not lib, not smoke) | 35.3% (18 files) | `bash scripts/comment-stats.sh` |
| comment share, scripts/smoke | 17.8% (65 files) | `bash scripts/comment-stats.sh` |
| comment share, scripts/lib | 53.1% (2 files) | `bash scripts/comment-stats.sh` |
| comment share, tests (`__tests__/`, `tests/`, any `.test.` or `.spec.` file) | 9.3% (139 files) | `bash scripts/comment-stats.sh` |
| files with the house header (≤3-line first comment block naming `Why, limits, history:`) | 21 of 399 (3 of them added by m2); 0 of the 30 files with most comment lines | `bash scripts/comment-stats.sh --top 30` |
| README openings: words per sentence, % over 30 (item 7) | 26.8, 33.7% (101 sentences, 44 READMEs) | `bash scripts/readability.sh` |
| SKILL description + when_to_use: words per sentence, % over 30 | 28.3, 49.7% (177 sentences, 126 skills) | `bash scripts/readability.sh` |
| command descriptions: words per sentence, % over 30 | 18.7, 10.9% (55 sentences, 52 commands) | `bash scripts/readability.sh` |
| CLAUDE.md prose: words per sentence, % over 30 | 20.9, 23.4% (167 sentences) | `bash scripts/readability.sh` |
| CLAUDE.md length (item 9) | 446 lines on `master`, before m2 (451 after m2 adds the `--workflow` sentences) | `git show master:CLAUDE.md \| wc -l` |
| turn blocks scanned | 59. Folded into the block already open: 227 harness frames (task notifications and peer messages, decided by `origin.kind`, else by text) and 10 compaction summaries. 183 subagent transcripts joined, 9 unlinked | `bash scripts/turn-cost.sh --workflow` |
| questions per block: AskUserQuestion calls (item 3b) | median 0, p90 1, max 8 (19 in all) | `bash scripts/turn-cost.sh --workflow` |
| questions per block: questions inside those calls | median 0, p90 3, max 17 (45 in all) | `bash scripts/turn-cost.sh --workflow` |
| subagents spawned per block | median 0, p90 7, max 39 (183 in all) | `bash scripts/turn-cost.sh --workflow` |
| Stop-check blocks per block (item 2) | median 0, p90 1, max 5 (15 in all, 6 inside subagents) | `bash scripts/turn-cost.sh --workflow` |
| full-suite runs per block (item 3a) | median 0, p90 23, max 144 (590 in all, 403 inside subagents). A run is a gate script or test runner at a command position, heredoc bodies removed; counting every mention gave 780 | `bash scripts/turn-cost.sh --workflow` |
| browser calls per block (item 5) | median 0, p90 0, max 0 | `bash scripts/turn-cost.sh --workflow` |
| model requests and estimated spend, cost report, this repo's transcripts | before the m2 fixes: 4,785 requests, $630.91, 175 blocks. After: 2,221 requests, $262.85, 59 blocks. One response is written as one record per content block, so requests were counted 2.15x; harness frames and compaction summaries had split blocks | the procedure below |
| dynamic-channel tokens (item 1) | skill-router 583, candor 262, taskmaster 79: 924 | `bash scripts/context-budget.sh` |

To reproduce the cost-report row, run from the repo root. Copy both versions of the script, and point `HOME` at a temp dir whose `.claude/projects` holds only this project's transcript dir, so no other project is read. Run the two back to back: the live session keeps appending records.

```bash
T=$(mktemp -d); mkdir -p "$T/home/.claude/projects"
ln -s ~/.claude/projects/-mnt-data-Personal-git-repositories-cc-marketplace "$T/home/.claude/projects/"
git show master:scripts/turn-cost.sh > "$T/before.sh"
git show overseer/m2-measure-first:scripts/turn-cost.sh > "$T/after.sh"
for s in before after; do HOME="$T/home" bash "$T/$s.sh" --json | jq -c '{requests, usd, turn_blocks}'; done
```

What these numbers cannot say yet:

- **Suite runs per milestone** (item 3a's 6-8): not measured. A turn block is one instruction; a milestone spans many blocks and sessions, and nothing groups them. Records carry `gitBranch`, so grouping blocks by milestone branch is the likely next step.
- **Questions per medium feature** (item 3b's 5-12) and **Stop-check blocks per run** (item 2's 47): no taskmaster feature run or task-runner run sits in these transcripts. The per-block max is the nearest proxy. The 47-block run was recorded in another project, which this default does not read.
- **Browser calls by UI workers** (item 5): 0 here means nothing, because these sessions did no UI work. Measure on a project with UI work with `--project`.
- **A turn block is still one instruction, not one task.** Harness frames and compaction summaries no longer open a block, but a user's "proceed" or "yes" mid-task does, and nothing marks where a task ends.
- **Whole-diff reviews per milestone** (item 3a) and **quoted lines that do not match the file** (item 8) have no counter yet. Subagents are counted, not classified by type.
- **Readability numbers are not comparable with m1's audit figures** (27.9 and 38% for READMEs, 28.8 and 51% for skills). The audit read plugin READMEs only and counted each word inside a code span; this counter adds the root README and counts a code span as one word. m7 and m12 compare against this table, not against the audit.
