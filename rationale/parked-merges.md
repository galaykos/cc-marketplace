# Parked merges — reviewed 2026-07-27, deliberately not executed

Suite review of taskmaster-suite's 30 members: 20 carry teeth (agents/hooks —
C16 bar, no merge), 9 pure prose. Two cleared the bar (high affinity, zero
teeth traded, small residuals) and are PARKED for adopt-as-touched, not a
sweep — session evidence (W6.2) showed merges move context tokens rather than
cut them, so the benefit is maintenance surface only:

- **sql → database** — statement floor into design floor; database already
  cites "dialect audits → sql" and ships the engineer agent to host. Carry
  /sql:review across before removal. Suites listing sql: db-suite, php-suite,
  taskmaster-suite.
- **stack-scan → packages** — installed-inventory into dependency hygiene;
  packages' boundary already cites stack-scan. Carry /stack-scan:report.
  Residual sweep: many plugins cite "stack-scan's inventory" in prose.

Rejected with reasons: api-design+api-docs-first (their partition IS routing:
design-yours vs consume-theirs), orchestration→task-runner (hook port cost,
sibling citations), git-workflow / claude-authoring / plugin-scout / dev-env /
resilience (distinct identities or fresh merge host).

Mechanics when executed: scripts/remove-plugin.sh <name> --merge-into <host>
--apply, commands carried BEFORE removal, suite deps fixed by hand (script
only WARNs), host description rewritten in plugin.json AND marketplace.json,
generate.sh --write, budget re-baseline reviewed key by key.
