# Changelog — taskmaster

Consumer-facing changes only. Newest first. Started at 0.50.4; earlier versions have no entries rather than invented ones.

## 0.50.4 — 2026-10-28

- **Hook comments cut to what a reader needs; behaviour unchanged.** `hooks/card-lint-observe.sh`, `hooks/clarify-gate.sh`, `hooks/preview-guard.sh`: each keeps a header saying what it catches and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/plugin-taskmaster.md (preview-guard.sh, ui-ux's twin: plugin-ui-ux.md), which an install does not contain. Every hook parses to the same code as before (comments ignored).
