---
name: flexbox-best-practices
description: Use when building one-dimensional layouts with Flexbox — main/cross axis control, flex shorthand pitfalls, gap, wrapping, when Flexbox over Grid.
---

## Use Flexbox for one-dimensional flow

Flexbox distributes and aligns items along a single axis (row or column) — toolbars, nav bars,
button groups, form rows, and card contents where items should stretch or align relative to one
line. If you find yourself needing independent control over both rows and columns at once, that's
a Grid problem, not a Flexbox one (see the css-grid-best-practices skill).

```css
/* Good: one-dimensional row of controls */
.toolbar { display: flex; align-items: center; gap: 0.5rem; }
```

## Understand what the `flex` shorthand actually sets

`flex: <grow> <shrink> <basis>`. The common shorthands mean different things and mixing them up
causes sizing bugs:

- `flex: 1` expands to `flex: 1 1 0%` — item ignores its content size as a starting point and
  grows/shrinks freely from zero basis. Good for equal-width columns regardless of content.
- `flex: auto` expands to `flex: 1 1 auto` — grows/shrinks starting from the item's natural
  (content) size. Good when you want flexible sizing that still respects content as a baseline.
- `flex: none` expands to `flex: 0 0 auto` — item never grows or shrinks; use for fixed-size
  items like icons or a sidebar with a hard width.
- The unitless default `flex-shrink: 1` means items shrink by default even without `flex` set —
  a common surprise when an item with a fixed `width` still shrinks below it under pressure.

```css
/* Good: equal-width flexible columns */
.col { flex: 1; }

/* Bad: expecting `flex: 1` to respect a min-content width without also setting min-width */
.col { flex: 1; width: 300px; } /* width is ignored as soon as the container is tight */
```

## Set `min-width: 0` (or `min-height: 0`) to fix overflow-in-flex bugs

Flex items default to `min-width: auto`, which means they refuse to shrink below their content's
intrinsic size (e.g., a long unbroken string or a wide child). This is the number one cause of
"my flex item overflows its container" bugs. Override it explicitly when the item should be
allowed to shrink and truncate/wrap its content.

```css
/* Good */
.flex-item { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

/* Bad: long text blows out the flex container because min-width defaults to auto */
.flex-item { overflow: hidden; }
```

## Use `gap` instead of margins for spacing between items

`gap` applies only between flex items, so you don't need `:last-child` margin resets or
negative-margin edge compensation. It also correctly handles wrapped rows, adding vertical gap
between wrapped lines automatically.

- Good: `.row { display: flex; gap: 1rem; }`
- Bad: `margin-right: 1rem` on every item, plus `&:last-child { margin-right: 0; }` to patch the edge.

## Control wrapping deliberately with `flex-wrap`

The default `flex-wrap: nowrap` forces all items onto one line, shrinking them (per `flex-shrink`)
until they fit — or overflow if they hit their `min-width`. Set `flex-wrap: wrap` when items
should flow onto new lines instead of being squeezed indefinitely, and pair it with `flex-basis`
to control roughly how many items land per line.

```css
/* Good: cards wrap to new lines instead of shrinking to nothing */
.cards { display: flex; flex-wrap: wrap; gap: 1rem; }
.cards > * { flex: 1 1 220px; }
```

## Use `justify-content`/`align-items` instead of margin-based centering hacks

Flexbox's alignment properties replace older centering tricks (`margin: 0 auto` combined with
fixed widths, or absolute-position-and-transform centering).

```css
/* Good */
.center { display: flex; align-items: center; justify-content: center; }

/* Bad: pre-flexbox centering hack */
.center-hack { position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); }
```

## Know the main axis vs. cross axis before reaching for a property

`justify-content` always acts on the main axis (row by default, column if `flex-direction:
column`); `align-items`/`align-content` act on the cross axis. Setting `flex-direction: column`
without re-checking which alignment property does what is a common source of "my centering isn't
working" confusion.

## When to hand a section to Grid instead

If a component needs precise alignment across two axes simultaneously — e.g., a form where labels
in one column must line up with inputs in another across multiple rows, or a page shell with
header/sidebar/footer — Grid expresses that directly with template areas or tracks. Don't nest
several Flexboxes trying to fake column alignment across rows; that's exactly what Grid solves.

## Common mistakes

- Assuming `flex: 1` behaves like `flex: auto` (or vice versa) and getting unexpected sizing.
- Not setting `min-width: 0` on a flex item that needs to truncate or wrap, causing overflow.
- Using margins with `:last-child` resets instead of `gap` for spacing.
- Leaving `flex-wrap: nowrap` (the default) on a row that should reflow on small screens.
- Reaching for `justify-content` to control the cross axis (or vice versa) after changing `flex-direction`.
- Nesting multiple Flexboxes to fake two-dimensional alignment instead of switching to Grid.

## Verify Against Current Docs

`gap` support in Flexbox and some alignment edge cases were added after Flexbox's initial
release, and browser behavior has evolved. Before relying on memory for support tables or exact
shorthand expansions, check the current docs:
https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_flexible_box_layout
