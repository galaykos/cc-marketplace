# Changelog — brain

Consumer-facing changes only. Newest first. Started at 0.4.6; earlier versions have no entries rather than invented ones.

## 0.5.0 — 2026-11-14

- **The map moved from `brain/` to `.cc-artifacts/brain/`**, the one folder a project gitignores for what plugins write during development. `/brain index` writes only there. A map built before this version still works: the SessionStart hook reads `brain/INDEX.md` until `.cc-artifacts/brain/` exists, and the next `/brain index` copies `brain/` into it once and never touches `brain/` again. A commit that changes only either folder is not drift. Standing: gate for the hook (`scripts/__tests__/inject-hook.test.sh`, 16 cases, three of them the fallback); agent-graded for the indexer's copy.
- **The map is no longer described as committed.** Ignored with the rest of `.cc-artifacts/`, it is local to each clone; the README says how a team tracks it instead. The staleness hint reads the commit the map was built against, so it works either way.
- **Two markers from other plugins are read from both places.** The approaches marker: `.cc-artifacts/approaches/deliberated.json`, else `.claude/approaches/deliberated.json`. The task-runner `scope.json` that turns the self-heal back into an offer: under `.cc-artifacts/task-runner/` or `.claude/task-runner/`. Standing: gate for the hook (`inject-hook.test.sh` cases 5 and 5b); agent-graded for the marker.

## 0.4.6 — 2026-10-28

- **Hook comments cut to what a reader needs; behaviour unchanged.** `hooks/inject.sh`: each keeps a header saying what it catches and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/plugin-brain.md, which an install does not contain. Every hook parses to the same code as before (comments ignored).
