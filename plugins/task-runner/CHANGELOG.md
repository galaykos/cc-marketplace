# Changelog

All notable changes to the task-runner plugin.

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
  The registry lives in `orchestration:delegation-contracts`. Every sibling
  mention (`task-executor.md:25`, `routing.md:127`) already qualified it; this one
  did not, so a reader following it found nothing.

## 0.29.4

### Changed
- `code-redteam` now says WHY its N=3 is fixed while `orchestration:verification-panels`
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
  `sql:sql-best-practices`. Its old target, `database:database-design`, was
  merged into that skill — the rubric moved, the routing follows it. <!-- removed-ok -->

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
