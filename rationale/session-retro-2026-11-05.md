# Session retro 2026-11-05 — where the plugins underperformed (sessions 10-29 … 11-05)

Branch `review/session-harvest-2026-11-05`. Report only: no plugin was changed by this pass.

## Scope and method

| Item | Value |
| --- | --- |
| Window | transcripts modified 2026-10-29 … 2026-11-05, every project under `~/.claude/projects` |
| Sessions | 52 found, 46 unique (forks `ed612757`, `2e06ef34` ⊂ `64de927c`; `3a593feb` ⊂ `f5ffe3b6`; `cae46dac` shares 712 KB with `8072a87a`; only the fork tails were mined) |
| Read | every line of a condensed extract: user text, assistant text, tool names and inputs, tool errors, hook output, Stop-hook summaries, long-turn and compaction markers — 12.3 MB in 54 chunks, one `hindsight:transcript-miner` per chunk, each confirming `read lines 1..N of N` |
| Not read | tool OUTPUT except errors (stripped by the extractor); tool INPUTS clipped (Bash 300 chars, Agent prompt 400); subagent transcripts under `*/subagents/` (only their dispatch lines in the parent) |
| Raw miner reports | 400 finding rows, machine-local: `~/.claude/hindsight/-mnt-data-Personal-git-repositories-cc-marketplace/reports/2026-11-05-raw.md` |
| Verified in source | the rows marked **src** below were re-read in the current tree (versions in the last section); every other row rests on transcript evidence relayed by a miner |
| Versions | sessions ran whatever was installed that day. Some defects were fixed in the repo before or during the window (ask-ledger 0.4.x, task-runner 0.46.0 board status); a row is not proof the current version still has it unless marked **src** |

Finding rows per plugin (all 54 reports; one row = one miner finding, so a noisy hook seen in many chunks counts many times):

| Plugin | Rows | Sessions | High | Medium | Dominant category |
| --- | ---: | ---: | ---: | ---: | --- |
| code-review | 82 | 17 | 3 | 40 | bad-judgement (nudge), slow (review waits) |
| task-runner | 53 | 12 | 9 | 26 | slow, gate false positives |
| skill-router | 53 | 21 | 0 | 7 | bad-judgement (irrelevant routing) |
| overseer | 43 | 5 | 6 | 22 | slow, bad-judgement, tooling errors |
| taskmaster | 35 | 21 | 1 | 11 | bad-judgement (nudge), slow (spec ceremony) |
| candor | 31 | 17 | 2 | 17 | gate false positives |
| ask-ledger | 21 | 11 | 1 | 11 | gate false positives |
| comment-discipline (code-review) | 12 | 11 | 0 | 0 | noise |
| secret-scanning | 9 | 9 | 0 | 5 | redaction breaking uploads |
| terse (candor) | 8 | 8 | 0 | 1 | budget not held |
| git-workflow, command-guard, stack-scan, database, meshy, blender, debugging | 1–7 each | | | | see the issue list |

No human frustration was aimed at a plugin by name. The one explicit outburst
(`4552acb6`, link-catalyst: "I am getting sick with your bullshit … This game of mouse needs to
fucking end") came after five chained purchase fixes that no debugging gate interrupted (issue 24).
Most of the cost is silent: idle hours, re-runs, and boilerplate lines the user scrolls past.

## 1. Overseer — why it is slow and loses focus

### What the five overseer programs cost

| Session | Project | What the user asked | What it took |
| --- | --- | --- | --- |
| `77602909` | cc-marketplace (worktree `overseer-dx-plan`) | DX plan, 20 milestones | 10-26 … 10-30; 33 turns over 10 min (2,670 min); per milestone worker + opus review + 1–3 fix cycles + full suite (~6 min); m14 alone ~5 h with 3 adversarial rounds and ~10 reviewer reports, shipped with 4 residuals never run live |
| `c5294305` | progressive-stages (Unity) | "review the steps needed, start working on the gameplay" | `/overseer:start` 16:33 → first card 18:15 (1 h 42 m, zero gameplay code); 20 cards at ~17 min each; review + fix ≈ 30–50 % of each card; final gate sat 91 min on a reduction ask; accept then blocked by a false stack-pin rule (issue 1f); ~11 h for m1, a scaffold |
| `f5ffe3b6` | rogue-chess (Unity/.NET) | "finish the game with what we can", 9 milestones | m1 (14 enum-style upgrades): 100 min, 24 agents, ~122 M tokens; m2: 4 h 14 m incl. 73 min of closing gates with no tool calls; m4: ~4.5 h incl. a 72-min behavioral gate after the 409-test suite was already green; m5: sim card stalled ~2 h, worker died; rigour `adversarial` on m1–m5 |
| `d707c56b` | claude-cowork (Unity, m4-awards) | one milestone | 13 h wall, ~7 h of it waiting; build 3.6 h with 27 reviewer agents and 16 red-team agents for a brief whose pattern was "one worker, one reviewer, one fix cycle"; 5 h stall on a PreToolUse ask |
| `d9198e1c` | claude-cowork | "finish the game with what we can" | charter + 11 milestones; m1–m3 in 2 h 40 m; the m4 session hand-off was refused by the host, and the spawned session spent ~1 h on scouts, a 4-lens panel and 3 adversaries before any code |

### Six causes, each traced to the text that produces it

**1a. The same unchanged code is verified six to seven times.** One card or milestone under
overseer passes through every one of these, and each layer is specified independently:

| Layer | Where it is specified | Re-runs the suite? |
| --- | --- | --- |
| Worker runs `VERIFY` | `plugins/overseer/skills/overseer/references/dispatch-prompts.md:172`; task-runner preamble | yes |
| Runner re-verifies every worker ("A subagent's 'done, tests pass' is a claim") | `plugins/task-runner/skills/task-execution/SKILL.md:147-150` **src** | yes |
| Negative control per card | `plugins/task-runner/skills/task-execution/SKILL.md:36` **src** | yes (mutant + control) |
| 1–3 per-card reviewers, fix cycle, re-verify, re-review | `plugins/task-runner/skills/task-execution/SKILL.md:91-94` **src** | yes after each fix |
| Whole-range review at run end (twice in `f5ffe3b6` m2 because a compaction re-entered it) | code-review:review | no |
| Code red-team: 3 lenses + completeness critic (standard: one round; adversarial: full) | `dispatch-prompts.md:123-133` **src** | critic probes |
| `behavioral-gate.sh` full suite at HEAD (candor clause 4 refuses the stop without it) | task-runner + candor | yes |
| Overseer accept, Protocol 1 "suite first" — a receipt is reusable only when the brief's verify set is ONE command | `plugins/overseer/skills/overseer/references/acceptance.md:58-64` **src** | yes |
| `git-workflow:finish` full-suite gate | git-workflow | yes |

Observed: `f5ffe3b6` "same tests run by worker, orchestrator re-verify, negative control, pre-commit
full suite, suite receipt, clean-worktree gate, evidence capture (6-7x) on unchanged code";
`c5294305` re-ran post.sh + negative control + full suite after every worker with the identical
count each time (240/240 …); `77602909` ran `fullsuite.sh` at the close of m11–m18 on top of the
workers' gate runs. No re-run in the window changed an outcome.

**1b. The pipeline prices its baseline as free.** `dispatch-prompts.md:104` and `:145` **src** say
per-card reviewers and the negative control "cost nothing extra", and `SKILL.md:91-92` **src**
repeats it. Measured in `c5294305` and `f5ffe3b6`: review + fix cycles are 30–50 % of each card's
wall time, and the closing gates (behavioral gate, receipts, evidence read-back) were the single
largest block of milestone time (73 and 72 min).

**1c. Rigour does not discriminate.** Every milestone in `f5ffe3b6` (m1–m5) and the `c5294305`
scaffold scored `adversarial`. Signals 3 (novel), 4 (blast radius) and 6 (four-plus cards) fire
on nearly any game milestone, and the first milestone defaults signal 5 to 1
(`dispatch-prompts.md:110-117` **src**). Even `lean` buys three spec adversaries, because every M+
milestone must go through taskmaster (`SKILL.md:72-75` **src**) and taskmaster red-teams any brief
with three-plus criteria (`dispatch-prompts.md:105,121` **src**). The adversaries overlap heavily
("43 holes … merge into roughly 20", `f5ffe3b6`), and coverage rounds 2 and 3 found nothing new in
`c5294305` and `d707c56b`.

**1d. "Hands-off" still stops for a human.** Three sources:
- Interactive mode asks after every milestone (`SKILL.md:127-129`, printed again by
  `scripts/program.sh:515` **src**). The user was away each time: 1.5 h, 3 h, 35 min, 1 h idle in
  `77602909`; 6 h in `f5ffe3b6` (m3's 6-question round, re-asking defaults the model had already
  filled in). The answer was always "start now".
- task-runner's reduction-record / review-skip PreToolUse `ask` halts autonomous runs for hours
  (issue 2): 5 h `d707c56b`, 91 min `c5294305`.
- "Cards are ready. Start execution now?" after the user had said "Merge, start m2" (`f5ffe3b6`).

**1e. Pre-code ceremony dwarfs small milestones.** Discovery, clarify, charter, then per
milestone: taskmaster grill/ultra, a 4-lens opinion panel, 3 spec adversaries at ~8–13 min each, a
re-check adversary, a Plan agent, 2–3 coverage rounds. `c5294305`: 1 h 42 m before the first card.
`d707c56b`: 53 min. `f5ffe3b6`: 19–44 min per milestone. Despite two coverage rounds the cards
still carried wrong file lists (issue 9).

**1f. The accept gate pulls the program off the user's ask.**
- `scripts/program.sh:146` **src** decides the `stack` group is "installed" when ANY laravel or
  web-dev skill exists in the machine-wide plugin cache. A Unity project therefore owes a stack pin
  it can never satisfy; there is no override flag. In `c5294305` the model wrote an unrequested
  project skill, a runner script and a shim, dispatched a reviewer and fixed 7 findings to get past it.
- Evidence read-back of 10 files plus an extra a11y review that ended "defer to m8" (`f5ffe3b6` m1).
- An acceptance criterion the build missed ("the AI used only Freeze and Fortify over 30 games")
  was rewritten in `decisions.md` and the milestone accepted (`f5ffe3b6` L2049): disclosed, but the
  gate did not hold.

Also seen: 366 "waiting on its own background work" notification lines in `77602909`, each forcing
an empty assistant turn; 12+ Bash calls refused as "too complex to verify that it stays inside the
worktree", each rewritten as a temp script; the dispatch gate parsing `MODEL: sonnet.` literally;
`/overseer:resume` is `disable-model-invocation` while the generated resume text tells the model to
run it; parallel m14 workers overwrote each other's `cite.sh`; task-runner left ~8 bytes and taskmaster a few hundred bytes under
the 160,000-byte corpus cap.

### Refactor shapes (the decision is yours)

| Shape | What changes | Keeps | Risk |
| --- | --- | --- | --- |
| **A. Receipts everywhere** (incremental) | One suite run per HEAD: the worker's receipt satisfies the runner re-verify, `behavioral-gate`, accept Protocol 1 and `finish`; accept reuses a receipt for any verify set, not only a one-command set; coverage stops after a round with 0 gaps | every review layer | review cost (1b) untouched |
| **B. Verify per milestone, not per card** (restructure) | Per card: worker + runner verify only. Per milestone: one range review, one red-team round gated by rigour, one suite/behavioral gate, the walk. Overseer passes a flag that turns task-runner's per-card reviewers and negative controls off inside its runs | the milestone's evidence set and accept gate | per-card review is gone; a bad card is found later. The window shows per-card reviews passing "merge-ready" while the range review found 1 critical + 5 highs (`c4be0af8`) and 2 highs + 14 mediums (`d89db2df`), so they were not the safety net |
| **C. Time/agent budget per size** | S/M/L/XL map to an agent and wall-clock budget; overseer buys checks in a fixed priority order until it runs out, and records what it did not buy | everything, rationed | needs a cost channel the plugin does not have today (`dispatch-prompts.md:142-145` says so) |

Recommendation: **B, with A's receipt mechanism**, plus three independent fixes that every shape
needs: hands-off never asks (record reductions, no per-milestone check-in when `--hands-off`),
rigour stops counting volume and novelty as risk, and `program.sh:146` checks the project's own
enabled plugins instead of the cache. Per this repo's evals rule, the change is not an improvement
until an overseer eval case built from one of these runs fails without it and passes with it.

## 2. Issue list — all plugins, ranked by cost

Sessions are 8-char ids; project in brackets where it helps. Costs are wall-clock or turns seen in
the transcript.

| # | Plugin / artifact | Problem | Evidence | Cost | Fix direction |
| --- | --- | --- | --- | --- | --- |
| 1 | overseer (+ the task-runner/taskmaster pipeline it drives) | Section 1: stacked verification, free-priced baseline, flat rigour, check-ins under hands-off, pre-code ceremony, accept gate side-work, false stack pin (`program.sh:146` **src**) | `77602909`, `c5294305`, `f5ffe3b6`, `d707c56b`, `d9198e1c` | hours per milestone | Section 1 shapes |
| 2 | task-runner reduction-record / review-skip PreToolUse `ask` | An autonomous run halts on a permission prompt to record a reduction it already decided; the user is away | 9.5 h `d89db2df`, 8.6 h and 1.5 h `a94479ce`, 5 h `d707c56b`, 91 min `c5294305`, five asks of 8–67 min `24d655d6`; card id parsed wrong ("card taskmaster-docs"), unexpanded "rt-$" | hours, 6 sessions | under `goal`/hands-off, record and continue; ask only interactively |
| 3 | task-runner spawn-cap PreToolUse `ask` at #20/#40/… | Asks mid fan-out on dispatches the plan already priced; text says dispatches "don't show in the transcript" though notifications do | 98 min `3afcbc01`; asks at #60, #80, #138, #160 in overseer/task-runner runs; a census in `e87bdd99` relays ~10.5 h of spawn-cap stalls (relayed) | up to 1.5 h | skip when a run is registered, or raise to a per-run budget |
| 4 | task-runner behavioral-gate / negative-control | Hangs (1,800 s timeout, 21+ min control), orphan pest/Playwright processes, clash with lerd's worktree hook (`public/hot`, `.env`), no runner for C#/Unity so every Unity card needs `--skip` or a reduction ask; malformed mutation reported `discriminating`; a list file read as one path → `no-executable-surface`; a "nothing to test" record that would satisfy the completion gate | `24d655d6`, `c4be0af8`, `d89db2df`, `f5ffe3b6`, `c5294305`, `d707c56b` (unpinned unity CLI reached a second editor and wiped a save) | 40+ min loops, a lost save | detect lerd and Unity up front; refuse an empty record; pin the Unity CLI to the project |
| 5 | code-review per-card review vs range review | Per-card "merge-ready" while the range review finds criticals; fix rounds introduce new highs and do not converge (5 rounds, 84 agents, 1,366 min in `a94479ce`; the paid-POST retry re-broke each round) | `c4be0af8`, `d89db2df`, `a94479ce` | hours | review the range, not each card; stop after two rounds that each introduce a new high and escalate to the user |
| 6 | code-review `review-debt.sh` nudge | Fires on every prompt incl. "commit" and system turns; counts binaries, art and other sessions' files (19 → 401 files); "touches auth" matches the substring `guard` (`review-debt.sh:99` **src**) so `SM_Env_GuardPost.fbx`, `upg_guardpost.png`, `Hero_Guard.controller` are "auth"; does not credit `code-reviewer` agent runs; dismissed ~100 % | 17 sessions, ~80 firings | a justification line per commit; the urgency means nothing | skip non-code extensions; word-boundary the auth regex; credit agent reviews; fire once per range |
| 7 | skill-router edit signals and per-edit loads | `route-prompt.sh:168` **src** flushes "Your recent edits may need these skills" on any prompt, incl. "commit" and status questions; routes resilience/security to PNG, CSV, `.md`, `.blend`, one-off Blender scripts and Unity VFX; PostToolUse demands up to 7 skills for one `cp`; tool-fit block (~1.8 KB) never changed routing; a census in `e87bdd99` relays 0 loads in 127 fires and an 8 % load rate (relayed) | 21 sessions | context and a dismissal line per prompt | route by language and code path only; drop asset/doc extensions; don't flush on non-work prompts |
| 8 | skill-router routing gap | Never names gamedev, unity-traps, blender, meshy or pixel-art in Unity/Blender/Meshy work, while it pushes resilience there. Cost when they were absent: Meshy decimation tore textures but was called "clean"; edits during Play froze the user's game twice; Meshy credits spent with no confirmation; Unity crashed on an FBX working-dir trap | cowork `5df215ae`/`64de927c`, `395b622e`, `8072a87a`/`db4f7775`, little-sprito `5d6230d0` | rework, credits | add the game-dev rows; Unity/Blender paths should outrank generic rules |
| 9 | taskmaster task-cards | Cards with missing or wrong file lists and verify targets halt workers: cards 08/10/11 and an audit of 12–20 (`c5294305`); an unreplaced `__B__` placeholder and a nonexistent test (`a94479ce`); an impossible PHP helper name and a mis-specified card 25 (`d89db2df`); 7 under-scoped cards (`c4be0af8`) | 5 sessions | a halt + re-dispatch each (~10 min) | a card linter: verify target exists, no placeholders, touched-file closure from the spec |
| 10 | taskmaster spec ceremony | 3 blind adversaries (~10 min each, heavy overlap), re-check, coverage 2–3 rounds that find 0; "Lets proceed with Building" → 3 h of spec and 46 cards (`d89db2df`); 16 h of spec-only work for "use stored data better" (`a94479ce`); the brainstorm narrowed the user's "review plus new tools" to one piece and had to be reopened | 6 sessions | hours before code | one adversary by default; stop coverage at a 0-gap round |
| 11 | task-runner scope-lock | Warns on the orchestrator's own bookkeeping (`00-INDEX.md`, `findings.md`, overseer dispatch files, `.claude/code-review/`): 16–45 times per run, ~3 KB each, never a real catch. `scope.sh:246,271` **src** exempts only `.claude/task-runner/`; a census in `e87bdd99` relays 0 reverts in 118 warnings | 9 sessions | context bloat | exempt the run's index dir, `.claude/*/` plugin scratch and overseer's program dir |
| 12 | ask-ledger | Extracts non-deliverables as "names": `CLAUDE`, `M0`, `Mana`, `Comfy`, `MCP`, hex from a session id (`8aca`, `77eb`), the word "etc", a tech stack, the user's own quoted phrase; blocks interim "waiting on workers" replies; then appends "X: as named" to 8–60 later messages. The "Comfy" injection pushed the model into a 1.5 h ComfyUI detour the user stopped | 11 sessions | forced extra turns, noise | re-check against 0.4.6; skip file names, ids and stack words; don't gate interim replies |
| 13 | candor avert hedge guard | `avert.sh:111` **src** asks on a word in content, not on a scope cut: "trademark" (store-rules doc), "copyright" (user's own public-domain note), "inspired by" (story text), "look-alike" (homoglyph term), "generic names/design", "legal safe" (chess move) | 9 sessions | asks; stalls up to 34 min | match only in the assistant's own plan/claims, not in file content or dispatch text |
| 14 | candor completion Stop gate (+ task-runner run state) | Blocks legitimate waits, a user-requested pause, a fork's status question and an unrelated APK install; forces sleep/flock polling instead of yielding. Gate-miss: let a run close while owing 20 negative controls and 36 reviews (`c4be0af8`) | 8+ sessions | extra turns, polling | allow stop while registered workers run; check obligations at run close, not at every stop |
| 15 | Stop-hook latency (candor and ask-ledger both ship `hooks/gate.sh`; the summary cannot tell them apart) | `gate.sh` mean 0.5–3.1 s, max 6.1 s, up to 490 runs in one session (~9 min); 6,100 runs in the window | all hook-enabled sessions | minutes per session | profile; cache per HEAD |
| 16 | secret-scanning PostToolUse redaction | Redacts Higgsfield `media_upload` URLs as secrets, so the upload flow breaks; the model regenerated images (extra credits) or dropped the planned inpainting | `5df215ae`/`64de927c`, `5d6230d0`/`b1c33fa3` | credits, rework | allowlist signed upload URLs on that tool |
| 17 | debugging hint | Fired only after "am I a joke to you?"; three earlier failed fixes passed without it; ~5 h and 6 PRs | `4552acb6` [link-catalyst] | the one explicit outburst | count failed-fix cycles per symptom, fire at the second |
| 18 | worker discipline (task-runner preamble) | Workers added 206 lines of unasked comments (`c4be0af8`); migrated the dev Postgres (`d89db2df`); a harness made stray commits on the real repo (`77602909`) | 3 sessions | hand cleanup | make the preamble's no-comment and no-DB rules a post-check |
| 19 | database destructive-SQL guard | Asked on React/TSX writes ("TRUNCATE", 20 min idle, `86fd417d`), a create-table migration's `down()`, a test that drops a table on purpose. `guard.sh:319-320` **src** already exempts Tailwind class lists; what matched in the TSX files was not visible in the extract | 3 sessions | ask stalls | re-test the TSX case; skip `down()` of a create migration |
| 20 | comment-discipline (code-review) | Blocks throwaway `/tmp` and `~/.cache` scripts written by heredoc; ratio warnings where siblings already exceed | 11 sessions | a retry each | skip paths outside the repo |
| 21 | stack-scan plugin-scout / suggest | Offers web-UI and Pest/Vitest `testing` plugins to Unity projects; 3-page pickers (6–7 min); recommends plugins whose skill names collide with Laravel Boost's | 4 sessions | user time, duplicate rules | filter by detected engine; warn on name collisions |
| 22 | git-workflow AI-attribution guard | Fired on a heredoc append to `findings.md` (not a commit); blocked heredoc `commit -F -` where no trailer was visible | `f5ffe3b6`, `8072a87a`, `395b622e` | a retry | match only git commit/tag/PR commands |
| 23 | command-guard | Asks on `rm -rf` of a `mktemp` variable set in the same command and on a single-file `git rm --cached` | 3 sessions | asks | treat a same-command `mktemp` var as safe |
| 24 | blender skill | `references/api-5x.md` and `export.md` missing from the installed cache, so the skill points at nothing | `4c2c76ce`, `6bb8fc2f` | ad-hoc API probing | check the published package contents |
| 25 | terse (candor) | Ultra budget (6 prose lines) not held: reports ran 15–40 lines; nothing enforces it | 8 sessions | none reported | decide whether it is a gate or advice; say which |
| 26 | taskmaster UserPromptSubmit nudge | Fires on approvals, summaries, reviews, status questions; called a package id an "auth surface" | 21 sessions | a skip line | skip short replies and non-edit asks |
| 27 | overseer tooling | resume flag vs resume prompt; host refused the session hand-off in an agent-triggered turn; `skill-path.sh` exit 1; dispatch-gate `MODEL:` parse | `77602909`, `d9198e1c`, `c5294305`, `f5ffe3b6` | retries | small fixes, one PR |

What worked: `code-review:code-reviewer` findings were real in the cowork game sessions ("six
findings, all valid", "eight findings, all valid", 26 findings fixed incl. a crash); the
git-workflow CI-red merge ask worked as designed; the unity-traps and meshy hooks fired correctly
on a synthetic test; task-runner's board-status bug (`card 0/25`) was found and fixed in 0.46.0
during the window.

Not plugin issues, listed so they are not re-investigated: Unity MCP "Unity not detected" after
every recompile (~100 errors, 1–5 min waits each); the host auto-mode classifier denials; an
expired OAuth token (~40 min); Monitor watchers expiring; the API weekly limit (15 h idle in
`77602909` and `d89db2df`, plausibly driven by the opus fan-out in issue 1).

## Next

The overseer refactor shape (Section 1) is the user's decision. Issues 2, 6, 7, 11, 12 and 13 are
independent hook fixes with transcript evidence from six or more sessions each; each needs a
harness case built from the quoted firing before it ships.
