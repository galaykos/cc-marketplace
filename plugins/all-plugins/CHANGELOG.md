# Changelog — all-plugins

Consumer-facing changes only. Newest first. Started at 0.7.1; earlier versions have no entries rather than invented ones.

## 0.7.3 — 2026-10-28

- **The `/all-plugins:install` and `/all-plugins:uninstall` descriptions now read in short, plain sentences.** Same scopes, flags and exit codes; both commands still run only when typed.

## 0.7.2 — 2026-10-28

- **Comments cut to what a reader needs; behaviour unchanged.** `scripts/all-plugins.sh`: each keeps a header saying what it does and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/, which an install does not contain.

## 0.7.1 — 2026-10-28

- **Hook comments cut to what a reader needs; behaviour unchanged.** `hooks/hint.sh`: each keeps a header saying what it catches and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/plugin-all-plugins.md, which an install does not contain. Every hook parses to the same code as before (comments ignored).
