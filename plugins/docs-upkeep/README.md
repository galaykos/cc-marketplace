# docs-upkeep

Documentation drift prevention: after any change, sync README claims, changelog
entries, ADR links, and API docs with what the code now actually does — docs
updated in the same change that invalidated them.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install docs-upkeep@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/docs-upkeep:check [scope]` | Scan the current change (or repo) for documentation drift — README claims, changelog gaps, stale examples, dead links — and list exact fixes |

## Example

```bash
/docs-upkeep:check                  # scan the current change (branch diff if the tree is clean)
/docs-upkeep:check README.md docs/  # scan named files, dirs, a commit range, or "repo"
```

Findings come back one line per drift (`doc-path:line — what drifted — the
fix`), grouped by document, with an offer to apply the fixes so doc updates
ride in the same change that caused them.

The bundled `docs-upkeep` skill also fires during normal work: when a change
alters behavior, interfaces, setup steps, or commands, it pushes to update the
documentation that just became a lie in the same change, before it merges.

## Pairs well with

- **code-review** — catch correctness bugs in the same pre-merge pass that catches doc drift
- **git-workflow** — run a drift check before finishing and merging a branch
