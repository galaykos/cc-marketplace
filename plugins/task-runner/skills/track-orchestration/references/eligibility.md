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

## Cards needing an MCP tool → non-eligible

A milestone holding a card tagged `asset` (`taskmaster/skills/task-cards/references/agent-tags.md`:
its own run calls a generation or modelling tool, CLI or MCP) or a card whose text names an MCP
tool (`mcp__…`) is non-eligible and runs serially. Track workers hold no MCP tools; the serial
path runs such a card inline in the main thread (`task-execution/references/routing.md` step 2).
The tag does not tell a CLI from an MCP server, so every `asset` card counts.
`plan-overlap.sh --index` reads the `<agent>` tag (`**Agent:**` on a legacy card) and the first
`mcp__` name of each card on the milestone's `Cards:` line. Standing: **gate where run** for those
two signals; a card that needs an MCP tool, carries another tag and names no `mcp__` tool is
**agent-graded** — the orchestrator has to spot it.

## Verdict

A milestone is **track-eligible** iff ALL hold: its file-set is disjoint from every
other candidate's, it touches no shared/registry file, it holds no card needing an MCP
tool, and its dependency milestones have merged. Everything else runs serially, in
dependency order, by the orchestrator in the main tree — interleaved with the waves.
This classification never splits a milestone's cards: the unit is the whole milestone.
