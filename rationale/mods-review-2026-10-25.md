# Claude Code mods in this marketplace — pros and cons (2026-10-25)

Purpose: list what each shipped mod does, what it buys and what it costs, so the owner can
decide per mod: keep, improve, rework or remove. Nothing here is decided; the "Lean" column is
the reviewer's suggestion only.

**Standing: `recorded`** — a one-time read; nothing re-runs it.

## What was checked, and how

- **Inventory.** Every `plugins/*/hooks/hooks.json` with a `modules` key: 13 plugins, 16
  features. All 13 are enabled in this machine's user settings.
- **Source.** Every mod source file read in full: the six `suggest.ts`, the shared
  `cc-kit.ts` (one copy; `pc_mod_kit` holds all 13 copies byte-identical), candor
  `badge.ts`, overseer `status-line.ts` + `status-core.ts`, stack-scan `pins.ts` +
  `pins-core.ts`, skill-router `mods.ts` + `listing.ts` + `compact.ts`, task-runner
  `mods.ts` + `floors*.ts` + `board*.ts{,x}`, session-hud `hud*.ts{,x}`, secret-scanning
  `redact.ts` + `redact-core.ts`, and prompt-coach `coach.ts` + `coach-core.ts` +
  `coach-view.tsx` + `sprite.ts`.
- **Probes.** The four mod probes read in full: `2026-10-06-mods-classic-coexistence-probe.md`,
  `2026-10-07-prompt-coach-probe.md`, `2026-10-08-mods-ui-survey-and-pane-probe.md` and
  `2026-10-08-skill-router-mods-probe.md`.
- **Tests run.** `bash scripts/mod-tests.sh` on CLI 2.1.310: all 13 plugins and the kit
  harness PASS, 14 s.
- **Timed.** git calls in this repo, median of 20 runs: `rev-parse --show-cdup` 0.6 ms,
  `symbolic-ref -q HEAD` 0.6 ms, `status --porcelain --untracked-files=no` 2.0 ms.
- **Seen live while writing this file (CLI 2.1.310).** The first `Write` of this document
  was refused by secret-scanning's `redact.ts`: the text quoted the redaction marker
  literally (the bracketed word `REDACTED` followed by a colon). That is row 1's first con,
  reproduced. This copy names the marker without its colon.
- **Not read in full:** the 13 test files (about 7,070 lines; run, not read line by line);
  the prompt-coach README (lines 1-60, 213-250 and 325-345 plus a grep); the
  secret-scanning README (a grep only); the candor README (its badge paragraph only); the
  mod sections of the other READMEs were read whole.

Size: about 4,650 lines of mod source outside the kit, plus 13 × 272 kit lines, plus about
7,070 test lines. prompt-coach alone is 1,467 source lines and 2,056 test lines.

## Per mod

| # | Plugin · mod | What it does | Pros | Cons | Lean |
|---|---|---|---|---|---|
| 1 | secret-scanning · `redact.ts` | Masks secrets with a `REDACTED` placeholder that names the label, in tool results, attached files and @-mentions. At submit it asks Mask / Send / Cancel when a prompt holds a secret. It marks secrets red in the draft, and refuses a Write or Edit that would write a placeholder back. | The only way to keep a secret out of the model's context: classic hooks cannot rewrite a tool result or a prompt. One `patterns.tsv` serves this and `scan.sh`, with an ERE/JS parity harness. A redaction that fails withholds the result rather than leaking it. 844 test lines. The host leaks below each CLI fix are documented. | The most complex mod: the PEM/merge core alone is 572 lines. It scans every tool result, subagents' included, and the CPU cost is measured only for the draft (16 ms per 100 KB). The placeholder refusal also blocks honest writes that quote the marker: it refused this review's first `Write` (seen live, 2.1.310), and it would refuse edits to this repo's own secret-scanning sources, tests and README. The only escape, `CC_SECRET_REDACT=off`, turns off all redaction. A false positive interrupts the prompt with a dialog. | **Keep**; consider a narrower escape for the write-back refusal |
| 2 | task-runner · `floors.ts` | On `agent.spawn`, raises the six registry agents (`role-floors.md`) to max(session model, floor). | Closes a gap prose cannot: main-thread PROACTIVE dispatches bypass every skill that reads the registry. It only raises and never refuses, toasts each change (once per workflow run) and is gated by tests. | A Fable session runs every floored reviewer on Fable, which costs more by design and is visible only as a toast. The registry is read once per session. The model family comes from a substring match (`opus` in the id), so an id without a family name passes through unfloored. | **Keep** |
| 3 | skill-router · `compact.ts` | On `/compact` with pipeline state on disk, adds at most 1,200 characters to the summarizer's instructions: keep the phase, run, card, scope and done list word for word. | Fires only on compaction, and only with state on disk. The fields are cleaned to path characters, so a file cannot inject a sentence. The probe showed the text reaching the summarizer request. | Automatic compaction is untested. Whether a real model's summary keeps what it is asked to keep is unmeasured. It overlaps `compact-capsule.sh`, which restates the same state afterwards. | **Keep** |
| 4 | skill-router · `listing.ts` | Opt-in, off by default. Drops 8 stack skills from the skill listing when the repo shows none of their stack. | Measured: the rewritten listing reaches the API, and a hidden skill still loads by name. Fails open. | Off by default because nothing shows that it helps: the repo's own eviction probe measured 47/50 against 47/50 for a name-only listing. It runs bash (`stack-evidence.sh` + `prime.sh`) for each listing. For a default install it is dead code that is still maintained and tested. | **Remove** (or leave off) |
| 5 | stack-scan · `pins.ts` | When a skill loads, prepends "installed X vs the version this skill was checked against" for each `Last verified: … npm:<pkg>@<ver>` stamp. | Carries exactly the rule a model gets wrong from memory: version drift. Costs nothing when a skill has no stamp; 12 SKILL.md files carry one. The semver parse keeps lockfile text out of the skill. | npm only: 0 SKILL.md files stamp composer, so the Laravel and PHP skills get nothing. It reads `package-lock.json` only (no pnpm or yarn), and the SKILL.md body only, so the 23 `references/` files with stamps get no line. Never seen live: `skill.prompt` is stubbed in tests. | **Keep + improve** (pnpm/yarn lockfiles, composer stamps + `composer.lock`) |
| 6 | task-runner · `board.ts` + `board-view.tsx` | During a run, a pinned status line `task-runner <phase> card N/M …` and a `/task-board` pane of cards with r (Run next) and t (Red-team) buttons that fill the prompt box. The pane opens itself once per run; an opt-in pin reopens it after a close. | Shows a run's progress with no model tokens. The buttons only fill the box, never send. A slow refresh cannot paint over a newer one. | Refreshes after every tool call, subagents' included, with 1-3 git calls plus a stat and a read, and the tool result waits for it. It is a fourth parser of the card-index format (board-core, task-runner `suggest.ts`, prompt-coach `runContext`, `announce.sh`). If the pane docks at the 23-column body session-hud measured, card titles get 8-10 characters. It opens a pane nobody asked for. Terminal only. | **Keep, rework**: throttle like session-hud (2 s gap), and decide whether the pane earns its ~470 lines |
| 7 | overseer · `status-line.ts` | One pinned line, `overseer milestone k/n <id> <title> (<status>)`, while `program.json` names a next milestone. | Tiny (120 lines). Re-reads only when the file's mtime moves, refreshes only on main-loop calls, and a parity test holds it to `program.sh next`. | Useful only during an overseer program, which is rare, yet it runs one git call per main-loop tool call in every repo unless switched off. Per session-hud's README (not verified here), the engine prefixes every plugin status line with `⚠ <plugin>:`, so it reads like a warning. | **Keep, improve**: skip the git call when `program.json` is absent at the cached root |
| 8 | candor · `badge.ts` | Appends `[TERSE:<LEVEL>]` to the hint line. | Shows terse mode with zero setup. Cheap: a stat and a read of the level file. | Re-reads on every tool call, subagents' included; `turn.start` plus a `/candor:level` trigger would do. It duplicates `statusline.sh`'s badge for anyone who wired that. Low value: the SessionStart hook already announces the mode to the model. | **Keep** (trim the `tool.call` refresh) |
| 9 | session-hud · `hud.tsx` | Context %, rate limits, cost, time and git on the hint line; a per-turn delta line; a `/hud` pane with a context breakdown; a `subagentStatusLine` script. | Needs no `settings.json` edit. Makes no model calls. The breakdown pane and the subagent rows are not available from a plain status line. | This machine already runs its own `statusLine` (`~/.claude/statusline.py`, 10 s refresh), so the hint-line segments probably duplicate it. It runs `git status` at most every 2 s and on a 30 s tick. It writes a pointer file into `~/.claude/plugins/` that uninstall leaves behind. The turn line is matched to its turn by duration, so it can mislabel. The subagent rows need `jq` and read the option from user `settings.json` only. | **Owner's call**: keep only the parts your `statusline.py` lacks (pane, subagent rows) or remove |
| 10 | prompt-coach · `coach.ts` | At Enter, holds each eligible prompt for a Haiku judge (≤ 5 s). On a flag, a Sonnet or Opus standby (≤ 10 per session) returns a verdict, and a high-confidence one drops the prompt and shows a rewrite bubble with fill buttons. Plus a pixel-art mascot pane or status face. | A unique mechanism: a classic hook cannot hold, drop and offer a rewrite. Careful fail-open: a deadline, a back-off after 3 failures, a cap, and a drop only when the band is provably on screen. Prompt-injection hardening on the judge input. A masked audit log of drops. 2,056 test lines. | Every eligible prompt waits about 0.6 s (Haiku, as probed on 4.5) and a flag about 3 s. The spend is billed but missing from `/cost` and session usage. Judge quality is unmeasured: no eval, and nothing records the button pressed, so the false-positive rate is unknown (the 2026-10-11 taskforce ledger idea was not built; `fill()` stores only a pass hash). When plugin order puts it before secret-scanning, a typed secret reaches the judge unmasked, and every terminal session opens with a toast saying so. The mascot (sprite, blink, pane reopen and status face, roughly 400 lines counted by hand) is decoration, not judgement. It was observed live on 2.1.291-2.1.294 only; the API is early access and the floor has no ceiling. Its README says bulk installs leave it out, yet it is enabled globally here. This repo has no `.claude/prompt-coach/held.jsonl`, so nothing was ever dropped here; other projects were not checked. | **Owner's call**: rework (cut the mascot, add a per-flag outcome row, run one control/treatment) or remove |
| 11 | taskmaster · `suggest.ts` | After a spec `Write`, suggests `/taskmaster:redteam <spec>` as Tab ghost text. | 25 lines. Zero context tokens. | Silent while the pipeline's phase sentinel is live, and `/taskmaster:task`, the flow that writes specs, writes that sentinel first and runs red-team itself (README: "the pipeline runs the red-team itself"). So it fires only for a spec written outside the pipeline, or when the model skipped the sentinel step. No instrument says how often that happens. | **Remove** candidate |
| 12 | task-runner · `suggest.ts` | After the main loop writes a card index, suggests `/task-runner:run <index>` at the first turn end with no live sentinel. | Picks up an index the user deferred. Skips closed or already-gated indexes. | It overlaps `/taskmaster:task`'s own "Run now" hand-off question. It sees `Write` only (not `Edit`, `MultiEdit` or Bash). It is one more caller in the shared suggestion slot. | **Keep, low priority** |
| 13 | code-review · `suggest.ts` | After a turn that edited 3+ code files, suggests `/code-review:review`, keyed by HEAD. | It is aimed at the user, not the model, and complements the review-debt nudge. Silent during a run. | The 3-file threshold is fitted to n = 2 real reviews (README). Edits made through Bash are invisible, and in one measured session 233 of 238 writes went through Bash (secret-scanning README). It costs 3-4 git calls per code edit. Outside git, or before the first commit, it never fires. | **Keep, improve**: count Bash writes (the `hook-bash-writes` blocks) |
| 14 | debugging · `suggest.ts` | When the same Bash command fails twice in the main loop, suggests ``/debugging:debug `<cmd>` failed twice``. | Fires on what commands did, not on wording. Cheap. | Its `failures` map grows for the whole session (minor). A subagent's failing runs are not seen. | **Keep** |
| 15 | testing · `suggest.ts` | When one test command both passes and fails with no edit in between, suggests `/testing:flake-hunt`. | A precise idea, and cheap. | Misfires on the most common loop: fail → fix → pass, when the fix went through Bash (README states this) **or through a subagent**. The kit drops every `tool.call` with an `agentId`, so a delegated fix between two main-loop runs is invisible. The README does not state the subagent case. With most writes going through Bash, the false-positive share is likely high (not measured). | **Fix or remove**: count Bash writes and subagent edits |
| 16 | git-workflow · `suggest.ts` | After task-runner's green gate on an unpushed feature branch, suggests `/git-workflow:finish`. | Precise: it keys on the gate head matching HEAD. | Useful only after a task-runner run. It runs 2 git calls at every main-loop turn end, in every repo. A branch pushed by hand without a PR reads as finished. | **Keep** |

## Cross-cutting

| Topic | Finding | Effect |
|---|---|---|
| Evidence of value | Not one mod records an outcome: no accepted-suggestion counter, no button ledger for prompt-coach, no count of floor raises or redactions. The taskforce review (2026-10-11 §4) proposed a counter for each; none was built. | Keep or remove is a judgement call for every mod except 1 and 2, whose mechanism is its own justification |
| Version drift | Every probe and walk was made on CLI 2.1.291-2.1.294. This machine runs 2.1.310, and `MODS_FLOOR` has no ceiling. The tests pass on 2.1.310, but they stub the engine; the one live observation on 2.1.310 is row 1's write refusal. | The UI claims (pane reopen, band collapse detector, deny strings prompt-coach matches by regex) are 16+ versions stale |
| Per-tool-call work | With defaults, each main-loop tool call waits for: overseer (1 git), board (1-3 git, subagents' calls too), hud (≤ 2 git, at most once per 2 s), candor (stat + read, subagents' calls too), secret-scanning (a regex scan of the result). Here a git call costs 0.6-2.0 ms. | Small in this repo. `git status` grows with repo size, and no test or meter counts any of it |
| `stateRoot` uncached | Every hook in every mod spawns `git rev-parse --show-cdup` again; code-review does it 3-4 times per edit. | A per-session cache keyed on cwd, in the kit, would remove most of the spawns |
| One suggestion slot | Six mods and the host's own suggestion share one prompt-box slot; the last caller wins, and contention is unmeasured. One env-only switch, `CC_SUGGEST`, covers all six, with no `/config` row and no per-plugin switch. | The user cannot keep one suggestion and drop another |
| Kit copies | 13 copies of `cc-kit.ts`, held identical by `pc_mod_kit`, and 7 more pasted `hostOf` blocks (gated as `mod-host-block-drift`) because the kit does not export `hostOf`. | Any kit edit bumps 13 plugin versions. Exporting `hostOf` would delete 7 pasted copies |
| Index parsers | The card-index table is parsed by `announce.sh`, task-runner `suggest.ts`, `board-core.ts` and prompt-coach `coach-core.ts`; the comments in each name the others. | A change to the index format has 4 readers to update, and only comments link them |

## Decisions for the owner

1. prompt-coach: rework (drop the mascot, add an outcome ledger, measure) or remove?
2. session-hud: keep beside your own `statusline.py`, trim to the pane and subagent rows, or remove?
3. Remove the near-dead features: skill-router `listing.ts`, taskmaster `suggest.ts`, testing `suggest.ts` (or fix the last one)?
4. Board pane: keep the pane, or keep only the status line?
5. Build an outcome counter (`$.state` or a local JSONL) before deciding the remaining suggestion mods?

## Decisions taken (2026-10-25, owner)

| Decision | What changed |
|---|---|
| prompt-coach: rework | Mascot cut; per-flag outcome counts (`coach.*`) added; prompt-coach 0.6.0. The one measurement: `rationale/2026-10-25-prompt-coach-judge.md` (0/36 clear runs dropped, 24/27 unclear; Haiku 5.5 first pass answers, median 1.16 s) |
| session-hud: trim | Hint line and turn line off by default; `/hud` pane and subagent rows stay on; session-hud 0.2.0 |
| Cut list: "decide on merit" | skill-router `listing.ts` removed (0.27.0); taskmaster `suggest.ts` removed (0.50.0); testing `suggest.ts` fixed, not removed (0.14.0): every main-loop call but a read-only tool or a test run now counts as a change |
| Kit | `hostOf` exported (7 pasted copies deleted, `templates/mods/host-block.ts` removed, `pc_mod_kit` now fails a paste as `mod-host-paste`); `stateRoot` remembered per host object; `countOutcome` added |
| Throttles | Board: idle (no run, no pane) skips subagent calls and refreshes a main-loop call at most every 2 s, plus each turn end; during a run it still refreshes on every call, subagents' included, because the mid-turn card update is a documented feature its tests pin. Overseer: refreshes only after main-loop Bash/Write/Edit/MultiEdit. Candor badge: only after main-loop Bash |
| pins | pnpm and yarn lockfiles, composer installed.json / composer.lock and composer stamps (stack-scan 0.14.0) |
| Outcome counter | Counts only, in each plugin's own `$.store` key `outcomes` (`~/.claude/plugins/store/<plugin>_<marketplace>-<hash>.json`, location measured with a probe plugin on CLI 2.1.310); `scripts/mod-outcomes.sh` prints them with accepted-of-shown per suggestion |

The board change departs from the option text the owner picked ("skip subagent calls"):
subagent calls are skipped only while the board is idle, for the reason in the table.
