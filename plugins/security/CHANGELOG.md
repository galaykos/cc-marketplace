# Changelog — security

Consumer-facing changes only. Newest first. Started at 0.12.6; earlier versions have no entries rather than invented ones.

## 0.12.7 — 2026-10-28

- **Comments cut to what a reader needs; behaviour unchanged.** `hooks/write-scan.sh` (shared-block comments): each keeps a header saying what it does and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/, which an install does not contain.

## 0.12.6 — 2026-10-28

- **Hook comments cut to what a reader needs; behaviour unchanged.** `hooks/write-scan.sh`: each keeps a header saying what it catches and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/plugin-security.md, which an install does not contain. Every hook parses to the same code as before (comments ignored).
