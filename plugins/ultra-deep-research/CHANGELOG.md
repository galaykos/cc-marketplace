# Changelog

All notable changes to the ultra-deep-research plugin.

## 0.6.2

### Changed
- **The verification loop states its structural limitation**: refutation is
  one-directional — the researcher never sees or answers a refutation, so a
  claim killed on a misread source dies undefended. The majority-vote panel is
  named as the mitigation, not a cure.

## 0.6.1

### Added
- **`lane.tsv`** — declares territory and phase for this plugin's researcher and
  verifier agents, so `pc_lanes_territory` can prove neither collides with another
  plugin's reviewer on the same job.

## 0.6.0

### Fixed

- **The ultra pipeline never spawned this plugin's own agents.** The recipe in
  `skills/ultra-deep-research/references/orchestration.md` says "spawn one
  `researcher` per facet" and "spawn `verifier` agents", then showed
  `agent(researcherPrompt(facet), {schema, phase})` — a `Workflow` `agent()` call
  with no `agentType`, which spawns the generic workflow subagent. The prompt
  arrived; `agents/researcher.md` and `agents/verifier.md` — source tiering, the
  verbatim-quote requirement, refute-by-default, never-fabricate-a-URL — did not.
  The transcript of an unbound run is indistinguishable from a bound one, so the
  panel read as if it had run under those contracts.

  Both calls now pass `agentType`, and the sample says why it is not optional.

### Notes

- `scripts/validate.sh` gates this from now on: a shipped `agent(<args>)` sample
  that names an agent this marketplace ships must bind it with `agentType`
  (`pc_dispatch_binding`, fixtures under
  `scripts/smoke/validate-fixtures/dispatch-binding/`). The standard
  parallel-Agent path was never affected — it dispatches by `subagent_type`.
