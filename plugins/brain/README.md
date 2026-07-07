# brain

A committed, Obsidian-style **codebase map** for a project. A terse `brain/INDEX.md` table
of contents (one line per area) is injected at session start so a fresh Claude session is
oriented immediately; per-area `brain/<area>.md` detail files (key files, classes,
entrypoints) load on demand via `/brain <area>`. No more re-scouting from zero.

> **Status: map-only tracer (Phase 1a).** An anchored-notes + backlink layer (notes you
> and Claude write against symbols, with staleness stamps) is planned as Phase 1b. This
> release ships the auto codebase map only.

## What it does

- **Scans the code, in place.** The map is derived from reading your source. `brain`
  **never modifies, moves, or deletes any file outside `brain/`** — not your source, not
  docs, not other plugins.
- **Auto-orients every session.** A `SessionStart` hook injects the terse `INDEX.md` table
  of contents (bounded ~30 lines / ~2 KB, delimited as project data) so Claude sees every
  area immediately; per-area depth loads on demand with `/brain <area>`.
- **Warns when stale.** `brain/INDEX.md` records the commit it was built against. If the
  repo has moved past it, the injected map carries a one-line hint:
  `⚠ brain map is behind HEAD — run /brain index to refresh.`

## Install

Install the `brain` plugin from this marketplace.

## Commands

| Command | Does |
|---------|------|
| `/brain` | Print the whole map (`brain/INDEX.md`). If none exists, prompts you to initialize. |
| `/brain <area>` | Print one area's detail. Unknown area → a not-found message listing known areas. |
| `/brain index` | **Incremental refresh** — diffs what changed since the map was built and re-indexes only the affected areas. Bootstraps a full build on first run. |
| `/brain index --full` | Force a full rebuild — re-picks areas; the only mode that discovers **new** subsystems. |
| `/brain index <area>` | Rebuild just one named area, leaving the rest untouched. |

## Freshness

The map carries a single stamp — the short commit hash it was built against. Refresh it
with `/brain index` whenever the code has moved on. There are no per-note or per-symbol
stamps in this release.

## `brain/INDEX.md` is a derived artifact

It is committed (so the whole team and every Claude session share it), but it is
**generated**, not hand-authored. On a merge conflict, do not hand-merge — discard the
conflicted `INDEX.md` and regenerate it with `/brain index`.

## Trust

`brain/` is committed repo content, at the same trust boundary as `CLAUDE.md` and skill
files — anyone who can commit to it can already commit code Claude runs. The injected map
is delimited and labeled as project data.

## Disabling

`brain` is opt-in by install. Until you build a map with `/brain index`, the only thing
it does is emit a **single one-line hint** at session start — `ℹ brain: no map for this
project yet — run /brain index to create one.` — so an enabled-but-unused install is not
silently forgotten. The `SessionStart` hook is fail-open (any error → silent exit, never
blocks a session) and writes nothing.

If you have `brain` enabled in a repo where you never intend to build a map and don't want
even that hint, disable the plugin locally (below).

To turn it off:

- **Stop the auto-inject, keep the map:** disable or uninstall the `brain` plugin in your
  Claude Code plugin settings — the `SessionStart` hook only runs while the plugin is
  enabled. This is per-developer and does **not** touch the shared `brain/` map.
- **Never start it:** just don't run `/brain index`. With no `brain/INDEX.md`, the hook
  injects nothing.

Avoid deleting a committed `brain/INDEX.md` merely to silence the hook — that removes the
shared map for the whole team. Disable the plugin locally instead.

## Not in this release (planned / out of scope)

Anchored notes and `/brain note` · per-symbol anchors and content-hash stamps · a backlink
graph over existing `.md` (taskmaster-docs, ADRs, hindsight, skills) · canvas · kanban ·
graph visualization · automatic re-indexing · cross-project maps · semantic/embedding search.

See [ROADMAP.md](ROADMAP.md) for the planned Phase 1b (anchored notes) and the go/revisit
trigger that decides when to build it.
