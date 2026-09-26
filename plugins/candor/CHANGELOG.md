# Changelog

All notable changes to the `candor` plugin.

## 0.5.1 — 2026-09-26

- The four meta-bundles (core-, frontend-, craft-, workflow-suite) were retired on 2026-09-26; install through `all-plugins` or `/stack-scan:suggest`. Wording that named the retired bundles in this plugin's hook text and README now describes the plugin standing alone; no behaviour changed.

## 0.5.0 — 2026-09-25

- `hooks/hooks.json` quotes `${CLAUDE_PLUGIN_ROOT}` in every hook command. Claude Code 2.1.282's `plugin validate --strict` rejects the unquoted form (an install path with a space splits into several words); the marketplace's CI pin moved to 2.1.282 with it.

Why for all three: `rationale/2026-09-25-session-plugin-usage-review.md`, findings 2, 4, 5.

### Changed
- **The completion gate no longer blocks while workers are in flight.** Clause 4's "no
  behavioral-gate pass for HEAD" branch prints one line and stands down while this session
  has a background worker running. It writes no per-HEAD nudge, so the stop after the last
  hand-back still gets its one block. Measured: one orchestrated run took 47 of these
  blocks, nearly all while workers were in flight, and each was answered with "No card can
  start yet…". The gate reads the host's `background_tasks` list when the Stop payload
  carries it; a live probe on CLI 2.1.282 showed a running background agent listed as
  `type: "subagent"`. Without that list it reads in-flight records: `hooks/preamble.sh`
  writes one on every `SubagentStart`, even under `CC_PREAMBLE=off`, and `hooks/gate.sh`
  deletes it on `SubagentStop`. If the gate blocks a subagent, the subagent keeps running,
  so the gate restores its record. A record older than 180 minutes is swept and not
  counted; that is what bounds an agent killed without a `SubagentStop`. Records live under
  `$TMPDIR`, keyed on the hashed `session_id`. The same probe showed that `SubagentStart`,
  `SubagentStop` and the parent's `Stop` share one `session_id`. The other clause-4 reasons
  still block with workers in flight.
- **`no-behavioral-coverage` can close a run, but only honestly.** Before this, the verdict
  always blocked, and in one run with ~40 React files and no JS runner the only exit was
  deleting `active-run.json`. It now passes when
  `.claude/task-runner/reductions/coverage-bg-<HEAD12>.json` exists and is newer than the
  run's registration. That file is exactly what task-runner's `scripts/reduction-record.sh
  --kind coverage --id bg-<HEAD12>` writes. The existing disclosure check then requires
  `bg-<HEAD12>` in the closing report. The block message for this verdict now names that
  command. `empty-suite`, `unverifiable-suite` and every other red verdict still block.

### Fixed
- **State and run records resolve at the project root, not the payload `cwd`.** The payload
  `cwd` follows the model's `cd`. The gate's own state dir already resolved the git
  toplevel, but clause 4 read `active-run.json`, `gate-pass.json`, `nc/`, `rv/`, `bg/`,
  `rt/` and `reductions/` from the raw `cwd`, so a stop taken from a subdirectory found no
  run and enforced nothing. Clause 5 read `$cwd/package.json` against repo-relative
  `git status` paths and passed silently. Clause 1 walked only the subdirectory, so a
  correct repo-relative citation could block as invented. All of them now use the shared
  `cc_state_root` block (`templates/blocks/state-root.md`). Clause 1 still tries the shell
  `cwd` first, then the root.

## 0.4.11 — 2026-09-24

### Changed
- **The completion gate's end-of-run branch names the exact command and a pace rule.** It
  said "run behavioral-gate.sh on the produced code (isolated)" under a "continue NOW with a
  tool call" that read as applying to both branches. On 2026-09-24, at the end of a 44-card
  run, an agent hand-built that "isolated" checkout as a rushed chain of commands. The
  worktree call was denied as a whole and the agent read the denial as "only the cp failed".
  The next `cd /tmp/… && …; cp .env.example .env && php artisan key:generate` then ran in the
  live repo and replaced the developer's `.env` and `APP_KEY`. Now the urgency applies only to
  the cards branch. The gate branch says it has no deadline and names task-runner's
  `scripts/behavioral-gate.sh --isolate --changed "…"` (task-runner 0.40.0). It forbids
  hand-built checkouts and writing any `.env` for the gate. It also adds one line for every
  branch: one shell step per call, read each result, and a denied or failed call ran
  NOTHING. The first line of the message is unchanged, so matchers on it still work.

## 0.4.10 — 2026-09-23

### Changed
- **Prompt audit (Claude Code's built-in `claude-api` skill, `prompt-audit` subcommand; target Opus 5.5 / Fable 5.1):** the per-turn terse reminder (`hooks/mode.sh`) and `/candor:level` now put "blocker or decision" second in the report skeleton, matching terse-output's skill since 0.4.9 — both copies had kept the old fifth-slot order; `/candor:check` and `/candor:level` drop dated incident prose. Method: that built-in skill's `shared/prompt-audit.md`; the full report and diff are in the maintainers' working area, not shipped.

## 0.4.9 — 2026-09-23

### Changed
- **`terse-output`'s work-done skeleton puts "Blocker or decision" second, right after
  the verdict.** It sat fifth of six. The Opus 5.5 playbook (claude.dev, 2026-09-22)
  says the first thing to read when a long run ends is what the model is waiting on
  you for; a slot near the bottom of a 12-line budget is the wrong place for it. The
  hooks read the contract block live from the skill, so the injected card moves with
  it. Order only; every slot's content is unchanged.

## 0.4.8 — 2026-09-22

### Fixed
- **`hooks/gate.sh` validates the payload `cwd` with `[ -d ]` before creating its state
  dir.** It checked only `-n`, so a stop taken with a deleted project directory as `cwd`
  recreated that directory three levels deep to hold `.claude/candor/` — reproduced
  against the committed hook. A cwd that is not a directory now degrades to the process
  cwd, which by construction exists, and the state dir is anchored at
  `git rev-parse --show-toplevel` when there is one. Residual: a cwd that IS a directory
  but not this project's still gets a `.claude/candor/` — the check proves existence,
  never identity.

### Changed
- **Every blocking reason now names its own off switch**, the way the lockfile clause
  already did for `CC_LOCKFILE_GATE`. Citation and reversal name `CC_CANDOR_GATE`, the
  evidence clause names `CC_EVIDENCE_GATE`, and all eight completion-gate reasons name
  `TASK_RUNNER_STOP_GATE` (one line at the single print site, not eight copies). A Stop
  gate reaches the reader only through its stderr, so a variable documented anywhere else
  is a variable the person being blocked cannot find.
- `hooks/avert.sh`'s ask reason names `CC_AVERT=off` and `CC_AVERT=notify`. It reads both
  and could deny; it named neither in anything it printed.

## 0.4.7 — 2026-09-19

### Removed
- Move 1's "and nothing less" half (added in 0.4.4). The corrected with/without eval on
  `substitution-surfaced-before-build` (3 runs per arm, Opus, all completed) had the
  preamble reaching every with-arm run and every run in both arms still inventing
  creatures without surfacing it: 0/3 vs 0/3 by the case's criteria. A rule that measures
  zero is decoration (`rationale/measured-zero-shapes.md`); the before-half with teeth is
  `hooks/avert.sh` (0.4.5), which fires on a hedge the model writes down. The eval case
  stays as the fixture for any future attempt. Move 1 is the 0.4.1 text again.

## 0.4.6 — 2026-09-19

### Fixed
- All five eval cases: `execution.timeout_seconds: 900` (the runner's default is 300 s, and
  on 2.1.276 five of six Opus runs of `substitution-surfaced-before-build` timed out, three
  before their first tool call), and every llm grader now sets `focus: trace` — the
  runner's default `last_message` shows the judges only the final reply, so a run that
  named Agumon in its transcript and its file was voted FAIL 3/3 against criteria that
  say "judge the files written and every assistant message". Measured 2026-09-19,
  `rationale/fable-distillation-2026-09-18.md` §4. Running any of these needs the operator
  grant `--allow-tools Write Edit` (Bash too where the case's scaffold needs it); the
  case's `allowed_tools` alone grants nothing.

## 0.4.5 — 2026-09-18

### Added
- `hooks/avert.sh`, PreToolUse on Agent, Write, Edit, MultiEdit and Bash: when the text
  about to reach a worker or disk declares doing less than what was named for a reason
  the user did not give — a legal/IP reason, a declared substitute (original, invented,
  generic, placeholder, stand-in, look-alike, inspired-by) in place of the real thing, or
  precaution language ("to be safe", "as a precaution", "to avoid any legal …") — and no
  human turn in the session transcript contains that term, the call becomes a permission
  question (`ask`), once per term per session. `CC_AVERT=notify` makes it a notification
  instead (the user asked for "a notification or a confirmation", not a trademark filter). Tool results are not human turns, so a worker's
  report cannot launder a hedge into "the user said it". Trigger: the 0.4.4 avert left its
  reason in the dispatch it wrote — "NOT copies of trademarked characters" — while no prompt
  of the user's mentioned trademarks; the user asked whether that intent could be caught.
  It can, inside this vocabulary: a hedge that never names its reason still passes, and
  that half stays with move 1 and drift-review. Eleven-case harness. `CC_AVERT=off`.
  Standing: gate on the call; a guard, not a proof.

## 0.4.4 — 2026-09-18

### Changed
- `hooks/preamble.sh` move 1 gains its other half: "and nothing less". Averting part of
  what the user named — a risk judged for them, a hedge, a safer substitute — is a question
  before the first edit, not a cut confessed after. The move is the avert, not its subject.
  Trigger: the same day, the orchestrating session — asked for a Digimon-themed page with
  2D sprites — decided a trademark hedge on the user's behalf, briefed its sprite worker
  to draw invented mascots, in a project whose library already showed real Digimon, and
  named the swap only at the end. The user's words: "the action you did which is avert". Harness cap raised from
  800 to 1,000 chars. One eval case, `substitution-surfaced-before-build`, with the
  with/without control arm; not run.

## 0.4.3 — 2026-09-18

### Added
- `hooks/preamble.sh` also runs on `SubagentStart`, once per `agent_id`, unconditionally —
  a spawn is work by construction, so the prompt-shape trigger is skipped. Measured the
  same day: three Agent-tool workers built a Laravel/React app under 0.4.2 and the preamble
  reached 0 of 3 (`UserPromptSubmit` never fires inside a subagent), while a plugin
  `SubagentStart` entry probed with `--plugin-dir` on CLI 2.1.276 did reach a
  `general-purpose` subagent, which quoted the injected text and named its source
  (`rationale/fable-distillation-2026-09-18.md`). No matcher: Explore and Plan spawns pay
  the ~640 chars too. Five new harness cases (14-18). Standing unchanged: `recorded`.

## 0.4.2 — 2026-09-18

### Added
- Three eval cases for the preamble, one per move the 2026-09-17 simulation showed a
  differential on, each with a scaffold so the action under test is real and cheap:
  `limitation-checked-before-stated` (move 4: the prompt asserts node is unavailable; the check
  must happen before the claim is repeated), `unasked-additions-need-a-trigger` (move 1: one
  flag asked for; any addition carries a named trigger or is absent),
  `configuration-named-in-report` (move 5: a stub becomes a Postmark send; the report names the
  token variable and sender and says the live path is untested). Three runs each; the control
  arm is `--ablation with-without`. They load on the eval gate; nothing runs them in CI and
  none has been run.

## 0.4.1 — 2026-09-17

### Changed
- `hooks/preamble.sh` move 1 names the admissible triggers again (the user asked, a stated
  criterion, an observed defect) and says an addition admitted afterwards is not one. The
  2026-08 arm-C wording carried that list and produced "cut, and why" lists with features left
  out; the 0.4.0 text ("name the trigger for anything more") produced, in a one-run simulation,
  an unasked minimax opponent plus a scope note confessing it
  (`rationale/fable-distillation-2026-09-17.md` §8). Wording change only; standing unchanged.

## 0.4.0 — 2026-09-17

### Added
- `hooks/preamble.sh` (UserPromptSubmit): once per session, on the first imperative
  work-shaped prompt, injects five working moves before the first edit — smallest change,
  prove it through the surface the user will use, a stale or load-contaminated green is not
  evidence, check a limitation before stating it, name the untested/cut/to-configure in the
  final message. Advisory (`recorded`); the Stop gate remains the only clause with teeth.
  `CC_PREAMBLE=off` silences it. Derivation and the measurements it rests on:
  `rationale/fable-distillation-2026-09-17.md`.
- `evals/first-edit-discipline/case.yaml`: the with/without fixture for that hook — a bare
  build prompt on which the recorded control arm (Opus 5, 2026-08) shipped no
  verified/unverified boundary in 3 of 3 runs. Not run in CI.
- `scripts/__tests__/preamble-hook.test.sh`: 13 cases over the trigger, the one-shot
  marker, the off switch and fail-open.

## 0.3.8 — 2026-09-16

### Changed
- `/candor:level` and `/candor:check` carry `disable-model-invocation: true` (trend
  audit D1, `rationale/marketplace-trend-audit-2026-09-16.md`). The level switch is
  the user's act — `hooks/mode.sh` keys on the literal `/candor:level` in the typed
  prompt and still does — and the check is a report the user asks for; neither is loaded
  by name from a skill or hook (`activate.sh`'s fallback line tells the USER to run it).
  Both descriptions leave the model's listing (measured on a skill, 2.1.237; on a command
  it rests on the host doc's "work the same way"); the typed commands run as before.

## 0.3.7

### Fixed
- **Clause 4's negative-control count accepted a record from a PREVIOUS run.** Its three
  sibling counts (`rv/`, `rt/`, `reductions/`) all bound `find` with `-newer
  active-run.json`; the `nc-pass-*`/`nc-skip-*` count did not, and `nc/` is never
  cleared while card ids repeat across runs — so two stale records covered two done
  cards that had no control at all. Measured against the shipped 0.3.6 hook: stale
  records, two done cards, every other gate green → **exit 0** (allowed); with the bound
  → **exit 2** with the missing-controls message, and fresh records still allow. The
  count is also deduplicated by card id now, like `rv/` (`nc-pass-01` plus `nc-skip-01`
  is one card, not two). The header's clause-4 limitation states the bound and its
  residual: a legitimate record written before the run registered itself is invisible,
  which blocks rather than passes.

## 0.3.6

### Fixed
- **The per-prompt cost of the terse mode was understated by a quarter.** `mode.sh`'s
  header and the README both said "~120 tokens per prompt (measured: 476 chars)". Driven
  against a real `UserPromptSubmit` payload on 2026-09-15 the injected line is **596-597
  chars at `lite`/`full`/`ultra` (~150 tok) and 693 at a `wenyan-*` level (~173 tok)** —
  it grew when the findings-cap waiver and the wenyan clause were added to the emitted
  string and nobody re-measured. The one number a user weighs against `/candor:level off`
  was the stale one. Both now carry the measured figures and the method.
- **The README's author-time check list carried a wrong case count and an incomplete
  scope.** `evidence-gate-hook-tests.sh` was labelled "30 cases" and prints 35;
  `gate.test.sh` was labelled "clauses 1-2" and also pins clause 5 and clause
  independence. The counts are gone rather than corrected — each harness prints its own,
  so a second copy here is only a thing to drift.
- **`CHANGELOG.md` carried two `## 0.3.3` sections.** Clause 5 (a blocking clause) landed
  under the version number the previous release had already used, so a consumer reading
  0.3.3 could not tell which of two feature sets they had. Merged under one heading that
  says so.
- **The statusline badge reads the level file only.** A level set purely through
  `CC_TERSE` is active and unbadged; the README implied the badge tracks the active level.
  Stated, not changed: the badge is opt-in, unwired by default, and its Windows twin
  would have to move with it.

## 0.3.5

### Fixed
- **The description announced five clauses and then listed four.** Clause 5 (lockfile
  drift) was missing from its own enumeration — 0.3.4 changed the count word and not the
  list, so the always-on text a user reads at install described a gate with one fewer
  rule than it has. The clause is named now, and `task-runner run` lost the redundant
  "registered" so the whole description stays under the 700-char clarity guideline.
  Found by a second branch review.

## 0.3.4

### Fixed
- **Clause 5 never stood down, so a blocked turn could not be unblocked.** It was
  missing the `$skip` term every other clause carries, and the loop guard keys on the
  final assistant text — so the continuation re-blocked, and a third turn with different
  text blocked again. The escape the clause's own message offers ("say plainly that the
  lockfile is deliberately unchanged and why") was unreachable. Found by a branch review
  before merge; 0.3.3 shipped for a few hours with it.
- **Clause 5 armed on ANY line change in a non-JSON manifest**, so a `version` bump in
  `pyproject.toml`, a `[tool.ruff]` edit, or a comment added to a `Gemfile` blocked a
  Stop — the exact false fire its own header promised could not happen. Each of the four
  now tests dependency-shaped lines and excludes metadata keys by name. Nine cases
  measured across pyproject/Gemfile/Cargo/go.mod, in both directions.

### Changed
- The README, the plugin description and the hook table say **five** clauses, and the
  clause table documents clause 5 and `CC_LOCKFILE_GATE`. 0.3.3 added a blocking clause
  and left every count at four.

## 0.3.3

Two releases shipped under this one version number — the clause-5 change below landed
after the three fixes without a bump, so the entries are merged here rather than split
across two `0.3.3` headings that a consumer could not order or tell apart.

### Added
- **Clause 5: lockfile drift.** A Stop is blocked when a dependency manifest's
  dependency map changed in the working tree and the lockfile that governs it did not —
  npm/pnpm/yarn/bun, Composer, Bundler, Poetry/uv/pdm, Cargo, Go. The install step was
  skipped, so the tree being left has a manifest and a lockfile that disagree; the next
  clone resolves different versions and CI blames whoever ran it.
  `stack-scan:package-hygiene` has stated the rule in prose all along, and the model
  agrees and does it anyway, because adding a dependency line looks complete. For JSON
  manifests it compares PARSED dependency maps rather than diff lines: package.json is
  frequently one line, so a line diff makes every `version` bump look like a dependency
  change — the harness caught exactly that, and a hand test had missed it because the
  loop guard was still holding the previous verdict. Disarmed for subagents.
  `CC_LOCKFILE_GATE=off` disables it.

### Fixed
- **Clause 3 arms on an MCP file write.** Its evidence scan counted only
  `Edit|Write|MultiEdit|NotebookEdit`, so a session that edited exclusively through an
  IDE's MCP server never armed the clause that blocks a done-claim after a mutation with
  nothing executed. It now also counts `apply_patch` and `create_new_file`.
- **The terse findings skeleton no longer collides with clause 1.** `path:line — problem`
  was mandatory; clause 1 blocks a citation into a file the turn just deleted or
  shortened, so a finding about a removed file failed the turn. The line number is now
  droppable in exactly that case.
- **The no-emoji rule yields to a mandated protocol banner.** taskmaster prints a
  byte-identical status line that `validate.sh` gates for parity; a terse level shortens
  prose, it does not rewrite another plugin's contract.

## 0.3.2

### Fixed
- **Clause 1 blocked `~/` citations.** `~` was outside the extraction class, so
  `~/.claude/settings.json:12` was read as the absolute path `/.claude/settings.json`,
  resolved to nothing, and blocked — on the exact file a settings question is
  answered from. `~/` now expands to `$HOME` before resolution; a `~/` path that
  does not exist, or a line past its end, still blocks. Three harness cases.
- **Clause 3 taxed docs-only turns.** "Fixed the typo in README.md" after one Edit
  to a `.md` file blocked, and the only way through was to run any command at all
  (`git diff` satisfied it) — a turn spent on ceremony, never on a check, because no
  command's failure proves prose wrong. Mutations of `.md`/`.mdx`/`.markdown`/`.txt`/
  `.rst`/`.adoc`/`.asciidoc` files no longer arm the clause. Everything else still
  does: an edit with no `file_path`, no extension, or a code/config extension
  (`.json`, `.yaml`, `.sh`, …). Same reasoning clause 4 already applies as its
  `no-executable-surface` verdict. Residual, stated: a prose edit that claims
  "verified" passes on the claim alone — there was nothing to execute either way.
  Five harness cases in `scripts/smoke/evidence-gate-hook-tests.sh`.

### Changed
- **Gate state moved into `.claude/candor/`** (`last`, `blocked`, per-agent
  suffixes unchanged) and the directory carries a self-ignoring `.gitignore` the
  first time it is created. The bare files `.claude/candor-last` and
  `.claude/candor-blocked` showed up as untracked in every user's `git status` —
  observed in a live repo, and named as "other plugins' scratch" by overseer's own
  acceptance protocol — one `git add -A` away from being committed. A stale bare
  file from 0.3.1 is inert; delete it by hand.

## 0.3.1

### Fixed
- **A bounded clause 4 silenced clauses 1-3.** In 0.3.0 the gate reported one
  verdict per stop and clause 4 ran first, so once a registered task-runner run had
  been blocked at a HEAD (per-HEAD nudge written) — or whenever
  `TASK_RUNNER_STOP_GATE=warn` — every later stop at that HEAD exited 0 before the
  citation, reversal and evidence clauses ran. On master those were three
  independent Stop hooks, each evaluated every stop; the merge lost that for the
  whole of every card. Clause 4 still blocks first and alone; when it is bounded or
  warn-mode it prints and falls through. Six regression cases in
  `scripts/__tests__/gate.test.sh` (clause independence), four of which fail on
  0.3.0. Found by a post-merge review; no harness case had combined a live run with
  a clause 1-3 shape at a second stop.

## 0.3.0

### Added
- **The marketplace's one Stop gate.** `hooks/gate.sh` gains clause 3 (a completion
  claim after edits with nothing executed since — code-architecture's
  `evidence-gate.sh` until now) and clause 4 (a registered task-runner run stopping
  without its recorded gate pass, card counts, per-card control and reviewer records,
  red-team panel or reduction disclosure — task-runner's `completion-gate.sh` until
  now). Both clauses keep their env overrides (`CC_EVIDENCE_GATE`,
  `TASK_RUNNER_STOP_GATE`), their messages and their harnesses
  (`scripts/smoke/{evidence,completion}-gate-hook-tests.sh` now drive this script).
  The three-script namespaced-disarm protocol is gone: one script records WHICH
  clause blocked (`.claude/candor-blocked` now carries the clause name) and skips
  only that clause on its own continuation; clause 4 keeps its per-HEAD nudge.
  (2026-09-14 consolidation plan, §4.2.)
- **The terse reply mode**, merged in from the terse plugin: `hooks/activate.sh` <!-- removed-ok -->
  (SessionStart), `hooks/mode.sh` (UserPromptSubmit), the `terse-output` skill,
  `/candor:level`, `scripts/measure.sh` behind `/candor:check --brevity` (also
  automatic while a level is active), the statusline badge and the MCP catalog
  shrinker. The level file (`~/.claude/terse-mode`) and `CC_TERSE` keep their names,
  so a level set under the old plugin stays set. Dropped with the merge: the
  terse-crew, terse-commit and terse-compress skills, the three crew agents and <!-- removed-ok -->
  `/terse:commit` / `/terse:compress` (the host's `/commit` covers the first). <!-- removed-ok -->

### Changed
- `lane.tsv`: `candor:gate` no longer yields to code-architecture's evidence gate —
  there is nothing left to yield to; rows for the mode hook, `/candor:level` and
  `terse-output`.
- `/candor:check` argument list grows the brevity flags; the candour scan is
  unchanged.

## 0.2.0

### Added
- `hooks/gate.sh` also fires on `SubagentStop`: a subagent's final report goes
  through the fabricated-citation clause before the main thread quotes it. The
  payload's `last_assistant_message` is judged directly; `agent_transcript_path`
  is the fallback. Clause 2 (reversal) disarms for subagents — no user turn there.
  Loop-guard and claim markers are suffixed per agent id (hashed). Seven harness
  cases drive the measured SubagentStop payload shape.
- A span ledger was considered and dropped: the host already writes one transcript
  per subagent under `<session>/subagents/`, which is the cost denominator
  `scripts/turn-cost.sh` lacks — a reader problem, not a new writer.

## 0.1.3

### Changed
- Citations of the four-laws / has-teeth doctrine now point at
  `.claude/skills/authoring-skills/SKILL.md` in the marketplace repository — the
  authoring plugin was demoted to a tracked project skill on 2026-09-03. Prose only;
  no behaviour change.

## 0.1.2

### Changed
- **Every hook entry now declares a `timeout`.** `gate.sh` 15s. Before this release the
  plugin expressed no opinion about how long its own hook may hold a turn and
  relied entirely on the host default; a hook that blocks — a slow network mount,
  a large transcript — stalled the user with no per-hook ceiling. Sizes are per
  script, not one house number: 5s for a jq-only classifier, 10s for git/find
  work, 15s where the script shells out to the network, a package manager or
  node. No hook logic changed.

## 0.1.1

### Fixed
- One measurement, two numbers: `CHANGELOG.md` said ~3.8k assistant messages
  across 47 transcripts, `hooks/gate.sh:148` said ~3.3k across the same 47 with
  the same two-step resolver. Aligned on the figure in the code comment nearest
  the script that produced it. Recorded as a judgment, not a re-measurement — the
  original run is not reproducible from here.

## 0.1.0 — 2026-08-18

Initial release.

### Added

- `hooks/gate.sh` — a blocking `Stop` hook with two falsifiable clauses.
  Clause 1 fails a turn whose final message cites a `path/file.ext:NNN` that does
  not resolve under `cwd` or points past the file's last line. Clause 2 fails a
  turn that retracts a position ("you're right", "my mistake", "I stand
  corrected") after challenge-shaped pushback that carried no correction of its
  own, when no tool ran between the challenge and the retraction.
  Modes: `CC_CANDOR_GATE=block` (default) `| warn | off`. Fails open on missing
  `jq`, an unreadable transcript, or empty text. One block per distinct final
  message.
- Citation resolver ladder, forced by measurement rather than theory: cwd-relative,
  then a full-suffix match, then the basename. Only a basename that exists
  **nowhere** counts as fabrication. Over 47 real transcripts (~3.3k assistant
  messages) a two-step version flagged mostly ABBREVIATED paths —
  `craft-layer/asset-sourcing/SKILL.md` for a file that really lives at
  `plugins/craft-layer/skills/asset-sourcing/SKILL.md` — which is the
  false-positive class that gets a gate switched off. The accepted residual: a
  real filename cited under the wrong directory now passes silently. Elided paths
  (`plugins/x/.../SKILL.md:74`) are skipped as prose, not resolved.
- `scripts/candor-scan.sh` + `/candor:check` — report-only measurement of a
  session transcript across six axes: the two gated ones plus flattery openers,
  apologies, defensive phrasing and emotional intensifiers. Always exits 0.
  Citations resolve against the transcript's own recorded `cwd`, printed in the
  report — pointing the scan at a session that ran elsewhere previously reported
  78 real paths as missing in a single transcript. The `defensive` axis dropped
  the bare `you asked for` pattern for the same reason: 4 hits on a 719-message
  transcript, all of them neutral back-references. The citation axis is
  backward-looking by nature (it resolves a whole session's history against
  today's tree); the gate is not, and both say so.
- `skills/straight-talk/SKILL.md` — the six orderings the gate cannot check:
  evidence before claim, disagreement before concession, reversal-as-finding,
  "I don't know" plus the settling command, scope honesty, correction without
  performance. Carries the standing table for which of them have teeth.
- `lane.tsv` — territory declaration; the Stop gate yields to
  `code-architecture:evidence-gate` on completion-claim territory, which it does
  not duplicate.
- Three author-time harnesses, 64 cases. `install.test.sh` is the one that would
  catch a plugin working only in-tree: it copies the plugin to a temp directory,
  resolves the hook by expanding `${CLAUDE_PLUGIN_ROOT}` from `hooks/hooks.json`,
  fails if that path lands back inside this repository, and drives it against a
  consumer project that is not a git repository, with full-shape transcript
  entries.
