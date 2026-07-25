# The static type contract — the floor kinetic type stands on

> Last verified: 2026-07-25 — https://web.dev/articles/baseline-in-action-fluid-type ·
> https://developer.mozilla.org/en-US/docs/Web/CSS/text-wrap

Read on demand from `kinetic-typography`. Animating a headline cannot rescue a type
system that has no scale, no fluid rule, and no loading strategy — an axis tween on a
headline that reflows on every breakpoint and swaps in with a layout shift reads worse
than static type would. This file owns the STATIC contract a kinetic surface assumes.
It ships rules, never a font choice or a px value: the modular scale, line-heights, and
measure belong to `plugins/ui-ux/skills/design-tokens/SKILL.md` — this adds only the
decisions that file does not make.

## Fluid sizing — clamp with a floor, never raw viewport units

Type that scales with the viewport must still obey the user. A size expressed purely in
`vw` cannot be zoomed, which fails WCAG 1.4.4 (text resizable to 200%). The correct
shape pairs a relative floor with a small viewport term inside `clamp()`, so zoom keeps
working and the viewport only modulates:

    /* floor and ceiling in rem/em; the middle term is rem + a SMALL vw component */
    font-size: clamp(<rem-floor>, <rem-base> + <small>vw, <rem-ceiling>);

- Keep the ceiling under roughly 2.5× the floor. A wider span makes zoom ineffective at
  one end of the range and makes the scale's ratios meaningless at the other.
- The middle term must contain a rem/em component. `clamp(1rem, 4vw, 3rem)` still fails
  zoom in the range where `4vw` wins — the floor and ceiling only clamp the extremes.
- Generate scale steps with CSS `pow()` rather than pasting computed numbers, so the
  ratio stays a visible, editable decision.
- Prefer container units (`cqi`) over viewport units for type inside a component that is
  reused at different widths — the component then scales to its own box, not the page.

## Line-breaking — `balance` for headings, `pretty` for body

- `text-wrap: balance` evens line lengths across a short block. Engines cap it (around
  six lines in Chromium, ten in Firefox) because it is expensive, so it is a HEADING,
  caption, and blockquote tool. Applying it to body copy silently does nothing past the
  cap.
- `text-wrap: pretty` targets long-form copy — it suppresses orphans and bad rags with a
  slower algorithm. Engine support lags `balance`, so treat it as progressive
  enhancement, never as the thing preventing a broken layout.
- Both are enhancements: the layout must be acceptable with neither applied.

## Optical sizing and the display/text split

- Turn on `font-optical-sizing: auto` whenever the family carries an `opsz` axis; the
  glyphs then thin their strokes and tighten spacing at display sizes and open up at
  body sizes automatically. This is the cheapest typographic quality win available and
  it costs nothing at runtime.
- Do not run a display face at body size. Display cuts have high stroke contrast and
  tight sidebearings that fall apart small; that is the same distinction `opsz`
  automates within one family.
- When one family must cover UI, prose, and code, prefer a SUPERFAMILY — sibling
  serif/sans/mono cuts sharing metrics and proportions — over three unrelated faces.
  Shared metrics are what make mixed-classification pages read as one system.
- Reach for a second family only when the concept needs the contrast. Two families is a
  decision; three is usually an accident.

## Loading — the layout-shift contract

The variable-font payload caveat in `variable-fonts.md` covers the flash of wrong
weight. This is the layout half:

- Self-host WOFF2 and subset it. Beyond the privacy exposure of third-party font CDNs
  (which has been litigated under GDPR), a self-hosted subset removes a connection from
  the critical path.
- Match fallback metrics with `size-adjust` plus `ascent-override` / `descent-override`
  / `line-gap-override` on a local fallback `@font-face`. Overrides alone reduce the
  shift; adding `size-adjust` is what can remove it, because the two faces then occupy
  the same box.
- `font-display: swap` is the default for text. Use `optional` where a brief flash of
  fallback is worse than never getting the webfont; use `block` only for icon faces,
  and prefer not shipping an icon face at all.
- Preload only the faces above the fold, and only the subset actually used there.

## Licensing — the trap the manifest does not catch

`asset-sourcing/references/licence-discipline.md` records a font's licence CLASS and
source, and that gate is what runs. It cannot see the trap: commercial foundries sell
desktop, web, app, and server licences SEPARATELY, so a font legitimately licensed for
desktop design work is not licensed for `@font-face` embedding. A manifest row reading
`commercial` is complete and still wrong if the purchase was desktop-only. When the
class is `commercial`, record WHICH licence tier was bought and, for a webfont, its
pageview or domain scope. Open families under SIL OFL avoid this entirely — and OFL's
own obligations (ship the licence text, honour the Reserved Font Name) are already in
the licence gate.

## Anti-patterns

- **Raw `vw` type** — a viewport-only size the user cannot zoom.
- **Clamp without a rem term** — floor and ceiling in rem but a pure `vw` middle; zoom
  still breaks in the middle of the range.
- **`balance` on body copy** — silently capped, so the block is unbalanced anyway.
- **Enhancement as load-bearing** — a layout that only works once `pretty` or `balance`
  applies.
- **Display face at body size** — or a family with `opsz` shipped with optical sizing
  off, throwing away free quality.
- **Unmatched fallback** — a webfont swapped in with no metric overrides, shifting
  layout on every load.
- **Desktop licence embedded** — `@font-face` on a font bought for desktop use, with a
  manifest row that looks compliant.
