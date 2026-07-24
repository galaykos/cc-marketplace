# Illustration & imagery — art direction + sourcing

Imagery is where a brand most often collapses into sameness. This file decides ART DIRECTION and
the source — never a specific stock library or photo (kill-trigger).

## Art-direct before you source

- **One visual language** — a build's illustrations / photos share treatment (palette, grain, crop,
  lighting, subject framing). Mixed styles read as a stock bin.
- **Custom vs stock** — the brand-defining imagery (hero, key moments) should be commissioned or
  art-directed, not the first stock result. Stock is fine for secondary slots when treated to match
  the language.
- **Uniqueness (fingerprint)** — a **generic stock-photo hero** is a sameness-fingerprint default
  (`plugins/craft-layer/skills/creative-direction/references/sameness-fingerprint.md`); breaking it
  is what the anti-sameness gate rewards. NEVER fabricate a photo of a real place / person / event
  to fill the slot — commission, illustrate, or use an honestly-sourced image.

## Format + responsive

- **Format** — AVIF first, WebP fallback, for photographic imagery; SVG for illustration / vector.
- **Art-directed responsive** — `<picture>` with per-breakpoint crops (not one image scaled): the
  mobile crop is a different composition, not a squeeze. Reserve width/height (no CLS); lazy-load
  below-the-fold imagery.

## Licence

Every third-party / stock / AI-generated image is under the licence gate (`licence-discipline.md`)
— record class + source. A model / property release is the photographer's concern, but the LICENCE
class + source must be declared; AI-generated imagery records the tool + its ToS (the `AI-assisted`
class).
