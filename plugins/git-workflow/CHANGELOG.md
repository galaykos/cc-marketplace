# Changelog — git-workflow

Consumer-facing changes only. Newest first. Started at 0.13.5; earlier versions have no entries rather than invented ones.

## 0.13.5 — 2026-10-28

- **Hook comments cut to what a reader needs; behaviour unchanged.** `hooks/merge-checks.sh`, `hooks/no-ai-trailer.sh`: each keeps a header saying what it catches and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/plugin-git-workflow.md, which an install does not contain. Every hook parses to the same code as before (comments ignored).
