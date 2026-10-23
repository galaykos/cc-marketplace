# Changelog — resilience

Consumer-facing changes only. Newest first.

**Starts at 0.7.3.** Nothing before this entry is recorded here, deliberately: the
releases up to 0.7.2 were never written down, and inventing their history in the file
whose job is history would be worse than the gap. Adding this file opts the plugin into
`scripts/check-version-bumps.sh`'s changelog gate permanently — every bump from here on
must carry an entry.

## 0.9.0 — 2026-10-23

### Changed
- **Six skills merged into one, `resilience`.** Each old skill body moved verbatim into a reference of the new skill, minus its frontmatter and its core rule, which the skill body now carries with a table that says which reference a change selects: `resilience-design` → `references/timeouts-retries.md`, `error-handling-design` → `error-handling.md`, `concurrency-safety` → `concurrency.md`, `observability-design` → `observability.md`, `performance-tuning` → `performance.md`, `event-driven` → `messaging.md`. Two sentences in the error-handling and observability references, which split ownership of a catch block between them, were dropped because the skill body states that split once. The listing carries one description instead of six. Standing: recorded; the routing table is agent-graded at review time (`/resilience:review` names the references it read on its `Checked:` line).
- **`/resilience:review --concern <name>` reads the matching reference**; without `--concern` it reads `references/timeouts-retries.md` and each reference whose surface the scope touches. The `observability-engineer` and `performance-engineer` workers take the `resilience` skill as their rubric and name their reference. `lane.tsv` declares one skill row in place of six. The service-boundary defer that pointed at code-architecture's design skill now names its `system-architect` agent, since that skill was removed in code-architecture 0.19.0.
- Unmeasured: whether one skill with references routes as well as six skills did. The five control-ceiling eval cases cannot show it; `liveness-probe-dependency` now reads its rule from `references/observability.md` and its delta is still unmeasured.

## 0.8.1 — 2026-10-15

- **`/resilience:review`'s hand-up says what the fan-in loads now.** code-review 0.33.0 stopped loading all six rubrics on every review: `/code-review:review` loads only the ones the diff's content selects. The command's hand-up, the README and a `lane.tsv` comment said "all six" and now say "the ones the diff selects". No behaviour changed here.

## 0.8.0 — 2026-10-06

- **`performance-tuning` states the current web-vitals API.** Its Core Web Vitals line now says INP replaced FID on 2024-03-12, and that field code reads the metrics with `web-vitals`' `on*` functions (`onLCP`, `onCLS`, `onINP`, each taking a callback, since v3 in 2022): `get*` was removed in v4 and `onFID` in v5 (2025-05), so a fix writes neither. Current on npm, 2026-10-06: 6.2.3.
- **Standing: agent-graded** — `/resilience:review --concern performance` can flag a `get*` or `onFID` call; no script checks the API names. Residual: the version is as of 2026-10-06.
- **Credit and effect.** Found while reviewing freshtechbro/claudedesignskills @1da73feb (MIT, © 2025 Claude Skills Project); rewritten here, not copied. Unmeasured: whether it changes what the model or the `performance-engineer` agent writes. No eval with a control arm covers it.

## 0.7.7 — 2026-10-04

- The `observability-engineer` and `performance-engineer` agents' code-shape rule adds required call order to the docblock facts a signature cannot state (units, ownership, what throws). Its effect on what the agents write is unmeasured. No hook or script changed.

## 0.7.6 — 2026-09-30

- Eval cases with an `llm` grader now declare `runs: 3` (was 1). Three runs are the fewest that can tell a regression from a flake, and the marketplace's eval load gate now fails a case with fewer.

## 0.7.5 — 2026-09-23

### Changed
- **Prompt audit (Claude Code's built-in `claude-api` skill, `prompt-audit` subcommand; target Opus 5.5 / Fable 5.1):** `/resilience:review` drops the "until 2026-09-14 five of them were separate slash commands" note. Method: that built-in skill's `shared/prompt-audit.md`; the full report and diff are in the maintainers' working area, not shipped.

## 0.7.4 — 2026-09-22

### Added
- **`evals/liveness-probe-dependency`, the first case in this suite with headroom.** A
  Deployment whose `livenessProbe` and `readinessProbe` both hit `/health`, and a
  `/health` handler that pings Postgres — six replicas behind one primary. The control
  arm reads that as a well-instrumented service; `observability-design` carries the <!-- removed-ok -->
  inversion ("never check dependencies here: a database blip becomes a restart storm")
  and the two-endpoint split that fixes it. The grader requires the consequence stated
  as a consequence and fails a response whose only advice is a bigger `failureThreshold`
  or a `startupProbe`. `runs: 5`; the README carries the paid invocation with
  `--ablation with-without` and states plainly that the other five cases sit at the
  control ceiling and can only ever be regression guards. The delta is unmeasured.
- README `## Evals` section: the exact paid invocation, why no `--allow-tools` or
  `--scaffold` grant is needed, and the free load check CI actually runs.

## 0.7.3 — 2026-09-22

### Added
- `lane.tsv` rows for all six skills. The plugin declared its command and its two
  agents and none of its skills, while `/code-review:review` fans all six in — so the
  artifacts a reader actually meets had no declared territory. `observability-design` <!-- removed-ok -->
  and `performance-tuning` share their agent's `owns` and yield to it: the skill is the <!-- removed-ok -->
  rubric, the agent is the hand.
