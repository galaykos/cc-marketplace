# Astryx structure digest — package, imports, category map

> Last verified: 2026-07-22 — https://astryx.atmeta.com/components

Read on demand from astryx-best-practices. Structure-stable material only:
package layout, install/import shape, and the component category inventory as
published on the components index. Astryx is **beta** (0.x) — nothing in this
file answers a props question.

## Package layout and install

- One published npm package: `@astryxdesign/core`. The components index
  documents no sibling packages — treat any other `@astryxdesign/*` name as
  unverified until the live docs show it.
- Install: `npm install @astryxdesign/core`. Pre-built CSS ships with the
  package; no StyleX compiler or build plugin is required to consume
  components.

## Import shape

- Per-component subpath imports, never a barrel:
  `import { … } from '@astryxdesign/core/ComponentName';`
- The subpath is the component's name as addressed on the components index;
  this per-component addressing is also how the typed manifest keys entries.

## Component category inventory (as fetched 2026-07-22)

Eleven categories, ~137 components listed; glosses are representative:

- **Action** — buttons, menus, segmented control, toolbar, link.
- **Chat** — composer, layout, message, system message, tool calls.
- **Container** — card (plain/clickable/selectable), carousel, collapsible.
- **Content** — avatar, heading/text, code and code block, markdown, icon,
  citation, empty state, timestamp, token.
- **Data Input** — the form surface: text/number/date/time inputs, field,
  selectors, typeahead, tokenizer, slider, switch, radio list, power search.
- **Feedback & Status** — badge, banner, progress bar, skeleton, spinner,
  status dot.
- **Layout** — app shell, grid, layout, section, divider, form layout,
  aspect ratio, resize handle.
- **Navigation** — breadcrumbs, pagination, outline, side nav, tab list,
  top nav and its mega-menu family.
- **Overlay** — dialog, popover, tooltip, toast, hover card, lightbox,
  overlay, command palette.
- **Table & List** — table, list, tree list, overflow list, metadata list.
- **Utility** — VisuallyHidden.

Pick the closest existing component from this map before composing your own;
these category names are the vocabulary the live docs use.

## Beta discipline (summary — the SKILL's steps stay binding)

1. Resolve the installed version from `package.json` / the lockfile FIRST;
   a 0.x minor can change APIs and package layout.
2. Per-component props, variants, defaults, and event signatures are NEVER
   answered from this digest or from memory — fetch the component's own page
   under https://astryx.atmeta.com/components for that surface.
3. When the project exposes the Astryx MCP server or the JSON component
   manifest, prefer it over prose docs — the manifest is the typed source of
   truth for props and variants.
