# RTL / BiDi — which motion mirrors, which stays LTR

Read on demand from motion-tiers, scroll-orchestration, and kinetic-typography. This is
the craft DECISION for right-to-left / bidirectional targets — not the base RTL mechanics.

## Reuse the base rules

The general RTL rules — logical CSS properties (`margin-inline`, `inset-inline`), `dir`,
mirrored directional icons, the reviewing checklist — live in the i18n plugin:
`plugins/i18n/skills/i18n/SKILL.md`. Apply them; do not re-teach them here. This file adds
only the MOTION + creative decisions i18n does not cover.

## Mirror these effects on RTL

Direction-bearing motion follows the reading direction — flip it when `dir="rtl"`:

- Scroll-linked progress mapping and pinned **horizontal-scroll** direction (a gallery
  advances leading-edge-first — right-to-left).
- **Marquee / ticker** direction.
- **Entrance offsets** — an element that enters from the inline-start comes from the RIGHT
  on RTL; use the logical sign, not a hard-coded `+x` / `−x`.
- **Parallax x-offset** side.

Drive these from the resolved direction (`getComputedStyle(el).direction`) or logical
properties, so one codebase serves both — never hard-code LTR pixel signs.

## Keep these as LTR-islands (do NOT mirror)

Some content is LTR by convention even inside an RTL page — wrap each in `dir="ltr"`:

- **Charts & graphs** — a time-series / growth chart reads left→right (time increases
  rightward; growth climbs to the right) regardless of page direction. Mirroring it
  inverts the meaning — a rising curve would read as a decline.
- **Numerals, metrics, currency, dates, percentages** — western digits and units keep LTR
  order (`+212%`, `4.2×`, `24/7`).
- **Code, URLs, identifiers, latin brand wordmarks.**

## reduced-motion still applies

Mirrored effects are still motion: the `prefers-reduced-motion` path (from the owning tier
/ scroll-orchestration / kinetic-typography) applies unchanged. Mirroring changes
DIRECTION, not whether the effect runs.

## Decide

1. Is the target (or a locale it serves) RTL / BiDi? If not, ignore this file.
2. For each animated element: does it carry reading direction (scroll, marquee, entrance,
   parallax)? → mirror it. Is it data / numeric / code? → LTR-island (`dir="ltr"`).
3. Verify against a different RTL brief: effects flow right-to-left AND every chart and
   number still reads left-to-right.
