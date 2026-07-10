---
name: tailwind-best-practices
description: Use when writing or reviewing Tailwind CSS — utility ordering, extracting components vs @apply, responsive/dark variants, design tokens via config.
---

## Keep class ordering consistent

Unordered utility soup is unreadable and makes diffs noisy. Use a consistent order (layout →
box model → typography → visual → state/variants) and let a formatter enforce it automatically
rather than debating it by hand.

- Good: run `prettier-plugin-tailwindcss` so class order is deterministic and diff-friendly.
- Bad: classes in random order that shifts every time someone touches the line, e.g.
  `text-sm bg-white p-4 flex hover:bg-gray-50 rounded border`.

## Extract repeated patterns into components, not `@apply` soup

When the same utility cluster shows up in five places, extract a framework-level component
(React/Vue/etc.) that renders those utilities, not a custom CSS class built from `@apply`.
`@apply` re-creates the specificity and maintenance problems Tailwind exists to avoid, and it
hides the utilities from tooling like the IntelliSense plugin and unused-class detection.

```tsx
// Good: a Button component wraps the repeated utility cluster
function Button({ variant = "primary", ...props }) {
  return <button className={cn(base, variants[variant])} {...props} />;
}
```

```css
/* Bad: @apply soup reintroduces a custom stylesheet to maintain */
.btn-primary {
  @apply px-4 py-2 rounded bg-blue-600 text-white hover:bg-blue-700;
}
```

## Use design tokens via config, not arbitrary values everywhere

Reach for `theme.extend` (colors, spacing, fontSize) so the whole app draws from a shared scale.
Arbitrary-value syntax (`w-[137px]`, `text-[#1a2b3c]`) is fine for a genuine one-off, but if the
same arbitrary value appears more than once, it belongs in the config as a token.

```js
// Good: tailwind.config.js
theme: { extend: { colors: { brand: { DEFAULT: "#1a2b3c", 600: "#16232f" } } } }
```

```html
<!-- Bad: the same magic value copy-pasted across files -->
<div class="bg-[#1a2b3c]">...</div>
<div class="bg-[#1a2b3c]">...</div>
```

## Design mobile-first, layer breakpoints upward

Tailwind's responsive variants are min-width by default: unprefixed utilities are the base
(mobile) style, and `sm:`, `md:`, `lg:` add overrides for larger viewports. Write the mobile
layout first, then layer breakpoint variants — don't design desktop-first and try to cram it
down with `max-*` variants everywhere.

- Good: `class="flex flex-col gap-2 md:flex-row md:gap-4"`
- Bad: designing only for desktop, then bolting on `max-md:flex-col` overrides as an afterthought.

## Dark mode via the `dark:` variant, not duplicate stylesheets

Use Tailwind's `dark:` variant (class or media-based, per your config) alongside the light
styles in the same markup. Don't maintain a parallel dark-mode CSS file or duplicate component
trees — that doubles the maintenance surface and will drift.

```html
<!-- Good -->
<div class="bg-white text-gray-900 dark:bg-gray-900 dark:text-gray-100">...</div>
```

## Avoid dynamic class-name construction that defeats purging

Tailwind's build scans source files for complete class strings. Building class names by string
concatenation at runtime means the compiler never sees the full name and won't generate the CSS.
Use a lookup map of complete class strings instead.

```tsx
// Bad: compiler can't statically see "bg-red-500", "bg-green-500", etc.
<div className={`bg-${color}-500`} />

// Good: complete strings the scanner can find
const colorMap = { red: "bg-red-500", green: "bg-green-500" };
<div className={colorMap[color]} />
```

## Prefer utilities over `@layer components` for one-off styling

Tailwind's `@layer components` has legitimate uses (e.g., third-party overrides), but default to
composing utilities directly in markup for anything specific to one feature. Reserve custom
layers for truly shared, cross-cutting primitives.

## Common mistakes

- Reformatting class order by hand instead of using the Prettier plugin, causing noisy diffs.
- Writing `@apply`-heavy stylesheets that recreate a parallel CSS architecture.
- Repeating the same arbitrary value (`[#1a2b3c]`, `[13px]`) instead of promoting it to a token.
- Desktop-first markup patched with `max-*` variants instead of mobile-first `sm:`/`md:`/`lg:`.
- Building class names via string interpolation (`` `text-${size}` ``), silently breaking purge.
- Maintaining separate dark-mode stylesheets instead of using the `dark:` variant inline.

## Verify Against Current Docs

Config shape, default breakpoints, and variant syntax have changed across Tailwind major
versions (e.g., v3 → v4 config format). Before relying on memory for config keys or utility
names, check the current docs: https://tailwindcss.com/docs
