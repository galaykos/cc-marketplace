# Changelog — taskmaster

Consumer-facing changes only. Newest first. Started at 0.50.4; earlier versions have no entries rather than invented ones.

## 0.50.5 — 2026-10-28

- **Comments cut to what a reader needs; behaviour unchanged.** `scripts/card-lint-record.sh`, `scripts/card-shape-lint.sh`, `scripts/goal-ledger-check.sh`, `scripts/phase-sentinel.sh`, `scripts/preview-cleanup.sh`, `scripts/skills-stamp-lint.sh`, `scripts/spec-ledger-lint.sh`, `scripts/theme-axis-check.py`, `scripts/verify-teeth-lint.sh`, `skills/visual-decisions/assets/serve.py`; `hooks/card-lint-observe.sh`, `hooks/clarify-gate.sh`, `hooks/preview-guard.sh` (shared-block comments); `hooks/remind.sh`, `hooks/ultra.sh` (generated hooks): each keeps a header saying what it does and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/, which an install does not contain. `--help` of `scripts/card-shape-lint.sh`, `scripts/goal-ledger-check.sh`, `scripts/skills-stamp-lint.sh`, `scripts/spec-ledger-lint.sh`, `scripts/verify-teeth-lint.sh` no longer prints the history prose; usage, flags and exit codes are unchanged.

## 0.50.4 — 2026-10-28

- **Hook comments cut to what a reader needs; behaviour unchanged.** `hooks/card-lint-observe.sh`, `hooks/clarify-gate.sh`, `hooks/preview-guard.sh`: each keeps a header saying what it catches and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/plugin-taskmaster.md (preview-guard.sh, ui-ux's twin: plugin-ui-ux.md), which an install does not contain. Every hook parses to the same code as before (comments ignored).
