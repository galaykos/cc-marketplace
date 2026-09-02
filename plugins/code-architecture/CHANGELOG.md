# Changelog

All notable changes to the code-architecture plugin.

## 0.13.16

### Changed
- `coding-entry` loads `code-review:comment-discipline`; the comment-discipline plugin <!-- removed-ok -->
  merged into code-review on 2026-09-02.

## 0.13.15

### Changed
- **`coding-entry`'s skill map primes `ui-ux:a11y-audit`**; the a11y plugin merged into <!-- removed-ok -->
  ui-ux on 2026-09-02.

## 0.13.14

### Changed
- **`coding-entry`'s skill map primes `stack-scan:package-hygiene`** on any manifest;
  the packages plugin merged into stack-scan on 2026-09-02. <!-- removed-ok -->

## 0.13.13

### Changed
- **`coding-entry`'s skill map primes `devops:docker-best-practices`** for Dockerfiles
  and compose files; dev-env merged into devops on 2026-09-02. <!-- removed-ok -->

## 0.13.12

### Changed
- **`coding-entry`'s skill map primes `database:sql-best-practices` and
  `database:mariadb-best-practices`**; the sql and mariadb plugins merged into <!-- removed-ok -->
  database on 2026-09-02.

## 0.13.11

### Changed
- **`coding-entry`'s skill map primes `laravel:inertia-best-practices`** for the
  Inertia manifest signals; the inertia plugin merged into laravel on 2026-09-02.

## 0.13.10

### Changed
- **`coding-entry`'s skill map primes web-dev for the three JS stacks.** The
  `react-native`, `next` and `vite` manifest signals now resolve to
  `web-dev:<stack>-best-practices`; the three plugins merged into web-dev on
  2026-09-02 and the skill names are unchanged, so the primed content is the same.

## 0.13.9

### Changed
- **Meta-prose compressed to a one-line standing tag.** Sections narrating this
  skill's relationship to its siblings — boundary tours, "what this is NOT" lists,
  and in places the repository's own drift history — are replaced by a `Standing:`
  line on the rule they qualify. No actionable rule changed, and every named
  cross-skill reference was preserved: those names are what make the skills they
  point at reachable, and a re-scan confirmed none was orphaned.

## 0.13.8

### Added
- **`plan-before-code` regains its worked example** — the file map, the interface
  block, and the locked-in decisions. It was moved to `references/worked-example.md`
  at `22c3239`, a commit titled "merge the two skill pairs the line ceiling had
  blocked", and the reference file's own opening said "Moved out … to make room".
  The skill instructs "define the interfaces between units before writing bodies"
  and then showed none; the Before/after narrative referenced an example the body no
  longer contained. Task sequencing and the longer narrative stay in the reference.

## 0.13.7

### Changed
- **Every hook entry now declares a `timeout`.** `evidence-gate.sh` 10s. Before this release the
  plugin expressed no opinion about how long its own hook may hold a turn and
  relied entirely on the host default; a hook that blocks — a slow network mount,
  a large transcript — stalled the user with no per-hook ceiling. Sizes are per
  script, not one house number: 5s for a jq-only classifier, 10s for git/find
  work, 15s where the script shells out to the network, a package manager or
  node. No hook logic changed.

## 0.13.6

### Fixed
- **`coding-entry`'s detection map dropped its rows for removed plugins** (php,
  livewire, node-backend, react, vue3, nuxt, mysql, postgresql — removed from
  the marketplace 2026-08-26); the map now notes that engines without a dialect
  plugin prime only the sql row. The output-shape example no longer primes a
  removed skill.

## 0.13.5

### Changed
- **`task-orchestration` merged into `plan-before-code`.** Its dependency edges
  were always derived from the file map plan-before-code produces, and its
  parallel-safety rule ("neither reads a still-changing output of the other, and
  neither writes shared state") was stated in four places across three plugins.
  The body gains a "Split into tasks" section carrying the task definition,
  dependency ordering, the parallel rule and the review gate; the worked
  decomposition table — the one thing nothing else stated — is
  `references/task-decomposition.md`. plan-before-code's own 38-line worked
  example moved to `references/worked-example.md` to make room, so no rule was
  displaced by the merge. <!-- removed-ok -->

## 0.13.4

### Changed
- `coding-entry/references/skill-map.md` maps `migrations/` and `*.sql` to
  `sql:sql-best-practices` alone. Its second target was merged into that skill,
  so the map now names one owner instead of two. <!-- removed-ok -->

## 0.13.3

### Added
- **`skill-map.md` gains a "Stack-neutral" section** — `packages:package-hygiene` and
  `testing:testing-best-practices`. Both were already emitted by
  `skill-router/hooks/prime.sh` and absent from this map, which is precisely the drift
  this file's own header warns about ("two copies of one matcher guarantees that one goes
  stale"). It was found by the new `pc_prime_coverage` gate, not by reading.

## 0.13.2

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

## 0.13.1 — 2026-08-16

### Added
- **`lane.tsv`** — declares the territory, phase and definite trigger for this plugin's
  agent and Stop hook, so `pc_lanes_territory` can prove no sibling silently claims the
  same job. `architecture-reviewer` owns `code-structure-review` and yields to
  `system-design:system-design-reviewer` on system topology.

### Changed
- **`evidence-gate` is declared `phase: any`**, not `verify`. A Stop gate has to fire
  whenever a turn tries to end; scoping it to one arc phase would have let a turn ending
  during `build` escape the gate entirely.

## 0.13.0

### Changed

- **`coding-entry`'s triage no longer escalates on file count.** The rule was "3+ files
  → needs a spec", which routed a 20-line change spread over three files into the full
  spec pipeline. File count is a bad proxy for blast radius: a 3-file rename is not a
  3-file redesign. The term is now size-and-reversibility. **The risk clause is
  unchanged** — auth, data, migrations, concurrency and money still force a spec, on one
  line as readily as on fifty, and an unresolved unknown still does.

- **The tiebreak is honest in both directions.** It previously read "ambiguity resolves
  toward the spec" and priced only the under-ceremony error (the run at 2x this
  repository's comment density and 8x its tests-per-integration, every gate green). The
  over-ceremony error is equally real and is the one now being reported: a spec doc, an
  index, cards and a review pass per card for a change one edit would have finished.
  Both costs are stated; the tiebreak is blast radius, not unease.

### Added

- **A fifth output line, `budget:`** — this task's minimum stated *before* any code is
  written (files, tests, comments), so overshoot is visible and arguable in the
  transcript instead of discovered at review. Exceeding it is allowed; the trigger gets
  named where the excess happens. Minimum means risk coverage, not count.

- **`lean:cost-model` joins the loaded discipline set**, sixth of six. It carries the
  bar per cost surface and the closed trigger list. Standing is unchanged and still
  **agent-graded**: no script checks the triage call, the size call, or the budget line.

## 0.12.0

### Added

- **`/code-architecture:coding-task`** and the `coding-entry` skill behind it — an
  entry point for coding work typed straight into a session, where nothing
  previously stated the house rules before the first edit.

  Skills reached work in exactly two ways before this: `Skills to apply` on a
  taskmaster card (delegated, spec'd work only) and skill-router's nudge (which
  fires AFTER a file is edited). Ad-hoc work hit neither.

  **Load vs prime.** Five always-relevant skills are loaded in full
  (comment-discipline, testing-best-practices, plan-before-code,
  low-cognitive-load, code-smells — ~9.5k tokens). Everything stack-matched is
  PRIMED: one `Read <abs-path>` line, expanded only when the work reaches that
  surface. Loading the matched set eagerly measures 17.9k on a Laravel + Inertia
  + React repo and 37k worst case, against 12.4k for this marketplace's entire
  always-on budget — most of it for surfaces the task never touches. Priming is
  the idiom `delegation-contracts` § Skill priming already uses for cards.

  **The triage line is mandatory, and not decoration.** Typing a slash command
  silences two hooks that fire on a plain prompt: `taskmaster/hooks/remind.sh:9`
  and `skill-router/hooks/route-prompt.sh:59` both exit on `/*`. So this command
  does not run alongside the clarify nudge — it replaces it. It emits one line —
  `trivial` / `needs a spec` / `already spec'd` — and hands to `/taskmaster:task`
  or `/task-runner:run` accordingly. Without that line, using the command would
  silently cost you a guardrail.

  **Ownership before size.** The triage asks first whether a deeper command already
  owns the shape of work — `/ui-ux:build` for a component, `/craft-layer:craft` for a
  whole app, `/craft-layer:sections`, `/ui-ux:theme`, `/debugging:debug`,
  `/ultra-deep-research:research` — and hands over with a one-line `route:` instead of
  loading anything. Those commands prime their own skills; `/ui-ux:build` in particular
  already resolves the stack skill and injects Read paths into its worker
  (`ui-ux/commands/build.md:43`), which is why a UI sibling of this command was
  considered and rejected rather than built. Schema and infrastructure work gets no
  entry command either: by blast radius it lands in the `needs a spec` row, and
  taskmaster's `erd` skill owns data modelling.

  `references/skill-map.md` holds the manifest → skill table. The file → skill
  half is NOT duplicated there; skill-router's `rules.tsv` owns it and fires on
  every write.

### Notes

- **Standing: agent-graded.** No script checks that a `trivial` verdict was
  honest, that a primed path was read, or that detection matched reality.
  `validate.sh` gates what it can — the 150-line body ceiling (91 used), the
  description linter, and `pc_handoff_refs` resolution for every `plugin:skill`
  token in the map. No new smoke harness ships: the existing gates cover every
  mechanically checkable property, and a harness re-asserting them would be the
  theater this repo's own laws name. Behaviour is judged by a reader.
- **A new command is not free.** It adds one line to skill-router's tool-fit
  catalog, injected on every work-shaped prompt: +25 dynamic tokens per prompt,
  forever, plus +142 always-on for the two descriptions. Both baselines are
  updated in this change rather than left to fail someone else's CI.
- Scope held deliberately narrow: no question rounds (grill), no spec or cards
  (taskmaster), no execution (task-runner). It primes and triages.
