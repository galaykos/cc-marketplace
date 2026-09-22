# Changelog — resilience

Consumer-facing changes only. Newest first.

**Starts at 0.7.3.** Nothing before this entry is recorded here, deliberately: the
releases up to 0.7.2 were never written down, and inventing their history in the file
whose job is history would be worse than the gap. Adding this file opts the plugin into
`scripts/check-version-bumps.sh`'s changelog gate permanently — every bump from here on
must carry an entry.

## 0.7.3 — 2026-09-22

### Added
- `lane.tsv` rows for all six skills. The plugin declared its command and its two
  agents and none of its skills, while `/code-review:review` fans all six in — so the
  artifacts a reader actually meets had no declared territory. `observability-design`
  and `performance-tuning` share their agent's `owns` and yield to it: the skill is the
  rubric, the agent is the hand.
