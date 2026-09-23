# Changelog

All notable changes to the ultra-deep-research plugin. Entries start at 0.6.0, when
this file was created; earlier releases have no entries rather than invented ones.
The verdict lint referenced below landed in 0.5.0, before that.

## 0.7.2 — 2026-09-23

### Changed
- **Prompt audit (Claude Code's built-in `claude-api` skill, `prompt-audit` subcommand; target Opus 5.5 / Fable 5.1):** orchestration.md no longer tells the orchestrator to paste prompt-hardening rules the skill removed in 0.6.x — the agent files carry them; the 0.6.0 references and "used to live here" note are gone. Method: that built-in skill's `shared/prompt-audit.md`; the full report and diff are in the maintainers' working area, not shipped.

## 0.7.1 — 2026-09-16

### Changed
- **README gains a boundary section with the host's built-in `/deep-research`** (trend
  audit C1, `rationale/marketplace-trend-audit-2026-09-16.md`): what the bundled
  workflow does, read from the 2.1.273 binary — one fixed pass, 5 angles, 15 sources, 25
  claims through a 3-vote panel, a structured object returned in-session and no file —
  and what this plugin adds (the contradiction ledger, the gated `confirmed`, `--ultra`
  loop-until-dry, the report file, the single-document engine), then when to reach for
  which. Which of the two fires on "deep research" is still unmeasured, and the section
  says so.
- **`scripts/verdict-lint.sh` is re-tiered from "one mechanical gate" to agent-graded**
  (endgame review §5.6 / audit K2): only the skill's and command's prose invokes it, no
  hook or CI step runs it over a live run, and the fixture harness proves the script,
  not that a run called it.
- `agents/researcher.md` and `agents/verifier.md` each state in the body why WebSearch
  and WebFetch are granted beyond the six default tools (audit E4) — the reason
  `authoring-agents` requires and neither carried.

## 0.7.0 — 2026-09-15

### Changed
- **The single-document mode is now reachable from the skill's description.** The
  plugin has carried a whole second engine since `references/local-corpus.md` shipped —
  hand it a contract, RFP, standard, filing or long PDF and it swaps corroboration for
  coverage — and the description, which is the only thing that decides whether a skill
  fires, named none of those words. The mode shipped reachable only by naming the
  plugin. `contract, RFP, standard, filing, PDF` are in the description now, the fork
  is declared at step 1 of the loop instead of being wedged between steps 6 and 7, and
  the README carries a two-engine table. **Budget-neutral by construction**: the four
  metered descriptions total 878 bytes against 893 before, so the always-on baseline
  falls by 3 tokens. Honest limitation — `rationale/2026-09-15-listing-eviction-probe.md`
  measured description TEXT as making no difference to firing (47/50 both arms) with a
  meaningful skill name; `ultra-deep-research` is not a name that suggests reading a
  contract, which is why this was worth the bytes, but the benefit is reasoned, not
  measured.
- **`/ultra-deep-research:research` is a thin entry point again.** It restated the
  skill's whole loop, and the copy had already drifted: no verdict lint, no
  local-corpus fork, so invoking the command was weaker than reading the skill. It now
  resolves the depth flag, carries the caller's constraints, names the fork, and hands
  off. It also states what to do with an empty `$ARGUMENTS`, which it did not.
- **The skill body no longer keeps a third copy of the prompt-hardening rules.** Those
  rules live in `agents/researcher.md` and `agents/verifier.md`, and since 0.6.0 both
  dispatch paths bind those files, so a shard already carries them. The body now states
  what the ORCHESTRATOR owes on top — the caller's domain constraints, the confidence
  rubric, not laundering a labelled inference into a fact — and says re-pasting the
  shard rules into a prompt is wrong. Body: 140 lines → 134, with a duplicated section removed and the fork moved.

## 0.6.3

### Fixed
- **"Local corpus, one authoritative source" is a section again.** It was inserted
  between steps 6 and 7 of the numbered loop with no heading or blank line, so an entire
  alternate operating mode rendered as a continuation of list item 6. Not caused by the
  line cap — it landed 34 lines under it.

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
