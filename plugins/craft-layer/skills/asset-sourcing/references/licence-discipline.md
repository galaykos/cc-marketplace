# Licence & provenance — the gate schema

Every award-grade build that ships a non-code visual or font asset owes a PROVENANCE record. This
file is the machine-checkable spec the craft audit (`/craft-layer:audit`) greps — it exists so a
read-only reviewer can verify licence discipline WITHOUT guessing an asset's origin.

## The provenance manifest (required)

A build shipping any non-code visual or font asset carries ONE provenance manifest. The filename is
your choice — a top-level `ASSETS` / `CREDITS` / `provenance` file, or a per-asset inline provenance
comment — what matters is that it is grep-able and COMPLETE. It enumerates every such asset with
four fields:

- `path` — where the asset lives in the build.
- `origin` — one of `first-party` · `third-party` · `AI-assisted`.
- `licence-class` — an enumerated token (below).
- `source` — where it came from (a category, a commission, a tool) — never left blank.

An all-in-code build (zero third-party assets) STILL ships the manifest, asserting "no third-party
assets." So a MISSING manifest is itself the finding, and the honest all-first-party build is
distinguishable from one whose provenance was stripped.

## Licence-class tokens (fixed set)

| Token | What it obliges |
| --- | --- |
| `public-domain/CC0` | nothing — free to ship; attribution optional |
| `permissive` (MIT / Apache / **SIL-OFL**) | keep the licence notice. **SIL-OFL additionally** obliges shipping the OFL licence text WITH the font and honouring the Reserved Font Name — a marker alone is NOT full compliance |
| `CC-BY` | attribution is OBLIGATORY (a visible credit + link) |
| `commercial` | a paid/seat licence — record the purchase/seat scope |
| `commissioned` | bespoke work — record the commission + its grant of rights |
| `AI-assisted` | provenance-uncertain / ToS-bound — record the TOOL and its terms; copyright status is contested, so treat as needs-review |

Attribution is required ONLY when the class obliges it (`CC-BY`). `source` is ALWAYS required.

## What the gate checks (teeth) — and its honest limit

Read-only, the reviewer verifies STRUCTURE + COMPLETENESS, not legal truth:

1. the manifest EXISTS;
2. every shipped visual/font asset file (Grep/Glob the asset dirs) maps to a manifest record —
   NO orphan asset;
3. every `third-party` / `AI-assisted` record carries a NON-EMPTY enumerated `licence-class` and a
   NON-EMPTY `source`. An empty or `unknown` value FAILS — not just a missing record.

It CANNOT confirm the declared licence is truthful — the teeth are declaration completeness +
schema. Say so plainly; never sell the gate as legal assurance.

## Absence-finding citation

A missing manifest or missing record has no file:line. Cite the offending asset's own path (or
`provenance:0` for a wholly-absent manifest) so the reviewer's
`path:line — severity — problem — fix` output stays well-formed.

## Fixture scenarios (how the gate is exercised)

- a third-party asset with NO manifest record → EXPECT a finding;
- an all-first-party build with a COMPLETE manifest → EXPECT a pass;
- a record with an empty / `unknown` licence value → EXPECT a finding.

## Anti-patterns

- **Marker-as-compliance** — a grep hit `licence: MIT` with `source:` blank; the empty value fails.
- **Partial manifest** — recording some assets, not all; the orphan check fails it.
- **Silence = pass** — omitting the manifest on an all-in-code build; absence IS the finding.
