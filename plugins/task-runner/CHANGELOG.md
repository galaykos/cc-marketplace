# Changelog

All notable changes to the task-runner plugin.

## 0.39.0 — 2026-09-23

### Changed
- **Card readers accept taskmaster's role-tagged card shape.** The routing reference
  reads the worker tag from `<agent>` and the skills to prime from `<skill name="…"/>`
  elements; delegation-contracts' skill-priming rule and task-execution's ordering rule
  name the same elements. A legacy bold-label card (`**Agent:**`, `Skills to apply`,
  `Depends on`) is still read — the acceptance is for in-flight card sets, not a second
  template. Why the shape changed, and the measurement showing it changes nothing on the
  READING side: taskmaster's `skills/task-cards/references/card-shape.md`.

## 0.38.0 — 2026-09-22

### Added
- **`scripts/behavioral-gate.sh` resolves a runner for PHP, Rust, Ruby and Java/Kotlin**,
  and takes `--runner '<cmd>::<empty-output-regex>'` (repeatable) for anything else.
  Before this the classifier knew `py`/`js`/`go`: every other language fell to
  `HAS_OPAQUE=1` → `no-behavioral-coverage` → exit 2, with no flag to escape, and candor's
  Stop gate then refused every close — a gate that could not be passed rather than a rule
  that could be followed. Driven against REAL toolchains on 2026-09-22 (PHPUnit 13.3.1,
  cargo 1.98.1, rspec 3.13.6, Gradle 9.7.1): four green-suite fixtures went EXIT=2 → EXIT=0,
  and four fixtures whose runner executes zero tests still exit 2. Empty-detection per
  runner is in `skills/behavioral-gate/references/runners.md`; 16 harness cases pin it.
  Two things the Java row states rather than hides: `--rerun-tasks` is required because
  the gate runs from a copied checkout carrying `build/`, where a plain `gradle test`
  reports `:test UP-TO-DATE` and executes nothing (→ `unverifiable-suite`, never a pass);
  and a green `gradle test` prints no counts at all, so that one path falls back to
  "test sources exist and the task did not fail" — weaker than every other row.
  `--runner`'s residual is the caller's: a regex that never matches turns an empty suite
  green and nothing in the script can tell. The gate still owns the two failures a
  declaration cannot paper over — a command that never started (126/127/signal) and one
  that hung (124).

### Changed
- **`hooks/scope.sh` enforces the union of every `scope*.json`**, not just the fixed
  `scope.json`. `task-execution/references/routing.md` writes one `scope-<cardId>.json`
  per delegated or tracked card, so the path the plugin sells was scope-locked by prose
  only: with per-card files present and no `scope.json`, the hook was silent on every
  edit. Union rather than per-file because the payload carries a path and not a card id.
  Residuals now in the header: a worker in another WORKTREE never reaches this hook at
  all, a stale card file widens the union rather than narrowing it, and one malformed
  member disarms the whole call (a partial union would warn about a path the file it
  could not parse had allowed). Nine harness cases.
- `commands/run.md` names `--runner` in the completion-gate invocation and the seven
  languages the gate resolves on its own.

### Fixed
- **`hooks/ultra-assess.sh` starts `#!/bin/bash`, not `#!/usr/bin/env bash`.** The absolute
  interpreter is what makes the fail-open claim in the hook's own header true under a
  stripped PATH, where `/usr/bin/env bash` exits 127 and the host reads the miss as an
  allow. Rendered from `templates/boost-hook.sh.tmpl`, not edited here; `pc_hook_shebang`
  reads the claim back and fails the build now that every shipped hook agrees with it.
- **`hooks/drift.sh` validates the payload `cwd` with `[ -d ]` before `mkdir -p`.** It
  did not, and recreated a project directory the user had just deleted, four levels deep
  — reproduced against the committed hook. The state dir is now anchored at
  `git rev-parse --show-toplevel` when there is one (pattern:
  `overseer/hooks/track-read.sh`). Residual: a cwd that IS a directory but not this
  project's still gets state — the check proves existence, never identity.

## 0.37.0 — 2026-09-22

### Added
- `hooks/announce.sh` (SessionStart, matcher `startup|resume|clear`): one line when the
  project has a registered run — slug, branch, how many index cards are still open, and
  the declared arc phase. `active-run.json` outlives the session that wrote it while the
  model's knowledge of it does not, so a cold session met candor's Stop block at the end
  of its first turn with no idea what the run was, and the cheapest-looking escape was
  deleting a live run's sentinel. Standing: advisory — SessionStart context informs a
  turn and cannot block one; the teeth remain the Stop gate. Pure read, silent with no
  run registered (so the always-on and activated context budgets read 0), and compaction
  is left to skill-router's capsule. Pinned by `scripts/__tests__/announce-hook.test.sh`.

### Fixed
- `commands/run.md` step 1 pre-created `rv/`, `rt/`, `bg/` and `reductions/` but not
  `nc/`, and `negative-control.sh` only creates it lazily on the first control that
  actually runs — so a run that skipped its first control left candor's gate on its
  "no `nc/` dir → legacy allow" path and the per-card negative-control count never armed.
- `skills/code-redteam/SKILL.md` named `plugins/task-runner/scripts/code-redteam-diff.sh`,
  a repo-relative path that does not exist on an installer's disk; now
  `${CLAUDE_PLUGIN_ROOT}/scripts/`.
- `commands/plan.md` read `$ARGUMENTS` with no `argument-hint` frontmatter.

## 0.36.6 — 2026-09-22

### Fixed
- `agents/task-executor.md` told every worker to write the fixed `scope.json`, which
  parallel workers clobber and which `routing.md` reserves for the inline tripwire; it
  now writes `scope-<task-id>.json` and says the hook does not read it.
- `track-orchestration/SKILL.md` cited `references/reviewer-routing.md`, a file that
  lives under `task-execution/references/`; path corrected.

## 0.36.5 — 2026-09-18

### Changed
- `delegation-contracts/references/discipline-preamble.md` clause 2: an exit code is evidence
  only if captured — the Bash tool may run zsh, where `${PIPESTATUS[0]}` is empty (two of three
  workers wrote it on 2026-09-18 and reported statuses they never saw). Clause 4: blaming an
  out-of-set file for a failed check requires the output line naming it. The `SKILL.md`
  evidence section says which report the orchestrator always doubts
  (`rationale/fable-distillation-2026-09-18.md`).

## 0.36.4

### Fixed
- `lane.tsv`'s `spawn-cap` trigger said "an Agent dispatch". `hooks/spawn-cap.sh:45`
  matches `Agent|Task` and `hooks/hooks.json` registers the same matcher, so the row
  understated the hook it describes — the row 0.36.3 rewrote to "say what the hook
  does" got the threshold right (one soft cap, then every doubling) and the tool set
  wrong. Regression review, 2026-09-17.

## 0.36.3

### Changed
- Marketplace trend audit, 2026-09-16 (`rationale/marketplace-trend-audit-2026-09-16.md`).
  B4: the README said `scope.sh` "enforces" a card's file list; `hooks/scope.sh` warns, once
  per edit outside the set, and never blocks — the README now says so. G12: `lane.tsv`'s
  `spawn-cap` trigger claimed a per-run budget of "20/40/80 by tier"; the hook counts per
  session against one soft cap (20) and then every doubling, no tiers, and the lane row now
  says what the hook does. C3: the README gains one boundary sentence each on the host's
  built-in `/run` (launches the project's app; unrelated to `/task-runner:run`) and `/batch`
  (one background subagent per worktree, PR each; `--tracks` keeps the sole-writer merge
  rule). D1: `behavioral-gate` carries `disable-model-invocation: true` — every consumer
  runs `scripts/behavioral-gate.sh` and nothing loads the skill by description, so its
  description no longer sits in always-on context. D5: `code-redteam`'s description leads
  with its gating clause (a boosted task-runner run only; an ad-hoc diff →
  `/code-review:review`) so an ordinary "red-team this diff" prompt no longer matches it.
  `commands/run.md` gains a `<!-- host-ok -->` line for the name it shares with the host's
  `/run`.

## 0.36.2

### Fixed
- `drift.sh`'s header said `CC_REMIND=off` silences "every advisory nudge here"; `scope.sh`, the run-scoped tripwire, reads no switch by design. The header now says which hooks the switch covers and that the tripwire is not among them.

## 0.36.1

### Changed
- **A boosted run now fans out on the Agent tool, not only on `Workflow`.** 0.35.1 fixed
  this in `verification-panels` and left it wrong in the two files that consume it plus the
  boost hook's own injected directive: `code-redteam`, `references/ultra-assess.md` and
  `.chassis.json` all keyed the uncorroborated inline fallback on the `Workflow` tool being
  absent. `Workflow` needs an explicit `ultracode` opt-in, so in an ordinary interactive
  session it usually IS absent — which meant the commonest way to invoke `ultra-assess` or a
  boosted red-team silently downgraded to one single-model pass while `verification-panels`
  said, correctly, to spawn the real panel through the Agent tool. The trigger is now what
  that skill already owned: no dispatch mechanism **at all**. Re-run
  `scripts/generate.sh --write` — `hooks/ultra-assess.sh` renders from the manifest.
- **`spawn-cap` is documented.** 0.35.0 shipped a `PreToolUse` hook that puts a permission
  prompt in front of subagent dispatch #20 and named it in no README, no description and no
  skill, so the first visible sign of it was an unexplained prompt mid-fan-out with no
  discoverable off switch. The README now states the thresholds, what it cannot see, and
  `CC_SPAWN_CAP`.
- `scripts/reduction-record.sh` accepts five `--kind` values (`redteam`, `dispatch`, `suite`,
  `coverage`, `other`); the README named the narrowed-suite case in prose while the only flag
  list on offer showed two of them.

### Fixed
- **`isolation-halt` was never a string the script prints.** Four files listed it beside
  `discriminating` / `vacuous` / `invalid-control` as if all four were stdout verdicts.
  The first three are echoed on stdout; `negative-control.sh`'s exit-5 path prints prose to
  **stderr with stdout empty**, and the token appears nowhere in the script — so a caller
  branching on stdout falls straight past its halt branch on the one result that must halt.
  All four sites now branch on the exit code, and `references/negative-control.md` says why.
- **A `--tracks` run could not stop clean.** The track-worker's negative-control invocation
  in `references/algorithm.md` omitted `--record-dir`/`--card`, so N done cards inside track
  leaves recorded zero controls and the completion gate refused the stop — the exact
  blocks-having-done-nothing-wrong failure that section's reviewer-record half exists to
  prevent. The record now goes to the MAIN repo's `nc/` by absolute path, because `.claude/`
  is gitignored and a worktree-local record merges nowhere.
- `references/negative-control.md`'s own copy-pasteable invocation dropped the two flags that
  write the record, so following it literally produced a control that ran and did not count.
- **The `task-executor` agent claimed "~40 chassis-generated `/…:review` commands" dispatch
  it without a discipline preamble.** One command in this marketplace is generated from
  `templates/review-command.md.tmpl`, and the commands that dispatch the executor are
  hand-written. The residual is real — none of them injects a preamble — so it now states
  that and gives the recount instead of a number.
- `delegation-contracts`' fleet-inventory table listed a11y, debugging and observability as
  having *neither* a worker nor a reviewer wired, long after all three shipped a worker
  agent — a stale table that would send a reader to build what already exists. Replaced by
  the decision it was for plus `ls plugins/*/agents/`.
- `role-floors.md` said "the seven above" over a six-row registry, and resolved `auto`
  through a taskmaster section heading that does not exist; both now point at this plugin's
  `verification-panels/references/dispatch-tier.md`, which owns the tier rule.
- `hooks/drift.sh` cited `scope.sh:32` for a guard that sits on line 40; `commands/run.md`
  said its two sentinels clear "at step 9" in a five-step procedure (they clear in step 4);
  `parallel-planning` said "this plugin's plugin's".

### Removed
- `scripts/_placeholder.sh`, which existed to reserve a directory that now holds seven
  shipped scripts.

## 0.35.1

### Fixed
- **`rv-consent`'s lane now declares `any`, not `build`.** It is armed by run state — a registered task-runner run whose reviewer verdict is unconsented — not by where you are in the arc, so a phase-specific claim was one no gate could check and no behaviour honoured. `pc_phase_guard` was widened the same day to cover deny-capable tool-channel hooks, which is what surfaced it.
- **`verification-panels` contradicted itself about when a panel is real.** One line keyed the inline fallback on the `Workflow` tool being absent, another correctly keyed it on whether N agents actually dispatched. The Agent tool is a real dispatch path, so the first line sent ordinary sessions to an uncorroborated single pass while `approach-deliberation` spawned the panel — the two disagreed on the same turn.

## 0.35.0

### Added
- **`spawn-cap`: an `ask` at 20 subagent dispatches, then at every doubling.**
  `scripts/turn-cost.sh` already states the fact this acts on — subagent turns do not
  appear in the transcript and they are billed — and nothing in this marketplace
  counted them, so a fan-out planned as three agents and grown to thirty was invisible
  until the invoice. `ask`, not `deny`: a large fan-out is sometimes right, and the
  claim is not that thirty is wrong but that thirty should be a decision. Thresholds
  double rather than firing every time, because asking at 21, 22, 23 trains reflexive
  approval, which is the same as not asking. It counts dispatches, not cost — twenty
  haiku calls and twenty opus calls are the same number here and not the same bill.
  `CC_SPAWN_CAP=<n>` moves the first threshold, `CC_SPAWN_CAP=off` disables it;
  `scripts/__tests__/spawn-cap.test.sh` drives 11 cases.

## 0.34.4

### Changed
- **`.claude/task-runner/` ignores itself.** The directory now writes a self-ignoring `.gitignore` (`*`) the first time a hook creates it. Plugin state under the user's `.claude/` showed up as untracked in `git status` in every repo without a hand-written ignore line — observed live, and named by overseer's acceptance protocol as "other plugins' scratch" — one `git add -A` away from being committed. One harness assertion per plugin. `hooks/scope.sh` and
  `hooks/drift.sh` drop the file as soon as they see the directory (a registered
  run's first edit), `scripts/review-skip.sh` and `scripts/reduction-record.sh` when
  a record lands under the default root (never under a `--record-dir` override), and
  `/task-runner:run` step 1 writes it at registration so a run interrupted before any
  hook fires leaves no untracked state either.
- A header comment in `hooks/drift.sh` no longer cites the removed `lean` plugin's hook.

## 0.34.3

### Changed
- `skills/task-execution/SKILL.md` and `skills/track-orchestration/SKILL.md` say whose
  gate "the completion gate" is: candor's clause 4, enforced only with candor installed.
  The README, `run.md` and `behavioral-gate` carried that condition since 0.33.0; the two
  bodies still read as an unconditional gate. `hooks/drift.sh`'s comment no longer cites
  the removed `lean` plugin as a live path. No behaviour change.

## 0.34.2

### Changed
- `plugin.json` description says what the README already said: the run-completion Stop
  gate is candor's clause 4 since 2026-09-14, so a by-name install without candor has no
  gate — the catalog and `/stack-scan:suggest` show the description, not the README.

## 0.34.1

### Changed
- `lane.tsv`: `/task-runner:plan` and `parallel-planning` declare the `plan` phase (the
  command yields to the skill); `behavioral-gate` declares `verify`. No behaviour change.

## 0.34.0

### Added
- **orchestration merged in** (2026-09-14 consolidation plan §3.1): the
  `delegation-contracts` and `verification-panels` skills with every reference
  (role-floors, discipline-preamble, fleet-and-apply, tree-wide-gates,
  dispatch-tier), `scripts/dispatch-lint.sh` with its harness, and the `ultra-assess`
  boost hook re-rendered from the boost-hook chassis as `task-runner:ultra-assess`
  (`ORCHESTRATION_BOOST` keeps its name). Every `orchestration:<skill>` citation in
  the marketplace now reads `task-runner:<skill>`; the role-floors resolution ladder
  probes this plugin's own root first. `lane.tsv` rows for both skills.

### Changed
- The `ultra-assess` skill body is `skills/verification-panels/references/ultra-assess.md`:
  the boost hook's directive names the path, so a listing entry was a second trigger
  for the same text.

### Removed
- Orchestration's review command. It reviewed prompts, not code; what it ran mechanically
  (`dispatch-lint.sh`) ships here, and its eight-point checklist is the
  delegation-contracts skill's own § Prompt contract.

## 0.33.0

### Removed
- `hooks/completion-gate.sh` and its `Stop` entry in `hooks/hooks.json`. The
  registered-run Stop gate is now clause 4 of candor's one Stop gate
  (`plugins/candor/hooks/gate.sh`): the same records check — gate pass for HEAD, card
  counts, per-card `nc/` and `rv/` coverage, `bg/` verdicts, red-team panel width,
  reduction disclosure — the same messages, the same `TASK_RUNNER_STOP_GATE` modes,
  the same per-HEAD nudge under `.claude/task-runner/`. Every writer of those records
  stays here (`run.md`, `rv-observe.sh`, `behavioral-gate.sh`, `review-skip.sh`,
  `reduction-record.sh`, `negative-control.sh`); only the Stop-time reader moved, and
  `scripts/smoke/completion-gate-hook-tests.sh` still drives the writers and the
  reader together. A run can end by narration if candor is not installed —
  process-suite and taskmaster-suite now carry it (2026-09-14 consolidation plan, §4.2).

## 0.32.0

### Added
- `Goal: true (boost=off)` — taskmaster's `goal-lean` marker. Hands-off autonomy (auto-take,
  run through, never merge) without the boost: no tier escalation, no code-redteam pass, and
  the completion gate owes no red-team panel. `boost-execution.md`, track-orchestration,
  code-redteam, the executor agent and `completion-gate.sh` read the suffix; an older
  runner reads a lone `Goal:` as boosted (overpays, never under-verifies). Smoke: a
  `boost=off` index with an empty panel is allowed.

## 0.31.6

### Changed
- Citations of the four-laws / has-teeth doctrine now point at
  `.claude/skills/authoring-skills/SKILL.md` in the marketplace repository — the
  authoring plugin was demoted to a tracked project skill on 2026-09-03. Prose only;
  no behaviour change.

## 0.31.5

### Changed
- **Worker agents default to no comment.** The "Code shape" section no longer says
  "match the surrounding file's comment density". The default is no comment; a comment
  is one line for a fact the code cannot show, a docblock that repeats the signature is
  deleted, and only a house style stated in the project's CLAUDE.md overrides it. The
  matching hooks (deny lanes and the 0.4:1 ceiling) ship in code-review.

## 0.31.4

### Changed
- `routing.md` and `reviewer-routing.md` resolve the `performance` and `observability`
  tags to resilience's workers and skills; both plugins merged into resilience on <!-- removed-ok -->
  2026-09-02.

## 0.31.3

### Changed
- The completion gate names `/api-design:drift`; api-docs-first merged into api-design <!-- removed-ok -->
  on 2026-09-02.

## 0.31.2

### Changed
- `reviewer-routing.md` primes `ui-ux:a11y-audit` for frontend and ui-ux cards; the a11y <!-- removed-ok -->
  plugin merged into ui-ux on 2026-09-02.

## 0.31.1

### Changed
- `reviewer-routing.md` primes `database:sql-best-practices` for database-tagged cards;
  the sql plugin merged into database on 2026-09-02. <!-- removed-ok -->

## 0.31.0

### Changed
- **`track-orchestration` names the harness as a second owner of `.claude/worktrees/`.**
  The cleanup guard already refused to touch worktrees outside this run's
  `<run-branch>-track-*` namespace, but it is one-directional — it stops the run
  touching someone else's trees, not the reverse. Claude Code's `EnterWorktree`
  creates trees in the same root and `ExitWorktree` prompts the user to keep or
  remove them at session exit, which can reach a live track worktree mid-run. The
  halt/handoff report now names the run's live track worktrees so that prompt is
  answerable.

## 0.30.1

### Changed
- **Meta-prose compressed to a one-line standing tag** (part of a marketplace-wide
  pass). No actionable rule changed; named cross-skill references preserved.

## 0.30.0

### Fixed
- **The scope lock no longer admits siblings that merely share a text prefix.** The
  allow-match was a raw `startswith`, so an entry was a prefix of arbitrarily many
  unrelated paths: `src/util.ts` admitted `src/util.tsx`, `src/api` admitted
  `src/apikeys.ts`, and a directory entry like `app/Models` admitted an entire
  parallel tree at `app/ModelsBackup/`. The lock reported nothing in every one of
  those cases — the near-miss paths a drifting edit actually produces. Matching is
  now equality or a true directory boundary (`$a + "/"`), with four boundary cases
  added to `scripts/__tests__/scope-hook.test.sh` (10 -> 14).

## 0.29.7

### Fixed
- **The run-start tier announcement is reachable again.** It is unconditional — every
  run announces its worker tier, boosted or not — but it had been displaced into
  `references/boost-execution.md`, whose own header reads "Read this when `00-INDEX.md`
  carries an `Ultra: true` or `Goal: true` marker. **On a standard run none of it
  applies.**" A rule for standard runs sat inside the one file that declares itself
  inapplicable to them, so a plain `/task-runner:run` had no reachable instruction to
  announce its tier while all four taskmaster commands carry their own.

## 0.29.6

### Changed
- **Every hook entry now declares a `timeout`.** `drift.sh` 5s, `rv-observe.sh` 5s, `scope.sh` 5s, `rv-consent.sh` 10s, `completion-gate.sh` 15s. Before this release the
  plugin expressed no opinion about how long its own hook may hold a turn and
  relied entirely on the host default; a hook that blocks — a slow network mount,
  a large transcript — stalled the user with no per-hook ceiling. Sizes are per
  script, not one house number: 5s for a jq-only classifier, 10s for git/find
  work, 15s where the script shells out to the network, a package manager or
  node. No hook logic changed.

## 0.29.5

### Fixed
- `task-execution/SKILL.md:66` cited "`references/role-floors.md`" unqualified,
  which reads as this skill's own `references/` dir — where no such file exists.
  The registry lives in `orchestration:delegation-contracts`. Every sibling <!-- removed-ok --> <!-- history: orchestration merged into task-runner 2026-09-14 -->
  mention (`task-executor.md:25`, `routing.md:127`) already qualified it; this one
  did not, so a reader following it found nothing.

## 0.29.4

### Changed
- `code-redteam` now says WHY its N=3 is fixed while `orchestration:verification-panels` <!-- removed-ok --> <!-- history: same merge -->
  sizes N to blast radius. A conflict audit found the two shipped opposite verdicts on
  the same number: that skill declares itself "the sizing authority for every consumer"
  with 2 refuters for a small radius and forbids a consumer inventing its own N, while
  this one said "spawn exactly three" directly under "reuse it wholesale" — and
  `completion-gate.sh` hard-blocks a boosted run below 3 lenses. A proportionally sized
  2-refuter panel was therefore unstoppable except by filing a `reduction-record` that
  claims a degradation which did not happen. N here is the lens count, not a radius
  call, so the fix is to record the exception on both sides rather than change either
  number. `verification-panels` now carries it as a table row.

## 0.29.3

### Changed
- `parallel-planning`'s boundary sentence names plan-before-code as the owner of
  task decomposition; the skill it named was merged there. <!-- removed-ok -->

## 0.29.2

### Changed
- `task-execution`'s body is 9,907 bytes, down from 11,918. The Extreme Boost
  block (~1.9 kB, inert on every standard run) moved to
  `references/boost-execution.md` and the role-tier floor's resolution rules to
  `references/reviewer-routing.md`; both are cited at the decision point. No rule
  was deleted — the body had grown 31% under a frozen 154-line count, which is
  the growth the new byte ceiling exists to make visible.

## 0.29.1

### Changed
- `task-execution/references/reviewer-routing.md` routes the database track to
  `sql:sql-best-practices`. Its old target, `database:database-design`, was <!-- removed-ok --> <!-- history: sql moved into database, database-design merged away -->
  merged into that skill — the rubric moved, the routing follows it.

## 0.29.0

### Added
- **`hooks/drift.sh`** — the ad-hoc complement to `scope.sh`. **Standing: advisory.**

  `scope.sh` compares each edit against a card's declared file list, and its first
  line is `[ -r "$scope" ] || exit 0` — so on a one-line request typed straight into
  a session, which is most turns, nothing watched whether the work stayed near what
  was asked. This is the marketplace's only **stack-agnostic** discipline surface:
  it counts files against a request, so a Dockerfile turn, a SQL turn and a React
  turn are read identically.

  It asks one question, once per request, when all four hold: no declared scope, at
  least **12** distinct files edited since the last typed message, no breadth marker
  in that message (`everywhere`, `rename`, `migrate`, `all the files`, …), and at
  least half those files unnamed in it.

  **The threshold is measured, not chosen.** 400 local transcripts, 169 turns that
  edited a file: p50=2, p75=5, **p90=12**, p95=21, p99=40, max=157. An earlier draft
  of this idea proposed 4 — which would have fired on roughly a third of all turns,
  and is why it was refused the first time rather than shipped with a guess.
  Re-derive from your own transcripts before changing it.

  **Known limits, stated in the hook:** it counts **breadth only, never depth** — an
  unasked refactor inside the one file you named is invisible, and that is probably
  the commoner way to stray. A legitimately wide request phrased in words the marker
  list does not know is a false positive. It reads only the last typed message, so a
  request built over three turns is scored against its final sentence. And whether a
  given extra file was necessary needs a reader, which is why the message ends in a
  question rather than a verdict.

  Silence with `CC_DRIFT=off`, or `CC_REMIND=off` for every advisory here.

## 0.28.2

### Fixed
- **A sibling Stop gate's block no longer spends this one's enforcement.**
  `stop_hook_active` is a SHARED flag — Claude Code sets it on the continuation after
  ANY blocking Stop hook — and this gate exited on it unconditionally, before its own
  loop-bounding marker was ever reached. Two Stop gates ship in this marketplace, so
  one blocking first disarmed the other for that continuation. The gate now evaluates
  normally and bounds itself with its own marker; the shared flag is honoured only when
  that marker cannot be written, which is the one case where nothing else bounds the
  loop. Verified: with the flag set, the first stop still blocks and an identical second
  stop does not.

## 0.28.1

### Added
- **`lane.tsv`** — declares the territory and phase of `task-executor` and the
  completion-gate Stop hook, so no sibling can silently claim the same job.

### Changed
- **`/task-runner:run` writes `.claude/cc-phase.json`** (`phase: build`) alongside the
  existing `active-run.json`, and clears both at step 9. The two are deliberately
  separate: `active-run.json` registers a RUN for this plugin's own Stop gate, while
  `cc-phase.json` declares a PHASE that every installed reminder hook reads — including
  in installs that have neither task-runner nor taskmaster. It is what stops a
  "clarify before your first code edit" nudge firing on turn 40 of an executing run.
- **`completion-gate` is declared `phase: any`**, not `verify`: a Stop gate has to fire
  whenever a turn tries to end, and scoping it to one arc phase would have let a turn
  ending during `build` escape it entirely.

## 0.28.0

### Fixed

- **The card-agent resolution map did not bind on the `Workflow` path.**
  `skills/task-execution/references/routing.md` resolves a card's `Agent:` tag to
  a worker (`laravel:backend-engineer`, `security:security-engineer`, …, else
  `task-executor`) and said only "dispatch the resolved worker with that prompt".
  A `Workflow` `agent()` call without `agentType` spawns the generic workflow
  subagent: steps 1–2 run, the prompt arrives, and the worker's own contract does
  not. The whole map is decorative on that path, and nothing in the run says so.

  What went missing in practice, on a 30-card fan-out: `task-executor`'s *"match
  the surrounding file's naming, idiom, and comment density"* and its *"new
  behavior no test exercises is named as untested"* rule. Neither reached a
  single writing agent. The output carried roughly twice the repository's own
  comment density and eight times its tests-per-integration, and every gate
  passed green — the checks that existed measure correctness, not proportion.

  Step 5 now names both dispatch forms (`subagent_type` on the Agent path,
  `agentType` on the `Workflow` path), states what is lost when it is omitted,
  and requires the bound agent to be logged per card in the run report.

- `skills/track-orchestration/references/algorithm.md` step 3 — the wave batch
  now passes `agentType: 'task-runner:task-executor'` alongside `model:`/`effort:`,
  under the same "this is a parameter of the call, not prose in the prompt" rule
  the tier already had. Also records why a track worker stays `task-executor`
  rather than a specialist: it runs mixed cards inline as a leaf, so there is no
  per-card resolution to bind, and skill priming carries the framework knowledge.

### Notes

- **Standing: agent-graded.** `scripts/validate.sh` gates shipped `agent(<args>)`
  code samples (`pc_dispatch_binding`), which is what catches a recipe. It cannot
  read a prose dispatch instruction and confirm an orchestrator obeyed it, and it
  cannot see a `Workflow` script composed at runtime — which is how the original
  failure happened. The per-card run-report line is the only thing that makes an
  unbound dispatch visible after the fact.
- Not addressed here: nothing in this marketplace measures test or comment
  *proportion* against a repository's own house style. Every surface pushes test
  count up (`verify-teeth`, `behavioral-gate`, the negative control,
  `coverage-check`) and none pushes back.
