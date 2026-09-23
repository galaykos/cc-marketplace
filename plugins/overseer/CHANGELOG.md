# Changelog

## 0.5.2 — 2026-09-22

### Changed
- Dropped the three mentions of `/approaches:size` (the approaches plugin removed its estimation skill and that command the same day); the milestone scale is described on its own terms. <!-- removed-ok -->

## 0.5.1 — 2026-09-22

### Changed
- The Finish step's destination offer spells each option out instead of showing bare
  `merge / PR / keep`: what merging does, what opening a PR does, what keeping the
  branch means. Three sites carried the same unglossed triple — `skills/overseer/SKILL.md`,
  `references/capability-map.md`, `scripts/capability-scan.sh` — and a user reading a
  picker has no access to any of them.

## 0.5.0 — 2026-09-22

### Added
- **Headless evidence profile.** `kinds.tsv` takes an optional fourth column, `profile`
  (`ui`, the default for every existing row, or `headless`). `accept` resolves the
  required evidence from the milestone's kind: `ui` keeps the nine kinds; `headless`
  requires exactly `tests` plus the new file-kind `run-log` (captured command output,
  read-gated like every other file). New kinds `audit` (read-only review or research;
  `stack` only) and `library` (non-UI code: script, CLI, package). Before this, every
  milestone of a non-UI program ended `parked` — measured 2026-09-16 when overseer ran a
  program over this marketplace itself. Harness 251 → 279 assertions.
- `evals/*/case.yaml` carry `timeout_seconds: 900` (the 300 s default timed out 5 of 6
  runs on 2026-09-18).

## 0.4.9 — 2026-09-16

### Changed
- `/overseer:start`, `/overseer:resume` and `/overseer:status` carry
  `disable-model-invocation: true` (trend audit D1, `rationale/marketplace-trend-audit-2026-09-16.md`).
  Each is a pipeline entry the user starts by hand — start asks a clarifying round and
  writes state, resume re-enters recorded state, status reads the board — and nothing
  in this plugin loads one through the Skill tool; the `announce.sh` hook and the skill
  name `/overseer:resume` for the USER to type. The three descriptions leave the model's
  listing (measured on a skill, 2.1.237; on a command it rests on the host doc's "work the
  same way"); the typed commands run exactly as before.

## 0.4.8 — 2026-09-15

### Fixed
- `skills/overseer/SKILL.md`: the four-laws citation now says the path is **in the
  marketplace repository**, the form the other 17 citing skills already use. An
  installer of this plugin has no `.claude/skills/authoring-skills/SKILL.md` in their
  project, so the bare path read as a file they were missing.

### Changed
- `skills/overseer/SKILL.md`: three rows left the standing table because the same rule,
  with the same `(**gate**)` marker, is stated inline in the step that applies it —
  hands-off needs an ASSUMED row and a reason (Clarify), a dispatch's `MODEL:` must fit
  the tier (Prompts are the product), the session must be opened in the project
  (Discover 0). A fourth row keeps its standing and points at Deliver step 3 for the
  requirements instead of restating them. Body: 191 → 185 lines, 13,991 → 13,491 bytes;
  it had 9 bytes of headroom under the 14,000-byte gate, so the next word added anywhere
  would have failed the build. No rule was dropped, and the README's installer-facing
  table still lists every one.

## 0.4.7

### Changed
- **`shape`-phase capability map points at `ui-ux` instead of `design-studio`** <!-- removed-ok -->
  (`scripts/capability-scan.sh`, `references/capability-map.md`) — the plugin was
  retired on 2026-09-14 and the mockup escalation it named is now the real-component
  rung of `taskmaster:visual-decisions`. `dispatch check` resolves again on a machine without the old
  plugin installed. <!-- removed-ok -->

## 0.4.6 — 2026-09-14

- `references/capability-map.md`: the review row no longer names `ui-ux` review and the
  `laravel`/`web-dev` review commands, retired 2026-09-14 — the fan-in
  `/code-review:review` loads their skills, `ui-ux` keeps `audit`, `resilience` is one
  command behind `--concern`. The `capability-scan.sh` map row (plugin names only) was
  already right.

## 0.4.5 — 2026-09-14

- `scripts/capability-scan.sh`: the guard row no longer names `lean` (removed from the
  marketplace 2026-09-14) — 0.4.1 fixed the reference copy of the map and missed the
  script, so the scan kept suggesting `/plugin install lean`. Found by installing the
  branch into a fresh project; no gate reads a `.sh` for retired names, and `lean` is
  deliberately outside `pc_removed_refs` because it is also this plugin's rigour tier.

## 0.4.4 — 2026-09-14

- `lane.tsv`: the overseer skill yields to `candor:gate` where it yielded to
  `task-runner:completion-gate` — that hook is clause 4 of candor's Stop gate now.

## 0.4.3 — 2026-09-14

- `scripts/capability-scan.sh` and `references/capability-map.md`: the shape row
  lists design-studio in place of design-lab and theme-design, which were merged <!-- removed-ok -->
  into it. No behaviour change beyond the name.

## 0.4.2 — 2026-09-14

- `scripts/capability-scan.sh` and `references/capability-map.md`: the understand row
  no longer lists plugin-scout as a separate plugin — it merged into stack-scan, whose
  `/stack-scan:suggest` now carries the install offer. No behaviour change beyond the
  name.

## 0.4.1 — 2026-09-14

- `references/capability-map.md`: the guard row no longer lists `lean` (removed from
  the marketplace). No behaviour change.

## 0.4.0 — 2026-09-13

- **Read before you record.** A new PostToolUse hook, `hooks/track-read.sh`, ledgers every
  `Read` while a program is open (`.claude/overseer/.reads`: epoch, session, physical path;
  zero stdout). `evidence add --file X` now refuses a file no Read in this session touched
  since X last changed — a screenshot nobody opened proves nothing, and one re-captured
  after the look is unread again. The plugin's own "unenforceable — a file exists, not what
  it shows" row moves to **gate** for the looking; what it shows stays agent-graded. Lifted
  from the verify-gate in Anthropic's cwc-long-running-agents demo. Fail-open, said aloud:
  no session id (plain terminal) or no Read tracked for the session (hook not loaded) → a
  WARN and the row is recorded.
- First eval suite with a control arm (`evals/`, two `case.yaml`s with a scaffold that
  writes a real open program, so the skill's trigger is genuine): the hands-off rigour pick
  and the green-suite acceptance refusal. Measured 2026-09-13, one run per arm, haiku judge,
  `claude plugin eval plugins/overseer --scaffold --ablation with-without`: rigour pick
  with 1 / without 0 (delta +1; the skill fired); acceptance refusal with 1 / without 0
  (delta +1 — but the with-arm answered from the skill's DESCRIPTION, `Skill` called 0x,
  and offered to record "accepted without evidence" on request, which the body forbids).
  Two lessons the run bought: without a scaffold the skill never fired in the sandbox (no
  program on disk → answered from the catalog, delta 0), and a case that only asks for a
  judgment does not make the model load the body. One run each is a reading, not a
  statistic; the without arm is the control CLAUDE.md says no plugin had.
- Harness 251 (+15).

## 0.3.2 — 2026-09-13

Final post-merge review: a Fable branch review, a marketplace-wide conflict audit and a
web survey of comparable harnesses (`taskmaster-docs/overseer/final-review-2026-09-13-*`).

- **A follow-up is gated now.** `dispatch check --kind followup` exited before the
  `.gated` record, so no fix cycle ever moved the stale-evidence line that 0.3.0 claimed —
  the exact sim-4 case. It is recorded like a worker; `accept` refuses evidence older than
  it and prints `(N worker/follow-up)`.
- **A project path with a space can be accepted.** File lists were word-split and the pin
  regex stopped at a space, so a project under `…/my proj` could pin nothing and never
  accept. Lists are newline-safe; a lenient second pass reads a spaced path and the
  existence check drops any over-capture.
- **A reader/reviewer carries no preamble.** The gate demanded all nine worker clauses
  (implement, verify, run the full suite) verbatim inside a prompt that also had to say
  "you write no file"; the SKILL's own reviewer template failed it. Worker only now.
- The boost marker is read from the index's first 40 lines, not 12 (an upgraded-statement
  blockquote may sit above it).
- Conflicts with neighbours resolved: `--tracks` is for two-plus track-eligible milestones,
  not parallel groups (task-runner owns the flag); `worktree.md` now follows
  git-workflow's worktree-isolation (`.claude/worktrees/`, lockfile install, plain remove)
  and keeps only the Laravel/Vite additions; the `api` kind pins `graphql-grpc`, not
  `api-docs-first` (which disclaims own-API design); the size letters are declared a
  milestone scale, not `/approaches:size`'s card scale; <!-- removed-ok --> tier `opus` is stated as a cost cap
  overriding role-floors; lean drops the code red-team only (the spec red-team is
  taskmaster's gate); README no longer says `goal` alone for hands-off, or that `--model
  auto` is the only way any seat runs above opus.
- Harness 236 (+11). Neighbours: taskmaster 0.42.2 (ultra description no longer reads all
  three bare tokens as "no boost"), orchestration 0.16.10 (skill resolution via
  `claude plugin list --json`, not `find | sort -V`), code-architecture 0.13.18 (a whole
  product routes to `/overseer:start`, a crafted surface to craft).

## 0.3.1 — 2026-09-13

- **Hands-off no longer pays the boost by default.** taskmaster 0.42.1 adds `goal-lean`
  (autonomy without the boost, marker `Goal: true (boost=off)`, read by task-runner
  0.32.0). The rigour mapping for hands-off is now `goal-lean` for lean/standard and `goal`
  for adversarial; `dispatch check` reads `boost=off` as unboosted, points a boosted
  lean/standard hands-off index at `goal-lean`, and WARNs on an adversarial milestone whose
  index is `boost=off`. The 0.3.0 residual ("hands-off still pays") is closed for
  pipelines at those versions and stated for older ones. Harness 225 (+3).

## 0.3.0 — 2026-09-13

Simulation 4 (a home-loan landing page on the same Vite starter, headless, hands-off,
session and tier opus) was the first run to take the intended path end to end: taskmaster
briefed, task-runner executing, every dispatch gated, every seat at opus, zero app code
from the main thread, eleven evidence kinds from a real Chromium walk. It also stopped
after m1 of 3 and cost $76.60 / 125 min. A two-reviewer read of the plugin afterwards
(one Fable, one Opus, every finding re-verified by experiment) found the cost mispriced
and three "gate" rows that were not gates. This entry folds the unreleased 0.2.1.

- **The boost is priced right and bought per milestone.** 0.2.1 charged the per-card
  reviewers and the negative control to `goal`; they are task-runner's baseline, and the
  spec red-team runs on any standard run past three criteria or an ASSUMED row. What the
  `ultra`/`goal` marker adds is the code red-team, coverage loop-until-dry and tier
  escalation — 40 of simulation 4's 119 minutes, and where the real bugs came from. Each
  milestone now carries a **rigour profile** (`lean|standard|adversarial`) scored from six
  brief signals (`dispatch-prompts.md` § Rigour): `milestone add/set --rigour`, shown by
  `status`; `dispatch check --milestone` WARNs while unset, when a surface kind is lean,
  and when the card index's marker disagrees (boost on lean/standard; none on
  adversarial). Interactive: `/taskmaster:task ultra <brief>` is the boost without
  autonomy — the overseer never mentioned it before. Hands-off still pays the boost on
  every milestone (`goal` is both); the WARN names that residual instead of a wrong token.
- **Three gates are now gates.** `dispatch check` exit 0 records the file (checksum, kind)
  in `dispatch/.gated`; `accept` counts only gated, unchanged files, refuses a milestone
  with none, and a kind-group pin counts only by a path that exists (a hand-written
  `/nowhere/…/SKILL.md` closed an auth milestone before). The `stack` group is "installed"
  only when a project or laravel/web-dev skill really is (it always refused before). A
  worker never `MODEL: inherit`s, even under `--model auto` (the check read the tier and
  never the seat).
- **Evidence must postdate the last worker.** `accept` refuses a required row recorded
  before the newest gated worker/follow-up dispatch (the walk was of older code); WARNs
  when nine kinds share one file or no reviewer dispatch was gated. It prints `sized X ·
  actual: N dispatches · +A/−B lines · T min` so the next size guess has an anchor, and
  `milestone set --size --reason` corrects a wrong one (history keeps the row).
- **Preamble check reads every clause line**, whitespace-folded: clauses 2–9 span two to
  ten lines and only the first was compared. The canonical file is resolved through
  `skill-path.sh` (the enabled install), not `find | sort -V` across marketplaces.
- **The index-age check uses the milestone's registration time**, not the brief's mtime:
  amending the brief mid-milestone turned the boost WARN into a false "pipeline skipped".
- **Kinds:** new `form` (user-data forms: a11y + security groups — sim 4's m3 collected
  name/email/phone as `feature`, which required neither); retired
  `database:database-design` removed; <!-- removed-ok --> `integration` row added to the map's table.
- **The loop continues.** `start.md` step 5 and SKILL § Deliver 7: after Finish,
  `program.sh next` — hands-off delivers every runnable milestone; interactive asks once.
  `accept` prints the next runnable milestone and the rule at the decision point.
- **Installed is not reachable.** A project's first session registers `enabledPlugins`
  without loading them; Discover checks the scan against the session's own Skill list and
  reloads or restarts before any milestone exists.
- `usage` prints the whole header (dispatch check, close, log, suggestion were cut off);
  "no absolute path" is anchored (the string `and/or` satisfied it); `state.md` resume
  rule matches the index-must-name-the-milestone check; the direct-path reviewer template
  says what task-runner's richer form adds.
- Not done, with reasons in `dispatch-prompts.md` § Rigour: no cut to task-runner's
  reviewer routing or negative control (every card major in sim 4 came from the second or
  third reviewer; both are free); no budget input (the plugin has no cost channel); the
  brief-vs-spec drift check (three silent contradictions in sim 4) is agent-graded at
  Deliver 3, not scripted.
- Harness: 222 cases (+37).

## 0.2.0 — 2026-09-12

- **Model tier, chosen at start and persisted.** `/overseer:start "goal" [--model opus|auto]`
  → `program.sh init --model` (default `opus`), printed by `status`, honoured by `resume`.
  Every dispatch file carries a `MODEL:` line and `dispatch check` refuses one without it
  or above the tier: under `opus` no seat runs above opus; under `auto` judgment seats
  (direction, adversary, reviewer) may `inherit` the session model, workers stay at opus.
  Simulation 3 ran two thirds of its subagent turns on the session model because no
  dispatch said a model and every `inherit` agent followed the session. Stated residual:
  taskmaster's own seats follow the session model under `goal`; `claude --model opus`
  holds every seat.
- **Milestone size routes the pipeline.** `milestone add --size S|M|L|XL` (default `M`),
  shown by `status`. M and up are briefed to `/taskmaster:task goal`; only S may go to one
  direct worker, and `dispatch check --milestone` WARNs when a direct worker targets an M+
  milestone with no taskmaster card index newer than its brief. "The brief is so complete
  grill would ask nothing" is named as not a reason — all three simulations said it.
- SKILL: `--tracks` when the card index has parallel groups; no filesystem-wide scans in
  discovery (`find /` ran in simulation 3); "pipeline by exception" anti-pattern.
- README: a directory-marketplace symlink install is live, not a cache snapshot.
- Harness: 179 cases (tier refusal and default, size default and refusal, `MODEL:` missing /
  above tier / below tier / `inherit` under `auto`, size WARN on M with and without an
  index, none on S, none for a reader).

## 0.1.1 — 2026-09-12

- `scripts/skill-path.sh`: the CLI route took the first enabled install of a plugin across
  every project on the machine — `claude plugin list --json` is not cwd-scoped — so from a
  project holding taskmaster 0.41.9 it pinned another project's 0.41.7 (simulation 3 pinned
  ui-ux 0.20.3 against an installed 0.21.0). It now takes only a row whose `projectPath` is
  this project (`--project`, else the git toplevel, else the cwd) or a user-scope row; the
  harness drives the route through a fake `claude`.

## 0.1.0 — 2026-09-11

- New plugin: `/overseer:start`, `/overseer:resume`, `/overseer:status`; the `overseer`
  skill with references for state, capability map, product judgment, dispatch prompts and
  acceptance; `scripts/program.sh` (state machine with the seven-kind acceptance gate) and
  `scripts/capability-scan.sh` (installed plugins per phase across user/project/local scope);
  a SessionStart announcer hook; harness `scripts/__tests__/program.test.sh`.
- Hardened after the first simulation's review: nine required evidence kinds (`keyboard`,
  `motion` added), every required kind file-backed and re-checked at accept; `--hands-off`
  needs `--reason` and an ASSUMED decision before accept; `decision add --assumed
  --alternative`; `dispatch check` refuses a prompt with a reworded preamble, no scope lock,
  no verify or no existing skill path; `close` archives a finished program; parked counts as
  closed for `next`, the hook and `init`; state writes are locked and fail loudly (exit 5);
  detached HEAD defaults the base to `main`; the hook resolves the git toplevel from a
  subdirectory; the scan reports CI workflows against the base branch and no longer offers
  the official `playwright` plugin as a marketplace install.
- After the second simulation: `dispatch check --kind reader|reviewer` for read-only
  dispatches, WARNs for state files named without an absolute path and for a prompt that
  may start a dev server without stopping it; `scripts/skill-path.sh`; worker template gains
  STATE FILES, SIBLINGS and a DESIGN block, plus a direction template that sizes the engine
  before it writes a budget and carries the product vocabulary; acceptance adds the
  built-assets rule (kill dev servers, delete the hot file), the untracked-paths check,
  the product-truth check and the overseer's own look; `references/worktree.md`; the
  capability scan's CI branch parse works on BSD sed.
- After the review of simulation 2's record: `close` rewrites every evidence path in the
  archived `program.json` to the archive (the record used to point at 35 files that no longer
  existed there); `dispatch check --kind followup` for a second message to a live worker
  (two were sent ungated in simulation 2); the reference and state docs name both.
- Improvement plan 2, step 1: `kinds.tsv` routing table — `milestone add --kind`, `dispatch
  check --milestone` WARNs on unpinned groups and on a dense card, `accept` refuses while a
  group is unpinned (uninstalled groups WARN); `init` refuses a Claude session opened in
  another project unless `--foreign-session "<why>"` records it (both simulations ran that
  way unnoticed); the reviewer template states read-only and is saved as a dispatch.
- Improvement plan 2, step 1b: milestone `history` stamps and a wall-time column in
  `status`; `program.sh log` (timeline generated from the record); `suggestion add` and
  `suggestions.md` printed at close; `close` refuses divergent done branches without a done
  `integration` milestone (kinds.tsv row) or `--divergent-ok`; close prints installed
  plugins no dispatch pinned; brief carries "primitives to add first", worker template an
  OWNER line and a consumer check; product-judgment lists the starter's known defects;
  acceptance walks an integration milestone across features.
- After simulation 3 (first project-session run, headless): close prints suggestions without
  a stray pipe, counts `AGENT:` lines so an agent-only plugin is not reported as never used,
  and prunes other plugins' hook scratch dirs from the archive; `game` kind; the Vite starter's
  known defects; the keyboard-walk focus note in acceptance.
