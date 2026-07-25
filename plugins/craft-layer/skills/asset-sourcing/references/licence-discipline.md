# Licence & provenance — the gate schema

Every award-grade build that ships a non-code visual or font asset owes a PROVENANCE record. This
file is the machine-checkable spec the craft audit (`/craft-layer:audit`) greps — it exists so a
read-only reviewer can verify licence discipline WITHOUT guessing an asset's origin.

## The provenance manifest (required)

A build shipping any non-code visual or font asset carries ONE provenance manifest at a name the
reviewer can actually find. **Accepted names, globbed by the audit** (repo root or the asset
directory, any of `.md`/`.txt`/`.json`/no extension): `ASSETS`, `CREDITS`, `PROVENANCE`,
`THIRD-PARTY-NOTICES`, case-insensitive. Per-asset inline provenance comments remain valid for
inline/`data:` refs, keyed by the `inline:<id>` marker. A manifest at any other path reads as
ABSENT to the gate — which is a finding — so use one of these names rather than a creative one.
It enumerates every such asset with four fields:

- `ref` — WHERE the asset is referenced from: a committed file path, a remote URL, or the
  inline marker `inline:<id>` (the three ref classes are defined below). Existing committed-file
  manifests keep a plain file path here — they stay valid unchanged.
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
2. every shipped visual/font asset — whether a committed FILE (Grep/Glob the asset dirs) or a
   third-party REF grepped from source (the ref classes below) — maps to a manifest record —
   NO orphan asset;
3. every `third-party` / `AI-assisted` record carries a NON-EMPTY enumerated `licence-class` and a
   NON-EMPTY `source`. An empty or `unknown` value FAILS — not just a missing record.

### Ref classes the source-grep enumerates

The gate greps SOURCE (the reviewer is Read/Grep/Glob — there is no build step) for third-party
asset refs that never land as a committed file. Each such unprovenanced third-party ref is a
finding:

- **absolute-URL** — an asset pulled from an `https?://` host: an `@font-face` `src:`, an
  `@import`, a `<link href|src>`, a `url(...)`, a `<use href>`, or an ESM `import` whose specifier
  is an absolute URL. Operational rule (the reviewer is deploy-domain-blind): ANY absolute-URL
  asset ref needs a manifest record UNLESS the manifest declares that ref `first-party` in its
  `origin` field — a self-hosted CDN is remote-but-first-party, the carve-out. `ref` is the URL. A
  same-origin reverse-proxied third-party asset is a stated blind spot.
- **inline** — a `data:`/base64 asset or an inline `<svg>` blob over a rough threshold (~40 lines
  or a few KB). It must carry a provenance marker — an `id`/`data-provenance` attribute or an
  adjacent provenance comment — that the manifest names as `ref = inline:<id>`. An anonymous
  sub-threshold blob is EXEMPT (presumed authored/first-party) so the orphan-scan stays decidable.
- **URL-fetched** — a `.lottie`/`.riv`/`.glb`/font (or similar) loaded from a URL string. `ref` is
  the URL; the same absolute-URL rule + first-party carve-out apply.

It CANNOT confirm the declared licence is truthful — AND it is blind to refs that are not literal
in source: a font/asset URL injected by a bundler or plugin, referenced through a framework
component by NAME (a `<Font>`/`next/font` face), string-BUILT at runtime (`fetch(base + name)`), or
reached through a CSS custom-property indirection — none of these appear as a literal ref for the
grep to catch, so they are a DECLARED blind spot, sitting beside the "not legal truth" limit. The
teeth are declaration completeness + schema over the LITERAL source refs. Say so plainly; never
sell the gate as legal assurance, and never claim it closes the hotlink hole by construction.

## Absence-finding citation

A missing manifest or missing record has no file:line. Cite the offending asset's own ref — a file
path, a remote URL, or `inline:<id>` (or `provenance:0` for a wholly-absent manifest) — so the
reviewer's `path:line — severity — problem — fix` output stays well-formed.

## Fixture scenarios (how the gate is exercised)

- a committed third-party asset FILE with NO manifest record → EXPECT a finding;
- an all-first-party build with a COMPLETE manifest → EXPECT a pass;
- a record with an empty / `unknown` licence value → EXPECT a finding;
- a CDN-hotlinked webfont (`@font-face { src: url(https://fonts.example.com/x.woff2) }`) with NO
  manifest line for that URL → EXPECT a finding (the remote absolute-URL ref is unprovenanced);
- a compliant remote font — `ref: https://fonts.example.com/x.woff2 · origin: third-party ·
  licence-class: permissive (SIL-OFL) · source: the foundry's webfont CDN` → EXPECT a pass (the
  same URL declared `first-party` would also pass — the self-hosted-CDN carve-out);
- an inline `<svg>` brand mark over the threshold with `id="brand-mark"`, recorded as
  `ref: inline:brand-mark · origin: third-party · licence-class: commissioned · source: …` →
  EXPECT a pass; the SAME blob with no marker and no record → EXPECT a finding;
- a URL-fetched Lottie (`fetch('https://cdn.example.com/hero.lottie')`) with NO record for that
  URL → EXPECT a finding.

## Anti-patterns

- **Marker-as-compliance** — a grep hit `licence: MIT` with `source:` blank; the empty value fails.
- **Partial manifest** — recording some assets, not all; the orphan check fails it.
- **Silence = pass** — omitting the manifest on an all-in-code build; absence IS the finding.
