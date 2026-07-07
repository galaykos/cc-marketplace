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

## Dogfooding learnings (2026-07-07)

Building + running the tracer on a real Laravel/Inertia app surfaced more than a clean build
would. These update the Phase-1b calculus:

- **Agent quality is high — better than the red-team feared.** The indexer produced skill
  cross-refs, "do not hand-edit" warnings on generated code, and a sensible area taxonomy
  unprompted. The agent-instruction-driven mechanism 1b's notes/stamps depend on is more
  reliable in practice than red-team hole H6 assumed → **1b risk is lower than priced.**
- **The map wants layering.** One file could not be both the injected summary and the full
  depth, so it split into a terse `INDEX.md` TOC + per-area `brain/<area>.md`. 1b's notes are a
  natural **third layer** on the same structure → the split de-risks 1b integration.
- **Auto-refresh is technically blocked, not merely deferred.** Claude Code hooks are
  deterministic shell — they cannot run the LLM indexer. "Re-index on change" needs an
  agent/command run, which can't fire cheaply or silently. The Phase-2 fence is a hard limit;
  do not re-litigate it. Best available freshness = incremental `/brain index` (built this
  session) + the ⚠ staleness hint; run it manually when you wrap a chunk of work.
- **"Phase 1a" grew.** Split + incremental refresh were not in the original tracer scope; real
  usage demanded them. The shipped plugin is bigger than the first tracer.
- **Biggest friction was distribution, not design.** "Push ≠ update install" caused stale-
  install confusion (fixes committed but not live until the plugin is reinstalled/updated).
  Worth a short update-flow note for users.
- **The go-trigger has NOT fired yet.** The map was generated + inspected, not yet used on a
  real task where a note was wanted. So 1b stays **HOLD** — with the friendlier risk profile
  above for when it does fire.

## Resuming (fresh conversation — no prior context needed)

1. **Check the trigger first.** If you never missed having notes while using the map, stop —
   1b isn't needed. This is a usage decision, not a schedule.
2. **If it earned its keep,** open Claude Code in this marketplace repo and run:
   ```
   /taskmaster:task Build Phase 1b of the brain plugin per plugins/brain/ROADMAP.md —
   the value slice (anchored notes + file-anchors + freshness). Re-scout and re-grill
   against the CURRENT plugins/brain/ code; deferred: sym-anchors and the sibling-.md
   graph. Layer on the shipped tracer (indexer, /brain, inject hook) — do not rebuild it.
   ```
3. The pipeline regenerates a **current-accurate** spec + task cards from this roadmap plus
   today's code. Do **not** resurrect the old gitignored `taskmaster-docs/` specs — they are
   a stale snapshot by design.

## Invariants to keep in any phase

Index-in-place (never write outside `brain/`) · agent-instruction-driven (the only shipped
script is the fail-open `SessionStart` hook) · honest freshness (flag stale, never silently
trust) · committed vault (shared, but `INDEX.md` is a derived artifact — regenerate, don't
hand-merge).
