---
description: Read and build the project brain codebase map — /brain prints the map, /brain <area> prints one area, /brain index refreshes changed areas (--full rebuilds all).
argument-hint: "[area | index [--full|<area>]]"
---

# /brain

Read or build the **brain map** — a terse `brain/INDEX.md` table of contents (one line per
area, injected at session start) plus per-area `brain/<area>.md` detail files (files, key
classes, meaning) loaded on demand.

Parse the first token of `$ARGUMENTS` and act:

## `index` — build or refresh (reserved word)

Dispatch the **indexer** agent (this plugin's `agents/indexer.md`) with the mode implied by
the argument after `index`:

- **no argument** → **incremental** (default): the indexer diffs what changed since the map's
  `built:` hash and re-indexes only the affected areas. If no `brain/` exists yet, it bootstraps
  a full build instead.
- **`--full`** (or `all`) → full rebuild: re-pick areas and rewrite everything. Use after adding
  a whole new subsystem — this is the only mode that discovers new areas.
- **`<area>`** → rebuild just that one area.

Report the indexer's summary (mode, areas refreshed, any unassigned new files it suggests
`--full` for, `built:` hash).

`index`, `--full`, and `all` are reserved — never treated as area names.

## `<area>` — print one area

Any other non-empty argument is an area name:

- Print that area's **`brain/<area>.md` detail file** (files, key classes, meaning) — this is
  where the depth lives.
- If no detail file exists but the area appears in `brain/INDEX.md`, print its one-line entry
  and note no detail file was built (suggest `/brain index <area>`).
- If the area is unknown (no detail file and no `INDEX.md` line), print `no such area: <area>`
  followed by the known area names (the `- <area>` lines in `brain/INDEX.md`).

## empty — print the whole map

No argument:

- Print `brain/INDEX.md`.
- If it does not exist, tell the user to run `/brain index` to initialize the map.

## Hard rule

Read `brain/` and (via the indexer) the codebase only. **Never modify, move, or delete
any file outside `brain/`.** This command surfaces and builds the map; it does not touch
source, docs, or sibling plugins.
