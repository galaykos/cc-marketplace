---
name: css3-best-practices
description: Use when writing or reviewing plain CSS3 — custom properties, cascade layers, logical properties, container queries, specificity management.
---

## Theme with custom properties, not repeated literals

Define colors, spacing, and other recurring values as custom properties on `:root` (or a scoped
ancestor) and reference them everywhere. This gives you a single edit point for theming and
dark-mode overrides, instead of hunting every literal in the stylesheet.

```css
/* Good */
:root { --color-primary: #1a2b3c; --space-md: 1rem; }
.card { padding: var(--space-md); color: var(--color-primary); }

/* Bad: same value hardcoded in a dozen places */
.card { padding: 16px; color: #1a2b3c; }
.button { color: #1a2b3c; }
```

## Use cascade layers to control specificity intentionally

`@layer` lets you declare explicit precedence order (e.g., `reset, base, components, utilities`)
so later layers always win regardless of selector specificity. This replaces the old habit of
fighting specificity with ID selectors or `!important`.

```css
@layer reset, base, components, utilities;

@layer base {
  button { border-radius: 4px; }
}
@layer utilities {
  .rounded-none { border-radius: 0; } /* wins over base, no specificity war needed */
}
```

## Use logical properties for layouts that must support i18n

`margin-inline-start`, `padding-block`, `inset-inline-end`, etc. adapt automatically to
right-to-left languages and vertical writing modes. Physical properties (`margin-left`,
`padding-top`) don't, and hardcode an assumption about text direction.

- Good: `margin-inline-start: 1rem;` — flips automatically under `dir="rtl"`.
- Bad: `margin-left: 1rem;` — visually wrong once the page is mirrored for RTL locales.

## Reach for container queries when a component depends on its own space

Media queries respond to the viewport; container queries respond to the size of a component's
containing element. Use container queries for reusable components (cards, widgets) that must
adapt regardless of where they're placed on the page — a media query can't express "this card is
narrow because it's in a sidebar."

```css
.card-container { container-type: inline-size; }

@container (min-width: 400px) {
  .card { grid-template-columns: auto 1fr; }
}
```

Use a media query instead when the concern is genuinely page-level layout (e.g., hiding a nav on
small screens), not component-level adaptation.

## Avoid `!important` and deep selector chains

Both are symptoms of unmanaged specificity. `!important` overrides the cascade unpredictably and
is hard to override again later; deep chains (`.page .sidebar .widget ul li a`) couple styles to
DOM structure and break the moment markup changes. Prefer flat, low-specificity selectors plus
cascade layers or source order to control precedence.

- Good: `.widget-link { color: var(--color-link); }`
- Bad: `.page .sidebar .widget ul li a { color: blue !important; }`

## Prefer modern layout (Grid/Flexbox) over positioning hacks

Floats-for-layout and `position: absolute` centering tricks predate Grid and Flexbox and carry
baggage (clearfix hacks, magic numbers, fragile centering math). Use Grid for two-dimensional
layout and Flexbox for one-dimensional flow; reserve `position: absolute` for things that are
genuinely meant to escape normal flow (tooltips, badges, overlays).

```css
/* Good */
.row { display: flex; gap: 1rem; align-items: center; }

/* Bad: float-based layout requiring a clearfix */
.row::after { content: ""; display: table; clear: both; }
.row .col { float: left; }
```

## Scope resets and base styles deliberately

A global reset applied without layers or scoping can clobber third-party widgets or later
overrides unpredictably. Put resets in their own cascade layer (first in the layer order) so
everything else can override them without specificity fights.

## Common mistakes

- Hardcoding color/spacing literals instead of custom properties, making theming a find-and-replace exercise.
- Reaching for `!important` as the first fix for a specificity problem instead of restructuring selectors or using layers.
- Using physical properties (`margin-left`) in layouts that need to support RTL locales.
- Reaching for a media query when the real concern is a component's own container size.
- Deeply nested selectors that break the first time the markup structure changes.
- Float/absolute-position layout hacks where Grid or Flexbox would be simpler and more robust.

## Verify Against Current Docs

Cascade layers, container queries, and logical properties are relatively recent and browser
support/syntax details evolve. Before relying on memory for support tables or exact syntax,
check the current docs: https://developer.mozilla.org/en-US/docs/Web/CSS
