---
description: Read and build the project brain codebase map — /brain prints the map, /brain <area> prints one area, /brain index [area] builds or refreshes it.
argument-hint: "[area|index]"
---

# /brain

Read or build the **brain map** — the committed `brain/INDEX.md` that indexes the
project's areas, key files, and notable classes/entrypoints.

Parse the first token of `$ARGUMENTS` and act:

## `index` — build or refresh (reserved word)

`/brain index` or `/brain index <area>`:

- Dispatch the **indexer** agent (this plugin's `agents/indexer.md`) to (re)build the
  map. Pass the `<area>` through when given; otherwise rebuild the whole map.
- If `brain/` does not exist yet, this bootstraps it (the indexer creates
  `brain/INDEX.md`).
- Report the indexer's summary (areas written, file count, `built:` hash).

`index` is a reserved subcommand — it is never treated as an area name.

## `<area>` — print one area

Any other non-empty argument is an area name:

- Print that area's `## <area>` section from `brain/INDEX.md` (and its `brain/<area>.md`
  detail file if one exists).
- If no such area exists, print `no such area: <area>` followed by the list of known
  area names (the `## ` headings in `brain/INDEX.md`).

## empty — print the whole map

No argument:

- Print `brain/INDEX.md`.
- If it does not exist, tell the user to run `/brain index` to initialize the map.

## Hard rule

Read `brain/` and (via the indexer) the codebase only. **Never modify, move, or delete
any file outside `brain/`.** This command surfaces and builds the map; it does not touch
source, docs, or sibling plugins.
