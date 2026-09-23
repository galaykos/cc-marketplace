# Changelog — resilience

Consumer-facing changes only. Newest first.

**Starts at 0.7.3.** Nothing before this entry is recorded here, deliberately: the
releases up to 0.7.2 were never written down, and inventing their history in the file
whose job is history would be worse than the gap. Adding this file opts the plugin into
`scripts/check-version-bumps.sh`'s changelog gate permanently — every bump from here on
must carry an entry.

## 0.7.4 — 2026-09-22

### Added
- **`evals/liveness-probe-dependency`, the first case in this suite with headroom.** A
  Deployment whose `livenessProbe` and `readinessProbe` both hit `/health`, and a
  `/health` handler that pings Postgres — six replicas behind one primary. The control
  arm reads that as a well-instrumented service; `observability-design` carries the
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
  artifacts a reader actually meets had no declared territory. `observability-design`
  and `performance-tuning` share their agent's `owns` and yield to it: the skill is the
  rubric, the agent is the hand.
