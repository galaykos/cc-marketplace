# Changelog

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
