# Changelog

## 0.2.1 — 2026-09-13

Simulation 4 (a home-loan landing page on the same Vite starter, headless, hands-off,
session and tier opus) was the first run to take the intended path end to end: taskmaster
briefed, task-runner executing, every dispatch gated, every seat at opus, zero app code
from the main thread, eleven evidence kinds from a real Chromium walk. It also stopped
after m1 of 3 and cost $76.60 / 125 min against simulation 3's $37 / 70 min for two.

- **The loop continues.** `start.md` step 5 and SKILL § Deliver 7: after Finish,
  `program.sh next` — hands-off delivers every runnable milestone in the session;
  interactive asks once per milestone whether to continue now or `/overseer:resume` in a
  fresh session (the main thread, not the workers, held three quarters of the tokens).
- **`goal` is Extreme Boost.** SKILL § Deliver 3 and `dispatch-prompts.md` § Brief say
  what `/taskmaster:task goal` buys (spec red-team, negative controls, 2–3 reviewers per
  card, a 3-round code red-team) and what it cost on an M; interactive runs brief
  `/taskmaster:task <brief>` without the token below L. `dispatch check --milestone`
  WARNs when an S/M milestone's card index carries a `Goal:`/`Ultra:` marker (not on L).
  Residual: a hands-off run has no autonomous route without the boost until taskmaster
  grows one; the cost is a decision row.
- **Installed is not reachable.** A project's first-ever session registers
  `enabledPlugins` without loading them (62 slash commands, 233 after a restart); the scan
  reads the same files. SKILL § Discover 2 and `capability-map.md` say to check the table
  against the session's own Skill listing and reload or restart before any milestone is
  registered — the first launch of simulation 4 would otherwise have hand-dispatched again.
- Skipping an installed command (`/stack-scan:report`, `/approaches:size`,
  `/security:review` in sim 4) is named in the decision triggers; acceptance step 1 names
  other plugins' `.claude/` scratch as an untracked path to explain.
- Harness: 183 cases (+4: boost WARN on an M index with and without the marker, not on L,
  and not alongside the skipped-pipeline WARN).

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
