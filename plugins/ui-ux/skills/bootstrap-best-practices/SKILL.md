---
name: bootstrap-best-practices
description: Use when building or reviewing Bootstrap 5 UI — grid, utility API, Sass customization, accessibility.
---

## Use the grid system instead of custom layout CSS

Bootstrap's container/row/col grid already handles gutters, breakpoints, and column math. Reach
for `row`/`col-*` classes before writing custom flex or grid CSS alongside Bootstrap — mixing the
two layout systems for the same region causes gutter and alignment inconsistencies.

```html
<!-- Good -->
<div class="container">
  <div class="row">
    <div class="col-md-8">Main</div>
    <div class="col-md-4">Sidebar</div>
  </div>
</div>

<!-- Bad: hand-rolled flex layout fighting Bootstrap's own gutters -->
<div class="container" style="display:flex; gap:20px;">
  <div style="flex: 0 0 66%;">Main</div>
</div>
```

## Prefer the utility API over custom CSS overrides

Bootstrap 5 ships spacing, color, border, and display utility classes (`mt-3`, `d-flex`,
`text-muted`, `border-0`). Use them for one-off adjustments instead of writing new CSS rules that
override Bootstrap's own classes — utility classes are already responsive-variant aware
(`d-md-none`) and keep spacing consistent with the rest of the app.

- Good: `<div class="d-flex justify-content-between mt-3">`
- Bad: a new stylesheet rule `.my-header { margin-top: 1rem !important; display: flex; }` that
  duplicates what a utility class already does, with higher specificity risk.

## Customize via Sass variables, not stylesheet-override wars

Bootstrap is a Sass codebase: override its `$variables` (colors, spacing scale, breakpoints,
border-radius) before importing Bootstrap's Sass, and the whole component set updates
consistently. Overriding compiled CSS with higher-specificity rules or `!important` produces a
fork that drifts further from Bootstrap with every update.

```scss
// Good: _custom.scss, before importing bootstrap
$primary: #1a2b3c;
$border-radius: 0.25rem;
@import "bootstrap/scss/bootstrap";
// 5.3+ also exposes CSS variables (--bs-*) for runtime theming without a Sass
// rebuild; note Dart Sass deprecates @import and Bootstrap 6 moves to @use.
```

```css
/* Bad: fighting the compiled CSS after the fact */
.btn-primary { background-color: #1a2b3c !important; }
```

## Keep component markup accessible — don't strip what Bootstrap expects

Bootstrap's JS components (modal, dropdown, collapse, tooltip) rely on specific `data-bs-*`
attributes and ARIA state (`aria-expanded`, `aria-controls`, `role="dialog"`) to function and to
be announced correctly by screen readers. Copy the documented markup structure exactly; don't
trim "unnecessary-looking" attributes to simplify HTML.

```html
<!-- Good: matches documented modal markup, ARIA wired correctly -->
<button data-bs-toggle="modal" data-bs-target="#exampleModal" aria-controls="exampleModal">
  Open
</button>
<div class="modal" id="exampleModal" tabindex="-1" aria-hidden="true">...</div>

<!-- Bad: stripped attributes break focus handling and screen-reader semantics -->
<button onclick="$('#exampleModal').show()">Open</button>
<div class="modal" id="exampleModal">...</div>
```

## Don't mix Bootstrap versions or fight its reset

Loading Bootstrap 4 utilities alongside Bootstrap 5 components (or a legacy jQuery plugin next to
Bootstrap 5's vanilla JS) causes class-name collisions and duplicate reset rules. Pick one
version per app, and don't reintroduce jQuery-era plugins into a Bootstrap 5 project — its JS
components no longer depend on jQuery.

- Bad: including `bootstrap@4` CSS for grid utilities while using `bootstrap@5` JS components on
  the same page.

## Extend, don't replace, the breakpoint and color systems

If the design needs an extra breakpoint or brand color, add it to the `$grid-breakpoints` /
`$theme-colors` Sass maps rather than inventing a parallel ad hoc class naming scheme. This keeps
new utilities (`col-xxl-*`, `btn-brand`) generated consistently by Bootstrap's own mixins.

```scss
$theme-colors: map-merge($theme-colors, ("brand": #1a2b3c));
```

## Use the responsive grid classes instead of custom media queries for layout

Bootstrap's `col-sm-*`, `col-md-*`, etc. already encode the breakpoint system. Writing custom
`@media` queries to reposition grid columns duplicates logic the grid already provides and can
conflict with Bootstrap's own breakpoint values if they've been customized.

## Common mistakes

- Mixing custom flexbox/grid CSS with Bootstrap's grid in the same region, breaking gutters.
- Writing `!important` overrides instead of Sass variable customization before compiling.
- Stripping `data-bs-*` or ARIA attributes from modal/dropdown/collapse markup, breaking a11y and JS behavior.
- Loading two Bootstrap major versions (or jQuery plugins) in the same project.
- Inventing new breakpoint/color class names instead of extending Bootstrap's Sass maps.
- Overriding compiled `bootstrap.css` directly instead of maintaining a custom Sass build.

## Verify Against Current Docs

Bootstrap 5's utility classes, Sass variable names, and JS component APIs (data attributes,
events) have changed across minor versions. Before relying on memory for a specific class or
option name, check the current docs: https://getbootstrap.com/docs
