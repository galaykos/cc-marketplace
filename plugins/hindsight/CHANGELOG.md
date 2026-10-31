# Changelog — hindsight

Consumer-facing changes only. Newest first. Started at 0.12.2; earlier versions have no entries rather than invented ones.

## 0.12.4 — 2026-10-28

- **The `harvest` skill's description now reads in short, plain sentences.** Same triggers and outputs; it keeps the words the model matches it on.

## 0.12.3 — 2026-10-28

- **Comments cut to what a reader needs; behaviour unchanged.** `scripts/claude-md-check.sh`, `scripts/outcome.sh`; `hooks/skill-use.sh` (shared-block comments): each keeps a header saying what it does and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/, which an install does not contain.

## 0.12.2 — 2026-10-28

- **Hook comments cut to what a reader needs; behaviour unchanged.** `hooks/collect.sh`, `hooks/skill-use.sh`: each keeps a header saying what it catches and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/plugin-hindsight.md, which an install does not contain. Every hook parses to the same code as before (comments ignored).
