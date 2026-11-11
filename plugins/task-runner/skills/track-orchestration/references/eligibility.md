# Milestone eligibility

How the orchestrator decides which milestones are **track-eligible** (may run
concurrently) vs which run **serially** in the main tree. Read by
`track-orchestration/SKILL.md`.

## Inputs

Each milestone in `00-INDEX.md` carries a `Files:` line — the normalized union of its
cards' declared `Files` (emitted by task-cards; see
`taskmaster/skills/task-cards/references/milestone-file-sets.md`). If the index has no
per-milestone `Files:` line, tracks mode cannot classify — fall back to serial with a
warning.

## Normalization (before any comparison)

`scripts/plan-overlap.sh --index <00-INDEX.md>` applies this page and prints each milestone's
verdict. A `Files` entry is free text (`src/billing/invoice.ts:88 (current: …)`): it loses its
`:line` suffix, any `(…)` annotation and a leading `./`; a directory entry (trailing `/`)
overlaps every path beneath it. The milestone's file-set is those paths across all its cards.

## Disjointness

Two milestones are **file-disjoint** when their file-sets share no path. `foo.ts:88` and
`foo.ts:120` are both `foo.ts`, so they overlap.

## Dependency roll-up

Milestone B **depends on** milestone A if any card in B lists (transitively) a
`<depends-on>` a card in A. A milestone is *launchable* only when every milestone it
depends on has already **merged**. Cross-milestone dependencies never run concurrently;
they land in a later wave.

## Shared / registry files → non-eligible

A milestone that touches any **shared or registry file** is non-eligible and runs
serially (editing these concurrently is unsafe and they are the integration surface).
The default shared set:

```
marketplace.json
README.md  CHANGELOG.md  ROADMAP.md        (repo root)
package.json  *.lock  (package-lock.json, composer.lock, yarn.lock, …)
.github/workflows/**
scripts/**
```

## Verdict

A milestone is **track-eligible** iff ALL hold: its file-set is disjoint from every
other candidate's, it touches no shared/registry file, and its dependency milestones
have merged. Everything else runs serially, in dependency order, by the orchestrator in
the main tree — interleaved with the waves. This classification never splits a
milestone's cards: the unit is the whole milestone.
