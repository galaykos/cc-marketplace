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

A card's `Files` entries are free-text (`src/billing/invoice.ts:88 (current: …)`).
Normalize each to a canonical repo-relative path:

1. Strip a trailing `:line` (and `:line-range`) suffix.
2. Strip any parenthetical annotation `(…)` and surrounding whitespace.
3. Resolve to a repo-relative path (no `./`, no absolute prefix).
4. A directory entry (trailing `/`) is a **prefix**: it overlaps any path beneath it.

The milestone's file-set is the set of normalized paths across all its cards.

## Disjointness

Two milestones are **file-disjoint** when their normalized file-sets have an empty
intersection, treating a directory entry as covering everything under its prefix.
`foo.ts:88` and `foo.ts:120` normalize to the same `foo.ts` and therefore **overlap**
(they are NOT disjoint) — this is the false-negative the normalization exists to prevent.

## Dependency roll-up

Milestone B **depends on** milestone A if any card in B lists (transitively) a
`Depends on` a card in A. A milestone is *launchable* only when every milestone it
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
