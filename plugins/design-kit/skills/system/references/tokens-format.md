# tokens.json — the shape system-extract.py writes

> Last verified: 2026-09-22 — https://www.designtokens.org/tr/drafts/format/ (Format Module 2025.10, Draft Community Group Report of 2026-09-08, which carries its own "Do not attempt to implement this version" warning)

The file is **DTCG-shaped, not DTCG-2025.10-conformant**, and says so here rather than
in a footnote. Shared with the draft: every token is an object with `$type` and `$value`;
groups are plain nested objects; `{group.token}` is an alias; `$extensions` holds
tool-specific data. Diverging from the 2025.10 draft: that draft requires a `color`
`$value` to be an object (`colorSpace`, `components`, optional `hex`) and a `dimension`
to be `{ "value": n, "unit": "px" | "rem" }`. This file keeps both **as strings, as the
source wrote them** — a hex, an `oklch()` call, an HSL triplet, `0.5rem`, `24px` — because
the source's form is evidence, `%`/`em` units have no conforming object, and the draft
tells implementers to wait. A consumer wanting the object form converts on its side.
The extension key is `design-kit` (the draft recommends reverse-domain keys; this one is
short on purpose and unlikely to collide).

## Groups and types

| Group | `$type` | Where it comes from |
|---|---|---|
| `color.<name>` | `color` | custom properties, `@theme --color-*`, SCSS `$vars`, Tailwind `extend.colors`, brand `.md` hex lines |
| `typography.family.<name>` | `fontFamily` | `--font-*`, `@font-face`, `font-family` declarations, Google Fonts links, Tailwind `extend.fontFamily` |
| `spacing.<name>` | `dimension` | `--spacing-*`, `--space-*`, `--gap-*`, Tailwind `extend.spacing` |
| `radius.<name>` | `dimension` | `--radius*`, Tailwind `extend.borderRadius` |
| `motion.duration.<name>` | `duration` | `--duration-*`, any custom property whose value is `<n>ms` or `<n>s` |
| `motion.easing.<name>` | `cubicBezier` | `--ease-*`; `cubic-bezier(a,b,c,d)` becomes `[a, b, c, d]`, a named easing stays a string |
| `elevation.<name>` | `shadow` | `--shadow-*`, Tailwind `extend.boxShadow` (kept as the raw CSS string) |

Colour values are kept **as written in the source** — a hex, an `oklch()` call, or a
shadcn v3 HSL triplet like `222.2 47.4% 11.2%`. Converting them would erase the fact
the source used that form. A consumer that needs one colour space converts on its side.

## Modes (light/dark)

One token, one path. The light value is `$value`; a dark value sits in
`$extensions.design-kit.modes.dark`. Sibling groups (`color-dark.*`) were rejected
because they double every path and let the two drift. A token with no dark block has no
`modes` key at all, which is how "this source has no dark mode" stays visible.

```json
"color": {
  "background": {
    "$type": "color",
    "$value": "#ffffff",
    "$extensions": { "design-kit": { "modes": { "dark": "#0a0a0a" },
                                     "sources": ["src/styles/globals.css:34", "src/styles/globals.css:43"] } }
  }
}
```

## Provenance

`$extensions.design-kit.sources` is a sorted list of `path:line` (repo, brand) or
`url` / `url#style` (url mode). It is the audit trail: a token without it did not come
from the script.

`$extensions.design-kit.literalColors` at the ROOT lists the twelve most-used literal
hex values with counts. They are not tokens — they are the colours the source used
without naming, offered so a reader can decide whether one deserves a name in the
source.

## Aliases

`hsl(var(--primary))` in a Tailwind config becomes `{color.primary}`; a `var(--font-sans)`
becomes `{typography.family.sans}`. Resolution is the consumer's job. A dangling alias
(the referenced token was not found) is left as written so the gap is visible.

## Names

`--color-brand` → `color.brand`; `--radius-lg` → `radius.lg`; `--radius` → `radius.radius`
(the bare name kept rather than invented); Tailwind `colors.primary.DEFAULT` →
`color.primary`, `colors.primary.foreground` → `color.primary-foreground`. Names are the
source's names lower-cased with non-alphanumerics folded to `-`; nothing is renamed to a
nicer scheme.

## What a consumer must tolerate

- Any group may be absent. An empty source yields `{}` plus `literalColors` at most.
- `$value` for `fontFamily` is the FIRST family in a stack, unquoted; the fallback stack
  is not recorded.
- `shadow` values are raw CSS strings, not the DTCG composite object.
- Determinism is byte-level for the same source and script version; a script change may
  reorder or rename, so pin the plugin version in a consumer that diffs the file.
