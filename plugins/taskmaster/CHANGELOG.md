# Changelog — taskmaster

Consumer-facing changes only. Newest first. Started at 0.50.4; earlier versions have no entries rather than invented ones.

## 0.50.6 — 2026-10-28

- **A bare `goal` first token is now described as what it does: boost + hands-off, the same as `ultra-goal`.** The `ultra` skill's description and trigger list, and the preambles of `/taskmaster:task`, `/taskmaster:redteam`, `/taskmaster:brainstorm` and `/taskmaster:coverage`, said hands-off only; each command's next sentence already ran it as `ultra-goal`. The `ultra` description also reads in short, plain sentences, with the same tokens and markers.
- **The `experience-walkthrough`, `erd` and `coverage-check` skills' descriptions now read in short, plain sentences.** Same triggers; each keeps the words the model matches it on.

## 0.50.5 — 2026-10-28

- **Comments cut to what a reader needs; behaviour unchanged.** `scripts/card-lint-record.sh`, `scripts/card-shape-lint.sh`, `scripts/goal-ledger-check.sh`, `scripts/phase-sentinel.sh`, `scripts/preview-cleanup.sh`, `scripts/skills-stamp-lint.sh`, `scripts/spec-ledger-lint.sh`, `scripts/theme-axis-check.py`, `scripts/verify-teeth-lint.sh`, `skills/visual-decisions/assets/serve.py`; `hooks/card-lint-observe.sh`, `hooks/clarify-gate.sh`, `hooks/preview-guard.sh` (shared-block comments); `hooks/remind.sh`, `hooks/ultra.sh` (generated hooks): each keeps a header saying what it does and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/, which an install does not contain. `--help` of `scripts/card-shape-lint.sh`, `scripts/goal-ledger-check.sh`, `scripts/skills-stamp-lint.sh`, `scripts/spec-ledger-lint.sh`, `scripts/verify-teeth-lint.sh` no longer prints the history prose; usage, flags and exit codes are unchanged.

## 0.50.4 — 2026-10-28

- **Hook comments cut to what a reader needs; behaviour unchanged.** `hooks/card-lint-observe.sh`, `hooks/clarify-gate.sh`, `hooks/preview-guard.sh`: each keeps a header saying what it catches and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/plugin-taskmaster.md (preview-guard.sh, ui-ux's twin: plugin-ui-ux.md), which an install does not contain. Every hook parses to the same code as before (comments ignored).
