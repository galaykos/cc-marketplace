# brain — roadmap

Durable record of intent. Detailed design/specs were drafted in `taskmaster-docs/`
(gitignored, ephemeral) — **do not build Phase 1b from that frozen snapshot.** Re-grill
against the then-current code when the time comes. This file preserves the *decisions*;
the *details* are meant to be regenerated fresh.

## Shipped — Phase 1a (tracer, map-only)

Auto codebase map: `brain/INDEX.md` (areas → key files/classes/entrypoints), built by the
`indexer` agent via `/brain index`, injected at `SessionStart`, read via `/brain` and
`/brain <area>`. Single map-level git-HEAD staleness stamp. Discoverability nudge when
enabled but no map. Standalone, opt-in, fail-open, writes only under `brain/`.

## Planned — Phase 1b (value slice: anchored notes)

The original "save info + anchor" want, cut to the low-fragility core:

- **Notes** — `brain/<area>/<slug>.md`, frontmatter `area, anchors, tags, stamp, links?`,
  body = the note (a gotcha, a "why", a decision-in-context).
- **File-anchors** — `file:<path>` only. Unambiguous; **no `sym:` resolution** (that's the
  fragile grep contract — deferred).
- **Freshness** — per-anchored-file content hash (`shasum`), read-time drift → coarse ⚠
  ("file changed since this note — verify"). Never silently trust a stale note.
- **Commands** — `/brain note` (capture), `/brain <area>` extended to surface the area's notes.
- **Skill** — `brain-notes` (note format + the anchor/hash procedures Claude runs).

## Deferred (higher fragility / speculative)

- **Sym-anchors** (`sym:Name`, 0/N/moved/qualified resolution) — precision, but a fragile,
  agent-reliability-dependent grep contract (red-team holes H2/H3/H6/H12).
- **Backlink graph over sibling `.md`** (taskmaster-docs, hindsight, ADRs, skills) — the
  "unify all knowledge" vision. Speculative + coupled to other plugins' formats.
- **Phase 2** — canvas · kanban · graph viz · hook auto-refresh · cross-project · embeddings.

## Why staged this way

The tracer proves orientation value *before* taking on the note layer's maintenance burden
and agent-reliability fragility. Building 1b on an unproven base bets against that strategy.

## Go / revisit trigger

Use the map in real work. If you catch yourself wanting to jot a gotcha and there's nowhere
to put it → 1b earned its keep, build it (re-grilled against current code). If you never
reach for that → 1b was never worth the fragility. Let usage decide, not momentum.

## Invariants to keep in any phase

Index-in-place (never write outside `brain/`) · agent-instruction-driven (the only shipped
script is the fail-open `SessionStart` hook) · honest freshness (flag stale, never silently
trust) · committed vault (shared, but `INDEX.md` is a derived artifact — regenerate, don't
hand-merge).
